import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../providers/app_state.dart';

/// Singleton SQLite service.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static Database? _db;

  Future<Database> get _database async {
    _db ??= await _init();
    return _db!;
  }

  /// Close the active DB connection. Used before backup restore to
  /// avoid writing to a stale file handle.
  Future<void> closeDatabase() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<Database> _init() async {
    final dir  = await getDatabasesPath();
    final path = join(dir, 'splitsmart_v3.db');

    return openDatabase(
      path,
      version: 19,
      onCreate: _create,
      onUpgrade: _upgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _create(Database db, int version) async {
    final batch = db.batch();

    // groups
    batch.execute('''
      CREATE TABLE groups (
        id           INTEGER PRIMARY KEY,
        name         TEXT    NOT NULL,
        emoji        TEXT    NOT NULL DEFAULT "💰",
        currency     TEXT    NOT NULL DEFAULT "USD",
        sym          TEXT    NOT NULL DEFAULT "\$",
        is_archived  INTEGER NOT NULL DEFAULT 0,
        firestore_id TEXT,
        created_by   TEXT
      )''');

    // group members
    batch.execute('''
      CREATE TABLE group_members (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id  INTEGER NOT NULL,
        name      TEXT    NOT NULL,
        member_id TEXT,
        uid       TEXT,
        is_guest  INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )''');

    // expenses
    batch.execute('''
      CREATE TABLE expenses (
        id             INTEGER PRIMARY KEY,
        group_id       INTEGER NOT NULL,
        desc           TEXT    NOT NULL,
        amount         REAL    NOT NULL,
        cat            TEXT    NOT NULL DEFAULT "🍽️",
        paid_by        TEXT    NOT NULL,
        paid_by_id     TEXT,
        date           TEXT    NOT NULL,
        receipt        INTEGER NOT NULL DEFAULT 0,
        receipt_path   TEXT,
        split_json     TEXT,
        split_ids_json TEXT,
        created_by     TEXT,
        updated_by     TEXT,
        subcat         TEXT,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )''');

    // settlements
    batch.execute('''
      CREATE TABLE settlements (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id  INTEGER NOT NULL,
        from_m    TEXT    NOT NULL,
        to_m      TEXT    NOT NULL,
        from_id   TEXT,
        to_id     TEXT,
        amount    REAL    NOT NULL,
        method    TEXT    NOT NULL DEFAULT "Cash",
        date      TEXT    NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )''');

    // personal transactions
    batch.execute('''
      CREATE TABLE transactions (
        id           INTEGER PRIMARY KEY,
        type         TEXT    NOT NULL,
        desc         TEXT    NOT NULL,
        amount       REAL    NOT NULL,
        cat          TEXT    NOT NULL,
        currency     TEXT    NOT NULL,
        sym          TEXT    NOT NULL,
        date         TEXT    NOT NULL,
        receipt_path TEXT,
        subcat       TEXT
      )''');

    // wallets — one row per currency code (Personal Finance)
    batch.execute('''
      CREATE TABLE wallets (
        currency TEXT PRIMARY KEY,
        balance  REAL NOT NULL DEFAULT 0
      )''');

    // group wallets — explicitly activated currencies for Groups
    batch.execute('''
      CREATE TABLE group_wallets (
        currency TEXT PRIMARY KEY,
        balance  REAL NOT NULL DEFAULT 0
      )''');

    // budget limits — one row per category emoji
    batch.execute('''
      CREATE TABLE budget_limits (
        cat     TEXT PRIMARY KEY,
        amount  REAL NOT NULL DEFAULT 0
      )''');

    // subscriptions
    batch.execute('''
      CREATE TABLE subscriptions (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        amount        REAL    NOT NULL,
        currency      TEXT    NOT NULL,
        sym           TEXT    NOT NULL,
        cycle         TEXT    NOT NULL DEFAULT 'monthly',
        billing_day   INTEGER NOT NULL DEFAULT 1,
        billing_month INTEGER NOT NULL DEFAULT 1,
        category      TEXT    NOT NULL DEFAULT 'Other',
        emoji         TEXT    NOT NULL DEFAULT '📱',
        color_hex     TEXT    NOT NULL DEFAULT '#00D68F',
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT    NOT NULL
      )''');

    // reminders
    batch.execute('''
      CREATE TABLE reminders (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        title         TEXT    NOT NULL,
        amount_str    TEXT    NOT NULL DEFAULT '',
        date          TEXT    NOT NULL,
        is_completed  INTEGER NOT NULL DEFAULT 0
      )''');

    // saving goals
    batch.execute('''
      CREATE TABLE saving_goals (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        currency      TEXT    NOT NULL,
        title         TEXT    NOT NULL,
        target_amount REAL    NOT NULL,
        saved_amount  REAL    NOT NULL DEFAULT 0,
        target_date   TEXT,
        icon          TEXT,
        color         TEXT
      )''');

    // named budgets (Phase A)
    batch.execute('''
      CREATE TABLE budgets (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        name             TEXT    NOT NULL,
        period           TEXT    NOT NULL DEFAULT 'monthly',
        amount           REAL    NOT NULL,
        currency         TEXT    NOT NULL,
        categories       TEXT,
        notify_overspent INTEGER NOT NULL DEFAULT 1,
        icon             TEXT,
        color            TEXT
      )''');

    await batch.commit(noResult: true);

    // Performance indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_group ON expenses(group_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_currency ON transactions(currency)');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE groups ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0');
      } catch (e) { debugPrint('[DB] migration v2 failed: $e'); }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS budget_limits (
            cat     TEXT PRIMARY KEY,
            amount  REAL NOT NULL DEFAULT 0
          )''');
      } catch (e) { debugPrint('[DB] migration v3 failed: $e'); }
    }
    if (oldVersion < 4) {
      // add receipt_path to existing tables
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN receipt_path TEXT');
      } catch (e) { debugPrint('[DB] migration v4 expenses failed: $e'); }
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN receipt_path TEXT');
      } catch (e) { debugPrint('[DB] migration v4 transactions failed: $e'); }
    }
    if (oldVersion < 5) {
      // add custom split JSON column
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN split_json TEXT');
      } catch (e) { debugPrint('[DB] migration v5 failed: $e'); }
    }
    if (oldVersion < 6) {
      // add subscriptions table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS subscriptions (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            name          TEXT    NOT NULL,
            amount        REAL    NOT NULL,
            currency      TEXT    NOT NULL,
            sym           TEXT    NOT NULL,
            cycle         TEXT    NOT NULL DEFAULT 'monthly',
            billing_day   INTEGER NOT NULL DEFAULT 1,
            billing_month INTEGER NOT NULL DEFAULT 1,
            category      TEXT    NOT NULL DEFAULT 'Other',
            emoji         TEXT    NOT NULL DEFAULT '📱',
            color_hex     TEXT    NOT NULL DEFAULT '#00D68F',
            is_active     INTEGER NOT NULL DEFAULT 1,
            created_at    TEXT    NOT NULL
          )''');
      } catch (e) { debugPrint('[DB] migration v6 failed: $e'); }
    }
    if (oldVersion < 7) {
      // add reminders table in v7
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reminders (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            title         TEXT    NOT NULL,
            amount_str    TEXT    NOT NULL DEFAULT '',
            date          TEXT    NOT NULL,
            is_completed  INTEGER NOT NULL DEFAULT 0
          )''');
      } catch (e) { debugPrint('[DB] migration v7 reminders failed: $e'); }
    }
    if (oldVersion < 8) {
      // BUG-8 fix: is_archived was already added in v2 migration.
      // This block intentionally left empty to preserve migration version numbering.
    }
    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS group_wallets (
            currency TEXT PRIMARY KEY,
            balance  REAL NOT NULL DEFAULT 0
          )''');
      } catch (e) { debugPrint('[DB] migration v9 group_wallets failed: $e'); }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS saving_goals (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            currency      TEXT    NOT NULL,
            title         TEXT    NOT NULL,
            target_amount REAL    NOT NULL,
            saved_amount  REAL    NOT NULL DEFAULT 0
          )''');
      } catch (e) { debugPrint('[DB] migration v10 saving_goals failed: $e'); }
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE saving_goals ADD COLUMN target_date TEXT');
      } catch (e) { debugPrint('[DB] migration v11 saving_goals target_date failed: $e'); }
    }
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN created_by TEXT');
        await db.execute('ALTER TABLE expenses ADD COLUMN updated_by TEXT');
      } catch (e) { debugPrint('[DB] migration v12 expenses authorship failed: $e'); }
    }
    if (oldVersion < 13) {
      // Store Firestore doc ID in SQLite so _docIdCache can be rebuilt after
      // app kills. This column is NULL for pre-v13 rows until next cloud sync.
      try {
        await db.execute('ALTER TABLE groups ADD COLUMN firestore_id TEXT');
      } catch (e) { debugPrint('[DB] migration v13 groups.firestore_id failed: $e'); }
    }
    if (oldVersion < 14) {
      // Saving goals: optional custom icon (emoji) and colour (hex string).
      try {
        await db.execute('ALTER TABLE saving_goals ADD COLUMN icon TEXT');
        await db.execute('ALTER TABLE saving_goals ADD COLUMN color TEXT');
      } catch (e) { debugPrint('[DB] migration v14 saving_goals icon/color failed: $e'); }
    }
    if (oldVersion < 15) {
      // Named budgets (Phase A).
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS budgets (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            name             TEXT    NOT NULL,
            period           TEXT    NOT NULL DEFAULT 'monthly',
            amount           REAL    NOT NULL,
            currency         TEXT    NOT NULL,
            categories       TEXT,
            notify_overspent INTEGER NOT NULL DEFAULT 1
          )''');
      } catch (e) { debugPrint('[DB] migration v15 budgets failed: $e'); }
    }
    if (oldVersion < 16) {
      // Stable member-id keying (fix duplicate-name balance corruption).
      // All additive + nullable: existing rows read back null → engine falls
      // back to name-based behavior. No data rewrite.
      Future<void> addCol(String sql) async {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('[DB] migration v16 add column skipped: $e');
        }
      }
      await addCol('ALTER TABLE group_members ADD COLUMN member_id TEXT');
      await addCol('ALTER TABLE group_members ADD COLUMN uid TEXT');
      await addCol('ALTER TABLE group_members ADD COLUMN is_guest INTEGER NOT NULL DEFAULT 0');
      await addCol('ALTER TABLE expenses ADD COLUMN paid_by_id TEXT');
      await addCol('ALTER TABLE expenses ADD COLUMN split_ids_json TEXT');
      await addCol('ALTER TABLE settlements ADD COLUMN from_id TEXT');
      await addCol('ALTER TABLE settlements ADD COLUMN to_id TEXT');
    }
    if (oldVersion < 17) {
      // Group creator uid (creator-only management). Additive + nullable.
      try {
        await db.execute('ALTER TABLE groups ADD COLUMN created_by TEXT');
      } catch (e) {
        debugPrint('[DB] migration v17 groups.created_by failed: $e');
      }
    }
    if (oldVersion < 18) {
      // Transaction sub-category key (sub:...) for granular budgets. Nullable.
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN subcat TEXT');
      } catch (e) {
        debugPrint('[DB] migration v18 transactions.subcat failed: $e');
      }
    }
    if (oldVersion < 19) {
      // Group-expense sub-category + budget icon/color. All additive+nullable.
      Future<void> addCol(String sql) async {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('[DB] migration v19 "$sql" failed: $e');
        }
      }
      await addCol('ALTER TABLE expenses ADD COLUMN subcat TEXT');
      await addCol('ALTER TABLE budgets ADD COLUMN icon TEXT');
      await addCol('ALTER TABLE budgets ADD COLUMN color TEXT');
    }
  }

  // ─── Groups ───────────────────────────────────────────────────────────────

  Future<List<GroupData>> loadGroups() async {
    final db = await _database;

    final groupRows = await db.query('groups', orderBy: 'id DESC');
    final groups    = <GroupData>[];

    for (final row in groupRows) {
      final gId = row['id'] as int;

      // members
      final mRows = await db.query('group_members',
          where: 'group_id = ?', whereArgs: [gId]);
      final members = mRows.map((r) => r['name'] as String).toList();
      // Roster only when member ids were persisted (v16+); else leave empty so
      // the engine falls back to name-based behavior for legacy data.
      final roster = <GroupMember>[];
      for (final r in mRows) {
        final mid = r['member_id'] as String?;
        if (mid != null && mid.isNotEmpty) {
          roster.add(GroupMember(
            id: mid,
            name: r['name'] as String,
            uid: r['uid'] as String?,
            isGuest: (r['is_guest'] as int? ?? 0) == 1,
          ));
        }
      }

      // expenses
      final eRows = await db.query('expenses',
          where: 'group_id = ?', whereArgs: [gId], orderBy: 'id DESC');
      final expenses = eRows.map((r) {
        Map<String, double>? splits;
        final sj = r['split_json'] as String?;
        if (sj != null) {
          final raw = jsonDecode(sj) as Map<String, dynamic>;
          splits = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }
        Map<String, double>? splitIds;
        final sij = r['split_ids_json'] as String?;
        if (sij != null) {
          final raw = jsonDecode(sij) as Map<String, dynamic>;
          splitIds = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }
        return ExpenseData(
          id:          r['id']           as int,
          desc:        r['desc']         as String,
          amount:      (r['amount'] as num).toDouble(),
          cat:         r['cat']          as String,
          paidBy:      r['paid_by']      as String,
          paidById:    r['paid_by_id']   as String?,
          date:        r['date']         as String,
          receipt:     (r['receipt'] as int) == 1,
          receiptPath: r['receipt_path'] as String?,
          splits:      splits,
          splitIds:    splitIds,
          createdBy:   r['created_by'] as String?,
          updatedBy:   r['updated_by'] as String?,
          subcat:      r['subcat']     as String?,
        );
      }).toList();

      // settlements
      final sRows = await db.query('settlements',
          where: 'group_id = ?', whereArgs: [gId], orderBy: 'id ASC');
      final settlements = sRows.map((r) => SettlementData(
            from:   r['from_m'] as String,
            to:     r['to_m']   as String,
            fromId: r['from_id'] as String?,
            toId:   r['to_id']   as String?,
            amount: (r['amount'] as num).toDouble(),
            method: r['method'] as String,
            date:   r['date']   as String,
          )).toList();

      groups.add(GroupData(
        id:          gId,
        name:        row['name']        as String,
        emoji:       row['emoji']       as String,
        currency:    row['currency']    as String,
        sym:         row['sym']         as String,
        members:     members,
        roster:      roster,
        expenses:    expenses,
        settlements: settlements,
        isArchived:  (row['is_archived'] as int? ?? 0) == 1,
        createdBy:   row['created_by'] as String?,
        firestoreId: row['firestore_id'] as String?,
      ));
    }
    return groups;
  }

  /// Member rows for [group_members], preferring the canonical roster (id+name)
  /// and falling back to plain names for legacy groups with no roster.
  List<Map<String, Object?>> _memberRows(GroupData g) {
    if (g.roster.isNotEmpty) {
      return g.roster
          .map((m) => {
                'group_id': g.id,
                'name': m.name,
                'member_id': m.id,
                'uid': m.uid,
                'is_guest': m.isGuest ? 1 : 0,
              })
          .toList();
    }
    return g.members.map((name) => {'group_id': g.id, 'name': name}).toList();
  }

  Map<String, Object?> _expenseRow(int groupId, ExpenseData e) => {
        'id': e.id,
        'group_id': groupId,
        'desc': e.desc,
        'amount': e.amount,
        'cat': e.cat,
        'paid_by': e.paidBy,
        'paid_by_id': e.paidById,
        'date': e.date,
        'receipt': e.receipt ? 1 : 0,
        'receipt_path': e.receiptPath,
        'split_json': e.splitsJson,
        'split_ids_json': e.splitIdsJson,
        'created_by': e.createdBy,
        'updated_by': e.updatedBy,
        'subcat': e.subcat,
      };

  Future<void> insertGroup(GroupData g) async {
    final db = await _database;
    await db.insert('groups', {
      'id':           g.id,
      'name':         g.name,
      'emoji':        g.emoji,
      'currency':     g.currency,
      'sym':          g.sym,
      'is_archived':  g.isArchived ? 1 : 0,
      'firestore_id': g.firestoreId,
      'created_by':   g.createdBy,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // members (clear any stale rows first so re-insert is idempotent)
    await db.delete('group_members', where: 'group_id = ?', whereArgs: [g.id]);
    for (final row in _memberRows(g)) {
      await db.insert('group_members', row);
    }
  }

  /// Atomically replace ALL synced group data in a single SQLite transaction.
  /// Because it is a transaction, an app kill mid-operation triggers a rollback
  /// — the OLD data is preserved rather than leaving the table empty.
  Future<void> atomicReplaceGroups(List<GroupData> groups) async {
    final db = await _database;
    await db.transaction((txn) async {
      // Delete FK children before parent
      await txn.delete('settlements');
      await txn.delete('expenses');
      await txn.delete('group_members');
      await txn.delete('groups');

      for (final g in groups) {
        await txn.insert('groups', {
          'id':           g.id,
          'name':         g.name,
          'emoji':        g.emoji,
          'currency':     g.currency,
          'sym':          g.sym,
          'is_archived':  g.isArchived ? 1 : 0,
          'firestore_id': g.firestoreId,
          'created_by':   g.createdBy,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        for (final row in _memberRows(g)) {
          await txn.insert('group_members', row);
        }
        for (final e in g.expenses) {
          await txn.insert('expenses', _expenseRow(g.id, e),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final s in g.settlements) {
          await txn.insert('settlements', {
            'group_id': g.id,
            'from_m':   s.from,
            'to_m':     s.to,
            'from_id':  s.fromId,
            'to_id':    s.toId,
            'amount':   s.amount,
            'method':   s.method,
            'date':     s.date,
          });
        }
      }
    });
    debugPrint('[DB] atomicReplaceGroups committed — ${groups.length} groups');
  }

  Future<void> updateGroup(GroupData g) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('groups', {
        'name':  g.name,
        'emoji': g.emoji,
      }, where: 'id = ?', whereArgs: [g.id]);

      // Replace members
      await txn.delete('group_members', where: 'group_id = ?', whereArgs: [g.id]);
      for (final row in _memberRows(g)) {
        await txn.insert('group_members', row);
      }
    });
  }

  Future<void> setGroupArchived(int id, bool archived) async {
    final db = await _database;
    await db.update('groups', {'is_archived': archived ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteGroup(int id) async {
    final db = await _database;
    await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Expenses ──────────────────────────────────────────────────────────────

  Future<void> insertExpense(int groupId, ExpenseData e) async {
    final db = await _database;
    await db.insert('expenses', _expenseRow(groupId, e),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateExpense(int groupId, ExpenseData e) async {
    final db = await _database;
    final row = _expenseRow(groupId, e)..remove('id');
    await db.update('expenses', row, where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> deleteExpense(int id) async {
    final db = await _database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Settlements ──────────────────────────────────────────────────────────

  Future<void> insertSettlement(int groupId, SettlementData s) async {
    final db = await _database;
    await db.insert('settlements', {
      'group_id': groupId,
      'from_m':   s.from,
      'to_m':     s.to,
      'from_id':  s.fromId,
      'to_id':    s.toId,
      'amount':   s.amount,
      'method':   s.method,
      'date':     s.date,
    });
  }

  // ─── Transactions ─────────────────────────────────────────────────────────

  Future<List<TransactionData>> loadTransactions() async {
    final db = await _database;
    final rows = await db.query('transactions', orderBy: 'id DESC');
    return rows.map((r) => TransactionData(
          id:          r['id']           as int,
          type:        r['type']         as String,
          desc:        r['desc']         as String,
          amount:      (r['amount'] as num).toDouble(),
          cat:         r['cat']          as String,
          currency:    r['currency']     as String,
          sym:         r['sym']          as String,
          date:        r['date']         as String,
          receiptPath: r['receipt_path'] as String?,
          subcat:      r['subcat']       as String?,
        )).toList();
  }

  Future<void> insertTransactionAtomic(TransactionData t, double newBal) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id':           t.id,
        'type':         t.type,
        'desc':         t.desc,
        'amount':       t.amount,
        'cat':          t.cat,
        'currency':     t.currency,
        'sym':          t.sym,
        'date':         t.date,
        'receipt_path': t.receiptPath,
        'subcat':       t.subcat,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('wallets', {'currency': t.currency, 'balance': newBal}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> insertTransactionRaw(TransactionData t) async {
    final db = await _database;
    await db.insert('transactions', {
      'id':           t.id,
      'type':         t.type,
      'desc':         t.desc,
      'amount':       t.amount,
      'cat':          t.cat,
      'currency':     t.currency,
      'sym':          t.sym,
      'date':         t.date,
      'receipt_path': t.receiptPath,
      'subcat':       t.subcat,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTransactionAtomic(TransactionData t, String oldCur, double revertedBal, double newBal) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('transactions', {
        'type':         t.type,
        'desc':         t.desc,
        'amount':       t.amount,
        'cat':          t.cat,
        'currency':     t.currency,
        'sym':          t.sym,
        'date':         t.date,
        'receipt_path': t.receiptPath,
        'subcat':       t.subcat,
      }, where: 'id = ?', whereArgs: [t.id]);
      
      await txn.insert('wallets', {'currency': oldCur, 'balance': revertedBal}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('wallets', {'currency': t.currency, 'balance': newBal}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> deleteTransactionAtomic(int id, String currency, double newBal) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      await txn.insert('wallets', {'currency': currency, 'balance': newBal}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  // ─── Wallets ──────────────────────────────────────────────────────────────

  Future<Map<String, double>> loadWallets() async {
    final db   = await _database;
    final rows = await db.query('wallets');
    return {for (final r in rows) r['currency'] as String: (r['balance'] as num).toDouble()};
  }

  Future<void> upsertWallet(String currency, double balance) async {
    final db = await _database;
    await db.insert(
      'wallets',
      {'currency': currency, 'balance': balance},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteWallet(String currency) async {
    final db = await _database;
    await db.delete('wallets', where: 'currency = ?', whereArgs: [currency]);
  }

  // ─── Group Wallets ────────────────────────────────────────────────────────
  
  Future<Map<String, double>> loadGroupWallets() async {
    final db   = await _database;
    try {
      final rows = await db.query('group_wallets');
      return {for (final r in rows) r['currency'] as String: (r['balance'] as num).toDouble()};
    } catch (e) {
      debugPrint('[DB] loadGroupWallets failed: $e');
      return {};
    }
  }

  Future<void> upsertGroupWallet(String currency, double balance) async {
    final db = await _database;
    await db.insert(
      'group_wallets',
      {'currency': currency, 'balance': balance},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteGroupWallet(String currency) async {
    final db = await _database;
    await db.delete('group_wallets', where: 'currency = ?', whereArgs: [currency]);
  }

  // ─── Budget limits ────────────────────────────────────────────────────────

  Future<Map<String, double>> loadBudgetLimits() async {
    final db   = await _database;
    try {
      final rows = await db.query('budget_limits');
      return {for (final r in rows) r['cat'] as String: (r['amount'] as num).toDouble()};
    } catch (e) {
      debugPrint('[DB] loadBudgetLimits failed: $e');
      return {};
    }
  }

  Future<void> upsertBudgetLimit(String cat, double amount) async {
    final db = await _database;
    await db.insert(
      'budget_limits',
      {'cat': cat, 'amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Subscriptions ────────────────────────────────────────────────────────

  Future<List<SubscriptionData>> loadSubscriptions() async {
    final db = await _database;
    try {
      final rows = await db.query('subscriptions', orderBy: 'id DESC');
      return rows.map((r) => SubscriptionData(
        id:           r['id']            as int,
        name:         r['name']          as String,
        amount:       (r['amount'] as num).toDouble(),
        currency:     r['currency']      as String,
        sym:          r['sym']           as String,
        cycle:        r['cycle']         as String,
        billingDay:   r['billing_day']   as int,
        billingMonth: r['billing_month'] as int,
        category:     r['category']      as String,
        emoji:        r['emoji']         as String,
        colorHex:     r['color_hex']     as String,
        isActive:     (r['is_active'] as int) == 1,
        createdAt:    DateTime.parse(r['created_at'] as String),
      )).toList();
    } catch (e) {
      debugPrint('[DB] loadSubscriptions failed: $e');
      return [];
    }
  }

  Future<int> insertSubscription(SubscriptionData s) async {
    final db = await _database;
    return db.insert('subscriptions', {
      'name':          s.name,
      'amount':        s.amount,
      'currency':      s.currency,
      'sym':           s.sym,
      'cycle':         s.cycle,
      'billing_day':   s.billingDay,
      'billing_month': s.billingMonth,
      'category':      s.category,
      'emoji':         s.emoji,
      'color_hex':     s.colorHex,
      'is_active':     s.isActive ? 1 : 0,
      'created_at':    s.createdAt.toIso8601String(),
    });
  }

  Future<void> updateSubscription(SubscriptionData s) async {
    final db = await _database;
    await db.update('subscriptions', {
      'name':          s.name,
      'amount':        s.amount,
      'currency':      s.currency,
      'sym':           s.sym,
      'cycle':         s.cycle,
      'billing_day':   s.billingDay,
      'billing_month': s.billingMonth,
      'category':      s.category,
      'emoji':         s.emoji,
      'color_hex':     s.colorHex,
      'is_active':     s.isActive ? 1 : 0,
    }, where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteSubscription(int id) async {
    final db = await _database;
    await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Reminders ────────────────────────────────────────────────────────────

  Future<List<ReminderData>> loadReminders() async {
    final db = await _database;
    try {
      final rows = await db.query('reminders', orderBy: 'date ASC');
      return rows.map((r) => ReminderData(
        id:          r['id']           as int,
        title:       r['title']        as String,
        amountStr:   r['amount_str']   as String,
        date:        DateTime.parse(r['date'] as String),
        isCompleted: (r['is_completed'] as int) == 1,
      )).toList();
    } catch (e) {
      debugPrint('[DB] loadReminders failed: $e');
      return [];
    }
  }

  Future<int> insertReminder(ReminderData r) async {
    final db = await _database;
    final map = <String, dynamic>{
      'title':        r.title,
      'amount_str':   r.amountStr,
      'date':         r.date.toIso8601String(),
      'is_completed': r.isCompleted ? 1 : 0,
    };
    if (r.id > 0) map['id'] = r.id;
    return db.insert('reminders', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateReminder(ReminderData r) async {
    final db = await _database;
    await db.update('reminders', {
      'title':        r.title,
      'amount_str':   r.amountStr,
      'date':         r.date.toIso8601String(),
      'is_completed': r.isCompleted ? 1 : 0,
    }, where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteReminder(int id) async {
    final db = await _database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> atomicReplaceReminders(List<ReminderData> reminders) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('reminders');
      for (final r in reminders) {
        await txn.insert('reminders', {
          'id':           r.id,
          'title':        r.title,
          'amount_str':   r.amountStr,
          'date':         r.date.toIso8601String(),
          'is_completed': r.isCompleted ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ─── Budgets (named, Phase A) ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadBudgets() async {
    final db = await _database;
    try {
      return await db.query('budgets', orderBy: 'id DESC');
    } catch (e) {
      debugPrint('[DB] loadBudgets failed: $e');
      return [];
    }
  }

  Future<int> insertBudget(Map<String, dynamic> data) async {
    final db = await _database;
    return await db.insert('budgets', data);
  }

  Future<void> updateBudget(int id, Map<String, dynamic> data) async {
    final db = await _database;
    await db.update('budgets', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBudget(int id) async {
    final db = await _database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Saving Goals ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadSavingGoals() async {
    final db = await _database;
    try {
      return await db.query('saving_goals', orderBy: 'id ASC');
    } catch (e) {
      debugPrint('[DB] loadSavingGoals failed: $e');
      return [];
    }
  }

  Future<int> insertSavingGoal(Map<String, dynamic> data) async {
    final db = await _database;
    return await db.insert('saving_goals', data);
  }

  Future<void> updateSavingGoal(int id, Map<String, dynamic> data) async {
    final db = await _database;
    await db.update('saving_goals', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSavingGoal(int id) async {
    final db = await _database;
    await db.delete('saving_goals', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Utility ──────────────────────────────────────────────────────────────


  /// Wipe only cloud-synced tables — used by _cacheToSQLite() so that
  /// local-only data (subscriptions, reminders) is preserved.
  Future<void> clearSyncedData() async {
    final db = await _database;
    final batch = db.batch();
    // FK children of groups — delete before groups
    batch.delete('settlements');
    batch.delete('expenses');
    batch.delete('group_members');
    batch.delete('groups');
    // Cloud-synced standalone tables
    batch.delete('transactions');
    batch.delete('wallets');
    batch.delete('group_wallets');
    batch.delete('budget_limits');
    batch.delete('saving_goals');
    batch.delete('reminders'); // REMINDERS ARE NOW SYNCED
    // NOTE: subscriptions are NOT cleared — they are local-only
    await batch.commit(noResult: true);
  }

  /// Wipe everything — useful for dev reset / full account data clear.
  /// Order: FK children first (settlements → expenses → group_members → groups),
  /// then standalone tables, so foreign key constraints are never violated.
  Future<void> clearAll() async {
    final db = await _database;
    final batch = db.batch();
    // FK children of groups — delete before groups
    batch.delete('settlements');
    batch.delete('expenses');
    batch.delete('group_members');
    batch.delete('groups');
    // Standalone tables — no FK ordering required
    batch.delete('transactions');
    batch.delete('wallets');
    batch.delete('group_wallets');
    batch.delete('budget_limits');
    batch.delete('subscriptions');
    batch.delete('reminders');
    batch.delete('saving_goals');
    await batch.commit(noResult: true);
  }
}
