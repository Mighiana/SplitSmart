import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../utils/icon_map.dart';
import 'group_detail_screen.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _nameCtrl = TextEditingController();
  String _groupEmoji = '✈️';
  bool _isCreating = false;

  static const List<_IconOption> _iconOptions = [
    _IconOption('✈️', 'Trip', Color(0xFF4F46E5)),
    _IconOption('🏠', 'Home', Color(0xFF2563EB)),
    _IconOption('🏢', 'Apartment', Color(0xFF475569)),
    _IconOption('💚', 'Couple', Color(0xFF16A34A)),
    _IconOption('👪', 'Family', Color(0xFFEA580C)),
    _IconOption('👥', 'Friends', Color(0xFF0891B2)),
    _IconOption('🛋️', 'Roommates', Color(0xFF7C3AED)),
    _IconOption('💼', 'Work', Color(0xFF334155)),
    _IconOption('🍽️', 'Food', Color(0xFFDC2626)),
    _IconOption('🛒', 'Groceries', Color(0xFF65A30D)),
    _IconOption('🧾', 'Bills', Color(0xFF0F766E)),
    _IconOption('🎉', 'Event', Color(0xFFDB2777)),
    _IconOption('🚐', 'Road Trip', Color(0xFF0284C7)),
    _IconOption('🎁', 'Gifts', Color(0xFFEA580C)),
    _IconOption('🌍', 'Other', Color(0xFF64748B), opensPicker: true),
  ];

  static const List<_IconOption> _moreIconOptions = [
    _IconOption('🎂', 'Birthday', Color(0xFFE11D48)),
    _IconOption('💍', 'Wedding', Color(0xFFBE185D)),
    _IconOption('🏖️', 'Beach', Color(0xFFF59E0B)),
    _IconOption('⛺', 'Camping', Color(0xFF15803D)),
    _IconOption('🎓', 'Study', Color(0xFF2563EB)),
    _IconOption('⚽', 'Sports', Color(0xFF059669)),
    _IconOption('🛍️', 'Shopping', Color(0xFFC026D3)),
    _IconOption('🍕', 'Dining Out', Color(0xFFDC2626)),
    _IconOption('🎮', 'Games', Color(0xFF7C3AED)),
    _IconOption('🌍', 'Other', Color(0xFF64748B)),
  ];
  CurrencyData _currency = AppState.currencies.first;
  final List<String> _members = ['You'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: TC.border(context)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '←',
                      style: TextStyle(fontSize: 18, color: TC.text(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'New Group',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: TC.text(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Group name ──────────────────────────────────────────────
            _label('Group Name'),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(fontSize: 15, color: TC.text(context)),
              decoration: const InputDecoration(
                hintText: 'Budapest Trip, Roommates...',
              ),
            ),
            const SizedBox(height: 20),

            // ── Icon picker ─────────────────────────────────────────────
            _label('Group Type'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemCount: _iconOptions.length,
              itemBuilder: (_, i) {
                final opt = _iconOptions[i];
                final active = opt.emoji == _groupEmoji;
                return Tooltip(
                  message: opt.label,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (opt.opensPicker) {
                        _showMoreGroupTypes();
                      } else {
                        setState(() => _groupEmoji = opt.emoji);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? opt.color.withValues(alpha: 0.18)
                            : TC.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? opt.color : TC.border(context),
                          width: active ? 1.7 : 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(opt.emoji, style: const TextStyle(fontSize: 19)),
                          const SizedBox(height: 4),
                          Text(
                            opt.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8.8,
                              fontWeight: FontWeight.w700,
                              color: active ? opt.color : TC.text2(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Currency ────────────────────────────────────────────────
            _label('Currency'),
            GestureDetector(
              onTap: () => _pickCurrency(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: TC.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TC.border(context), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_currency.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      '${_currency.code} — ${_currency.name}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: TC.text(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('▾', style: TextStyle(color: TC.text3(context))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Members (account-only: invite by code after creating) ──────
            _label('Members'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TC.border(context)),
              ),
              child: Row(
                children: [
                  Icon(iconForEmoji('🔗'), size: 20, color: TC.primary(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "It's just you for now. After you create the group, share its invite code so friends can join from their own phones — each person adds their own expenses.",
                      style: TextStyle(
                          fontSize: 12.5, height: 1.4, color: TC.text2(context)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Create button ───────────────────────────────────────────
            GestureDetector(
              onTap: _isCreating ? null : _createGroup,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _isCreating ? AppColors.green.withValues(alpha: 0.5) : AppColors.green,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _isCreating
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                  'Create Group →',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: TC.text3(context),
        letterSpacing: 1.5,
      ),
    ),
  );


  void _showMoreGroupTypes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TC.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'More group types',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: TC.text(context),
                ),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                ),
                itemCount: _moreIconOptions.length,
                itemBuilder: (_, i) {
                  final opt = _moreIconOptions[i];
                  final active = opt.emoji == _groupEmoji;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _groupEmoji = opt.emoji);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? opt.color.withValues(alpha: 0.18)
                            : TC.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? opt.color : TC.border(context),
                          width: active ? 1.7 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(opt.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 5),
                          Text(
                            opt.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: active ? opt.color : TC.text2(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    if (_isCreating) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast('Enter a group name!');
      return;
    }

    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    // Account-only: the group starts with just the creator; others join via the
    // invite code. The creator is keyed by their Firebase uid (or a local id if
    // signed out), and recorded as the group owner via createdBy.
    final myUid = AuthService.instance.uid;
    final isGuest = AuthService.instance.isGuest;
    final creator = GroupMember(
      id: myUid ?? GroupMember.generateLocalId(),
      name: _members.isNotEmpty ? _members.first : 'You',
      uid: myUid,
      isGuest: isGuest,
    );
    final g = GroupData(
      id: DateTime.now().microsecondsSinceEpoch,
      name: name,
      emoji: _groupEmoji,
      currency: _currency.code,
      sym: _currency.sym,
      members: [creator.name],
      roster: [creator],
      createdBy: myUid,
    );
    try {
      await state.addGroup(g);
      await AnalyticsService.logGroupCreated();
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
      }
      return;
    }
    state.currentGroup = g;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GroupDetailScreen()),
    );
  }

  void _pickCurrency(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) =>
          _CurrencyPicker(onSelect: (c) => setState(() => _currency = c)),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

// ─── Currency Picker ──────────────────────────────────────────────────────────
class _CurrencyPicker extends StatefulWidget {
  final void Function(CurrencyData) onSelect;
  const _CurrencyPicker({required this.onSelect});

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? AppState.currencies
        : AppState.currencies
              .where(
                (c) =>
                    c.code.toLowerCase().contains(_search.toLowerCase()) ||
                    c.name.toLowerCase().contains(_search.toLowerCase()),
              )
              .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: TC.border(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Currency',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: TC.text(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  style: TextStyle(fontSize: 15, color: TC.text(context)),
                  decoration: const InputDecoration(hintText: '🔍  Search...'),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final c = filtered[i];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelect(c);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: TC.border(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.code,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: TC.text(context),
                                ),
                              ),
                              Text(
                                c.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: TC.text2(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          c.sym,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Icon option model ────────────────────────────────────────────────────────
class _IconOption {
  final String emoji;
  final String label;
  final Color color;
  final bool opensPicker;
  const _IconOption(
    this.emoji,
    this.label,
    this.color, {
    this.opensPicker = false,
  });
}
