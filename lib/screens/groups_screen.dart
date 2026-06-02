import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../services/analytics_service.dart';
import '../services/firestore_service.dart';
import 'group_detail_screen.dart';
import 'new_group_screen.dart';
import 'qr_scan_screen.dart';
import 'qr_share_screen.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  String _tab = 'active';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    
    final active = state.activeGroups;
    final archived = state.archivedGroups;

    final items = _tab == 'active' ? active : archived;

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.green,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          onRefresh: () => context.read<AppState>().refresh(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── HEADER ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SHARED EXPENSES',
                            style: TC.geist(context,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: TC.primaryMd(context),
                                letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Groups',
                            style: TC.gloock(context,
                                fontSize: 32, letterSpacing: -0.8, height: 1.1),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${active.length} active · ${archived.length} archived',
                            style: TextStyle(
                              fontSize: 12,
                              color: TC.text3(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // QR scan pill
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showJoinOptions(context, state, isDark);
                      },
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: TC.card(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TC.border(context)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 20,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // New Group pill button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NewGroupScreen()));
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D68F), Color(0xFF00B377)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.green.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 17),
                            SizedBox(width: 5),
                            Text(
                              'New Group',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.08, end: 0, delay: 50.ms, duration: 300.ms),

              // ── TAB TOGGLE ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TC.border(context)),
                  ),
                  child: Row(
                    children: [
                      // Active tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _tab = 'active');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: _tab == 'active'
                                  ? AppColors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _tab == 'active'
                                  ? [
                                      BoxShadow(
                                        color: AppColors.green.withValues(alpha: 0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.groups_rounded,
                                  size: 18,
                                  color: _tab == 'active'
                                      ? Colors.white
                                      : TC.text3(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _tab == 'active'
                                        ? Colors.white
                                        : TC.text3(context),
                                  ),
                                ),
                                if (active.isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _tab == 'active'
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : TC.border(context),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${active.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _tab == 'active'
                                            ? Colors.white
                                            : TC.text3(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Archived tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _tab = 'archive');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: _tab == 'archive'
                                  ? AppColors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _tab == 'archive'
                                  ? [
                                      BoxShadow(
                                        color: AppColors.green.withValues(alpha: 0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 16,
                                  color: _tab == 'archive'
                                      ? Colors.white
                                      : TC.text3(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Archived',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _tab == 'archive'
                                        ? Colors.white
                                        : TC.text3(context),
                                  ),
                                ),
                                if (archived.isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _tab == 'archive'
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : TC.border(context),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${archived.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _tab == 'archive'
                                            ? Colors.white
                                            : TC.text3(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.08, end: 0, delay: 100.ms, duration: 300.ms),

              // LIST
              if (_tab == 'active' && active.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C2D25) : const Color(0xFFEAFBF4),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? const Color(0xFF264F3D) : const Color(0xFFB6F0D6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ── Stacked avatars illustration ──
                      SizedBox(
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Left avatar
                            const Positioned(
                              left: 0,
                              right: 60,
                              child: _AvatarCircleIllustration(
                                color: Color(0xFF6EE7B7),
                                icon: Icons.person_rounded,
                                iconColor: Color(0xFF059669),
                                size: 54,
                              ),
                            ),
                            // Right avatar
                            const Positioned(
                              left: 60,
                              right: 0,
                              child: _AvatarCircleIllustration(
                                color: Color(0xFFBBF7D0),
                                icon: Icons.person_rounded,
                                iconColor: Color(0xFF16A34A),
                                size: 54,
                              ),
                            ),
                            // Center avatar (on top)
                            const _AvatarCircleIllustration(
                              color: Color(0xFF22C55E),
                              icon: Icons.person_rounded,
                              iconColor: Colors.white,
                              size: 66,
                              border: 3,
                            ),
                            // Green + badge
                            Positioned(
                              right: 58,
                              top: 2,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Split with your people',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: TC.text(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create a group or scan a QR\nto join an existing circle.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: TC.text2(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ── Buttons row ──
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScanScreen()));
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: TC.card(context),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: TC.border(context), width: 1.4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Color(0xFF19C98D)),
                                    const SizedBox(width: 6),
                                    Text('Scan QR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.text(context))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const NewGroupScreen()));
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF08E1A0), Color(0xFF07C887)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF08D894).withValues(alpha: 0.30),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_rounded, size: 20, color: Colors.white),
                                    SizedBox(width: 5),
                                    Text('New Group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade().slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 320.ms)
              else if (_tab == 'archive' && archived.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                  child: Column(
                    children: [
                      Text('No archived groups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TC.text(context))),
                      const SizedBox(height: 6),
                      Text('Archived groups will appear here', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TC.text3(context))),
                    ],
                  ),
                ).animate().fade()
              else
                ...items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final g = entry.value;
                  final heroTag = 'groups_${_tab}_${g.id}';
                  return _GroupCard(
                    g: g,
                    bal: state.getMyBalance(g),
                    heroTag: heroTag,
                    isDark: isDark,
                    dimmed: g.isArchived,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      state.currentGroup = g;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(heroTag: heroTag)));
                    },
                    onLongPress: () => _showGroupActions(context, state, g, isDark),
                  ).animate().fade().slideY(begin: 0.05, end: 0, delay: (150 + idx * 60).ms, duration: 320.ms);
                }),
            ],
          ),         // Column
        ),           // SingleChildScrollView
        ),           // RefreshIndicator
      ),             // SafeArea
    );
  }

  void _showJoinOptions(BuildContext context, AppState state, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 5, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Join or Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context)))
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: AppColors.greenDim, shape: BoxShape.circle),
                child: const Icon(Icons.keyboard_alt_outlined, color: AppColors.green, size: 22),
              ),
              title: Text('Enter Invite Code', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
              subtitle: Text('Type a short 8-character code', style: TextStyle(color: TC.text2(context))),
              onTap: () {
                Navigator.pop(context);
                _showInviteCodeDialog(context);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: AppColors.blueDim, shape: BoxShape.circle),
                child: const Icon(Icons.qr_code_scanner, color: AppColors.blue, size: 22),
              ),
              title: Text('Scan QR Code', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
              subtitle: Text('Scan a friend\'s screen', style: TextStyle(color: TC.text2(context))),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScanScreen()));
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: AppColors.purpleDim, shape: BoxShape.circle),
                child: const Icon(Icons.share, color: AppColors.purple, size: 22),
              ),
              title: Text('Share Group QR', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
              subtitle: Text('Let others scan to join', style: TextStyle(color: TC.text2(context))),
              onTap: () {
                Navigator.pop(context);
                _showGroupSharePicker(context, state, isDark);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  void _showInviteCodeDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool isLoading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 24),
                      Text('Join with Code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TC.text(context))),
                      const SizedBox(height: 8),
                      Text('Enter the 8-character invite code shared by the group creator.', style: TextStyle(fontSize: 14, color: TC.text2(context))),
                      const SizedBox(height: 32),
                      
                      TextField(
                        controller: ctrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 4, color: TC.text(context)),
                        decoration: InputDecoration(
                          hintText: 'XXXXXXXX',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onChanged: (v) {
                          if (error != null) setModalState(() => error = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: TC.text(context)),
                        decoration: InputDecoration(
                          hintText: 'Your Name in Group',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                      
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(error!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        
                      const SizedBox(height: 32),
                      
                      GestureDetector(
                        onTap: isLoading ? null : () async {
                          if (ctrl.text.trim().length < 6) {
                            setModalState(() => error = 'Please enter a valid code');
                            return;
                          }
                          if (nameCtrl.text.trim().isEmpty) {
                            setModalState(() => error = 'Please enter your name');
                            return;
                          }
                          
                          setModalState(() => isLoading = true);
                          HapticFeedback.mediumImpact();
                          
                          final state = context.read<AppState>();
                          final group = await FirestoreService.instance.joinGroupByInviteCode(ctrl.text.trim(), nameCtrl.text.trim());
                          
                          if (group == null) {
                            if (ctx.mounted) {
                              setModalState(() {
                                isLoading = false;
                                error = 'Invalid invite code or group not found.';
                              });
                            }
                            return;
                          }
                          
                          // Avoid race conditions with Firestore index latency by manually adding it to state
                          await state.joinGroupLocally(group);
                          
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined ${group.name}! 🎉'), backgroundColor: AppColors.green));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Join Group', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showGroupSharePicker(BuildContext context, AppState state, bool isDark) {
    if (state.activeGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active groups to share.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 36, height: 5, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select a group to share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context)))
                ),
              ),
              const SizedBox(height: 16),
              ...state.activeGroups.map((g) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: EmojiBox(emoji: g.emoji, size: 44),
                title: Text(g.name, style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
                subtitle: Text('${g.members.length} members', style: TextStyle(color: TC.text2(context))),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => QRShareScreen(group: g)));
                },
              )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupActions(BuildContext context, AppState state, GroupData g, bool isDark) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 5, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  EmojiBox(emoji: g.emoji, size: 48),
                  const SizedBox(width: 14),
                  Text(g.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🔗', style: TextStyle(fontSize: 22)),
              title: Text('Share Invite Code', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
              subtitle: Text('Share code or QR to invite friends', style: TextStyle(color: TC.text2(context))),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _showShareInviteOptions(context, g);
              },
            ),
            ListTile(
              leading: Text(g.isArchived ? '📂' : '📦', style: const TextStyle(fontSize: 22)),
              title: Text(g.isArchived ? 'Unarchive Group' : 'Archive Group', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
              subtitle: Text(g.isArchived ? 'Move back to active groups' : 'Hide from active — history kept', style: TextStyle(color: TC.text2(context))),
              onTap: () async {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                if (g.isArchived) {
                  state.unarchiveGroup(g);
                } else {
                  await state.archiveGroup(g);
                  AnalyticsService.logGroupArchived();
                  final prefs = await SharedPreferences.getInstance();
                  final hasArchived = prefs.getBool('has_archived_first_time') ?? false;
                  if (!hasArchived && context.mounted) {
                    await prefs.setBool('has_archived_first_time', true);
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: TC.card(ctx),
                        title: Text('Group Archived', style: TextStyle(color: TC.text(ctx), fontWeight: FontWeight.w800)),
                        content: Text('This group has been archived. You can unarchive it anytime.', style: TextStyle(color: TC.text2(ctx))),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: AppColors.green)))],
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Text('🗑', style: TextStyle(fontSize: 22)),
              title: const Text('Delete Group', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.red)),
              subtitle: Text('Permanently removes all expenses', style: TextStyle(color: TC.text2(context))),
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                _confirmDelete(context, state, g, isDark);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  void _confirmDelete(BuildContext context, AppState state, GroupData g, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text('Delete group?', style: TextStyle(fontWeight: FontWeight.w800, color: TC.text(context))),
        content: Text('Delete "${g.name}" and all its expenses? This cannot be undone.', style: TextStyle(color: TC.text2(context))),
        actions: [
          TextButton(
            onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
            child: Text('Cancel', style: TextStyle(color: TC.text2(context), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              try {
                await state.deleteGroup(g);
                await AnalyticsService.logGroupDeleted();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showShareInviteOptions(BuildContext context, GroupData g) async {
    String code = g.inviteCode ?? '';
    
    // If invite code is empty, try fetching from Firestore
    if (code.isEmpty) {
      final fetched = await FirestoreService.instance.getGroupInviteCode(g.id);
      if (fetched != null) {
        code = fetched;
        g.inviteCode = fetched; // Cache locally
      } else {
        code = 'N/A';
      }
    }
    
    if (code != 'N/A' && code.isNotEmpty) {
      await FirestoreService.instance.ensureInviteCodeMapping(g.id, code);
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Invite to ${g.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context))),
              const SizedBox(height: 8),
              Text('Share this code — friends can join instantly!', style: TextStyle(color: TC.text2(context), fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.greenDim, Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(code, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4, color: TC.text(context))),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite code copied! 📋'), backgroundColor: AppColors.green, duration: Duration(seconds: 2)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.copy, color: Colors.black, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => QRShareScreen(group: g)));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: TC.card2(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TC.border(context)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code, size: 18),
                      const SizedBox(width: 8),
                      Text('Show QR Code', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
  }
}


class _GroupCard extends StatefulWidget {
  final GroupData g;
  final double bal;
  final String heroTag;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool dimmed;
  
  const _GroupCard({
    required this.g, required this.bal,
    required this.heroTag,
    required this.isDark,
    required this.onTap, required this.onLongPress,
    this.dimmed = false,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  double _scale = 1.0;

  String _formatGroupUpdated(GroupData g) {
    if (g.expenses.isEmpty && g.settlements.isEmpty) return 'No expenses yet';

    DateTime? latestDt;

    if (g.expenses.isNotEmpty) {
      final sorted = List.of(g.expenses)..sort((a, b) {
        final d1 = TransactionData.parseDate(a.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final d2 = TransactionData.parseDate(b.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return d2.compareTo(d1);
      });
      latestDt = TransactionData.parseDate(sorted.first.date);
    }

    if (latestDt == null) return 'No expenses yet';

    // Compare by calendar date to avoid midnight-parse false "hours ago"
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final expDate = DateTime(latestDt.year, latestDt.month, latestDt.day);
    final dayDiff = todayDate.difference(expDate).inDays;

    if (dayDiff == 0) return 'Updated today';
    if (dayDiff == 1) return 'Updated yesterday';
    if (dayDiff < 7)  return 'Updated ${dayDiff}d ago';
    if (dayDiff < 30) return 'Updated ${(dayDiff / 7).floor()}w ago';
    final m = latestDt.month.toString().padLeft(2, '0');
    final d = latestDt.day.toString().padLeft(2, '0');
    return 'Updated $d/$m/${latestDt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final bal = widget.bal;
    final isDark = widget.isDark;

    // Balance badge values
    final isOwed    = bal > 0;
    final isOwes    = bal < 0;
    final isSettled = bal == 0;

    final Color badgeBg    = isOwed    ? AppColors.green.withValues(alpha: 0.13)
                           : isOwes    ? AppColors.red.withValues(alpha: 0.11)
                           : TC.card2(context);
    final Color badgeText  = isOwed    ? AppColors.green
                           : isOwes    ? AppColors.red
                           : TC.text3(context);
    final String badgeLabel = isOwed   ? 'Owed'
                            : isOwes   ? 'You owe'
                            : 'Settled';
    final String badgeAmt  = isSettled ? 'Settled ✓'
        : '${g.sym}${AppCurrencyUtils.formatAmount(bal.abs())}';

    return GestureDetector(
      onTapDown:   (_) => setState(() => _scale = 0.98),
      onTapUp:     (_) => setState(() => _scale = 1.0),
      onTapCancel: ()  => setState(() => _scale = 1.0),
      onTap:       widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Opacity(
          opacity: widget.dimmed ? 0.55 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TC.border(context), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                  blurRadius: 16, offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                // ── Icon box ──────────────────────────────────────────
                Hero(
                  tag: widget.heroTag,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.greenDim,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(g.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // ── Text info ─────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: TC.gloock(context,
                            fontSize: 17, letterSpacing: -0.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // members · expenses · currency
                      Row(children: [
                        Icon(Icons.people_outline, size: 13, color: TC.text3(context)),
                        const SizedBox(width: 3),
                        Text('${g.members.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TC.text2(context))),
                        _dot(context),
                        Flexible(
                          child: Text(
                            '${g.expenses.length} expenses',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TC.text2(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _dot(context),
                        Flexible(
                          child: Text(
                            g.currency,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text2(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      // updated
                      Row(children: [
                        Icon(Icons.update_rounded, size: 12, color: TC.text3(context)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(
                          _formatGroupUpdated(g),
                          style: TextStyle(fontSize: 11, color: TC.text3(context)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        )),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // ── Balance badge ────────────────────────────────────
                Flexible(
                  flex: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ⋮ menu
                      GestureDetector(
                        onTap: widget.onLongPress,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Icon(Icons.more_vert, size: 18, color: TC.text3(context)),
                        ),
                      ),
                      // badge pill
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(14),
                          border: isSettled
                              ? Border.all(color: TC.border(context), width: 1)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isSettled)
                              Text(badgeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeText)),
                            Text(
                              badgeAmt,
                              style: TextStyle(
                                fontSize: isSettled ? 13 : 15,
                                fontWeight: FontWeight.w800,
                                color: badgeText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(BuildContext ctx) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 5),
    width: 3, height: 3,
    decoration: BoxDecoration(color: TC.text3(ctx), shape: BoxShape.circle),
  );
}



// ── Helper: avatar circle for the empty-state illustration ───────────────────
class _AvatarCircleIllustration extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final double size;
  final double border;

  const _AvatarCircleIllustration({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.size,
    this.border = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border > 0
              ? Border.all(color: Colors.white, width: border)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.52),
      ),
    );
  }
}
