import 'package:flutter/material.dart';
import '../../providers/app_state.dart';

import '../../utils/app_utils.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../main.dart';

class GroupMembersTab extends StatelessWidget {
  final GroupData g;
  final AppState state;
  const GroupMembersTab({super.key, required this.g, required this.state});

  @override
  Widget build(BuildContext context) {
    final allBal = state.getAllBalances(g);
    
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      children: [
        if (g.inviteCode != null)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.greenDim,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.group_add_rounded, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: TC.text2(context))),
                      Text(g.inviteCode!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 2)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.green),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: g.inviteCode!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied!')));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded, color: AppColors.green),
                  onPressed: () {
                    SharePlus.instance.share(ShareParams(text: 'Join my SplitSmart group "${g.name}" using this invite code: ${g.inviteCode!}'));
                  },
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Group Members',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TC.text(context)),
          ),
        ),
        ...g.members.map((m) {
          final isYou = m == 'You';
          final bal = allBal[m] ?? 0;
          double totalPaid = 0.0;
          for (final e in g.expenses) {
            if (e.paidBy == m) totalPaid += e.amount;
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(16),
              border: isYou ? Border.all(color: AppColors.green.withValues(alpha: 0.3)) : Border.all(color: Colors.transparent),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isYou ? AppColors.text : TC.card2(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    m.substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isYou ? Colors.white : TC.text(context)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isYou ? 'You' : m,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bal == 0 ? 'Settled ✓' : (bal > 0 ? 'Gets back ${g.sym}${bal.toStringAsFixed(2)}' : 'Owes ${g.sym}${bal.abs().toStringAsFixed(2)}'),
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.w600, 
                          color: bal == 0 ? TC.text3(context) : (bal > 0 ? AppColors.green : AppColors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${g.sym}${totalPaid.toStringAsFixed(2)} paid',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TC.text2(context)),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
