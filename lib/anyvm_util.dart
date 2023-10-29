import 'dart:io';
import 'package:logger/logger.dart';

String getScriptDirectory() {
  Uri scriptUri = Platform.script;
  String scriptPath = scriptUri.toFilePath();
  return Directory(scriptPath).parent.path;
}

void setupLogging() {
  Logger.level = Level.all;

  // コンソールにinfoレベルのログを出力するハンドラ
  Logger.addLogListener((record) {
    if (record.level == Level.info) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    }
  });

  // ファイルにwarningとerrorレベルのログを出力するハンドラ
  Logger.addLogListener((record) {
    if (record.level == Level.warning ||
        record.level == Level.error ||
        record.level == Level.fatal) {
      final logFile = File('${getScriptDirectory()}/error.log');
      logFile.writeAsStringSync(
          '${record.level.name}: ${record.time}: ${record.message}\n',
          mode: FileMode.append);
    }
  });
}

final logger = Logger();
