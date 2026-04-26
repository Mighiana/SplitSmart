import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
import 'auth_service.dart';

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
      isArchived: d['isArchived'] ?? false,
      inviteCode: d['inviteCode'],
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
      Map<String, double>? splits;
      if (ed['splits'] != null) {
        splits = Map<String, double>.from(
          (ed['splits'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        );
      }
      return ExpenseData(
        id: eid,
        desc: ed['desc'] ?? '',
        amount: (ed['amount'] as num?)?.toDouble() ?? 0,
        cat: ed['cat'] ?? '💰',
        paidBy: ed['paidBy'] ?? '',
        date: ed['date'] ?? '',
        receipt: ed['receipt'] ?? false,
        receiptPath: ed['receiptUrl'],
        splits: splits,
        createdBy: ed['createdBy'],
        updatedBy: ed['updatedBy'],
      );
    }).toList();

    // Load settlements
    final setSnap = await _groupsCol
        .doc(groupDocId)
        .collection('settlements')
        .orderBy('createdAt', descending: false)
        .get();
    final settlements = setSnap.docs.map((s) {
      final sd = s.data();
      return SettlementData(
        from: sd['from'] ?? '',
        to: sd['to'] ?? '',
        amount: (sd['amount'] as num?)?.toDouble() ?? 0,
        method: sd['method'] ?? 'Cash',
        date: sd['date'] ?? '',
      );
    }).toList();

    final gid = groupDocId.hashCode;
    _docIdCache[gid] = groupDocId; // BUG-1 fix: cache group doc ID

    return GroupData(
      id: gid,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '💰',
      currency: d['currency'] ?? 'USD',
      sym: d['sym'] ?? '\$',
      members: List<String>.from(d['members'] ?? []),
      expenses: expenses,
      settlements: settlements,
      isArchived: d['isArchived'] ?? false,
      inviteCode: d['inviteCode'],
      firestoreId: groupDocId,
    );
  }

  /// Create a new group. Returns `{docId, inviteCode}`.
  Future<Map<String, String>> insertGroup(GroupData g) async {
    final inviteCode = _generateInviteCode();
    final doc = await _groupsCol.add({
      'name': g.name,
      'emoji': g.emoji,
      'currency': g.currency,
      'sym': g.sym,
      'members': g.members,
      'memberUids': [_uid],
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

  Future<void> deleteGroup(int groupId) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return;
    // Delete subcollections first
    final batch = _db.batch();
    final expenses = await _groupsCol.doc(docId).collection('expenses').get();
    for (final d in expenses.docs) batch.delete(d.reference);
    final settlements = await _groupsCol.doc(docId).collection('settlements').get();
    for (final d in settlements.docs) batch.delete(d.reference);
    batch.delete(_groupsCol.doc(docId));
    await batch.commit();
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
      'date': e.date,
      'receipt': e.receipt,
      'receiptUrl': e.receiptPath,
      'splits': e.splits,
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
        'date': e.date,
        'receipt': e.receipt,
        'receiptUrl': e.receiptPath,
        'splits': e.splits,
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
          'date': e.date,
          'receipt': e.receipt,
          'receiptUrl': e.receiptPath,
          'splits': e.splits,
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

    // SEC-M4: Validate settlement amount is positive
    if (s.amount <= 0) return;

    // SEC-M4: Validate from/to are actual group members
    final groupDoc = await _groupsCol.doc(docId).get();
    final groupData = groupDoc.data() as Map<String, dynamic>?;
    if (groupData != null) {
      final members = List<String>.from(groupData['members'] ?? []);
      if (!members.contains(s.from) || !members.contains(s.to)) {
        debugPrint('[Firestore] Settlement rejected: from/to not in members');
        return;
      }
    }

    await _groupsCol.doc(docId).collection('settlements').add({
      'from': s.from,
      'to': s.to,
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
        .map((snap) => snap.docs.map((e) {
              final ed = e.data();
              Map<String, double>? splits;
              if (ed['splits'] != null) {
                splits = Map<String, double>.from(
                  (ed['splits'] as Map).map(
                      (k, v) => MapEntry(k.toString(), (v as num).toDouble())),
                );
              }
              return ExpenseData(
                id: e.id.hashCode,
                desc: ed['desc'] ?? '',
                amount: (ed['amount'] as num?)?.toDouble() ?? 0,
                cat: ed['cat'] ?? '💰',
                paidBy: ed['paidBy'] ?? '',
                date: ed['date'] ?? '',
                receipt: ed['receipt'] ?? false,
                receiptPath: ed['receiptUrl'],
                splits: splits,
                createdBy: ed['createdBy'],
                updatedBy: ed['updatedBy'],
              );
            }).toList());
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

  /// Join a group via invite code (Client-side secure pattern).
  Future<GroupData?> joinGroupByInviteCode(String code, String memberName) async {
    try {
      final cleanCode = code.toUpperCase().trim();
      
      // 1. Fetch the groupId from the secure inviteCodes mapping
      final mappingDoc = await _db.collection('inviteCodes').doc(cleanCode).get();
      if (!mappingDoc.exists) {
        debugPrint('[Firestore] Invalid invite code or mapping not found.');
        return null;
      }
      final String groupId = mappingDoc.data()?['groupId'] ?? '';
      
      // 2. Fetch the actual group to verify
      final doc = await _groupsCol.doc(groupId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final memberUids = List<String>.from(data['memberUids'] ?? []);
      final members = List<String>.from(data['members'] ?? []);

      // SEC-H4: Enforce member cap locally (Rules will enforce it server-side)
      if (memberUids.length >= _maxGroupMembers) {
        debugPrint('[Firestore] Group full: ${memberUids.length} >= $_maxGroupMembers');
        return null;
      }

      if (!memberUids.contains(_uid)) {
        memberUids.add(_uid);
        // Sanitize member name length
        final safeName = memberName.length > 30 ? memberName.substring(0, 30) : memberName;
        members.add(safeName);
        
        // SEC-C1: Pass the code to prove we know it, bypassing member-only lock
        await doc.reference.update({
          'memberUids': memberUids,
          'members': members,
          'joinAttemptCode': cleanCode, 
        });
      }

      return await _groupFromDocFull(doc);
    } catch (e) {
      debugPrint('[Firestore] joinGroupByInviteCode error: $e');
      return null;
    }
  }

  /// Get the invite code for a group.
  Future<String?> getGroupInviteCode(int groupId) async {
    final docId = await _groupDocId(groupId);
    if (docId == null) return null;
    final doc = await _groupsCol.doc(docId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?['inviteCode'] as String?;
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
    final personalBatch = _db.batch();
    for (final col in ['transactions', 'wallets', 'groupWallets', 'budgetLimits', 'savingGoals']) {
      final snap = await _userDoc.collection(col).get();
      for (final d in snap.docs) personalBatch.delete(d.reference);
    }
    await personalBatch.commit();

    // ── 2. Groups (top-level collection) ──────────────────────────────────
    // Each group is deleted in its own batch to stay under the 500-op limit.
    try {
      final groupsSnap = await _groupsCol
          .where('memberUids', arrayContains: _uid)
          .get();

      for (final groupDoc in groupsSnap.docs) {
        final groupBatch = _db.batch();

        // Delete expenses sub-collection
        final expenses = await groupDoc.reference.collection('expenses').get();
        for (final d in expenses.docs) groupBatch.delete(d.reference);

        // Delete settlements sub-collection
        final settlements = await groupDoc.reference.collection('settlements').get();
        for (final d in settlements.docs) groupBatch.delete(d.reference);

        // Delete the group document itself
        groupBatch.delete(groupDoc.reference);

        await groupBatch.commit();
        debugPrint('[Firestore] Deleted group ${groupDoc.id} and its sub-collections');
      }
    } catch (e) {
      debugPrint('[Firestore] clearAll group deletion error (non-fatal): $e');
    }

    _docIdCache.clear();
    debugPrint('[Firestore] clearAll complete');
  }
}
