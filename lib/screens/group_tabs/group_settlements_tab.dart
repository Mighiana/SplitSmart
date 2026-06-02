import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../utils/app_utils.dart';

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
    final g = widget.g;
    final plan = widget.state.buildSettlePlan(g);

    if (plan.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('All settled up!',
                  style: TC.gloock(context, fontSize: 20, color: TC.text(context))),
              const SizedBox(height: 8),
              Text('No payments needed.',
                  style: TC.geist(context, fontSize: 13, color: TC.text2(context))),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: TC.primaryPale(context),
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Icon(Icons.compare_arrows_rounded,
                        color: TC.primary(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Suggested settlements',
                        style: TC.geist(context,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: TC.text(context))),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: TC.primaryPale(context),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('Optimized',
                        style: TC.geist(context,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: TC.primary(context))),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...plan.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: p == plan.last
                                ? Colors.transparent
                                : TC.border(context))),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(p.from,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TC.geist(context,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: TC.text(context))),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 16, color: TC.text3(context)),
                      ),
                      Expanded(
                        child: Text(p.to,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TC.geist(context,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: TC.text(context))),
                      ),
                      const SizedBox(width: 8),
                      Text('${g.sym}${p.amount.toStringAsFixed(2)}',
                          style: TC.gloock(context,
                              fontSize: 16, color: TC.primary(context))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
