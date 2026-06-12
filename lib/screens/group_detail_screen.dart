import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../utils/icon_map.dart';
import '../utils/app_utils.dart';
import '../l10n/app_localizations.dart';
import '../services/export_service.dart';
import '../widgets/common_widgets.dart';
import 'add_expense_screen.dart';
import 'qr_share_screen.dart';

import 'group_tabs/group_expenses_tab.dart';
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
      backgroundColor: const Color(0xFFF7F5F0),
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildScreenshotGroupHeader(context, state, g, l),
                    Offstage(
                      offstage: true,
                      child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 50, 20, 60),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2ab55a), Color(0xFF1a9447), Color(0xFF157a3a)],
                              stops: [0.0, 0.6, 1.0],
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
                                      height: 36, padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(50)),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
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
                                        height: 36, width: 36,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(color: _isSearching ? Colors.white.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                                        child: const Icon(Icons.search, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () => _showExportOptions(context, state, g),
                                    child: Container(
                                      height: 36, padding: const EdgeInsets.symmetric(horizontal: 12), margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(50)),
                                      alignment: Alignment.center,
                                      child: const Row(
                                        children: [
                                          Icon(Icons.ios_share, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('Export', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => QRShareScreen(group: g)));
                                    },
                                    child: Container(
                                      height: 36, padding: const EdgeInsets.symmetric(horizontal: 12), margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(50)),
                                      alignment: Alignment.center,
                                      child: const Row(
                                        children: [
                                          Icon(Icons.qr_code_scanner, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('QR', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showGroupSettings(context, state, g),
                                    child: Container(
                                      height: 36, width: 36,
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.more_horiz, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Material(
                                  type: MaterialType.transparency,
                                  child: Container(
                                    width: 100, height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 4))],
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(iconForEmoji(g.emoji), size: 46, color: AppColors.green),
                                  ),
                              )
                                  .animate(delay: 120.ms)
                                  .scale(begin: const Offset(0.88, 0.88), end: const Offset(1, 1), duration: 360.ms, curve: Curves.easeOutBack)
                                  .fadeIn(duration: 260.ms),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(child: Text(g.name, style: GoogleFonts.gloock(color: Colors.white, fontSize: 30, letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
                                  if (g.isArchived)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                      child: const Text('Archived', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              )
                                  .animate(delay: 190.ms)
                                  .fadeIn(duration: 280.ms)
                                  .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${g.members.length} ${l.members}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15)),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    width: 5, height: 5,
                                    decoration: const BoxDecoration(color: Color(0xFF6de896), shape: BoxShape.circle),
                                  ),
                                  Text(g.currency, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15)),
                                ],
                              )
                                  .animate(delay: 240.ms)
                                  .fadeIn(duration: 260.ms)
                                  .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6de896),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                      .animate(onPlay: (c) => c.repeat(reverse: true))
                                      .scale(begin: const Offset(0.72, 0.72), end: const Offset(1.18, 1.18), duration: 1200.ms)
                                      .fade(begin: 0.45, end: 1),
                                  const SizedBox(width: 7),
                                  Text(
                                    'All changes saved · Last synced just now',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                                  .animate(delay: 300.ms)
                                  .fadeIn(duration: 280.ms)
                                  .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
                            ],
                          ),
                        ),
                        // Decorators
                        Positioned(top: 60, left: 30, child: Text('+', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 18, fontWeight: FontWeight.w300))),
                        Positioned(top: 90, right: 28, child: Text('+', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14, fontWeight: FontWeight.w300))),
                        Positioned(top: 160, left: 55, child: Text('+', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12, fontWeight: FontWeight.w300))),
                        Positioned(bottom: 80, right: 50, child: Text('+', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 22, fontWeight: FontWeight.w300))),
                        Positioned(bottom: 50, left: 80, child: Text('+', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10, fontWeight: FontWeight.w300))),
                      ],
                    ),
                    ),
                    Transform.translate(
                      offset: Offset.zero,
                      child: Column(
                        children: [
                          _buildOweCard(bal, l, g)
                              .animate(delay: 340.ms)
                              .fadeIn(duration: 340.ms)
                              .slideY(begin: 0.12, end: 0, curve: Curves.easeOutBack),
                          const SizedBox(height: 16),
                          _buildActionButtons(l)
                              .animate(delay: 420.ms)
                              .fadeIn(duration: 320.ms)
                              .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
                          const SizedBox(height: 16),
                          _buildTabs(l)
                              .animate(delay: 500.ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                          
                          // Search field if open
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            child: _isSearching && _tab == 0
                                ? Padding(
                                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                                    child: TextField(
                                      controller: _searchCtrl,
                                      autofocus: true,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: l.searchExpenses,
                                        prefixIcon: const Icon(Icons.search, color: AppColors.text3, size: 18),
                                        suffixIcon: _searchQuery.isNotEmpty ? GestureDetector(onTap: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }), child: const Icon(Icons.close, color: AppColors.text3, size: 18)) : null,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE9E4DB))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE9E4DB))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF9FD1C9))),
                                        filled: true,
                                        fillColor: Colors.white,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            body: Container(
              color: const Color(0xFFF7F5F0),
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

  Widget _buildScreenshotGroupHeader(BuildContext context, AppState state, GroupData g, AppLocalizations l) {
    const avatarColors = [
      Color(0xFF0D7377),
      Color(0xFF059669),
      Color(0xFF3B82F6),
      Color(0xFFD97706),
      Color(0xFFE85A6A),
      Color(0xFF8B5CF6),
    ];

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 134,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D7377), Color(0xFF149080)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const Spacer(),
                  _HeaderPill(
                    icon: Icons.search,
                    label: 'Search',
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
                  ),
                  const SizedBox(width: 8),
                  _HeaderPill(
                    icon: Icons.inventory_2_outlined,
                    label: 'Export',
                    onTap: () => _showExportOptions(context, state, g),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: -38,
              child: Hero(
                tag: widget.heroTag ?? 'group_emoji_${g.id}',
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D7377).withValues(alpha: 0.18),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(iconForEmoji(g.emoji), size: 30, color: AppColors.green),
                  ),
                ),
              )
                  .animate(delay: 120.ms)
                  .scale(begin: const Offset(0.88, 0.88), end: const Offset(1, 1), duration: 360.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 260.ms),
            ),
          ],
        ),
        const SizedBox(height: 58),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              Text(
                g.name,
                style: GoogleFonts.gloock(
                  color: const Color(0xFF111918),
                  fontSize: 31,
                  letterSpacing: -0.9,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).animate(delay: 190.ms).fadeIn(duration: 280.ms).slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 9),
              Text(
                '${g.members.length} ${l.members} · ${g.currency} · ${g.expenses.length} expenses',
                style: const TextStyle(
                  color: Color(0xFF9BB5B0),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(0.75, 0.75), end: const Offset(1.2, 1.2), duration: 1200.ms)
                      .fade(begin: 0.45, end: 1),
                  const SizedBox(width: 8),
                  const Text(
                    'All changes saved · Last synced just now',
                    style: TextStyle(
                      color: Color(0xFF009B73),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(g.members.length, (i) {
                    final name = g.members[i];
                    final left = (i - (g.members.length - 1) / 2) * 27.0;
                    return Transform.translate(
                      offset: Offset(left, 0),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: avatarColors[i % avatarColors.length],
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF7F5F0), width: 2.3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOweCard(double bal, AppLocalizations l, GroupData g) {
    final total = g.expenses.fold<double>(0, (sum, e) => sum + e.amount);
    // "Paid by you" = expenses whose payer matches the current user's identity
    // in this group (the 'You' convention or their actual display name).
    final myName = context.read<AppState>().userName.trim().toLowerCase();
    final paidByYou = g.expenses
        .where((e) {
          final payer = e.paidBy.trim().toLowerCase();
          return payer == 'you' || (myName.isNotEmpty && payer == myName);
        })
        .fold<double>(0, (sum, e) => sum + e.amount);
    final balanceLabel = bal < 0 ? l.youOweLabel.toUpperCase() : 'YOU OWE';
    final balanceColor = bal < 0 ? const Color(0xFFE85A6A) : const Color(0xFF009B73);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            _SummaryCell(label: 'GROUP TOTAL', value: '${g.sym}${total.toStringAsFixed(0)}'),
            Container(width: 1, height: 76, color: const Color(0xFFE9E4DB)),
            _SummaryCell(label: 'YOU PAID', value: '${g.sym}${paidByYou.toStringAsFixed(0)}'),
            Container(width: 1, height: 76, color: const Color(0xFFE9E4DB)),
            _SummaryCell(label: balanceLabel, value: '${g.sym}${bal.abs().toStringAsFixed(0)}', valueColor: balanceColor),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOweCardLegacy(double bal, AppLocalizations l, GroupData g) {
    final bool isOwed = bal > 0;
    final bool owes = bal < 0;
    final bool settled = bal == 0;
    
    final Color bgColor = owes ? const Color(0xFFfff5f5) : (isOwed ? const Color(0xFFf0fdf4) : Colors.white);
    final Color borderColor = owes ? const Color.fromRGBO(255, 120, 120, 0.15) : (isOwed ? const Color.fromRGBO(34, 197, 94, 0.15) : const Color(0xFFf0f0f0));
    final Color labelColor = owes ? const Color(0xFFe84040) : (isOwed ? const Color(0xFF1fa84a) : const Color(0xFF888888));
    final Color amountColor = owes ? const Color(0xFFe84040) : (isOwed ? const Color(0xFF1fa84a) : const Color(0xFF1a1a1a));
    
    final String labelText = isOwed ? l.youAreOwedLabel : (owes ? l.youOweLabel : l.allSettledUpLabel);
    final String amountText = settled ? l.everyoneEven : '${g.sym}${bal.abs().toStringAsFixed(2)}';
    final String subText = owes ? 'Settle up and clear your balance.' : (isOwed ? 'Someone owes you money.' : 'No pending balances.');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labelText, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(amountText, style: TextStyle(color: amountColor, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1)),
                const SizedBox(height: 4),
                Text(subText, style: const TextStyle(color: Color(0xFFaaaaaa), fontSize: 12)),
              ],
            ),
          ),
          if (!settled)
            GestureDetector(
              onTap: () {
                 HapticFeedback.mediumImpact();
                 setState(() => _tab = 3); // switch to Settle tab
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: owes 
                    ? const LinearGradient(colors: [Color(0xFFff6b6b), Color(0xFFe84040)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : const LinearGradient(colors: [Color(0xFF2ab55a), Color(0xFF1a9447)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: owes ? const Color.fromRGBO(232, 64, 64, 0.35) : const Color.fromRGBO(26, 148, 71, 0.35), 
                      blurRadius: 16, 
                      offset: const Offset(0, 4)
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Text(l.settleUp, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          _GroupActionTile(
            icon: Icons.add_rounded,
            label: l.addExpense,
            primary: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
          ),
          const SizedBox(width: 10),
          _GroupActionTile(
            icon: Icons.settings_rounded,
            label: l.settings,
            onTap: () {
              final g = context.read<AppState>().currentGroup;
              if (g != null) _showGroupSettings(context, context.read<AppState>(), g);
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildActionButtonsLegacy(AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFf0f0f0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          _buildActionItem(
            icon: const Icon(Icons.add, color: Color(0xFF1fa84a), size: 26),
            iconBg: const Color(0xFFe8f8ee),
            label: l.expense,
            sub: 'Record new',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
          ),
          Container(width: 1, height: 44, color: const Color(0xFFf0f0f0)),
          _buildActionItem(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF666666), size: 24),
            iconBg: const Color(0xFFf2f2f2),
            label: l.settings,
            sub: 'Preferences',
            onTap: () {
              final g = context.read<AppState>().currentGroup;
              if (g != null) _showGroupSettings(context, context.read<AppState>(), g);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({required Widget icon, required Color iconBg, required String label, required String sub, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1a1a1a)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFFaaaaaa)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l) {
    final labels = ['Expenses', 'Breakdown', 'Settle Up'];
    return SizedBox(
      height: 39,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = _tab == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _tab = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE7F3F0) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: active ? const Color(0xFF9FD1C9) : const Color(0xFFE9E4DB)),
              ),
              child: Center(
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: active ? const Color(0xFF0D7377) : const Color(0xFF9BB5B0),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTabsLegacy(AppLocalizations l) {
    // Use short labels to prevent overflow in the compact pill tabs
    const shortLabels = ['Expenses', 'Members', 'Breakdown', 'Settle'];
    final icons = [Icons.receipt_long_outlined, Icons.people_outline, Icons.pie_chart_outline, Icons.compare_arrows];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFf2f3f5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFe8e8e8)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
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
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: active ? 1.1 : 1.0,
                      child: Icon(
                        icons[i],
                        size: 17,
                        color: active ? const Color(0xFF1fa84a) : const Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shortLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? const Color(0xFF1fa84a) : const Color(0xFF999999),
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
    // Only the creator may edit the group; everyone else gets a read-only view
    // plus the ability to leave. Legacy groups (no createdBy) fall back to the
    // first-member convention so their owner can still manage them.
    final bool isCreator =
        g.isCreatedBy(AuthService.instance.uid, displayName: state.userName);
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
  
                  // Group Name — editable for the creator, read-only otherwise.
                  if (isCreator)
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
                          child: Icon(iconForEmoji(selectedEmoji), size: 20, color: AppColors.green),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: TC.card2(context), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Icon(iconForEmoji(selectedEmoji), size: 20, color: AppColors.green),
                        const SizedBox(width: 12),
                        Expanded(child: Text(g.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context)))),
                      ]),
                    ),
                  const SizedBox(height: 16),

                  // Emoji Picker — creator only.
                  if (isCreator) ...[
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
                              child: Icon(iconForEmoji(e), size: 22, color: isActive ? AppColors.green : TC.text2(context)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
  
                  // Members — real account-holders. Only the creator can remove.
                  Builder(builder: (mctx) {
                    final roster = g.roster;
                    final names = roster.isNotEmpty
                        ? roster.map((m) => m.name).toList()
                        : g.members;
                    final myUid = AuthService.instance.uid;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('MEMBERS (${names.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 1)),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: names.length,
                            itemBuilder: (_, i) {
                              final name = names[i];
                              final GroupMember? rm = roster.isNotEmpty ? roster[i] : null;
                              final isMe = rm != null
                                  ? (rm.uid != null && rm.uid == myUid)
                                  : (name == 'You');
                              final canKick = isCreator && !isMe && rm != null;
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
                                    AvatarCircle(label: name, size: 28),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TC.text(context)))),
                                    if (isMe)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(8)),
                                        child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
                                      )
                                    else if (canKick)
                                      GestureDetector(
                                        onTap: () async {
                                          HapticFeedback.lightImpact();
                                          final memBal =
                                              (state.getBalancesById(g)[rm.id] ?? 0.0);
                                          final unsettled = memBal.abs() >= 0.01;
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (dctx) => AlertDialog(
                                              backgroundColor: TC.card(context),
                                              title: Text('Remove $name?',
                                                  style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
                                              content: Text(
                                                unsettled
                                                    ? '$name still has an unsettled balance of ${g.sym}${memBal.abs().toStringAsFixed(2)} in this group. Removing them now may throw off everyone\'s totals. Remove anyway?'
                                                    : 'Remove $name from "${g.name}"? They\'ll lose access to this group.',
                                                style: TextStyle(color: TC.text2(context)),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dctx, false),
                                                  child: Text(l.cancel, style: TextStyle(color: TC.text3(context))),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dctx, true),
                                                  child: const Text('Remove',
                                                      style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await state.removeMember(g, rm);
                                            setSheetState(() {});
                                          }
                                        },
                                        child: Container(
                                          width: 28, height: 28,
                                          decoration: const BoxDecoration(color: AppColors.redDim, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: AppColors.red),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 24),

                  // Creator → Save name/emoji. Non-creator → Leave the group.
                  if (isCreator)
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final newName = nameCtrl.text.trim();
                        if (newName.isEmpty) return;
                        await state.editGroup(g, name: newName, emoji: selectedEmoji);
                        if (!context.mounted) return;
                        try {
                          Navigator.pop(context);
                        } catch (e) {
                          debugPrint('[GroupDetail] pop failed: $e');
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.center,
                        child: Text(l.saveChanges, style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        // Can't leave with an outstanding balance — it would
                        // corrupt everyone's totals. Require settle-up first.
                        final myBal = state.getMyBalance(g);
                        if (myBal.abs() >= 0.01) {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: TC.card(context),
                              title: Text('Settle up first', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
                              content: Text(
                                '${myBal > 0 ? 'You\'re owed' : 'You owe'} ${g.sym}${myBal.abs().toStringAsFixed(2)} in this group. Please settle up before leaving so everyone\'s balances stay correct.',
                                style: TextStyle(color: TC.text2(context)),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('OK', style: TextStyle(color: TC.primary(context), fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: TC.card(context),
                            title: Text('Leave group?', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
                            content: Text('You\'ll be removed from "${g.name}" and stop seeing its expenses. The group stays for everyone else.', style: TextStyle(color: TC.text2(context))),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel, style: TextStyle(color: TC.text3(context)))),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context); // dialog
                                  Navigator.pop(context); // sheet
                                  await state.leaveGroup(g);
                                  if (context.mounted) Navigator.pop(context); // leave group screen
                                },
                                child: const Text('Leave', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.center,
                        child: const Text('Leave Group', style: TextStyle(color: AppColors.red, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),

                  // Creator: delete the group (only once all balances are settled).
                  if (isCreator)
                    Builder(builder: (context) {
                      final balances = state.getBalancesById(g);
                      final isSettled = balances.values.every((b) => b.abs() < 0.01);
                      if (!isSettled) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: TC.bg2(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: TC.border(context)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 16, color: TC.text3(context)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text('Settle all balances before deleting this group',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: TC.text3(context), fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: TC.card(context),
                                title: Text('Delete Group?', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
                                content: Text('Are you sure you want to delete this group? This cannot be undone.', style: TextStyle(color: TC.text2(context))),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel, style: TextStyle(color: TC.text3(context)))),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context); // close dialog
                                      Navigator.pop(context); // close bottom sheet
                                      try {
                                        await state.deleteGroup(g);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Delete failed: $e')),
                                          );
                                          return;
                                        }
                                      }
                                      if (context.mounted) Navigator.pop(context); // leave group screen
                                    },
                                    child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.center,
                            child: const Text('Delete Group', style: TextStyle(color: AppColors.red, fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 30),
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
        child: SingleChildScrollView(
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
      ),
    );
  }

  void _exportToText(BuildContext context, AppState state, GroupData g) {
    HapticFeedback.mediumImpact();
    final plan = state.buildSettlePlan(g);
    final total = g.expenses.fold(0.0, (s, e) => s + e.amount);
    final allBal = state.getBalancesById(g);

    final sb = StringBuffer();
    sb.writeln('📊 ${g.name} — Summary');
    sb.writeln('━━━━━━━━━━━━━━━━━━━');
    sb.writeln(
      '💰 Total spent: ${g.sym}${total.toStringAsFixed(2)} ${g.currency}',
    );
    sb.writeln('');
    sb.writeln('👥 Balances:');
    final balKeys = g.roster.isNotEmpty
        ? g.roster.map((m) => m.id)
        : g.members.map((n) => 'name:$n');
    for (final key in balKeys) {
      final b = allBal[key] ?? 0;
      final name = g.displayNameForKey(key);
      final label = b > 0
          ? 'gets back ${g.sym}${b.toStringAsFixed(2)}'
          : b < 0
              ? 'owes ${g.sym}${b.abs().toStringAsFixed(2)}'
              : 'settled ✓';
      sb.writeln('  • $name: $label');
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

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9BB5B0),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: GoogleFonts.gloock(
                color: valueColor ?? const Color(0xFF111918),
                fontSize: 19,
                letterSpacing: -0.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  // Primary = the main call-to-action (Add expense): filled teal so it reads
  // as the obvious tap target, not a passive label.
  final bool primary;

  const _GroupActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : const Color(0xFF6E8C86);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: primary ? AppColors.green : Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
                color: primary ? AppColors.green : const Color(0xFFE9E4DB)),
            boxShadow: [
              BoxShadow(
                  color: (primary ? AppColors.green : Colors.black)
                      .withValues(alpha: primary ? 0.28 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withValues(alpha: 0.22)
                      : const Color(0xFFEDE9E1),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: fg),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          color: isSelected ? const Color(0xFF0D7377) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D7377) : const Color(0xFFE9E4DB),
            width: 1,
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
                color: isSelected ? Colors.white : const Color(0xFF4E6560),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
