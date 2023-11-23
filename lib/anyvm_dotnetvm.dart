import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

const String versionCacheJsonName = 'dotnet_vm_version_cache.json';
const String vmName = 'dotnetVm';
const String langName = 'dotnetLang';
const String vmActivate = 'dotnetVmActivate';
const String vmDeactivate = 'dotnetVmDeactivate';
const String nugetURL =
    'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'dotnet'));
  return path.join(anyvmDir, 'envs', 'dotnet');
}

String getEnvCacheDirectory() {
  String envDir = getEnvDirectory();
  anyvm_util.logger.d(path.join(envDir, 'install-cache'));
  return path.join(envDir, 'install-cache');
}

List<String> getVersionDirectory() {
  List<String> versionDir = <String>[];
  var directory = Directory(getEnvDirectory());
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  List<FileSystemEntity> entities = directory.listSync();
  for (var entity in entities) {
    if (entity is Directory) {
      RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
      if (pattern.hasMatch(path.basename(entity.path))) {
        versionDir.add(path.basename(entity.path));
      }
    }
  }
  anyvm_util.logger.d(versionDir);
  return versionDir;
}

String getNugetDirectory() {
  String envDir = getEnvDirectory();
  anyvm_util.logger.d(path.join(envDir, 'nuget'));
  return path.join(envDir, 'nuget');
}

String getNugetPackagesDirectory() {
  String nugetDir = getNugetDirectory();
  anyvm_util.logger.d(path.join(nugetDir, 'packages'));
  return path.join(nugetDir, 'packages');
}

String getNugetFallbackPackagesDirectory() {
  String nugetDir = getNugetDirectory();
  anyvm_util.logger.d(path.join(nugetDir, 'fallback_packages'));
  return path.join(nugetDir, 'fallback_packages');
}

String getNugetNugetHttpCacheDirectory() {
  String nugetDir = getNugetDirectory();
  anyvm_util.logger.d(path.join(nugetDir, 'http_cache_path'));
  return path.join(nugetDir, 'http_cache_path');
}

String getNugetPersistDirectory() {
  String nugetDir = getNugetDirectory();
  anyvm_util.logger.d(path.join(nugetDir, 'persist_dg'));
  return path.join(nugetDir, 'persist_dg');
}

Future<void> setVersion(String version) async {
  await unSetVersion();
  var envDirPath = getEnvDirectory();

  var dotnetCurrentDirPath = path.join(envDirPath, 'current');
  anyvm_util.logger.d(dotnetCurrentDirPath);
  var dotnetCurrentDir = Directory(dotnetCurrentDirPath);

  var dotnetVersionDirPath = path.join(envDirPath, version);
  anyvm_util.logger.d(dotnetVersionDirPath);
  var dotnetVersionDir = Directory(dotnetVersionDirPath);

  if (!await dotnetVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await dotnetCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', dotnetCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $dotnetCurrentDirPath');
    }
  }
  var args = ['/C', 'MKLINK', '/J', dotnetCurrentDirPath, dotnetVersionDirPath];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  final result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
  } else {
    anyvm_util.logger
        .i('Junction created: $dotnetCurrentDirPath -> $dotnetVersionDirPath');
  }
  var toolsPath = path.join(envDirPath, '.dotnet', 'tools');

  var setPath = '$dotnetCurrentDirPath;$toolsPath;';
  anyvm_util.logger.d(setPath);

  var nugetPackagesDirPath = getNugetPackagesDirectory();
  var nugetFallbackPackagesDirPath = getNugetFallbackPackagesDirectory();
  var nugetNugetHttpCacheDirPath = getNugetNugetHttpCacheDirectory();
  var nugetPersistDirPath = getNugetPersistDirectory();

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;

  var activateScriptBat = path.join(scriptsDir, '$vmActivate.bat');
  scriptText = '';
  scriptText += '@ECHO OFF\n';
  scriptText += 'IF DEFINED _${vmName}_ENV_VAL GOTO END_SET_ENV_VAL\n';
  scriptText += 'SET _${vmName}_ENV_VAL={"yes"}\n';
  scriptText += 'SET PATH=$setPath%PATH%\n';
  scriptText += 'SET _OLD_DOTNET_ROOT=%DOTNET_ROOT%\n';
  scriptText += 'SET DOTNET_ROOT=$dotnetCurrentDirPath\n';
  scriptText += 'SET _OLD_DOTNET_ROOT(x86)=%_OLD_DOTNET_ROOT(x86)%\n';
  scriptText += 'SET DOTNET_ROOT(x86)=$dotnetCurrentDirPath\n';
  scriptText += 'SET _OLD_DOTNET_CLI_HOME=%DOTNET_CLI_HOME%\n';
  scriptText += 'SET DOTNET_CLI_HOME=$envDirPath\n';
  scriptText +=
      'SET _OLD_DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=%DOTNET_ADD_GLOBAL_TOOLS_TO_PATH%\n';
  scriptText += 'SET DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=false\n';
  scriptText +=
      'SET _OLD_DOTNET_CLI_TELEMETRY_OPTOUT=%DOTNET_CLI_TELEMETRY_OPTOUT%\n';
  scriptText += 'SET DOTNET_CLI_TELEMETRY_OPTOUT=true\n';
  scriptText += 'SET _OLD_NUGET_PACKAGES=%NUGET_PACKAGES%\n';
  scriptText += 'SET NUGET_PACKAGES=$nugetPackagesDirPath\n';
  scriptText += 'SET _OLD_NUGET_FALLBACK_PACKAGES=%NUGET_FALLBACK_PACKAGES%\n';
  scriptText += 'SET NUGET_FALLBACK_PACKAGES=$nugetFallbackPackagesDirPath\n';
  scriptText += 'SET _OLD_NUGET_HTTP_CACHE_PATH=%NUGET_HTTP_CACHE_PATH%\n';
  scriptText += 'SET NUGET_HTTP_CACHE_PATH=$nugetNugetHttpCacheDirPath\n';
  scriptText += 'SET _OLD_NUGET_PERSIST_DG=%NUGET_PERSIST_DG%\n';
  scriptText += 'SET NUGET_PERSIST_DG=$nugetPersistDirPath\n';
  scriptText += ':END_SET_ENV_VAL\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptBat, scriptText);
  anyvm_util.logger.i('$activateScriptBat creatred');

  var activateScriptPs1 = path.join(scriptsDir, '$vmActivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "yes";\n';
  scriptText += '    \$env:Path = "$setPath" + \$env:Path;\n';
  scriptText += '    \$env:_OLD_DOTNET_ROOT = \$env:OLD_DOTNET_ROOT;\n';
  scriptText += '    \$env:DOTNET_ROOT = "$dotnetCurrentDirPath";\n';
  scriptText +=
      '    \${env: _OLD_DOTNET_ROOT(x86)} = \${env:DOTNET_ROOT(x86)};\n';
  scriptText += '    \${env:DOTNET_ROOT(x86)} = "$dotnetCurrentDirPath";\n';
  scriptText += '    \$env:_OLD_DOTNET_CLI_HOME = \$env:DOTNET_CLI_HOME;\n';
  scriptText += '    \$env:DOTNET_CLI_HOME = "$envDirPath";\n';
  scriptText +=
      '    \$env:_OLD_DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = \$env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH;\n';
  scriptText += '    \$env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = "false";\n';
  scriptText +=
      '    \$env:_OLD_DOTNET_CLI_TELEMETRY_OPTOUT = \$env:DOTNET_CLI_TELEMETRY_OPTOUT;\n';
  scriptText += '    \$env:DOTNET_CLI_TELEMETRY_OPTOUT = "true";\n';
  scriptText += '    \$env:_OLD_NUGET_PACKAGES = \$env:NUGET_PACKAGES;\n';
  scriptText += '    \$env:NUGET_PACKAGES = "$nugetPackagesDirPath";\n';
  scriptText +=
      '    \$env:_OLD_NUGET_FALLBACK_PACKAGES = \$env:NUGET_FALLBACK_PACKAGES;\n';
  scriptText +=
      '    \$env:NUGET_FALLBACK_PACKAGES = "$nugetFallbackPackagesDirPath";\n';
  scriptText +=
      '    \$env:_OLD_NUGET_HTTP_CACHE_PATH = \$env:NUGET_HTTP_CACHE_PATH;\n';
  scriptText +=
      '    \$env:NUGET_HTTP_CACHE_PATH = "$nugetNugetHttpCacheDirPath";\n';
  scriptText += '    \$env:_OLD_NUGET_PERSIST_DG = \$env:NUGET_PERSIST_DG;\n';
  scriptText += '    \$env:NUGET_PERSIST_DG = "$nugetPersistDirPath";\n';
  scriptText += '} else {\n';
  scriptText += '}\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptPs1, scriptText);
  anyvm_util.logger.i('$activateScriptPs1 creatred');

  var deActivateScriptBat = path.join(scriptsDir, '$vmDeactivate.bat');
  scriptText = '';
  scriptText += '@ECHO OFF\n';
  scriptText += 'IF NOT DEFINED _${vmName}_ENV_VAL GOTO END_SET_ENV_VAL\n';
  scriptText += 'SET _${vmName}_ENV_VAL=\n';
  scriptText += 'SET PATH=%PATH:$setPath=%\n';
  scriptText += 'SET DOTNET_ROOT=%_OLD_DOTNET_ROOT%\n';
  scriptText += 'SET _OLD_DOTNET_ROOT=\n';
  scriptText += 'SET DOTNET_ROOT(x86)=%_OLD_DOTNET_ROOT(x86)%\n';
  scriptText += 'SET _OLD_DOTNET_ROOT(x86)=\n';
  scriptText += 'SET DOTNET_CLI_HOME=%_OLD_DOTNET_CLI_HOME%\n';
  scriptText += 'SET _OLD_DOTNET_CLI_HOME=\n';
  scriptText +=
      'SET DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=%_OLD_DOTNET_ADD_GLOBAL_TOOLS_TO_PATH%\n';
  scriptText += 'SET _OLD_DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=\n';
  scriptText +=
      'SET DOTNET_CLI_TELEMETRY_OPTOUT=%_OLD_DOTNET_CLI_TELEMETRY_OPTOUT%\n';
  scriptText += 'SET _OLD_DOTNET_CLI_TELEMETRY_OPTOUT=\n';
  scriptText += 'SET NUGET_PACKAGES=%_OLD_NUGET_PACKAGES%\n';
  scriptText += 'SET _OLD_NUGET_PACKAGES=\n';
  scriptText += 'SET NUGET_FALLBACK_PACKAGES=%_OLD_NUGET_FALLBACK_PACKAGES%\n';
  scriptText += 'SET _OLD_NUGET_FALLBACK_PACKAGES=\n';
  scriptText += 'SET NUGET_HTTP_CACHE_PATH=%_OLD_NUGET_HTTP_CACHE_PATH%\n';
  scriptText += 'SET _OLD_NUGET_HTTP_CACHE_PATH=\n';
  scriptText += 'SET NUGET_PERSIST_DG=%_OLD_NUGET_PERSIST_DG%\n';
  scriptText += 'SET _OLD_NUGET_PERSIST_DG=\n';
  scriptText += ':END_SET_ENV_VAL\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(deActivateScriptBat, scriptText);
  anyvm_util.logger.i('$deActivateScriptBat creatred');

  var deActivateScriptPs1 = path.join(scriptsDir, '$vmDeactivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '} else {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "";\n';
  scriptText += '    Set-Item ENV:Path \$env:Path.Replace("$setPath", "");\n';
  scriptText += '    \$env:DOTNET_ROOT = \$env:_OLD_DOTNET_ROOT;\n';
  scriptText += '    \$env:_OLD_DOTNET_ROOT = "";\n';
  scriptText +=
      '    \${env:DOTNET_ROOT(x86)} = \${env:_OLD_DOTNET_ROOT(x86)};\n';
  scriptText += '    \${env:_OLD_DOTNET_ROOT(x86)} = "";\n';
  scriptText += '    \$env:DOTNET_CLI_HOME = \$env:_OLD_DOTNET_CLI_HOME;\n';
  scriptText += '    \$env:_OLD_DOTNET_CLI_HOME = "";\n';
  scriptText +=
      '    \$env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = \$env:_OLD_DOTNET_ADD_GLOBAL_TOOLS_TO_PATH;\n';
  scriptText += '    \$env:_OLD_DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = "";\n';
  scriptText +=
      '    \$env:DOTNET_CLI_TELEMETRY_OPTOUT = \$env:_OLD_DOTNET_CLI_TELEMETRY_OPTOUT;\n';
  scriptText += '    \$env:_OLD_DOTNET_CLI_TELEMETRY_OPTOUT = "";\n';
  scriptText += '    \$env:NUGET_PACKAGES = \$env:_OLD_NUGET_PACKAGES;\n';
  scriptText += '    \$env:_OLD_NUGET_PACKAGES = "";\n';
  scriptText +=
      '    \$env:NUGET_FALLBACK_PACKAGES = \$env:_OLD_NUGET_FALLBACK_PACKAGES;\n';
  scriptText += '    \$env:_OLD_NUGET_FALLBACK_PACKAGES = "";\n';
  scriptText +=
      '    \$env:NUGET_HTTP_CACHE_PATH = \$env:_OLD_NUGET_HTTP_CACHE_PATH;\n';
  scriptText += '    \$env:_OLD_NUGET_HTTP_CACHE_PATH = "";\n';
  scriptText += '    \$env:NUGET_PERSIST_DG = \$env:_OLD_NUGET_PERSIST_DG;\n';
  scriptText += '    \$env:_OLD_NUGET_PERSIST_DG = "";\n';
  scriptText += '}\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(deActivateScriptPs1, scriptText);
  anyvm_util.logger.i('$deActivateScriptPs1 creatred');

  anyvm_util.setVmVersion(vmName, version);
}

Future<void> unSetVersion() async {
  var currentVersion = await anyvm_util.getVmVersion(vmName);
  if (currentVersion == null) {
    return;
  }
  var dotnetCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(dotnetCurrentDirPath);
  var dotnetCurrentDir = Directory(dotnetCurrentDirPath);

  var dotnetVersionDirPath = path.join(getEnvDirectory(), currentVersion);
  anyvm_util.logger.d(dotnetVersionDirPath);
  var dotnetVersionDir = Directory(dotnetVersionDirPath);

  if (!await dotnetVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await dotnetCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', dotnetCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    }
    anyvm_util.logger
        .i('Directory renamed/moved successfully.:$dotnetCurrentDirPath');
  }

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;

  var activateScriptBat = path.join(scriptsDir, '$vmActivate.bat');
  anyvm_util.logger.d(activateScriptBat);

  scriptText = '';
  scriptText += '@ECHO OFF\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptBat, scriptText);
  anyvm_util.logger.i('$activateScriptBat creatred');

  var activateScriptPs1 = path.join(scriptsDir, '$vmActivate.ps1');
  scriptText = '';
  scriptText += '\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptPs1, scriptText);
  anyvm_util.logger.i('$activateScriptPs1 creatred');

  anyvm_util.clearVmVersion(vmName);
}

class DotnetVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'dotnet version manager.';

  DotnetVm() {
    addSubcommand(DotnetVmInstall());
    addSubcommand(DotnetVmUpdate());
    addSubcommand(DotnetVmVersions());
    addSubcommand(DotnetVmVersion());
    addSubcommand(DotnetVmSet());
    addSubcommand(DotnetVmUnset());
    addSubcommand(DotnetVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class DotnetVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'see $vmName install -h';

  DotnetVmInstall() {
    argParser.addFlag('list', abbr: 'l', help: 'List all available versions.');
    argParser.addFlag('lastest', help: 'Lastest version to install.');
    argParser.addOption('version', abbr: 'v', help: 'Version to install.');
  }

  @override
  Future<void> run() async {
    var jsonPath =
        path.join(anyvm_util.getApplicationDirectory(), versionCacheJsonName);
    File file = File(jsonPath);
    String jsonString = await file.readAsString();
    List<Map<String, dynamic>> versionList = (jsonDecode(jsonString) as List)
        .map((item) => item as Map<String, dynamic>)
        .toList();

    final isList = argResults?['list'] ?? false;
    if (isList) {
      if (argResults?.rest.isNotEmpty == true) {
        printUsage();
        return;
      }
      for (var item in versionList) {
        anyvm_util.logger.i(item['version']);
      }
      return;
    }
    final isLast = argResults?['lastest'] ?? false;
    if (isLast) {
      if (argResults?.rest.isNotEmpty == true) {
        printUsage();
        return;
      }
      await install(versionList.last);
      return;
    }

    final version = argResults?['version'];
    if (version != null) {
      try {
        Map<String, dynamic> foundMap =
            versionList.firstWhere((map) => map['version'] == version);
        await install(foundMap);
      } catch (e) {
        anyvm_util.logger.i('No version found');
      }
      return;
    }
  }

  Future<void> install(Map<String, dynamic> item) async {
    var envVerDirPath = path.join(getEnvDirectory(), item['version']);
    anyvm_util.logger.d(envVerDirPath);
    var envVerDir = Directory(envVerDirPath);

    if (await envVerDir.exists()) {
      anyvm_util.logger.i('Already installed');
      return;
    }

    var envCacheDirPath = getEnvCacheDirectory();
    anyvm_util.logger.d(envCacheDirPath);
    var envCacheDir = Directory(envCacheDirPath);

    if (!(await envCacheDir.exists())) {
      await envCacheDir.create(recursive: true);
      anyvm_util.logger.i('$envCacheDirPath creatred');
    }

    var nugetDirPath = getNugetDirectory();
    anyvm_util.logger.d(nugetDirPath);
    var nugetDir = Directory(nugetDirPath);

    if (!(await nugetDir.exists())) {
      await nugetDir.create(recursive: true);
      anyvm_util.logger.i('$nugetDirPath creatred');
    }

    var nugetPackagesDirPath = getNugetPackagesDirectory();
    anyvm_util.logger.d(nugetPackagesDirPath);
    var nugetPackagesDir = Directory(nugetPackagesDirPath);

    if (!(await nugetPackagesDir.exists())) {
      await nugetPackagesDir.create(recursive: true);
      anyvm_util.logger.i('$nugetPackagesDirPath creatred');
    }

    var nugetFallbackPackagesDirPath = getNugetFallbackPackagesDirectory();
    anyvm_util.logger.d(nugetFallbackPackagesDirPath);
    var nugetFallbackPackagesDir = Directory(nugetFallbackPackagesDirPath);

    if (!(await nugetFallbackPackagesDir.exists())) {
      await nugetFallbackPackagesDir.create(recursive: true);
      anyvm_util.logger.i('$nugetFallbackPackagesDirPath creatred');
    }

    var nugetNugetHttpCacheDirPath = getNugetNugetHttpCacheDirectory();
    anyvm_util.logger.d(nugetNugetHttpCacheDirPath);
    var nugetNugetHttpCacheDir = Directory(nugetNugetHttpCacheDirPath);

    if (!(await nugetNugetHttpCacheDir.exists())) {
      await nugetNugetHttpCacheDir.create(recursive: true);
      anyvm_util.logger.i('$nugetNugetHttpCacheDirPath creatred');
    }

    var nugetPersistDirPath = getNugetPersistDirectory();
    anyvm_util.logger.d(nugetNugetHttpCacheDirPath);
    var nugetPersistDir = Directory(nugetPersistDirPath);

    if (!(await nugetPersistDir.exists())) {
      await nugetPersistDir.create(recursive: true);
      anyvm_util.logger.i('$nugetPersistDirPath creatred');
    }

    String? url;
    final response = await http.get(Uri.parse(item['url']));
    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      // ディレクトリリストを含むaタグを取得
      var links = document.querySelectorAll('a');

      for (final link in links) {
        final href = link.attributes['href'];
        if (href != null) {
          if (href.endsWith(item['file'])) {
            url = href;
            anyvm_util.logger.i('Download url: $href');
            break;
          }
        }
      }
    }
    if (url == null) {
      anyvm_util.logger.i('Download url not found');
      return;
    }
    var filePath = path.join(envCacheDirPath, item['file']);
    var file = File(filePath);
    if (!await file.exists()) {
      try {
        await anyvm_util.downloadFileWithProgress(url, filePath);
      } catch (e) {
        anyvm_util.logger.e('Error during downloading: $e');
        return;
      }
    }
    var extractDirPath = path.join(envCacheDirPath, item['version']);
    var extractDir = Directory(extractDirPath);
    if (!await extractDir.exists()) {
      try {
        await anyvm_util.unzipWithProgress(filePath, extractDirPath);
      } catch (e) {
        anyvm_util.logger.e('Error during unzipping: $e');
      }
    }

    if (await extractDir.exists()) {
      var nugetfilePath = path.join(extractDirPath, 'nuget.exe');
      var nugetfile = File(nugetfilePath);
      if (!await nugetfile.exists()) {
        try {
          await anyvm_util.downloadFileWithProgress(nugetURL, nugetfilePath);
        } catch (e) {
          anyvm_util.logger.e('Error during downloading: $e');
          return;
        }
      }
      await extractDir.rename(envVerDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $envVerDirPath');
    }

    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }
}

class DotnetVmUpdate extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Update the list of installable $langName versions';

  DotnetVmUpdate();

  @override
  Future<void> run() async {
    final exe = 'git';
    var args = <String>[];
    args.add('ls-remote');
    args.add('--tags');
    args.add('https://github.com/dotnet/sdk/');

    anyvm_util.logger.d(exe);
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run(exe, args);
    // コマンドが成功したかどうかを確認
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to git: ${result.stderr}');
      return;
    } else {
      var versions = <String>[];
      var tags = result.stdout.split('\n');
      anyvm_util.logger.d(tags);
      for (var tag in tags) {
        var tagInfo = tag.split('\t');
        if (tagInfo.length > 1) {
          var version = tagInfo[1].replaceAll('refs/tags/v', '');
          RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
          if (pattern.hasMatch(version)) {
            if (anyvm_util.compareVersion(version, '6.0.0') >= 0) {
              versions.add(version);
            }
          }
        }
      }
      versions.sort(anyvm_util.compareVersion);
      List<Map<String, dynamic>> versionList = <Map<String, dynamic>>[];
      for (var version in versions) {
        Map<String, dynamic> versionMap = {
          'version': version,
          'url':
              'https://dotnet.microsoft.com/ja-jp/download/dotnet/thank-you/sdk-$version-windows-x64-binaries',
          'file': 'dotnet-sdk-$version-win-x64.zip'
        };
        versionList.add(versionMap);
      }
      String jsonString =
          const JsonEncoder.withIndent('  ').convert(versionList);
      anyvm_util.logger.d(jsonString);

      var jsonPath =
          path.join(anyvm_util.getApplicationDirectory(), versionCacheJsonName);
      anyvm_util.logger.d(jsonPath);

      File file = File(jsonPath);
      await file.writeAsString(jsonString);
      anyvm_util.logger.i('$jsonPath creatred');
    }
  }
}

class DotnetVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  DotnetVmVersions();

  @override
  Future<void> run() async {
    var currentVersion = await anyvm_util.getVmVersion(vmName);
    var versionDirs = getVersionDirectory();
    if (versionDirs.isNotEmpty) {
      for (var dir in versionDirs) {
        if (currentVersion == dir) {
          anyvm_util.logger.i('*$dir');
        } else {
          anyvm_util.logger.i(' $dir');
        }
      }
    } else {
      anyvm_util.logger.i('No versions found');
    }
  }
}

class DotnetVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  DotnetVmVersion();

  @override
  Future<void> run() async {
    var currentVersion = await anyvm_util.getVmVersion(vmName);
    if (currentVersion == null) {
      anyvm_util.logger.i('No version found');
    } else {
      anyvm_util.logger.i(currentVersion);
    }
  }
}

class DotnetVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  DotnetVmSet() {
    argParser.addOption('version', abbr: 'v', help: 'Version to set.');
  }

  @override
  Future<void> run() async {
    final version = argResults?['version'];
    if (version != null) {
      RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
      if (pattern.hasMatch(path.basename(version))) {
        var versionDirs = getVersionDirectory();
        var hasVesion = versionDirs.where((w) => w == version).firstOrNull;
        if (hasVesion == null) {
          anyvm_util.logger.i('version does not exist');
        } else {
          await setVersion(version);
        }
      } else {
        anyvm_util.logger.i('version does not exist');
      }
    } else {
      anyvm_util.logger.i('version does not exist');
    }
  }
}

class DotnetVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  DotnetVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class DotnetVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  DotnetVmUnInstall() {
    argParser.addOption('version', abbr: 'v', help: 'Version to uninstall.');
  }

  @override
  Future<void> run() async {
    final version = argResults?['version'];
    if (version != null) {
      try {
        await uninstall(version);
      } catch (e) {
        anyvm_util.logger.i('No version found');
      }
      return;
    }
  }

  Future<void> uninstall(String version) async {
    var envVerDirPath = path.join(getEnvDirectory(), version);
    var envVerDir = Directory(envVerDirPath);

    if (!await envVerDir.exists()) {
      anyvm_util.logger.i('No version found');
      return;
    }
    await envVerDir.delete(recursive: true);
    anyvm_util.logger
        .i('Directory renamed/moved successfully.: $envVerDirPath');
  }
}
