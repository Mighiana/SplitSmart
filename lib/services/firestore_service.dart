import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
import 'auth_service.dart';
import 'cloud_doc_parser.dart';

/// Cloud Firestore data service — replaces SQLite for synced data.
///
/// Schema:
///   users/{uid}/wallets/{currency}
///   users/{uid}/transactions/{txnId}
///   users/{uid}/budgetLimits/{catKey}
///   users/{uid}/savingGoals/{goalId}
///   groups/{groupId}                    ← top-level for sharing
///   groups/{groupId}/expenses/{expId}
///   groups/{groupId}/settlements/{sId}
///
/// Subscriptions and Reminders are NOT synced (kept in local SQLite).
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Test connectivity to Firestore by attempting a simple read.
  Future<bool> ping() async {
    try {
      // Try to read a dummy document with a very short timeout
      await _db.collection('ping').doc('status').get().timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('[FirestoreService] Ping failed: $e');
      return false;
    }
  }

  // BUG-1 fix: Cache mapping hashCode-based IDs → actual Firestore document IDs.
  // Populated during loads, maintained during inserts. Eliminates O(n) scans
  // and prevents hashCode collision data corruption.
  final Map<int, String> _docIdCache = {};

  String get _uid {
    final uid = AuthService.instance.uid;
    if (uid == null) throw Exception('User not signed in');
    return uid;
  }

  // ─── User profile ───────────────────────────────────────────────────────

  DocumentReference get _userDoc => _db.collection('users').doc(_uid);

  /// Create or update the user profile document.
  Future<void> saveUserProfile({
    required String name,
    String? email,
    String? photoUrl,
  }) async {
    await _userDoc.set({
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ensure user doc exists on first sign-in.
  Future<void> ensureUserDocument() async {
    final doc = await _userDoc.get();
    if (!doc.exists) {
      final authName = await AuthService.instance.displayName;
      await _userDoc.set({
        'name': authName,
        'email': AuthService.instance.email,
        'photoUrl': AuthService.instance.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPS — top-level collection for real-time collaboration
  // ═══════════════════════════════════════════════════════════════════════════

  CollectionReference get _groupsCol => _db.collection('groups');

  /// Real-time stream of all groups the current user belongs to.
  Stream<List<GroupData>> watchGroups() {
    return _groupsCol
        .where('memberUids', arrayContains: _uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(_groupFromDoc).toList();
          list.sort((a, b) => b.id.compareTo(a.id));
          return list;
        });
  }

  /// Load groups once (for app startup).
  /// NOTE: We intentionally avoid combining arrayContains + orderBy in a
  /// single Firestore query because it requires a composite index that may
  /// not exist. Instead we sort in Dart after fetching.
  Future<List<GroupData>> loadGroups() async {
    try {
      // Query: Groups where user is in memberUids
      final snap1 = await _groupsCol.where('memberUids', arrayContains: _uid).get();

      final groups = <GroupData>[];
      for (final doc in snap1.docs) {
        // CRITICAL: wrap each group individually so one failing sub-collection
        // read (expenses/settlements) doesn't wipe out ALL groups.
        try {
          groups.add(await _groupFromDocFull(doc));
        } catch (e) {
          // Fallback: add group without sub-collections rather than losing it entirely
          debugPrint('[Firestore] _groupFromDocFull failed for ${doc.id}, using shallow load: $e');
          try {
            groups.add(_groupFromDoc(doc));
          } catch (_) {}
        }
      }
      // Sort by createdAt descending in Dart (avoids composite index requirement)
      groups.sort((a, b) => b.id.compareTo(a.id));
      return groups;
    } catch (e) {
      debugPrint('[Firestore] loadGroups error: $e');
      return [];
    }
  }

  /// Build a canonical id+name roster from a group's `memberMeta` map, but ONLY
  /// when it covers every member name — otherwise return empty so the app falls
  /// back to safe name-based behavior (mixed app-user + typed-name legacy
  /// groups). Handles both new (id-keyed) and legacy (uid-keyed) meta shapes.
  List<GroupMember> _rosterFromData(Map<String, dynamic> d) {
    final meta = d['memberMeta'];
    if (meta is! Map || meta.isEmpty) return const [];
    final tmp = <GroupMember>[];
    meta.forEach((id, m) {
      if (m is Map) {
        final mm = Map<String, dynamic>.from(m);
        tmp.add(GroupMember(
          id: id.toString(),
          name: (mm['name'] ?? '').toString(),
          // Legacy meta was keyed by uid, so fall back to the key.
          uid: (mm['uid'] ?? id).toString(),
          isGuest: mm['isGuest'] == true,
        ));
      }
    });
    final memberNames = List<String>.from(d['members'] ?? []);
    final rosterNames = tmp.map((e) => e.name).toSet();
    final coversAll = memberNames.every(rosterNames.contains) &&
        tmp.length >= memberNames.length;
    return coversAll ? tmp : const [];
  }

  GroupData _groupFromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final id = doc.id.hashCode;
    _docIdCache[id] = doc.id; // BUG-1 fix: cache doc ID
    return GroupData(
      id: id,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '💰',
      currency: d['currency'] ?? 'USD',
      sym: d['sym'] ?? '\$',
      members: List<String>.from(d['members'] ?? []),
      roster: _rosterFromData(d),
      isArchived: d['isArchived'] ?? false,
      isPremiumGroup: d['isPremiumGroup'] ?? false,
      inviteCode: d['inviteCode'],
      createdBy: d['createdBy'] as String?,
      firestoreId: doc.id,
    );
  }

  /// Full load with sub-collections (expenses, settlements).
  Future<GroupData> _groupFromDocFull(DocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final groupDocId = doc.id;

    // Load expenses
    final expSnap = await _groupsCol
        .doc(groupDocId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .get();
    final expenses = expSnap.docs.map((e) {
      final ed = e.data();
      final eid = e.id.hashCode;
      _docIdCache[eid] = e.id; // BUG-1 fix: cache expense doc ID
      return CloudDocParser.expense(ed, eid);
    }).toList();

    // Load settlements
    final setSnap = await _groupsCol
        .doc(groupDocId)
        .collection('settlements')
        .orderBy('createdAt', descending: false)
        .get();
    final settlements = setSnap.docs
        .map((s) => CloudDocParser.settlement(s.data()))
        .toList();

    final gid = groupDocId.hashCode;
    _docIdCache[gid] = groupDocId; // BUG-1 fix: cache group doc ID

    return GroupData(
      id: gid,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '💰',
      currency: d['currency'] ?? 'USD',
      sym: d['sym'] ?? '\$',
      members: List<String>.from(d['members'] ?? []),
      roster: _rosterFromData(d),
      expenses: expenses,
      settlements: settlements,
      isArchived: d['isArchived'] ?? false,
      isPremiumGroup: d['isPremiumGroup'] ?? false,
      inviteCode: d['inviteCode'],
      createdBy: d['createdBy'] as String?,
      firestoreId: groupDocId,
    );
  }

  /// Create a new group. Returns `{docId, inviteCode}`.
  Future<Map<String, String>> insertGroup(GroupData g) async {
    final inviteCode = _generateInviteCode();
    // The creator's own member name = first non-'You' label if present,
    // else their display name, else 'You'. We record an authoritative
    // uid→name mapping in `memberMeta` to fix the legacy parallel-array bug.
    final ownerName = g.members.isNotEmpty ? g.members.first : 'You';
    // Authoritative memberId → {name, uid?, isGuest} mapping. When the caller
    // supplies a roster (post-refactor), persist EVERY member (incl. typed ones
    // with generated ids) so balances can be id-keyed. Else fall back to an
    // owner-only entry keyed by uid (legacy shape).
    final Map<String, dynamic> memberMeta = {};
    final List<String> memberUids = [_uid];
    if (g.roster.isNotEmpty) {
      for (final m in g.roster) {
        memberMeta[m.id] = {
          'name': m.name,
          if (m.uid != null) 'uid': m.uid,
          'isGuest': m.isGuest,
        };
        if (m.uid != null && !memberUids.contains(m.uid)) memberUids.add(m.uid!);
      }
    } else {
      memberMeta[_uid] = {
        'name': ownerName,
        'uid': _uid,
        'isGuest': AuthService.instance.isGuest,
        'provider': AuthService.instance.isGuest ? 'anonymous' : 'full',
      };
    }
    final doc = await _groupsCol.add({
      'name': g.name,
      'emoji': g.emoji,
      'currency': g.currency,
      'sym': g.sym,
      'members': g.members,
      'memberUids': memberUids,
      'memberMeta': memberMeta,
      // Guest-join gate. Flipped to true only when a PREMIUM owner enables
      // guest access (enforced by security rules via the `premium` claim).
      'isPremiumGroup': false,
      'isArchived': false,
      'createdBy': _uid,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // SEC-C5: Store code mapping in separate collection to prevent group scraping
    try {
      await _db.collection('inviteCodes').doc(inviteCode).set({'groupId': doc.id});
    } catch (e) {
      debugPrint('[Firestore] Failed to save invite code mapping: $e');
    }
    
    _docIdCache[g.id] = doc.id; // Map local ID to Firestore doc ID
    return {'docId': doc.id, 'inviteCode': inviteCode};
  }

  /// Get the Firestore doc ID for a group by its hashCode ID.
  /// BUG-1 fix: uses cache first, falls back to query only if cache miss.
  Future<String?> _groupDocId(int groupId) async {
    // Fast path: cache hit
    final cached = _docIdCache[groupId];
    if (cached != null) return cached;

    // Slow path: query and rebuild cache
    final snap = await _groupsCol.where('memberUids', arrayContains: _uid).get();
    for (final doc in snap.docs) {
      _docIdCache[doc.id.hashCode] = doc.id;
      if (doc.id.hashCode == groupId) return doc.id;
    }
    return null;
  }

  /// Allows AppState to restore the in-memory cache from SQLite-persisted
  /// firestoreId values after an app kill/restart — avoids a slow Firestore
  /// query for every mutation on the first session after a cold start.
  void cacheDocId(int localId, String firestoreDocId) {
    _docIdCache[localId] = firestoreDocId;
  }

  /// Update group name, emoji, and members.
  Future<void> updateGroup(GroupData g) async {
    final docId = await _groupDocId(g.id);
    if (docId == null) return;
    await _groupsCol.doc(docId).update({
      'name': g.name,
      'emoji': g.emoji,
      'members': g.members,
    });
  }

  Future<void> setGroupArchived(int groupId, bool archived) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;
    await _groupsCol.doc(docId).update({'isArchived': archived});
  }

  /// Remove a member from a group: drops their uid from `memberUids`, their
  /// display name from `members`, and their `memberMeta` entry. Used for a
  /// member leaving (uid == self) and the creator removing someone.
  Future<void> removeMemberFromGroup(int groupId, String uid, String name) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;
    await _groupsCol.doc(docId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
      'members': FieldValue.arrayRemove([name]),
      'memberMeta.$uid': FieldValue.delete(),
    });
  }

  Future<void> deleteGroup(GroupData g) async {
    final docId = g.firestoreId ?? await _groupDocId(g.id);
    if (docId == null) {
      debugPrint('[Firestore] Could not find docId for group ${g.name}.');
      return;
    }

    // ── Phase A: delete sub-collections (best-effort) ──────────────────────
    // Each sub-doc is deleted independently so one failure doesn't block the rest.
    try {
      final expenses = await _groupsCol.doc(docId).collection('expenses').get();
      for (final d in expenses.docs) {
        try { await d.reference.delete(); } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Firestore] deleteGroup: expense fetch failed: $e');
    }
    try {
      final settlements = await _groupsCol.doc(docId).collection('settlements').get();
      for (final d in settlements.docs) {
        try { await d.reference.delete(); } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Firestore] deleteGroup: settlement fetch failed: $e');
    }

    // ── Phase B: delete the group document itself ──────────────────────────
    // Runs even if Phase A had partial failures.
    try {
      await _groupsCol.doc(docId).delete();
      debugPrint('[Firestore] deleteGroup: deleted group $docId');
    } catch (e) {
      debugPrint('[Firestore] deleteGroup: delete denied, removing from memberUids: $e');
      // Fallback: remove user from memberUids so the group won't reappear.
      try {
        await _groupsCol.doc(docId).update({
          'memberUids': FieldValue.arrayRemove([_uid]),
        });
      } catch (e2) {
        debugPrint('[Firestore] deleteGroup: memberUids fallback also failed: $e2');
      }
    }
  }

  // ─── Group Expenses ─────────────────────────────────────────────────────

  Future<void> insertExpense(int groupId, ExpenseData e) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;
    final doc = await _groupsCol.doc(docId).collection('expenses').add({
      'desc': e.desc,
      'amount': e.amount,
      'cat': e.cat,
      'paidBy': e.paidBy,
      'paidById': e.paidById,
      'date': e.date,
      'receipt': e.receipt,
      'receiptUrl': e.receiptPath,
      'splits': e.splits,
      'splitIds': e.splitIds,
      'subcat': e.subcat,
      'addedBy': _uid,
      'createdBy': e.createdBy,
      'updatedBy': e.updatedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _docIdCache[e.id] = doc.id; // Map local expense ID to Firestore doc ID
  }

  Future<void> updateExpense(int groupId, ExpenseData e) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;
    // BUG-1 fix: use cached doc ID for direct lookup
    final expDocId = _docIdCache[e.id];
    if (expDocId != null) {
      await _groupsCol.doc(docId).collection('expenses').doc(expDocId).update({
        'desc': e.desc,
        'amount': e.amount,
        'cat': e.cat,
        'paidBy': e.paidBy,
        'paidById': e.paidById,
        'date': e.date,
        'receipt': e.receipt,
        'receiptUrl': e.receiptPath,
        'splits': e.splits,
        'splitIds': e.splitIds,
        'subcat': e.subcat,
        'updatedBy': e.updatedBy,
      });
      return;
    }
    // Fallback: scan (should rarely happen)
    final expSnap = await _groupsCol.doc(docId).collection('expenses').get();
    for (final d in expSnap.docs) {
      if (d.id.hashCode == e.id) {
        _docIdCache[e.id] = d.id;
        await d.reference.update({
          'desc': e.desc,
          'amount': e.amount,
          'cat': e.cat,
          'paidBy': e.paidBy,
          'paidById': e.paidById,
          'date': e.date,
          'receipt': e.receipt,
          'receiptUrl': e.receiptPath,
          'splits': e.splits,
          'splitIds': e.splitIds,
          'subcat': e.subcat,
          'updatedBy': e.updatedBy,
        });
        return;
      }
    }
  }

  Future<void> deleteExpense(int groupId, int expenseId) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;
    // BUG-1 fix: use cached doc ID
    final expDocId = _docIdCache[expenseId];
    if (expDocId != null) {
      await _groupsCol.doc(docId).collection('expenses').doc(expDocId).delete();
      _docIdCache.remove(expenseId);
      return;
    }
    // Fallback: scan
    final expSnap = await _groupsCol.doc(docId).collection('expenses').get();
    for (final d in expSnap.docs) {
      if (d.id.hashCode == expenseId) {
        await d.reference.delete();
        _docIdCache.remove(expenseId);
        return;
      }
    }
  }

  // ─── Settlements ────────────────────────────────────────────────────────

  Future<void> insertSettlement(int groupId, SettlementData s) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;

    if (s.amount <= 0) return;

    await _groupsCol.doc(docId).collection('settlements').add({
      'from': s.from,
      'to': s.to,
      'fromId': s.fromId,
      'toId': s.toId,
      'amount': s.amount,
      'method': s.method,
      'date': s.date,
      'addedBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Real-time listeners for a specific group ───────────────────────────

  /// Watch expenses for a specific group in real-time.
  Stream<List<ExpenseData>> watchGroupExpenses(String groupDocId) {
    return _groupsCol
        .doc(groupDocId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((e) => CloudDocParser.expense(e.data(), e.id.hashCode))
            .toList());
  }

  // ─── Group invite system ────────────────────────────────────────────────

  /// Generate a short 8-char invite code using cryptographic randomness.
  /// BUG-14 fix: replaced timestamp-based generation which was predictable.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// SEC-H4: Maximum group members allowed.
  static const int _maxGroupMembers = 50;

  /// Resolve an invite code to `{groupId, name, isPremiumGroup, memberCount,
  /// memberUids, members, memberMeta}`, or null if invalid.
  ///
  /// Tries the direct Firestore reads first (works on the Spark plan, where
  /// rules allow signed-in single-doc gets). If rules have been tightened to
  /// member-only reads (Blaze setup), the read is denied and we fall back to
  /// the `resolveInvite` Cloud Function — so both backend configurations work
  /// without a client update.
  Future<Map<String, dynamic>?> _resolveInvite(String cleanCode) async {
    try {
      final mapping =
          await _db.collection('inviteCodes').doc(cleanCode).get();
      if (!mapping.exists) return null;
      final groupId = mapping.data()?['groupId'] as String? ?? '';
      if (groupId.isEmpty) return null;
      final doc = await _groupsCol.doc(groupId).get();
      if (!doc.exists) return null;
      final d = doc.data() as Map<String, dynamic>;
      return {
        'groupId': groupId,
        'name': d['name'] ?? '',
        'isPremiumGroup': d['isPremiumGroup'] == true,
        'memberCount': (d['memberUids'] as List?)?.length ?? 0,
        'memberUids': List<String>.from(d['memberUids'] ?? []),
        'members': List<String>.from(d['members'] ?? []),
        'memberMeta': Map<String, dynamic>.from(d['memberMeta'] as Map? ?? {}),
      };
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        debugPrint('[Firestore] invite resolution error: $e');
        return null;
      }
      // Member-only rules are live: resolve through the Cloud Function.
      return _resolveInviteViaFunction(cleanCode);
    } catch (e) {
      debugPrint('[Firestore] invite resolution error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _resolveInviteViaFunction(
      String cleanCode) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('resolveInvite')
          .call<Map<dynamic, dynamic>>({'code': cleanCode});
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[Firestore] resolveInvite failed: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[Firestore] resolveInvite error: $e');
      return null;
    }
  }

  /// Join a group via invite code (server-resolved secure pattern).
  ///
  /// The join write must be built from CURRENT group state (the rules only
  /// allow appending exactly the caller's own entry). If another member joins
  /// between our resolve and our update, the write is rejected — so we retry
  /// with freshly resolved data a few times before giving up.
  Future<GroupData?> joinGroupByInviteCode(String code, String memberName) async {
    final cleanCode = code.toUpperCase().trim();

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        // 1. Resolve the code (direct reads on Spark, CF fallback on Blaze).
        final resolved = await _resolveInvite(cleanCode);
        if (resolved == null) {
          debugPrint('[Firestore] Invalid invite code or mapping not found.');
          return null;
        }
        final String groupId = resolved['groupId'] ?? '';
        if (groupId.isEmpty) return null;

        final memberUids = List<String>.from(resolved['memberUids'] ?? []);
        final members = List<String>.from(resolved['members'] ?? []);
        final isPremiumGroup = resolved['isPremiumGroup'] == true;
        final isGuest = AuthService.instance.isGuest;

        // GUEST GATE: anonymous users may only join groups whose owner has
        // SplitSmart Premium. Full accounts may always join via invite (free).
        // Security rules enforce the same condition server-side.
        if (isGuest && !isPremiumGroup) {
          debugPrint('[Firestore] Guest join blocked: group is not premium.');
          return null;
        }

        // SEC-H4: Enforce member cap locally (Rules enforce it server-side)
        if (memberUids.length >= _maxGroupMembers) {
          debugPrint('[Firestore] Group full: ${memberUids.length} >= $_maxGroupMembers');
          return null;
        }

        if (!memberUids.contains(_uid)) {
          memberUids.add(_uid);
          // Sanitize member name length
          final safeName = memberName.length > 30 ? memberName.substring(0, 30) : memberName;
          members.add(safeName);

          // Authoritative uid → name mapping (fixes parallel-array ambiguity).
          final memberMeta =
              Map<String, dynamic>.from(resolved['memberMeta'] as Map? ?? {});
          memberMeta[_uid] = {
            'name': safeName,
            'uid': _uid,
            'isGuest': isGuest,
            'provider': isGuest ? 'anonymous' : 'full',
          };

          // SEC-C1: Pass the code to prove we know it, bypassing member-only lock
          await _groupsCol.doc(groupId).update({
            'memberUids': memberUids,
            'members': members,
            'memberMeta': memberMeta,
            'joinAttemptCode': cleanCode,
          });
        }

        // Now a member, so the member-only `get` rule allows this read.
        final doc = await _groupsCol.doc(groupId).get();
        if (!doc.exists) return null;
        return await _groupFromDocFull(doc);
      } on FirebaseException catch (e) {
        // permission-denied here = our snapshot went stale mid-join (another
        // member joined first). Re-resolve and try again.
        if (e.code == 'permission-denied' && attempt < 3) {
          debugPrint(
              '[Firestore] join raced with another member (attempt $attempt), retrying…');
          await Future.delayed(Duration(milliseconds: 200 * attempt));
          continue;
        }
        debugPrint('[Firestore] joinGroupByInviteCode error: $e');
        return null;
      } catch (e) {
        debugPrint('[Firestore] joinGroupByInviteCode error: $e');
        return null;
      }
    }
    return null;
  }

  /// Get the invite code for a group.
  Future<String?> getGroupInviteCode(int groupId) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return null;
    final doc = await _groupsCol.doc(docId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?['inviteCode'] as String?;
  }

  /// Backfill mapping for legacy groups that have an invite code but no mapping doc
  Future<void> ensureInviteCodeMapping(int groupId, String inviteCode) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;
    try {
      await _db.collection('inviteCodes').doc(inviteCode).set({'groupId': docId});
    } catch (e) {
      debugPrint('[Firestore] Failed to ensure invite code mapping: $e');
    }
  }

  // ─── Guest access (premium, owner-controlled) ───────────────────────────

  /// Owner toggles guest-join for a group they own. Setting `true` requires
  /// the caller to hold the `premium` custom claim — the security rule rejects
  /// the write otherwise, so this is safe to call optimistically.
  Future<void> setGroupGuestAccess(int groupId, bool enabled) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;
    await _groupsCol.doc(docId).update({
      'isPremiumGroup': enabled,
      if (enabled) 'premiumByUid': _uid,
    });
  }

  /// Lightweight pre-join probe: does this invite code map to a group that
  /// currently allows guests? Lets the Join screen decide whether to offer
  /// "Join as guest" BEFORE creating an anonymous session.
  ///
  /// Returns `{groupId, isPremiumGroup, memberCount, name}` or null if invalid.
  Future<Map<String, dynamic>?> probeInviteCode(String code) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      final resolved = await _resolveInvite(cleanCode);
      if (resolved == null) return null;
      final groupId = resolved['groupId'] as String? ?? '';
      if (groupId.isEmpty) return null;
      return {
        'groupId': groupId,
        'isPremiumGroup': resolved['isPremiumGroup'] == true,
        'memberCount': resolved['memberCount'] ?? 0,
        'name': resolved['name'] ?? '',
      };
    } catch (e) {
      debugPrint('[Firestore] probeInviteCode error: $e');
      return null;
    }
  }

  // ─── Entitlement (server-verified, read-only mirror) ────────────────────

  /// Read the server-written entitlement for the current user. The client
  /// never WRITES this — the `verifyPurchase` Cloud Function does, after
  /// validating the store receipt.
  Future<Map<String, dynamic>?> loadEntitlement() async {
    try {
      final doc = await _userDoc.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['entitlement'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[Firestore] loadEntitlement error: $e');
      return null;
    }
  }

  /// Real-time stream of the current user's entitlement (for live unlock).
  Stream<Map<String, dynamic>?> watchEntitlement() {
    return _userDoc.snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['entitlement'] as Map<String, dynamic>?;
    });
  }

  /// Persist the device's FCM-style purchase token to a queue the
  /// `verifyPurchase` callable reads. (Most flows call the callable directly;
  /// this is a durable fallback if the callable is unreachable at purchase time.)
  Future<void> queuePurchaseForVerification({
    required String store,
    required String productId,
    required String token,
  }) async {
    await _userDoc.collection('purchaseQueue').add({
      'store': store,
      'productId': productId,
      'token': token,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSONAL DATA — under users/{uid}/... (sync on open/close only)
  // ═══════════════════════════════════════════════════════════════════════════

  // ─── Transactions ───────────────────────────────────────────────────────

  CollectionReference get _txnCol => _userDoc.collection('transactions');

  Future<List<TransactionData>> loadTransactions() async {
    try {
      final snap = await _txnCol.orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        final tid = d.id.hashCode;
        _docIdCache[tid] = d.id; // BUG-1 fix: cache txn doc ID
        return TransactionData(
          id: tid,
          type: data['type'] ?? 'expense',
          desc: data['desc'] ?? '',
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
          cat: data['cat'] ?? '💰',
          subcat: data['subcat'] as String?,
          currency: data['currency'] ?? 'USD',
          sym: data['sym'] ?? '\$',
          date: data['date'] ?? '',
          receiptPath: data['receiptUrl'],
        );
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] loadTransactions error: $e');
      return [];
    }
  }

  Future<void> insertTransaction(TransactionData t) async {
    final doc = await _txnCol.add({
      'type': t.type,
      'desc': t.desc,
      'amount': t.amount,
      'cat': t.cat,
      'subcat': t.subcat,
      'currency': t.currency,
      'sym': t.sym,
      'date': t.date,
      'receiptUrl': t.receiptPath,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _docIdCache[t.id] = doc.id; // Map local txn ID to Firestore doc ID
  }

  Future<void> updateTransaction(TransactionData t) async {
    // BUG-1 fix: use cached doc ID
    final txnDocId = _docIdCache[t.id];
    if (txnDocId != null) {
      await _txnCol.doc(txnDocId).update({
        'type': t.type,
        'desc': t.desc,
        'amount': t.amount,
        'cat': t.cat,
        'subcat': t.subcat,
        'currency': t.currency,
        'sym': t.sym,
        'date': t.date,
        'receiptUrl': t.receiptPath,
      });
      return;
    }
    // Fallback: scan
    final snap = await _txnCol.get();
    for (final d in snap.docs) {
      if (d.id.hashCode == t.id) {
        _docIdCache[t.id] = d.id;
        await d.reference.update({
          'type': t.type,
          'desc': t.desc,
          'amount': t.amount,
          'cat': t.cat,
          'subcat': t.subcat,
          'currency': t.currency,
          'sym': t.sym,
          'date': t.date,
          'receiptUrl': t.receiptPath,
        });
        return;
      }
    }
  }

  Future<void> deleteTransaction(int txnId) async {
    // BUG-1 fix: use cached doc ID
    final txnDocId = _docIdCache[txnId];
    if (txnDocId != null) {
      await _txnCol.doc(txnDocId).delete();
      _docIdCache.remove(txnId);
      return;
    }
    // Fallback: scan
    final snap = await _txnCol.get();
    for (final d in snap.docs) {
      if (d.id.hashCode == txnId) {
        await d.reference.delete();
        _docIdCache.remove(txnId);
        return;
      }
    }
  }

  // ─── Wallets ────────────────────────────────────────────────────────────

  CollectionReference get _walletsCol => _userDoc.collection('wallets');

  Future<Map<String, double>> loadWallets() async {
    try {
      final snap = await _walletsCol.get();
      return {
        for (final d in snap.docs)
          d.id: ((d.data() as Map<String, dynamic>)['balance'] as num?)?.toDouble() ?? 0,
      };
    } catch (e) {
      debugPrint('[Firestore] loadWallets error: $e');
      return {};
    }
  }

  Future<void> upsertWallet(String currency, double balance) async {
    await _walletsCol.doc(currency).set({'balance': balance});
  }

  Future<void> deleteWallet(String currency) async {
    await _walletsCol.doc(currency).delete();
  }

  // ─── Group Wallets ──────────────────────────────────────────────────────

  CollectionReference get _groupWalletsCol => _userDoc.collection('groupWallets');

  Future<Map<String, double>> loadGroupWallets() async {
    try {
      final snap = await _groupWalletsCol.get();
      return {
        for (final d in snap.docs)
          d.id: ((d.data() as Map<String, dynamic>)['balance'] as num?)?.toDouble() ?? 0,
      };
    } catch (e) {
      debugPrint('[Firestore] loadGroupWallets error: $e');
      return {};
    }
  }

  Future<void> upsertGroupWallet(String currency, double balance) async {
    await _groupWalletsCol.doc(currency).set({'balance': balance});
  }

  Future<void> deleteGroupWallet(String currency) async {
    await _groupWalletsCol.doc(currency).delete();
  }

  // ─── Budget Limits ──────────────────────────────────────────────────────
  
  CollectionReference get _budgetCol => _userDoc.collection('budgetLimits');
  
  Future<Map<String, double>> loadBudgetLimits() async {
    try {
      final snap = await _budgetCol.get();
      return {
        for (final d in snap.docs)
          d.id: ((d.data() as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0,
      };
    } catch (e) {
      debugPrint('[Firestore] loadBudgetLimits error: $e');
      return {};
    }
  }

  Future<void> upsertBudgetLimit(String key, double amount) async {
    await _budgetCol.doc(key).set({'amount': amount});
  }

  // ─── Reminders ────────────────────────────────────────────────────────────

  CollectionReference get _remindersCol => _userDoc.collection('reminders');

  Future<List<ReminderData>> loadReminders() async {
    try {
      final snap = await _remindersCol.get();
      return snap.docs.map((d) {
        final map = d.data() as Map<String, dynamic>;
        final rid = d.id.hashCode;
        _docIdCache[rid] = d.id;
        return ReminderData(
          id: rid,
          title: map['title'] as String? ?? '',
          amountStr: map['amount_str'] as String? ?? '',
          date: DateTime.parse(map['date'] as String),
          isCompleted: (map['is_completed'] as bool?) ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] loadReminders error: $e');
      return [];
    }
  }

  Future<int> insertReminder(ReminderData r) async {
    final doc = await _remindersCol.add({
      'title': r.title,
      'amount_str': r.amountStr,
      'date': r.date.toIso8601String(),
      'is_completed': r.isCompleted,
    });
    final id = doc.id.hashCode;
    _docIdCache[id] = doc.id;
    return id;
  }

  Future<void> updateReminder(ReminderData r) async {
    final docId = _docIdCache[r.id];
    if (docId != null) {
      await _remindersCol.doc(docId).update({
        'title': r.title,
        'amount_str': r.amountStr,
        'date': r.date.toIso8601String(),
        'is_completed': r.isCompleted,
      });
    } else {
      // Fallback
      final snap = await _remindersCol.get();
      for (final d in snap.docs) {
        if (d.id.hashCode == r.id) {
          _docIdCache[r.id] = d.id;
          await d.reference.update({
            'title': r.title,
            'amount_str': r.amountStr,
            'date': r.date.toIso8601String(),
            'is_completed': r.isCompleted,
          });
          return;
        }
      }
    }
  }

  Future<void> deleteReminder(int id) async {
    final docId = _docIdCache[id];
    if (docId != null) {
      await _remindersCol.doc(docId).delete();
      _docIdCache.remove(id);
    } else {
      final snap = await _remindersCol.get();
      for (final d in snap.docs) {
        if (d.id.hashCode == id) {
          await d.reference.delete();
          return;
        }
      }
    }
  }

  // ─── Saving Goals ──────────────────────────────────────────────────────

  CollectionReference get _goalsCol => _userDoc.collection('savingGoals');

  Future<List<Map<String, dynamic>>> loadSavingGoals() async {
    try {
      final snap = await _goalsCol.orderBy('createdAt').get();
      return snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        final gid = d.id.hashCode;
        _docIdCache[gid] = d.id; // BUG-1 fix: cache goal doc ID
        return {
          'id': gid,
          'currency': data['currency'] ?? 'USD',
          'title': data['title'] ?? '',
          'target_amount': (data['targetAmount'] as num?)?.toDouble() ?? 0,
          'saved_amount': (data['savedAmount'] as num?)?.toDouble() ?? 0,
          'target_date': data['targetDate'],
          'icon': data['icon'],
          'color': data['color'],
          'deposits': data['deposits'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] loadSavingGoals error: $e');
      return [];
    }
  }

  Future<int> insertSavingGoal(Map<String, dynamic> data) async {
    final doc = await _goalsCol.add({
      'currency': data['currency'],
      'title': data['title'],
      'targetAmount': data['target_amount'],
      'savedAmount': data['saved_amount'] ?? 0.0,
      'targetDate': data['target_date'],
      'icon': data['icon'],
      'color': data['color'],
      'deposits': data['deposits'],
      'createdAt': FieldValue.serverTimestamp(),
    });
    final id = doc.id.hashCode;
    _docIdCache[id] = doc.id; // BUG-1 fix: cache new goal doc ID
    return id;
  }

  Future<void> updateSavingGoal(int goalId, Map<String, dynamic> data) async {
    // BUG-1 fix: use cached doc ID
    final goalDocId = _docIdCache[goalId];
    if (goalDocId != null) {
      await _goalsCol.doc(goalDocId).update({
        'currency': data['currency'],
        'title': data['title'],
        'targetAmount': data['target_amount'],
        'savedAmount': data['saved_amount'],
        'targetDate': data['target_date'],
        'icon': data['icon'],
        'color': data['color'],
        'deposits': data['deposits'],
      });
      return;
    }
    // Fallback: scan
    final snap = await _goalsCol.get();
    for (final d in snap.docs) {
      if (d.id.hashCode == goalId) {
        _docIdCache[goalId] = d.id;
        await d.reference.update({
          'currency': data['currency'],
          'title': data['title'],
          'targetAmount': data['target_amount'],
          'savedAmount': data['saved_amount'],
          'targetDate': data['target_date'],
          'icon': data['icon'],
          'color': data['color'],
          'deposits': data['deposits'],
        });
        return;
      }
    }
  }

  Future<void> deleteSavingGoal(int goalId) async {
    // BUG-1 fix: use cached doc ID
    final goalDocId = _docIdCache[goalId];
    if (goalDocId != null) {
      await _goalsCol.doc(goalDocId).delete();
      _docIdCache.remove(goalId);
      return;
    }
    // Fallback: scan
    final snap = await _goalsCol.get();
    for (final d in snap.docs) {
      if (d.id.hashCode == goalId) {
        await d.reference.delete();
        _docIdCache.remove(goalId);
        return;
      }
    }
  }

  // ─── Utility ────────────────────────────────────────────────────────────

  /// Wipe ALL user data from Firestore.
  ///
  /// This deletes:
  ///   1. All personal sub-collections under users/{uid}
  ///   2. Every group document (+ its expenses & settlements sub-collections)
  ///      where the current user is listed as a memberUid.
  ///
  /// Groups are top-level documents — they were NOT touched by the old
  /// clearAll(), which is why they kept reappearing after a data reset.
  Future<void> clearAll() async {
    // ── 1. Personal data (transactions, wallets, budgets, goals) ──────────
    // Collect all refs then delete in 400-op chunks to stay under Firestore's
    // 500-operation batch limit.
    final allPersonalRefs = <DocumentReference>[];
    for (final col in ['transactions', 'wallets', 'groupWallets', 'budgetLimits', 'savingGoals']) {
      final snap = await _userDoc.collection(col).get();
      allPersonalRefs.addAll(snap.docs.map((d) => d.reference));
    }
    const kChunk = 400;
    for (var i = 0; i < allPersonalRefs.length; i += kChunk) {
      final chunk = allPersonalRefs.sublist(i, (i + kChunk).clamp(0, allPersonalRefs.length));
      final b = _db.batch();
      for (final ref in chunk) { b.delete(ref); }
      await b.commit();
    }

    // ── 2. Groups (top-level collection) ──────────────────────────────────
    // FIXED: Two-phase deletion so that a failed expense/settlement delete
    // never prevents the group document itself from being removed.
    // Phase A: delete sub-collections (best-effort, individual docs so one
    //          failure doesn't roll back the rest).
    // Phase B: delete the group document in a SEPARATE operation — always runs
    //          even if phase A had partial failures.
    // Fallback: if even the group-doc delete is denied (e.g. the user is only
    //           a member but not the creator and rules block full delete), we
    //           strip the user's UID from memberUids so the group never shows
    //           up in future loadGroups() queries.
    try {
      final groupsSnap = await _groupsCol
          .where('memberUids', arrayContains: _uid)
          .get();

      for (final groupDoc in groupsSnap.docs) {
        // ── Phase A: sub-collections (ignore per-doc failures) ─────────────
        try {
          final expenses = await groupDoc.reference.collection('expenses').get();
          // Delete in chunks of 400 to stay under the 500-op batch limit
          const chunkSize = 400;
          for (var i = 0; i < expenses.docs.length; i += chunkSize) {
            final chunk = expenses.docs.sublist(
                i, (i + chunkSize).clamp(0, expenses.docs.length));
            final b = _db.batch();
            for (final d in chunk) {
              b.delete(d.reference);
            }
            try { await b.commit(); } catch (e) {
              debugPrint('[Firestore] clearAll: expense batch failed: $e');
            }
          }
        } catch (e) {
          debugPrint('[Firestore] clearAll: expense fetch failed: $e');
        }

        try {
          final settlements = await groupDoc.reference.collection('settlements').get();
          const chunkSize = 400;
          for (var i = 0; i < settlements.docs.length; i += chunkSize) {
            final chunk = settlements.docs.sublist(
                i, (i + chunkSize).clamp(0, settlements.docs.length));
            final b = _db.batch();
            for (final d in chunk) {
              b.delete(d.reference);
            }
            try { await b.commit(); } catch (e) {
              debugPrint('[Firestore] clearAll: settlement batch failed: $e');
            }
          }
        } catch (e) {
          debugPrint('[Firestore] clearAll: settlement fetch failed: $e');
        }

        // ── Phase B: group document itself ─────────────────────────────────
        try {
          await groupDoc.reference.delete();
          debugPrint('[Firestore] clearAll: deleted group ${groupDoc.id}');
        } catch (e) {
          debugPrint('[Firestore] clearAll: group delete denied, removing from memberUids: $e');
          // Fallback: strip the user from memberUids so the group won't
          // reappear in future loadGroups() arrayContains queries.
          try {
            await groupDoc.reference.update({
              'memberUids': FieldValue.arrayRemove([_uid]),
            });
            debugPrint('[Firestore] clearAll: removed $_uid from memberUids of ${groupDoc.id}');
          } catch (e2) {
            debugPrint('[Firestore] clearAll: memberUids fallback also failed: $e2');
          }
        }
      }
    } catch (e) {
      debugPrint('[Firestore] clearAll group fetch error: $e');
    }

    _docIdCache.clear();
    debugPrint('[Firestore] clearAll complete');
  }
}
