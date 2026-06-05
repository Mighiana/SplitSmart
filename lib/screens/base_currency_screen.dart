import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';

/// First-run step (shown after sign-in when the user has no account/wallet yet):
/// pick the main / home currency. Creates the first wallet and sets it as the
/// home currency. Users can add more accounts — and later connect banks — from
/// the Home "Your Accounts" sheet.
class BaseCurrencyScreen extends StatefulWidget {
  final VoidCallback onDone;
  const BaseCurrencyScreen({super.key, required this.onDone});

  @override
  State<BaseCurrencyScreen> createState() => _BaseCurrencyScreenState();
}

class _BaseCurrencyScreenState extends State<BaseCurrencyScreen> {
  late CurrencyData _selected = AppState.currencies.firstWhere(
    (c) => c.code == 'USD',
    orElse: () => AppState.currencies.first,
  );
  bool _saving = false;

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    try {
      await state.createWallet(_selected.code, 0);
      state.setHomeCurrency(_selected.code);
    } catch (_) {
      // Non-fatal — proceed regardless so the user is never stuck here.
    }
    if (mounted) widget.onDone();
  }

  void _pick() {
    HapticFeedback.lightImpact();
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            final list = AppState.currencies.where((c) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return c.code.toLowerCase().contains(q) ||
                  c.name.toLowerCase().contains(q);
            }).toList();
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(sheetCtx).size.height * 0.75,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                          color: TC.border(context),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: TC.card(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: TC.border(context)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded,
                                size: 18, color: TC.text3(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                autofocus: true,
                                style: TC.geist(context, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search currency',
                                  hintStyle: TC.geist(context,
                                      fontSize: 14, color: TC.text3(context)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onChanged: (v) => setSheet(() => query = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          final sel = c.code == _selected.code;
                          return ListTile(
                            leading: Text(c.flag,
                                style: const TextStyle(fontSize: 22)),
                            title: Text('${c.code} — ${c.name}',
                                style: TC.geist(context,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: TC.text(context))),
                            trailing: sel
                                ? Icon(Icons.check_circle_rounded,
                                    color: TC.primary(context), size: 20)
                                : null,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selected = c);
                              Navigator.pop(sheetCtx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    color: TC.primaryPale(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('💰', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select your main currency',
                textAlign: TextAlign.center,
                style: TC.gloock(context,
                    fontSize: 26, color: TC.text(context), letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Your balance & statistics will show in this currency. You can add more accounts — and connect banks — later.',
                textAlign: TextAlign.center,
                style: TC.geist(context,
                    fontSize: 13, color: TC.text2(context), height: 1.5),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _pick,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TC.border(context), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(_selected.flag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_selected.code} — ${_selected.name}',
                          style: TC.geist(context,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: TC.text(context)),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: TC.text3(context)),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
              GestureDetector(
                onTap: _confirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: TC.primary(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: TC.primaryGlow(context),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
