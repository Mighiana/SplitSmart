import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/app_utils.dart';
import '../../main.dart';

class GroupSettlementsTab extends StatefulWidget {
  final GroupData g;
  final AppState state;
  const GroupSettlementsTab({super.key, required this.g, required this.state});

  @override
  State<GroupSettlementsTab> createState() => _GroupSettlementsTabState();
}

class _GroupSettlementsTabState extends State<GroupSettlementsTab> {
  @override
  Widget build(BuildContext context) {
    final plan = widget.state.buildSettlePlan(widget.g);
    
    if (plan.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('All settled up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('No payments needed.', style: TextStyle(color: TC.text2(context))),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: plan.length,
      itemBuilder: (context, i) {
        final p = plan[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.greenDim, shape: BoxShape.circle),
                child: const Icon(Icons.payment, color: AppColors.green, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: TC.text(context)),
                        children: [
                          TextSpan(text: p.from, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: ' pays '),
                          TextSpan(text: p.to, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Settle debt manually', style: TextStyle(fontSize: 12, color: TC.text3(context))),
                  ],
                ),
              ),
              Text(
                '${widget.g.sym}${p.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.green),
              ),
            ],
          ),
        );
      },
    );
  }
}
