import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../providers/app_state.dart';
import 'analytics_service.dart';

class ExportService {
  static Future<void> exportAndSharePdf(AppState state, BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              text: 'SplitSmart Report',
            ),
            pw.Paragraph(
              text: 'Generated on: ${DateTime.now().toLocal().toString().split('.')[0]}',
            ),
            pw.SizedBox(height: 20),
            pw.Text('Groups Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (state.groups.isEmpty)
              pw.Text('No groups found.')
            else
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: ['Name', 'Members', 'Expenses', 'Status'],
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                data: state.groups.map((g) => [
                  g.name,
                  g.members.length.toString(),
                  g.expenses.length.toString(),
                  g.isArchived ? 'Archived' : 'Active'
                ]).toList(),
              ),
            
            pw.SizedBox(height: 20),
            pw.Text('Wallet Balances', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (state.wallets.isEmpty)
              pw.Text('No wallets found.')
            else
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: ['Currency', 'Current Balance'],
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                data: state.wallets.entries.map((e) => [
                  e.key,
                  e.value.toStringAsFixed(2)
                ]).toList(),
              ),
              
            pw.SizedBox(height: 20),
            pw.Text('Recent Personal Transactions (Top 50)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (state.transactions.isEmpty)
              pw.Text('No recent transactions.')
            else
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: ['Date', 'Type', 'Description', 'Amount', 'Currency'],
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                data: state.transactions.take(50).map((t) => [
                  t.date,
                  t.type,
                  t.desc,
                  t.amount.toStringAsFixed(2),
                  t.currency
                ]).toList(),
              ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/SplitSmart_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    if (context.mounted) {
       final box = context.findRenderObject() as RenderBox?;
       final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
       await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: 'SplitSmart Data Report',
          sharePositionOrigin: origin,
        ),
       );
       AnalyticsService.logExportedPDF();
       // SEC-12: Clean up temp file after sharing
       try { await file.delete(); } catch (_) {}
    }
  }

  static Future<void> exportPersonalTransactions(List<TransactionData> transactions, String currency, BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              text: 'Personal Transactions Report ($currency)',
            ),
            pw.Paragraph(
              text: 'Generated on: ${DateTime.now().toLocal().toString().split('.')[0]}',
            ),
            pw.SizedBox(height: 20),
            pw.Text('Transactions', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (transactions.isEmpty)
              pw.Text('No transactions found.')
            else
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: ['Date', 'Type', 'Description', 'Category', 'Amount'],
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                data: transactions.map((t) => [
                  t.date,
                  t.type,
                  t.desc,
                  t.cat,
                  '${t.sym}${t.amount.toStringAsFixed(2)}'
                ]).toList(),
              ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/SplitSmart_Transactions_${currency}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    if (context.mounted) {
       final box = context.findRenderObject() as RenderBox?;
       final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
       await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: 'Personal Transactions Report ($currency)',
          sharePositionOrigin: origin,
        ),
       );
       // SEC-12: Clean up temp file after sharing
       try { await file.delete(); } catch (_) {}
    }
  }

  static Future<void> exportGroupPdf(GroupData g, AppState state, BuildContext context) async {
    final pdf = pw.Document();
    
    final plan = state.buildSettlePlan(g);
    final total = g.expenses.fold(0.0, (s, e) => s + e.amount);
    final allBal = state.getAllBalances(g);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              text: 'Group Report: ${g.name}',
            ),
            pw.Paragraph(
              text: 'Generated on: ${DateTime.now().toLocal().toString().split('.')[0]}',
            ),
            pw.SizedBox(height: 20),
            pw.Text('Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Total Spent: ${g.sym}${total.toStringAsFixed(2)} ${g.currency}'),
            pw.SizedBox(height: 20),
            
            pw.Text('Member Balances', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: ['Member', 'Status'],
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              data: g.members.map((m) {
                final b = allBal[m] ?? 0;
                final label = b > 0
                    ? 'gets back ${g.sym}${b.toStringAsFixed(2)}'
                    : b < 0
                        ? 'owes ${g.sym}${b.abs().toStringAsFixed(2)}'
                        : 'settled \u{2713}'; // unicode checkmark
                return [m, label];
              }).toList(),
            ),
            
            if (plan.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Settlement Plan', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: ['From', 'To', 'Amount'],
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                data: plan.map((p) => [
                  p.from,
                  p.to,
                  '${g.sym}${p.amount.toStringAsFixed(2)}'
                ]).toList(),
              ),
            ],
            
            pw.SizedBox(height: 20),
            pw.Text('Expenses', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (g.expenses.isEmpty)
              pw.Text('No expenses yet.')
            else
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: ['Date', 'Description', 'Paid By', 'Amount'],
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                data: g.expenses.map((e) => [
                  e.date,
                  e.desc,
                  e.paidBy,
                  '${g.sym}${e.amount.toStringAsFixed(2)}'
                ]).toList(),
              ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/SplitSmart_Group_${g.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    if (context.mounted) {
       final box = context.findRenderObject() as RenderBox?;
       final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
       await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: '${g.name} Expense Report (PDF)',
          subject: '${g.name} expense summary',
          sharePositionOrigin: origin,
        ),
       );
       // SEC-12: Clean up temp file after sharing
       try { await file.delete(); } catch (_) {}
    }
  }
}
