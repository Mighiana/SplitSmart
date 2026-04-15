import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('app_utils.dart')) continue;

    String content = file.readAsStringSync();
    bool changed = false;

    if (content.contains('AppUtils.todayStr')) {
      content = content.replaceAll('AppUtils.todayStr', 'AppDateUtils.todayStr');
      changed = true;
    }
    if (content.contains('AppUtils.monthLabel')) {
      content = content.replaceAll('AppUtils.monthLabel', 'AppDateUtils.monthLabel');
      changed = true;
    }
    if (content.contains('AppUtils.formatAmount')) {
      content = content.replaceAll('AppUtils.formatAmount', 'AppCurrencyUtils.formatAmount');
      changed = true;
    }
    if (content.contains('AppUtils.pageRoute')) {
      content = content.replaceAll('AppUtils.pageRoute', 'AppNavUtils.pageRoute');
      changed = true;
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated \${file.path}');
    }
  }
}
