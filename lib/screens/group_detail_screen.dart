import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../l10n/app_localizations.dart';
import '../services/export_service.dart';
import '../widgets/common_widgets.dart';
import 'add_expense_screen.dart';
import 'qr_share_screen.dart';

import 'group_tabs/group_expenses_tab.dart';
import 'group_tabs/group_members_tab.dart';
import 'group_tabs/group_breakdown_tab.dart';
import 'group_tabs/group_settlements_tab.dart';

class GroupDetailScreen extends StatefulWidget {
  final String? heroTag;
  const GroupDetailScreen({super.key, this.heroTag});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with TickerProviderStateMixin {
  int _tab = 0; // 0=expenses, 1=members, 2=calc
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedCategory = ''; // '' = all
  final _searchCtrl = TextEditingController();
  late ConfettiController _confettiCtrl;

  AnimationController? _sheetCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _sheetCtrl?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final g = state.currentGroup;
    if (g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bal = state.getMyBalance(g);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Green Gradient Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 52, 20, 48),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2ec86a), Color(0xFF1aa34a)],
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                                ),
                              ),
                              const Spacer(),
                              if (_tab == 0)
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _isSearching = !_isSearching;
                                      if (!_isSearching) {
                                        _searchCtrl.clear();
                                        _searchQuery = '';
                                        _selectedCategory = '';
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 36, height: 36,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(color: _isSearching ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                                    child: const Icon(Icons.search, color: Colors.white, size: 16),
                                  ),
                                ),
                              GestureDetector(
                                onTap: () => _showExportOptions(context, state, g),
                                child: Container(
                                  height: 32, padding: const EdgeInsets.symmetric(horizontal: 12), margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                  alignment: Alignment.center,
                                  child: const Text('📤 Export', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => QRShareScreen(group: g)));
                                },
                                child: Container(
                                  height: 32, padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                  alignment: Alignment.center,
                                  child: const Text('🔗 QR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Hero(
                            tag: widget.heroTag ?? 'group_emoji_${g.id}',
                            child: Material(
                              type: MaterialType.transparency,
                              child: Container(
                                width: 80, height: 80,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
                                alignment: Alignment.center,
                                child: Text(g.emoji, style: const TextStyle(fontSize: 42)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // White Info Card
                    Container(
                      transform: Matrix4.translationValues(0.0, -20.0, 0.0),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: TC.card(context),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(g.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: TC.text(context))),
                              if (g.isArchived)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.yellowDim, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('📦 Archived', style: TextStyle(fontSize: 10, color: AppColors.yellow, fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${g.members.length} ${l.members} · ${g.currency}', style: TextStyle(fontSize: 13, color: TC.text2(context))),
                          const SizedBox(height: 16),
                          
                          // Balance + Settle Row
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bal > 0 ? AppColors.greenDim : (bal < 0 ? AppColors.redDim : AppColors.greenDim),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bal > 0 ? l.youAreOwedLabel : (bal < 0 ? l.youOweLabel : l.allSettledUpLabel),
                                      style: TextStyle(fontSize: 11, color: bal > 0 ? const Color(0xFF0D9E3E) : (bal < 0 ? AppColors.red : AppColors.green), fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bal == 0 ? l.everyoneEven : '${g.sym}${bal.abs().toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: bal >= 0 ? AppColors.green : AppColors.red),
                                    ),
                                  ],
                                ),
                                if (bal != 0)
                                  GestureDetector(
                                    onTap: () {
                                       HapticFeedback.mediumImpact();
                                       setState(() => _tab = 2); // switch to balances/breakdown
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(color: bal > 0 ? AppColors.green : AppColors.red, borderRadius: BorderRadius.circular(20)),
                                      child: Text(l.settleUp, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Quick Icons Row
                          Row(
                            children: [
                              _buildQuickIcon('➕', l.expense, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()))),
                              _buildQuickIcon('👥', l.members, () => setState(() => _tab = 1)),
                              _buildQuickIcon('⚖️', l.balancesTab, () => setState(() => _tab = 2)),
                              _buildQuickIcon('⚙️', l.settings, () => _showGroupSettings(context, state, g)),
                            ],
                          ),
                          
                          // Search field if open
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            child: _isSearching && _tab == 0
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: TextField(
                                      controller: _searchCtrl,
                                      autofocus: true,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: l.searchExpenses,
                                        prefixIcon: const Icon(Icons.search, color: AppColors.text3, size: 18),
                                        suffixIcon: _searchQuery.isNotEmpty ? GestureDetector(onTap: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }), child: const Icon(Icons.close, color: AppColors.text3, size: 18)) : null,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        filled: true,
                                        fillColor: TC.card2(context),
                                      ),
                                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            child: _isSearching && _tab == 0
                                ? Padding(padding: const EdgeInsets.only(top: 10), child: _buildCategoryChips(context))
                                : const SizedBox.shrink(),
                          ),
                          
                          // Tabs
                          _buildTabs(l),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            body: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: IndexedStack(
                index: _tab,
                children: [
                  GroupExpensesTab(
                    g: g,
                    state: state,
                    isArchived: g.isArchived,
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                  ),
                  GroupMembersTab(g: g, state: state),
                  GroupBreakdownTab(g: g, state: state),
                  GroupSettlementsTab(g: g, state: state),
                ],
              ),
            ),
          ),
          

          
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirection: math.pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 5,
              gravity: 0.2,
              colors: const [AppColors.green, AppColors.blue, AppColors.yellow, AppColors.red, AppColors.purple, AppColors.amber],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickIcon(String emoji, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: TC.card2(context), shape: BoxShape.circle, border: Border.all(color: TC.border(context), width: 1.5)),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: TC.text2(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l) {
    final labels = [l.expenses, l.members, l.breakdownTab, l.settlementsTab];
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TC.card2(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(4, (i) {
          final active = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _tab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? TC.card(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.green : TC.text2(context),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }


  Widget _buildCategoryChips(BuildContext context) {
    final g = context.read<AppState>().currentGroup;
    if (g == null || g.expenses.isEmpty) return const SizedBox.shrink();

    final seen = <String>{};
    final cats = <_ChipCat>[];
    for (final e in g.expenses) {
      if (seen.add(e.cat)) {
        final match = AppState.expenseCategories
            .where((c) => c.icon == e.cat)
            .firstOrNull;
        cats.add(_ChipCat(icon: e.cat, label: match?.label ?? e.cat));
      }
    }
    if (cats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _CategoryChip(
              label: 'All',
              icon: '🔖',
              isSelected: _selectedCategory.isEmpty,
              onTap: () => setState(() => _selectedCategory = ''),
            ),
            ...cats.map(
              (c) => _CategoryChip(
                label: c.label,
                icon: c.icon,
                isSelected: _selectedCategory == c.icon,
                onTap: () => setState(
                  () => _selectedCategory =
                      _selectedCategory == c.icon ? '' : c.icon,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupSettings(BuildContext context, AppState state, GroupData g) {
    HapticFeedback.mediumImpact();
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: g.name);
    String selectedEmoji = g.emoji;
    List<String> members = List.from(g.members);
    final memberCtrl = TextEditingController();
    final emojis = ['🏠','🍽️','✈️','🎉','💼','🛒','🎮','⚽','🏖️','🎓','💪','🎬','🎵','🏕️','🚗','❤️','🐾','🎁','🧳','💰'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text(l.groupSettings, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: TC.text(context))),
                  const SizedBox(height: 20),
  
                  // Group Name
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TC.text(context)),
                    decoration: InputDecoration(
                      labelText: l.groupName,
                      labelStyle: TextStyle(color: TC.text3(context)),
                      filled: true,
                      fillColor: TC.card2(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(selectedEmoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
  
                  // Emoji Picker
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(l.groupIcon, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 1)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: emojis.map((e) {
                        final isActive = e == selectedEmoji;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedEmoji = e),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44, height: 44,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.greenDim : TC.card(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isActive ? AppColors.green : TC.border(context), width: isActive ? 2 : 1),
                            ),
                            alignment: Alignment.center,
                            child: Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
  
                  // Members
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('MEMBERS (${members.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 1)),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: members.length,
                      itemBuilder: (_, i) {
                        final m = members[i];
                        final isYou = m == 'You';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: TC.card(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TC.border(context)),
                          ),
                          child: Row(
                            children: [
                              AvatarCircle(label: m, size: 28),
                              const SizedBox(width: 10),
                              Expanded(child: Text(m, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TC.text(context)))),
                              if (isYou)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setSheetState(() => members.removeAt(i));
                                  },
                                  child: Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 14, color: AppColors.red),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: memberCtrl,
                          style: TextStyle(fontSize: 14, color: TC.text(context)),
                          decoration: InputDecoration(
                            hintText: l.addMemberName,
                            hintStyle: TextStyle(color: TC.text3(context)),
                            filled: true,
                            fillColor: TC.card2(context),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (v) {
                            final name = v.trim();
                            if (name.isNotEmpty && !members.contains(name)) {
                              setSheetState(() { members.add(name); memberCtrl.clear(); });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final name = memberCtrl.text.trim();
                          if (name.isNotEmpty && !members.contains(name)) {
                            HapticFeedback.lightImpact();
                            setSheetState(() { members.add(name); memberCtrl.clear(); });
                          }
                        },
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.add, color: Colors.black, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
  
                  // Save Button
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final newName = nameCtrl.text.trim();
                      if (newName.isEmpty) return;
                      await state.editGroup(g, name: newName, emoji: selectedEmoji, members: members);
                      if (!context.mounted) return;
                      // Use the outer context to pop the bottom sheet, and
                      // defer setState to avoid !_debugLocked assertion.
                      try {
                        Navigator.pop(context);
                      } catch (e) {
                        debugPrint('[GroupDetail] pop failed: $e');
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() {}); // refresh parent
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.center,
                      child: Text(l.saveChanges, style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExportOptions(BuildContext context, AppState state, GroupData g) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TC.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Export Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('📄', style: TextStyle(fontSize: 24)),
              title: const Text('Export as PDF', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Detailed PDF document with expenses'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                ExportService.exportGroupPdf(g, state, context);
              },
            ),
            ListTile(
              leading: const Text('📝', style: TextStyle(fontSize: 24)),
              title: const Text('Export as Text', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Simple summary for WhatsApp or messages'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _exportToText(context, state, g);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _exportToText(BuildContext context, AppState state, GroupData g) {
    HapticFeedback.mediumImpact();
    final plan = state.buildSettlePlan(g);
    final total = g.expenses.fold(0.0, (s, e) => s + e.amount);
    final allBal = state.getAllBalances(g);

    final sb = StringBuffer();
    sb.writeln('📊 ${g.name} — Summary');
    sb.writeln('━━━━━━━━━━━━━━━━━━━');
    sb.writeln(
      '💰 Total spent: ${g.sym}${total.toStringAsFixed(2)} ${g.currency}',
    );
    sb.writeln('');
    sb.writeln('👥 Balances:');
    for (final m in g.members) {
      final b = allBal[m] ?? 0;
      final label = b > 0
          ? 'gets back ${g.sym}${b.toStringAsFixed(2)}'
          : b < 0
              ? 'owes ${g.sym}${b.abs().toStringAsFixed(2)}'
              : 'settled ✓';
      sb.writeln('  • $m: $label');
    }
    if (plan.isNotEmpty) {
      sb.writeln('');
      sb.writeln('💸 To settle up:');
      for (final p in plan) {
        sb.writeln(
          '  ${p.from} → ${p.to}: ${g.sym}${p.amount.toStringAsFixed(2)}',
        );
      }
    }
    sb.writeln('');
    sb.writeln('Shared from SplitSmart — free at Play Store');

    SharePlus.instance.share(
      ShareParams(
        text: sb.toString(),
        subject: '${g.name} expense summary',
      ),
    );
  }
}

class _ChipCat {
  final String icon, label;
  _ChipCat({required this.icon, required this.label});
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.green : TC.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.green : TC.border(context),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : TC.text(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
