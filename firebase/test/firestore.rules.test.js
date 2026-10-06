/**
 * Firestore security-rules tests for the guest-join + premium gate.
 *
 * These require Java + the Firestore emulator and are intended for CI:
 *
 *   cd firebase/test
 *   npm install
 *   npm test        # runs: firebase emulators:exec --only firestore "mocha"
 *
 * They cannot run in environments without Java (the emulator JAR needs a JVM).
 */

const assert = require("assert");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");
const path = require("path");

let testEnv;

const RULES = fs.readFileSync(
  path.resolve(__dirname, "../firestore.rules"),
  "utf8"
);

// Helper: seed a group document directly (bypassing rules).
async function seedGroup(id, data, options = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    // Call ctx.firestore() ONCE and reuse it. rules-unit-testing re-applies
    // emulator settings on every .firestore() call, so a second call throws
    // "Firestore has already been started ... settings can no longer be changed".
    const db = ctx.firestore();
    await db.collection("groups").doc(id).set(data);
    if (data.inviteCode && options.mapInvite !== false) {
      await db.collection("inviteCodes").doc(data.inviteCode).set({ groupId: id });
    }
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "splitsmart-rules-test",
    firestore: { rules: RULES },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe("group creation", () => {
  it("allows a full (non-anonymous) user to create a group", async () => {
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertSucceeds(
      ctx.firestore().collection("groups").add({
        name: "Trip",
        memberUids: ["owner"],
        createdBy: "owner",
        isPremiumGroup: false,
        inviteCode: "CODE1234",
      })
    );
  });

  it("blocks an anonymous guest from creating a group", async () => {
    const ctx = testEnv.authenticatedContext("guest", {
      firebase: { sign_in_provider: "anonymous" },
    });
    await assertFails(
      ctx.firestore().collection("groups").add({
        name: "Spam",
        memberUids: ["guest"],
        createdBy: "guest",
      })
    );
  });
});

describe("invite code mappings", () => {
  it("allows the group owner to create the mapping for their own invite code", async () => {
    await seedGroup("owned", {
      name: "Trip",
      memberUids: ["owner"],
      members: ["Owner"],
      createdBy: "owner",
      isPremiumGroup: false,
      inviteCode: "OWNR1234",
    }, { mapInvite: false });
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertSucceeds(
      ctx.firestore().collection("inviteCodes").doc("OWNR1234").set({
        groupId: "owned",
      })
    );
  });

  it("blocks a non-owner from creating or poisoning an invite mapping", async () => {
    await seedGroup("owned", {
      name: "Trip",
      memberUids: ["owner"],
      members: ["Owner"],
      createdBy: "owner",
      isPremiumGroup: false,
      inviteCode: "OWNR9999",
    }, { mapInvite: false });
    const ctx = testEnv.authenticatedContext("attacker", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx.firestore().collection("inviteCodes").doc("OWNR9999").set({
        groupId: "owned",
      })
    );
  });
});

describe("guest join gate", () => {
  const groupId = "g1";
  const base = {
    name: "Trip",
    memberUids: ["owner"],
    members: ["Owner"],
    createdBy: "owner",
    inviteCode: "CODE1234",
  };

  it("allows a guest to join a PREMIUM group via invite code", async () => {
    await seedGroup(groupId, { ...base, isPremiumGroup: true });
    const ctx = testEnv.authenticatedContext("guest", {
      firebase: { sign_in_provider: "anonymous" },
    });
    await assertSucceeds(
      ctx.firestore().collection("groups").doc(groupId).update({
        memberUids: ["owner", "guest"],
        members: ["Owner", "Sam"],
        joinAttemptCode: "CODE1234",
      })
    );
  });

  it("blocks a guest from joining a NON-premium group", async () => {
    await seedGroup(groupId, { ...base, isPremiumGroup: false });
    const ctx = testEnv.authenticatedContext("guest", {
      firebase: { sign_in_provider: "anonymous" },
    });
    await assertFails(
      ctx.firestore().collection("groups").doc(groupId).update({
        memberUids: ["owner", "guest"],
        members: ["Owner", "Sam"],
        joinAttemptCode: "CODE1234",
      })
    );
  });

  it("still allows a FULL user to join a non-premium group (free)", async () => {
    await seedGroup(groupId, { ...base, isPremiumGroup: false });
    const ctx = testEnv.authenticatedContext("friend", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertSucceeds(
      ctx.firestore().collection("groups").doc(groupId).update({
        memberUids: ["owner", "friend"],
        members: ["Owner", "Alex"],
        joinAttemptCode: "CODE1234",
      })
    );
  });

  it("blocks an existing member from using the join path to add someone else", async () => {
    await seedGroup(groupId, {
      ...base,
      memberUids: ["owner", "member"],
      members: ["Owner", "Mem"],
      isPremiumGroup: true,
    });
    const ctx = testEnv.authenticatedContext("member", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx.firestore().collection("groups").doc(groupId).update({
        memberUids: ["owner", "member", "victim"],
        members: ["Owner", "Mem", "Victim"],
        joinAttemptCode: "CODE1234",
      })
    );
  });

  it("blocks invite join from rewriting group profile fields", async () => {
    await seedGroup(groupId, { ...base, isPremiumGroup: false });
    const ctx = testEnv.authenticatedContext("friend", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx.firestore().collection("groups").doc(groupId).update({
        name: "Pwned",
        memberUids: ["owner", "friend"],
        members: ["Owner", "Alex"],
        joinAttemptCode: "CODE1234",
      })
    );
  });
});

describe("group update hardening", () => {
  const groupId = "g-update";
  const base = {
    name: "Trip",
    memberUids: ["owner", "member"],
    members: ["Owner", "Mem"],
    createdBy: "owner",
    inviteCode: "UPDT1234",
    isPremiumGroup: false,
  };

  it("allows a member to leave by removing only their own uid", async () => {
    await seedGroup(groupId, base);
    const ctx = testEnv.authenticatedContext("member", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertSucceeds(
      ctx.firestore().collection("groups").doc(groupId).update({
        memberUids: ["owner"],
        members: ["Owner"],
      })
    );
  });

  it("blocks self-leave from renaming the group at the same time", async () => {
    await seedGroup(groupId, base);
    const ctx = testEnv.authenticatedContext("member", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx.firestore().collection("groups").doc(groupId).update({
        name: "Renamed",
        memberUids: ["owner"],
        members: ["Owner"],
      })
    );
  });

  it("allows the owner to remove a member", async () => {
    await seedGroup(groupId, base);
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertSucceeds(
      ctx.firestore().collection("groups").doc(groupId).update({
        memberUids: ["owner"],
        members: ["Owner"],
      })
    );
  });

  it("blocks the owner from adding arbitrary user ids without invite join", async () => {
    await seedGroup(groupId, {
      ...base,
      memberUids: ["owner"],
      members: ["Owner"],
    });
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx.firestore().collection("groups").doc(groupId).update({
        memberUids: ["owner", "victim"],
        members: ["Owner", "Victim"],
      })
    );
  });
});

describe("premium flag protection", () => {
  const groupId = "g2";

  it("blocks enabling guest access WITHOUT the premium claim", async () => {
    await seedGroup(groupId, {
      name: "Trip",
      memberUids: ["owner"],
      createdBy: "owner",
      isPremiumGroup: false,
      inviteCode: "CODE9",
    });
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
      // no premium claim
    });
    await assertFails(
      ctx.firestore().collection("groups").doc(groupId).update({
        isPremiumGroup: true,
      })
    );
  });

  it("allows enabling guest access WITH the premium claim", async () => {
    await seedGroup(groupId, {
      name: "Trip",
      memberUids: ["owner"],
      createdBy: "owner",
      isPremiumGroup: false,
      inviteCode: "CODE9",
    });
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
      premium: true,
    });
    await assertSucceeds(
      ctx.firestore().collection("groups").doc(groupId).update({
        isPremiumGroup: true,
      })
    );
  });

  it("blocks a non-owner member from editing group profile fields", async () => {
    await seedGroup(groupId, {
      name: "Legacy",
      memberUids: ["owner", "member"],
      members: ["Owner", "Mem"],
      createdBy: "owner",
      inviteCode: "CODE9",
      // NOTE: intentionally no isPremiumGroup field (legacy doc)
    });
    const ctx = testEnv.authenticatedContext("member", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx.firestore().collection("groups").doc(groupId).update({
        name: "Legacy Renamed",
      })
    );
  });
});

describe("group child document authorship", () => {
  const groupId = "g-child";
  const group = {
    name: "Trip",
    memberUids: ["owner", "member"],
    members: ["Owner", "Mem"],
    createdBy: "owner",
    inviteCode: "CHLD1234",
    isPremiumGroup: false,
  };

  beforeEach(async () => {
    await seedGroup(groupId, group);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db
        .collection("groups")
        .doc(groupId)
        .collection("expenses")
        .doc("e1")
        .set({
          amount: 12,
          desc: "Dinner",
          paidBy: "Owner",
          addedBy: "owner",
        });
      await db
        .collection("groups")
        .doc(groupId)
        .collection("settlements")
        .doc("s1")
        .set({
          amount: 5,
          from: "Mem",
          to: "Owner",
          addedBy: "member",
        });
    });
  });

  it("allows an expense author to edit normal fields", async () => {
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertSucceeds(
      ctx
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("expenses")
        .doc("e1")
        .update({ desc: "Dinner updated" })
    );
  });

  it("blocks rewriting expense addedBy on update", async () => {
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("expenses")
        .doc("e1")
        .update({ addedBy: "member" })
    );
  });

  it("blocks rewriting settlement addedBy on update", async () => {
    const ctx = testEnv.authenticatedContext("member", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("settlements")
        .doc("s1")
        .update({ addedBy: "owner" })
    );
  });

  // Shape the real client writes in FirestoreService.insertExpense.
  const clientExpense = () => ({
    desc: "Taxi",
    amount: 20,
    cat: "🚕",
    paidBy: "Mem",
    paidById: "m2",
    date: "2026-10-06",
    receipt: false,
    receiptUrl: null,
    splits: null,
    splitIds: { m1: 10, m2: 10 },
    subcat: null,
    addedBy: "member",
    createdBy: "You",
    updatedBy: null,
    createdAt: new Date(),
  });
  const memberExpenses = () =>
    testEnv
      .authenticatedContext("member", { firebase: { sign_in_provider: "google.com" } })
      .firestore()
      .collection("groups")
      .doc(groupId)
      .collection("expenses");

  it("allows a member to add an expense with the client's real shape", async () => {
    await assertSucceeds(memberExpenses().add(clientExpense()));
  });

  it("blocks wrong-typed expense fields that would break other members' sync", async () => {
    await assertFails(memberExpenses().add({ ...clientExpense(), date: 12345 }));
    await assertFails(memberExpenses().add({ ...clientExpense(), receipt: "yes" }));
    await assertFails(memberExpenses().add({ ...clientExpense(), createdBy: { x: 1 } }));
  });

  it("blocks oversized receipt URLs and padded expense docs", async () => {
    await assertFails(
      memberExpenses().add({ ...clientExpense(), receiptUrl: "x".repeat(3000) })
    );
    const padded = clientExpense();
    for (let i = 0; i < 10; i++) padded[`junk${i}`] = i;
    await assertFails(memberExpenses().add(padded));
  });

  it("validates settlement method/date types", async () => {
    const settlements = testEnv
      .authenticatedContext("member", { firebase: { sign_in_provider: "google.com" } })
      .firestore()
      .collection("groups")
      .doc(groupId)
      .collection("settlements");
    const ok = {
      from: "Mem", to: "Owner", fromId: "m2", toId: "m1", amount: 5,
      method: "Cash", date: "2026-10-06", addedBy: "member", createdAt: new Date(),
    };
    await assertSucceeds(settlements.add(ok));
    await assertFails(settlements.add({ ...ok, method: 7 }));
    await assertFails(settlements.add({ ...ok, date: ["x"] }));
  });
});

describe("user subcollection hardening", () => {
  it("blocks arbitrary user-owned backend namespaces", async () => {
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertFails(
      ctx
        .firestore()
        .collection("users")
        .doc("owner")
        .collection("adminFlags")
        .doc("x")
        .set({ enabled: true })
    );
  });

  it("allows a well-formed purchase verification queue entry", async () => {
    const ctx = testEnv.authenticatedContext("owner", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertSucceeds(
      ctx
        .firestore()
        .collection("users")
        .doc("owner")
        .collection("purchaseQueue")
        .add({
          store: "play",
          productId: "splitsmart_premium_monthly",
          token: "token-123",
          status: "pending",
        })
    );
  });
});

describe("connectivity ping", () => {
  it("allows a signed-in user to read the ping doc", async () => {
    const ctx = testEnv.authenticatedContext("anyuser", {
      firebase: { sign_in_provider: "google.com" },
    });
    await assertSucceeds(
      ctx.firestore().collection("ping").doc("status").get()
    );
  });

  it("blocks an unauthenticated client from reading the ping doc", async () => {
    const ctx = testEnv.unauthenticatedContext();
    await assertFails(
      ctx.firestore().collection("ping").doc("status").get()
    );
  });
});

// Sanity check so `mocha` exits non-empty even if emulator wiring changes.
describe("meta", () => {
  it("loaded rules file", () => {
    assert.ok(RULES.includes("isPremiumGroup"));
  });
});
