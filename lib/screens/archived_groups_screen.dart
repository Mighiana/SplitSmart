import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import 'group_detail_screen.dart';
import '../main.dart';

class ArchivedGroupsScreen extends StatelessWidget {
  const ArchivedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final archived = state.archivedGroups;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TC.card(context),
              shape: BoxShape.circle,
              border: Border.all(color: TC.border(context)),
            ),
            alignment: Alignment.center,
            child: Text(
              '←',
              style: TextStyle(fontSize: 16, color: TC.text(context)),
            ),
          ),
        ),
        title: Text(
          'Archived Groups',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: TC.text(context),
          ),
        ),
      ),
      body: archived.isEmpty
          ? const EmptyState(
              icon: '📦',
              title: 'No archived groups',
              subtitle: 'Archived groups will appear here',
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: archived.length,
              itemBuilder: (context, i) {
                final g = archived[i];
                final bal = state.getMyBalance(g);
                final Color balColor = bal > 0 ? AppColors.green : bal < 0 ? AppColors.red : AppColors.text2;
                final String balText = bal > 0
                    ? '+${g.sym}${bal.toStringAsFixed(2)}'
                    : bal < 0 ? '-${g.sym}${bal.abs().toStringAsFixed(2)}' : 'Settled ✓';
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    state.currentGroup = g;
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => GroupDetailScreen(heroTag: 'archive_${g.id}')));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TC.border(context)),
                    ),
                    child: Row(
                      children: [
                        Hero(tag: 'archive_${g.id}', child: Material(type: MaterialType.transparency, child: EmojiBox(emoji: g.emoji, size: 48))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                                      color: TC.text(context))),
                              const SizedBox(height: 3),
                              Text('${g.members.length} members · ${g.expenses.length} expenses',
                                  style: TextStyle(fontSize: 12, color: TC.text2(context))),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(balText,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14, color: balColor)),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                state.unarchiveGroup(g);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('${g.name} unarchived', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), 
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: TC.card(context),
                                ));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.greenDim,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Unarchive', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700)),
                              )
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
