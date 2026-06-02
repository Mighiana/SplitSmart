/**
 * SplitSmart Cloud Functions
 *
 * Triggers:
 *  1. onExpenseCreated     — notifies group members when a new expense is added
 *  2. onSettlementCreated  — notifies the payee when someone settles a debt
 *  3. verifyPurchase       — server-side validation of Play/App Store receipts;
 *                            sets the `premium` custom claim + entitlement doc
 *  4. playRtdnHandler      — Google Play Real-Time Developer Notifications
 *  5. appStoreNotifications — App Store Server Notifications V2
 *  6. cleanupAnonUsers     — scheduled removal of orphan anonymous (guest) accts
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

// ─── Helper: get FCM tokens for a list of UIDs, excluding the sender ──────────
async function getTokensForUids(uids, excludeUid) {
  const tokens = [];
  for (const uid of uids) {
    if (uid === excludeUid) continue;
    try {
      const userDoc = await db.collection("users").doc(uid).get();
      if (userDoc.exists) {
        const data = userDoc.data();
        if (data.fcmTokens && Array.isArray(data.fcmTokens)) {
          tokens.push(...data.fcmTokens);
        }
      }
    } catch (e) {
      console.warn(`[FCM] Could not read tokens for ${uid}:`, e.message);
    }
  }
  return tokens;
}

// ─── Helper: sanitize text for notifications (SEC-H3) ──────────────────────────
function sanitizeNotifText(text, maxLen = 100) {
  if (!text || typeof text !== "string") return "";
  // Strip URLs to prevent phishing via push notifications
  let clean = text.replace(/https?:\/\/\S+/gi, "[link]");
  // Strip control characters
  clean = clean.replace(/[\x00-\x1F\x7F]/g, "");
  // Truncate
  if (clean.length > maxLen) clean = clean.substring(0, maxLen) + "…";
  return clean;
}

// ─── Helper: send multicast and clean up stale tokens ──────────────────────────
async function sendMulticast(tokens, notification, data, targetUids) {
  if (tokens.length === 0) return;

  const message = {
    tokens,
    notification,
    data: data || {},
    android: {
      priority: "high",
      notification: {
        channelId: "splitsmart_group",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    console.log(
      `[FCM] Sent: ${response.successCount} success, ${response.failureCount} failures`
    );

    // SEC-C2: Remove stale tokens — only scan targeted UIDs, not ALL users
    if (response.failureCount > 0) {
      const staleTokens = [];
      response.responses.forEach((res, i) => {
        if (
          !res.success &&
          res.error &&
          (res.error.code === "messaging/invalid-registration-token" ||
            res.error.code === "messaging/registration-token-not-registered")
        ) {
          staleTokens.push(tokens[i]);
        }
      });

      if (staleTokens.length > 0 && targetUids && targetUids.length > 0) {
        console.log(`[FCM] Removing ${staleTokens.length} stale tokens from ${targetUids.length} users`);
        const batch = db.batch();
        for (const uid of targetUids) {
          try {
            const userDoc = await db.collection("users").doc(uid).get();
            if (userDoc.exists) {
              const userData = userDoc.data();
              if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
                const cleaned = userData.fcmTokens.filter(
                  (t) => !staleTokens.includes(t)
                );
                if (cleaned.length !== userData.fcmTokens.length) {
                  batch.update(userDoc.ref, { fcmTokens: cleaned });
                }
              }
            }
          } catch (e) {
            console.warn(`[FCM] Could not clean tokens for ${uid}:`, e.message);
          }
        }
        await batch.commit();
      }
    }
  } catch (e) {
    console.error("[FCM] sendMulticast error:", e.message);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. NEW EXPENSE → Notify other group members
// ═══════════════════════════════════════════════════════════════════════════════

exports.onExpenseCreated = onDocumentCreated(
  "groups/{groupId}/expenses/{expenseId}",
  async (event) => {
    const expenseData = event.data?.data();
    if (!expenseData) return;

    const groupId = event.params.groupId;
    const addedBy = expenseData.addedBy; // UID of the person who added it

    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Group";
    const memberUids = groupData.memberUids || [];

    if (memberUids.length <= 1) return; // No one else to notify

    // Get tokens for all members except the sender
    const tokens = await getTokensForUids(memberUids, addedBy);

    const desc = sanitizeNotifText(expenseData.desc || "New expense", 60);
    const amount = expenseData.amount
      ? parseFloat(expenseData.amount).toFixed(2)
      : "0.00";
    const paidBy = sanitizeNotifText(expenseData.paidBy || "Someone", 30);
    const sym = groupData.sym || "$";

    await sendMulticast(tokens, {
      title: `💸 ${sanitizeNotifText(groupName, 40)}`,
      body: `${paidBy} added "${desc}" — ${sym}${amount}`,
    }, {
      type: "expense_added",
      groupId: groupId,
    }, memberUids);
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// 2. NEW SETTLEMENT → Notify the person receiving the payment
// ═══════════════════════════════════════════════════════════════════════════════

exports.onSettlementCreated = onDocumentCreated(
  "groups/{groupId}/settlements/{settlementId}",
  async (event) => {
    const settlementData = event.data?.data();
    if (!settlementData) return;

    const groupId = event.params.groupId;
    const addedBy = settlementData.addedBy; // UID who recorded the settlement

    // Get group info
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Group";
    const memberUids = groupData.memberUids || [];

    // Notify all members except the person who recorded it
    const tokens = await getTokensForUids(memberUids, addedBy);

    const from = sanitizeNotifText(settlementData.from || "Someone", 30);
    const to = sanitizeNotifText(settlementData.to || "Someone", 30);
    const amount = settlementData.amount
      ? parseFloat(settlementData.amount).toFixed(2)
      : "0.00";
    const sym = groupData.sym || "$";

    await sendMulticast(tokens, {
      title: `✅ ${sanitizeNotifText(groupName, 40)} — Settlement`,
      body: `${from} paid ${to} ${sym}${amount}`,
    }, {
      type: "settlement_added",
      groupId: groupId,
    }, memberUids);
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// PREMIUM BILLING — server-side entitlement (owner-paid; gates guest join)
// ═══════════════════════════════════════════════════════════════════════════════

// Android package name + iOS bundle id (override via env in production).
const ANDROID_PACKAGE = process.env.ANDROID_PACKAGE || "com.splitsmart.app";

// Map product IDs → subscription duration (fallback only; we prefer the store's
// own expiry timestamp when the validation response provides one).
const PRODUCT_DURATION_MS = {
  splitsmart_premium_monthly: 31 * 24 * 60 * 60 * 1000,
  splitsmart_premium_yearly: 366 * 24 * 60 * 60 * 1000,
};

/**
 * Apply (or revoke) a user's entitlement everywhere it matters:
 *  1. the `premium` custom claim (authoritative — security rules read this),
 *  2. the `users/{uid}.entitlement` mirror doc (for UX/offline),
 *  3. `isPremiumGroup` on every group the user OWNS (so guest joins resolve).
 *
 * Idempotent — safe to call repeatedly from verify + webhooks.
 */
async function applyEntitlement(uid, ent) {
  const active = !!ent.premium && (!ent.until || ent.until > Date.now());

  // 1. Custom claim (preserve any existing claims).
  try {
    const user = await auth.getUser(uid);
    const claims = Object.assign({}, user.customClaims || {});
    claims.premium = active;
    await auth.setCustomUserClaims(uid, claims);
  } catch (e) {
    console.error(`[billing] setCustomUserClaims failed for ${uid}:`, e.message);
  }

  // 2. Mirror doc.
  await db.collection("users").doc(uid).set(
    {
      entitlement: {
        premium: active,
        until: ent.until || null,
        productId: ent.productId || null,
        store: ent.store || null,
        updatedAt: FieldValue.serverTimestamp(),
      },
    },
    { merge: true }
  );

  // 3. Stamp owned groups. When entitlement lapses we set isPremiumGroup=false
  //    so NEW guest joins are blocked; existing guests are retained (no data loss).
  try {
    const owned = await db.collection("groups").where("createdBy", "==", uid).get();
    const batch = db.batch();
    owned.forEach((doc) => {
      batch.update(doc.ref, { isPremiumGroup: active });
    });
    if (!owned.empty) await batch.commit();
  } catch (e) {
    console.error(`[billing] stamping owned groups failed for ${uid}:`, e.message);
  }

  return active;
}

/**
 * Validate a Google Play subscription purchase token.
 * Returns { valid, until, productId, store }.
 */
async function validatePlay(productId, token) {
  const { google } = require("googleapis");
  const authClient = await google.auth.getClient({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const publisher = google.androidpublisher({ version: "v3", auth: authClient });
  const res = await publisher.purchases.subscriptions.get({
    packageName: ANDROID_PACKAGE,
    subscriptionId: productId,
    token,
  });
  const data = res.data || {};
  // paymentState: 1 = received, 2 = free trial. 0 = pending (not paid yet).
  const paid = data.paymentState === 1 || data.paymentState === 2;
  const until = data.expiryTimeMillis ? Number(data.expiryTimeMillis) : null;
  return {
    valid: paid && (!until || until > Date.now()),
    until,
    productId,
    store: "play",
  };
}

/**
 * Validate an App Store transaction (StoreKit 2 JWS signed transaction).
 * For brevity this decodes the signed payload; production should additionally
 * verify the x5c certificate chain against Apple's root CA.
 */
async function validateAppStore(productId, jws) {
  const jwt = require("jsonwebtoken");
  const decoded = jwt.decode(jws, { complete: true });
  if (!decoded || !decoded.payload) {
    return { valid: false, store: "appstore" };
  }
  const p = decoded.payload;
  const until = p.expiresDate ? Number(p.expiresDate) : null;
  const revoked = !!p.revocationDate;
  return {
    valid: !revoked && (!until || until > Date.now()),
    until,
    productId: p.productId || productId,
    store: "appstore",
  };
}

exports.verifyPurchase = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  // Guests (anonymous) cannot buy — only owners subscribe.
  if (request.auth.token.firebase &&
      request.auth.token.firebase.sign_in_provider === "anonymous") {
    throw new HttpsError("permission-denied", "Create an account to subscribe.");
  }

  const { store, productId, token } = request.data || {};
  if (!store || !productId || !token) {
    throw new HttpsError("invalid-argument", "Missing purchase data.");
  }

  let result;
  try {
    if (store === "play") {
      result = await validatePlay(productId, token);
    } else if (store === "appstore") {
      result = await validateAppStore(productId, token);
    } else {
      throw new HttpsError("invalid-argument", "Unknown store.");
    }
  } catch (e) {
    console.error("[billing] validation error:", e.message);
    throw new HttpsError("internal", "Could not validate the purchase.");
  }

  // Fallback expiry from product duration if the store gave none.
  if (result.valid && !result.until && PRODUCT_DURATION_MS[productId]) {
    result.until = Date.now() + PRODUCT_DURATION_MS[productId];
  }

  if (!result.valid) {
    return { valid: false };
  }

  const ent = { premium: true, until: result.until, productId, store };
  await applyEntitlement(uid, ent);
  return { valid: true, entitlement: ent };
});

// ─── Google Play Real-Time Developer Notifications (Pub/Sub) ──────────────────
// Configure Play Console → Monetization → Real-time developer notifications to
// publish to a Pub/Sub topic, then bind this function to that topic.
exports.playRtdnHandler = onMessagePublished("play-rtdn", async (event) => {
  try {
    const raw = event.data.message.data
      ? Buffer.from(event.data.message.data, "base64").toString("utf8")
      : "{}";
    const notification = JSON.parse(raw);
    const sub = notification.subscriptionNotification;
    if (!sub) return; // ignore non-subscription notifications
    const { subscriptionId, purchaseToken } = sub;

    // Look up which user owns this purchase token.
    const q = await db
      .collectionGroup("purchaseQueue")
      .where("token", "==", purchaseToken)
      .limit(1)
      .get();
    if (q.empty) {
      console.warn("[billing] RTDN: no user found for token");
      return;
    }
    const uid = q.docs[0].ref.parent.parent.id;

    const result = await validatePlay(subscriptionId, purchaseToken);
    await applyEntitlement(uid, {
      premium: result.valid,
      until: result.until,
      productId: subscriptionId,
      store: "play",
    });
  } catch (e) {
    console.error("[billing] playRtdnHandler error:", e.message);
  }
});

// ─── App Store Server Notifications V2 (HTTPS) ────────────────────────────────
exports.appStoreNotifications = onRequest(async (req, res) => {
  try {
    const jwt = require("jsonwebtoken");
    const signedPayload = req.body && req.body.signedPayload;
    if (!signedPayload) {
      res.status(400).send("missing signedPayload");
      return;
    }
    const decoded = jwt.decode(signedPayload);
    const info = decoded && decoded.data && decoded.data.signedTransactionInfo;
    if (!info) {
      res.status(202).send("ignored");
      return;
    }
    const tx = jwt.decode(info);
    const originalTxId = tx.originalTransactionId;

    const q = await db
      .collectionGroup("purchaseQueue")
      .where("token", "==", originalTxId)
      .limit(1)
      .get();
    if (!q.empty) {
      const uid = q.docs[0].ref.parent.parent.id;
      const until = tx.expiresDate ? Number(tx.expiresDate) : null;
      const revoked = !!tx.revocationDate;
      await applyEntitlement(uid, {
        premium: !revoked && (!until || until > Date.now()),
        until,
        productId: tx.productId,
        store: "appstore",
      });
    }
    res.status(200).send("ok");
  } catch (e) {
    console.error("[billing] appStoreNotifications error:", e.message);
    res.status(500).send("error");
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// GUEST HYGIENE — delete orphan anonymous accounts (no group membership)
// ═══════════════════════════════════════════════════════════════════════════════

exports.cleanupAnonUsers = onSchedule("every 24 hours", async () => {
  const cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000; // 30 days
  let nextPageToken;
  let deleted = 0;
  do {
    const list = await auth.listUsers(1000, nextPageToken);
    nextPageToken = list.pageToken;
    for (const user of list.users) {
      const isAnon =
        user.providerData.length === 0 && !user.email && !user.phoneNumber;
      if (!isAnon) continue;
      const lastActive = new Date(
        user.metadata.lastRefreshTime || user.metadata.creationTime
      ).getTime();
      if (lastActive > cutoff) continue;

      // Keep guests who still belong to a group.
      const member = await db
        .collection("groups")
        .where("memberUids", "array-contains", user.uid)
        .limit(1)
        .get();
      if (!member.empty) continue;

      try {
        await auth.deleteUser(user.uid);
        deleted++;
      } catch (e) {
        console.warn(`[cleanup] could not delete ${user.uid}:`, e.message);
      }
    }
  } while (nextPageToken);
  console.log(`[cleanup] deleted ${deleted} orphan anonymous users`);
});
