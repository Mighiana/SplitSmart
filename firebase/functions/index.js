/**
 * SplitSmart Cloud Functions
 * 
 * Triggers:
 *  1. onExpenseCreated  — notifies group members when a new expense is added
 *  2. onSettlementCreated — notifies the payee when someone settles a debt
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

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
