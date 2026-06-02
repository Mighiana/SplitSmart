import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_state.dart';

const _teal = Color(0xFF0D7377);
const _text = Color(0xFF111918);
const _muted = Color(0xFF9BB5B0);
const _coral = Color(0xFFE85A6A);
const _green = Color(0xFF009B73);
const _line = Color(0xFFE9E4DB);

class GroupMembersTab extends StatelessWidget {
  final GroupData g;
  final AppState state;

  const GroupMembersTab({
    super.key,
    required this.g,
    required this.state,
  });

  Color _avatarColor(String name, int index) {
    const colors = [
      Color(0xFF0D7377),
      Color(0xFF059669),
      Color(0xFF3B82F6),
      Color(0xFFD97706),
      Color(0xFFE85A6A),
      Color(0xFF8B5CF6),
    ];
    if (name.toLowerCase().contains('usman') || name.toLowerCase() == 'you') return colors.first;
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final allBal = state.getAllBalances(g);
    final youName = g.members.firstWhere(
      (m) => m.toLowerCase() == 'you' || m.toLowerCase().contains('usman'),
      orElse: () => g.members.isNotEmpty ? g.members.first : 'You',
    );
    final myBal = allBal[youName] ?? 0;
    final owedToYou = g.members.where((m) => m != youName && (allBal[m] ?? 0) < 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 122),
      children: [
        _SectionHeader(
          icon: '📤',
          title: 'YOU OWE',
          color: _coral,
          trailing: myBal < 0 ? '${g.sym}${myBal.abs().toStringAsFixed(0)}' : 'Nothing',
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 26),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE1F1E9),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            myBal < 0 ? 'Pay ${g.sym}${myBal.abs().toStringAsFixed(0)} to settle up' : "✓ You don't owe anyone right now",
            style: const TextStyle(color: _green, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
        _SectionHeader(
          icon: '📥',
          title: 'OWED TO YOU',
          color: _green,
          trailing: '${g.sym}${owedToYou.fold<double>(0, (sum, m) => sum + (allBal[m] ?? 0).abs()).toStringAsFixed(0)}',
        ),
        if (owedToYou.isNotEmpty)
          _WhiteCard(
            children: [
              for (int i = 0; i < owedToYou.length; i++)
                _BalancePersonRow(
                  name: '${owedToYou[i]} owes you',
                  initial: owedToYou[i].isNotEmpty ? owedToYou[i][0].toUpperCase() : '?',
                  color: _avatarColor(owedToYou[i], i + 1),
                  amount: '${g.sym}${(allBal[owedToYou[i]] ?? 0).abs().toStringAsFixed(0)}',
                  amountColor: _green,
                  showRemind: true,
                  progressColor: _avatarColor(owedToYou[i], i + 1),
                  isLast: i == owedToYou.length - 1,
                ),
            ],
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 26),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: const Text('Nobody owes you right now', style: TextStyle(color: _muted, fontWeight: FontWeight.w800)),
          ),
        const SizedBox(height: 8),
        const _SectionHeader(
          icon: '👥',
          title: 'ALL MEMBERS',
          color: _teal,
        ),
        _WhiteCard(
          children: [
            for (int i = 0; i < g.members.length; i++)
              _AllMemberRow(
                name: g.members[i] == youName ? '${g.members[i]} (You)' : g.members[i],
                initial: g.members[i].isNotEmpty ? g.members[i][0].toUpperCase() : '?',
                color: _avatarColor(g.members[i], i),
                balance: allBal[g.members[i]] ?? 0,
                sym: g.sym,
                paid: g.expenses.where((e) => e.paidBy == g.members[i]).fold<double>(0, (sum, e) => sum + e.amount),
                share: g.members.isEmpty
                    ? 0
                    : g.expenses.fold<double>(0, (sum, e) => sum + e.amount / g.members.length),
                isLast: i == g.members.length - 1,
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  final Color color;
  final String? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.9),
          ),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final List<Widget> children;

  const _WhiteCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _BalancePersonRow extends StatelessWidget {
  final String name;
  final String initial;
  final Color color;
  final String amount;
  final Color amountColor;
  final bool showRemind;
  final Color progressColor;
  final bool isLast;

  const _BalancePersonRow({
    required this.name,
    required this.initial,
    required this.color,
    required this.amount,
    required this.amountColor,
    required this.showRemind,
    required this.progressColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : _line))),
      child: Row(
        children: [
          _Avatar(initial: initial, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: 0.66,
                    backgroundColor: _line,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: GoogleFonts.gloock(color: amountColor, fontSize: 19, letterSpacing: -0.5)),
              if (showRemind) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(9)),
                  child: const Text('Remind', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AllMemberRow extends StatelessWidget {
  final String name;
  final String initial;
  final Color color;
  final double balance;
  final String sym;
  final double paid;
  final double share;
  final bool isLast;

  const _AllMemberRow({
    required this.name,
    required this.initial,
    required this.color,
    required this.balance,
    required this.sym,
    required this.paid,
    required this.share,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final balColor = balance >= 0 ? _green : _coral;
    final label = balance >= 0 ? 'Gets $sym${balance.toStringAsFixed(0)}' : 'Owes $sym${balance.abs().toStringAsFixed(0)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : _line))),
      child: Row(
        children: [
          _Avatar(initial: initial, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w900))),
                    Text(label, style: GoogleFonts.gloock(color: balColor, fontSize: 18, letterSpacing: -0.4)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: paid <= 0 && share <= 0 ? 0.08 : (paid / (paid + share)).clamp(0.06, 1.0),
                    backgroundColor: _line,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Paid $sym${paid.toStringAsFixed(0)} · Share $sym${share.toStringAsFixed(0)}',
                  style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final Color color;

  const _Avatar({required this.initial, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
    );
  }
}
