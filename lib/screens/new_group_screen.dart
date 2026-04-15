import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';
import 'group_detail_screen.dart';
import '../widgets/common_widgets.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  String _emoji = '✈️';
  CurrencyData _currency = AppState.currencies.first;
  List<String> _members = ['You'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memberCtrl.dispose();
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
                      style: TextStyle(
                        fontSize: 18,
                        color: TC.text(context),
                      ),
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

            // ── Emoji picker ────────────────────────────────────────────
            _label('Pick Emoji'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: AppState.emojis.length,
              itemBuilder: (_, i) {
                final e = AppState.emojis[i];
                final active = e == _emoji;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _emoji = e);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: active ? AppColors.greenDim : TC.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.green : TC.border(context),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 20)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

            // ── Members ─────────────────────────────────────────────────
            _label('Add Members'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberCtrl,
                    style: TextStyle(fontSize: 15, color: TC.text(context)),
                    decoration:
                        const InputDecoration(hintText: 'Member name...'),
                    onSubmitted: (_) => _addMember(),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addMember,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '+',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              children: _members
                  .map(
                    (m) => Container(
                      margin: const EdgeInsets.all(3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: TC.card(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TC.border(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: TC.text(context),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              if (m != 'You') {
                                HapticFeedback.lightImpact();
                                setState(() => _members.remove(m));
                              }
                            },
                            child: Text(
                              m == 'You' ? '·' : '×',
                              style: TextStyle(
                                color: m == 'You'
                                    ? TC.text2(context)
                                    : AppColors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 Each person adds their own expenses — no disputes about who paid what.',
              style: TextStyle(fontSize: 12, color: TC.text3(context)),
            ),
            const SizedBox(height: 28),

            // ── Create button ───────────────────────────────────────────
            GestureDetector(
              onTap: _createGroup,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
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

  void _addMember() {
    final name = _memberCtrl.text.trim();
    if (name.isEmpty) return;
    if (_members.map((m) => m.toLowerCase()).contains(name.toLowerCase())) {
      _showToast('Already added!');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _members.add(name);
      _memberCtrl.clear();
    });
  }

  void _createGroup() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast('Enter a group name!');
      return;
    }
    if (_members.length < 2) {
      _showToast('Add at least 1 member!');
      return;
    }

    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    final g = GroupData(
      id: DateTime.now().microsecondsSinceEpoch,
      name: name,
      emoji: _emoji,
      currency: _currency.code,
      sym: _currency.sym,
      members: [..._members],
    );
    state.addGroup(g);
    AnalyticsService.logGroupCreated();
    state.currentGroup = g;
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
      builder: (ctx) => _CurrencyPicker(
        onSelect: (c) => setState(() => _currency = c),
      ),
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
