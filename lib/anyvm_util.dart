import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:charset/charset.dart';

import 'package:path/path.dart' as path;

Future<void> writeStringWithSjisEncoding(
    String filePath, String content) async {
  try {
    ShiftJISEncoder encoder = shiftJis.encoder as ShiftJISEncoder;
    // 文字列をSJISにエンコード
    var sjisBytes = encoder.convert(content);
    await File(filePath).writeAsBytes(sjisBytes);
  } catch (e) {
    print('エラーが発生しました: $e');
  }
}

String getApplicationDirectory() {
  Uri scriptUri = Platform.script;
  String scriptPath = scriptUri.toFilePath();
  return Directory(scriptPath).parent.path;
}

String getScriptsDirectory() {
  String appDir = getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  return path.join(anyvmDir, 'scripts');
}

String getToolsDirectory() {
  String appDir = getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  return path.join(anyvmDir, 'tools');
}

String getSymExeFile() {
  String toolDir = getToolsDirectory();
  return path.join(toolDir, 'symexe.exe');
}

String getAnyVmFile() {
  String appDir = getApplicationDirectory();
  return path.join(appDir, 'anyvm_win.json');
}

Future<String?> getVmVersion(String vmName) async {
  var jsonPath = getAnyVmFile();
  File file = File(jsonPath);
  if (await file.exists()) {
    String jsonString = await file.readAsString();
    Map<String, dynamic> vmList = jsonDecode(jsonString);
    return vmList[vmName];
  }
  logger.d('file not found: $jsonPath');
  return null;
}

Future<void> setVmVersion(String vmName, String version) async {
  var jsonPath = getAnyVmFile();
  File file = File(jsonPath);
  Map<String, dynamic> vmList = <String, dynamic>{};
  if (await file.exists()) {
    String jsonString = await file.readAsString();
    vmList = jsonDecode(jsonString);
  }
  vmList[vmName] = version;
  String jsonString = const JsonEncoder.withIndent('  ').convert(vmList);
  logger.d(jsonString);
  await file.writeAsString(jsonString);
  logger.d('$jsonPath updated $version');
}

Future<void> clearVmVersion(String vmName) async {
  var jsonPath = getAnyVmFile();
  File file = File(jsonPath);
  Map<String, dynamic> vmList = <String, dynamic>{};
  if (await file.exists()) {
    String jsonString = await file.readAsString();
    vmList = jsonDecode(jsonString);
    vmList.remove(vmName);
    jsonString = const JsonEncoder.withIndent('  ').convert(vmList);
    await file.writeAsString(jsonString);
    logger.d('$jsonPath cleared');
  }
}

void setupLogging([Level level = Level.info]) {
  Logger.level = level;

  // コンソールにinfoレベルのログを出力するハンドラ
  Logger.addLogListener((record) {
    if (Logger.level.index <= record.level.index) {
      if (record.level == Level.info || record.level == Level.warning) {
        print('${record.message}');
      } else {
        print('${record.level.name}: ${record.time}');
        print(StackTrace.current);
        print(record.message);
      }
    }
  });

  // ファイルにwarningとerrorレベルのログを出力するハンドラ
  Logger.addLogListener((record) {
    if (record.level.index >= Level.error.index) {
      final logFile = File('${getApplicationDirectory()}/error.log');
      logFile.writeAsStringSync(
          '${record.level.name}: ${record.time}: ${StackTrace.current}: ${record.message}\n',
          mode: FileMode.append);
    }
  });
}

final logger = Logger();

int compareVersion(String version1, String version2) {
  List<int> nums1 = version1.split('.').map((e) => int.parse(e)).toList();
  List<int> nums2 = version2.split('.').map((e) => int.parse(e)).toList();

  int n1 = nums1.length, n2 = nums2.length;

  for (int i = 0; i < n1 || i < n2; i++) {
    int num1 = i < n1 ? nums1[i] : 0;
    int num2 = i < n2 ? nums2[i] : 0;

    if (num1 < num2) {
      return -1;
    } else if (num1 > num2) {
      return 1;
    }
  }
  return 0; // versions are equal
}

Future<void> downloadFileWithProgress(String url, String filePath) async {
  logger.i('Download $filePath from $url');

  final httpClient = HttpClient();
  final request = await httpClient.getUrl(Uri.parse(url));
  final response = await request.close();

  final totalBytes = response.contentLength;
  int downloadedBytes = 0;

  final file = File(filePath);
  final sink = file.openWrite();

  // 進行状況バーの最大長
  const progressBarLength = 40;

  // Streamからデータを全て取得
  final allData = await response.toList();

  for (var data in allData) {
    sink.add(data);

    downloadedBytes += data.length;
    final progress = (downloadedBytes / totalBytes);

    final numBars = (progress * progressBarLength).round();
    final progressBars = List.filled(numBars, '=').join();
    final emptySpaces = List.filled(progressBarLength - numBars, ' ').join();

    stdout.write(
        '\r[$progressBars$emptySpaces] ${((progress * 100).toStringAsFixed(2))}%');
  }
  logger.i('\nDownload complete.');
  await sink.close();
  httpClient.close();
}

Future<void> unzipWithProgress(String zipFilePath, String outputDirPath) async {
  logger.i('Unziping $zipFilePath to $outputDirPath');

  final File file = File(zipFilePath);
  final bytes = file.readAsBytesSync();

  final Archive archive = ZipDecoder().decodeBytes(bytes);

  final progressBarLength = 40;
  final totalFiles = archive.length;
  int extractedFiles = 0;

  for (ArchiveFile archiveFile in archive) {
    final String filename = archiveFile.name;
    if (archiveFile.isFile) {
      final data = archiveFile.content as List<int>;
      File('$outputDirPath/$filename')
        ..createSync(recursive: true)
        ..writeAsBytesSync(data);
    } else {
      Directory('$outputDirPath/$filename').createSync(recursive: true);
    }

    extractedFiles++;

    final progress = (extractedFiles / totalFiles);
    final numBars = (progress * progressBarLength).round();
    final progressBars = List.filled(numBars, '=').join();
    final emptySpaces = List.filled(progressBarLength - numBars, ' ').join();

    stdout.write(
        '\r[$progressBars$emptySpaces] ${((progress * 100).toStringAsFixed(2))}%');
  }
  logger.i('\nExtraction complete.');
}
