import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../utils/theme_utils.dart';
import '../widgets/common_widgets.dart';
import '../services/analytics_service.dart';
import '../services/firestore_service.dart';
import '../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);

    final items = _tab == 'active' ? active : archived;

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.activeCircles,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.green,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text(l.groups,
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: TC.text(context),
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // QR Icon
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showJoinOptions(context, state, isDark);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TC.card(context),
                          shape: BoxShape.circle,
                          border: Border.all(color: TC.border(context)),
                          boxShadow: [
                            BoxShadow(color: TC.shadow(context), blurRadius: 10, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Icon(Icons.qr_code, color: TC.text(context), size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // New Group btn
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NewGroupScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: AppColors.greenGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6))
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.black, size: 20),
                            const SizedBox(width: 6),
                            Text(l.create, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // Custom Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: TC.border(context)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _tab = 'active');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _tab == 'active' ? (isDark ? const Color(0xFF2a2a30) : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: _tab == 'active' ? [
                                BoxShadow(color: TC.shadow(context), blurRadius: 4, offset: const Offset(0, 1))
                              ] : [],
                            ),
                            alignment: Alignment.center,
                            child: Text('${l.active} (${active.length})', style: TextStyle(
                              color: _tab == 'active' ? TC.text(context) : TC.text3(context),
                              fontWeight: _tab == 'active' ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                            )),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _tab = 'archive');
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _tab == 'archive' ? (isDark ? const Color(0xFF2a2a30) : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: _tab == 'archive' ? [
                                BoxShadow(color: TC.shadow(context), blurRadius: 4, offset: const Offset(0, 1))
                              ] : [],
                            ),
                            alignment: Alignment.center,
                            child: Text('${l.archived} (${archived.length})', style: TextStyle(
                              color: _tab == 'archive' ? TC.text(context) : TC.text3(context),
                              fontWeight: _tab == 'archive' ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                            )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // Group List
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: _tab == 'active' ? '👥' : '📦',
                    title: _tab == 'active' ? l.noActiveGroups : 'No archived groups',
                    subtitle: _tab == 'active' ? l.createToSplit : 'Archived groups will appear here',
                  ).animate().fade().scale(),
                )
              else
                ...items.map((g) {
                  final heroTag = 'groups_${_tab}_${g.id}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _GroupCard(
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
                    ),
                  ).animate().fade().slideY(begin: 0.05, end: 0, duration: 300.ms);
                }),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinOptions(BuildContext context, AppState state, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
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
                child: Text('Join Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context)))
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.greenDim, shape: BoxShape.circle),
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
                decoration: BoxDecoration(color: AppColors.blueDim, shape: BoxShape.circle),
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
                decoration: BoxDecoration(color: AppColors.purpleDim, shape: BoxShape.circle),
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
                          
                          // Because joinGroupByInviteCode does NOT automatically push to activeGroups locally unless we reload, let's reload groups
                          await state.reloadFromDatabase();
                          
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
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
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
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: TC.card(context),
                        title: Text('Group Archived', style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w800)),
                        content: Text('This group has been archived. You can unarchive it anytime.', style: TextStyle(color: TC.text2(context))),
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
            onPressed: () {
              HapticFeedback.heavyImpact();
              state.deleteGroup(g);
              AnalyticsService.logGroupDeleted();
              Navigator.pop(context);
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

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
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
                  gradient: LinearGradient(colors: [AppColors.greenDim, Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
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

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final bal = widget.bal;
    final isDark = widget.isDark;
    final l = AppLocalizations.of(context);

    final Color balColor = bal > 0 ? AppColors.green : bal < 0 ? AppColors.red : TC.text2(context);
    final String balText = bal > 0
        ? '+ ${g.sym}${AppCurrencyUtils.formatAmount(bal)}'
        : bal < 0 ? '- ${g.sym}${AppCurrencyUtils.formatAmount(bal.abs())}' : 'Settled ✓';
    final String balLabel = bal > 0 ? l.owedToYou : bal < 0 ? l.youOweShort : '';

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp:   (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Opacity(
          opacity: widget.dimmed ? 0.6 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TC.border(context)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))
              ]
            ),
            child: Row(
              children: [
                Hero(tag: widget.heroTag, child: Material(type: MaterialType.transparency, child: EmojiBox(emoji: g.emoji, size: 52))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                              color: TC.text(context))),
                      const SizedBox(height: 4),
                      Text('${g.members.length} ${l.members} · ${g.expenses.length} ${l.expenses}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: TC.text2(context))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(balText,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15, color: balColor)),
                    if (balLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(balLabel,
                            style: TextStyle(fontSize: 11, color: TC.text3(context), fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
