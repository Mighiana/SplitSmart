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
async function seedGroup(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection("groups").doc(id).set(data);
    if (data.inviteCode) {
      await ctx
        .firestore()
        .collection("inviteCodes")
        .doc(data.inviteCode)
        .set({ groupId: id });
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

  it("lets a non-owner member edit a legacy group with no isPremiumGroup field", async () => {
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
    await assertSucceeds(
      ctx.firestore().collection("groups").doc(groupId).update({
        name: "Legacy Renamed",
      })
    );
  });
});

// Sanity check so `mocha` exits non-empty even if emulator wiring changes.
describe("meta", () => {
  it("loaded rules file", () => {
    assert.ok(RULES.includes("isPremiumGroup"));
  });
});
