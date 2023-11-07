import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:anyvm_win/anyvm_dartvm.dart' as anyvm_dartvm;
import 'package:anyvm_win/anyvm_fluttervm.dart' as anyvm_fluttervm;
import 'package:anyvm_win/anyvm_govm.dart' as anyvm_govm;
import 'package:anyvm_win/anyvm_ninjavm.dart' as anyvm_ninjavm;
import 'package:anyvm_win/anyvm_nodejsvm.dart' as anyvm_nodejsvm;
import 'package:anyvm_win/anyvm_pythonvm.dart' as anyvm_pythonvm;
import 'package:path/path.dart' as path;

class InitVm extends Command {
  @override
  final name = 'init';
  @override
  final description = 'Init version manager.';

  InitVm();
  @override
  void run() async {
    var scriptDirPath = anyvm_util.getScriptsDirectory();
    String scriptText;
    String scriptPath;
    List<String> activates = <String>[];
    List<String> deactivates = <String>[];

    activates.add(anyvm_dartvm.vmActivate);
    activates.add(anyvm_fluttervm.vmActivate);
    activates.add(anyvm_govm.vmActivate);
    activates.add(anyvm_ninjavm.vmActivate);
    activates.add(anyvm_nodejsvm.vmActivate);
    activates.add(anyvm_pythonvm.vmActivate);

    deactivates.add(anyvm_dartvm.vmDeactivate);
    deactivates.add(anyvm_fluttervm.vmDeactivate);
    deactivates.add(anyvm_govm.vmDeactivate);
    deactivates.add(anyvm_ninjavm.vmDeactivate);
    deactivates.add(anyvm_nodejsvm.vmDeactivate);
    deactivates.add(anyvm_pythonvm.vmDeactivate);

    scriptPath = path.join(scriptDirPath, 'AnyVmActivate.bat');
    scriptText = '';
    scriptText += '@ECHO OFF\n';
    for (var activate in activates) {
      scriptText += 'CALL %~dp0$activate.bat\n';
    }
    await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);

    scriptPath = path.join(scriptDirPath, 'AnyVmActivate.ps1');
    scriptText = '';
    for (var activate in activates) {
      scriptText += '. \$PSScriptRoot\\$activate.ps1\n';
    }
    await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);

    scriptPath = path.join(scriptDirPath, 'AnyVmDeactivate.bat');
    scriptText = '';
    scriptText += '@ECHO OFF\n';
    for (var deactivate in deactivates) {
      scriptText += 'CALL %~dp0$deactivate.bat\n';
    }
    await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);

    scriptPath = path.join(scriptDirPath, 'AnyVmDeactivate.ps1');
    scriptText = '';
    for (var deactivate in deactivates) {
      scriptText += '. \$PSScriptRoot\\$deactivate.ps1\n';
    }
    await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);

    scriptText = '';
    scriptText += '@ECHO OFF\n';
    for (var activate in activates) {
      scriptPath = path.join(scriptDirPath, '$activate.bat');
      var script = File(scriptPath);
      if (!await script.exists()) {
        await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);
      }
    }
    for (var deactivate in deactivates) {
      scriptPath = path.join(scriptDirPath, '$deactivate.bat');
      var script = File(scriptPath);
      if (!await script.exists()) {
        await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);
      }
    }
    scriptText = '\n';
    for (var activate in activates) {
      scriptPath = path.join(scriptDirPath, '$activate.ps1');
      var script = File(scriptPath);
      if (!await script.exists()) {
        await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);
      }
    }
    for (var deactivate in deactivates) {
      scriptPath = path.join(scriptDirPath, '$deactivate.ps1');
      var script = File(scriptPath);
      if (!await script.exists()) {
        await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);
      }
    }

    anyvm_util.logger
        .i('Please append the following process to the profile.ps1 file.');
    anyvm_util.logger.i(
        '\$env:Path = "${anyvm_util.getApplicationDirectory()};" + \$env:Path;');
    anyvm_util.logger.i('. "${path.join(scriptDirPath, "AnyVmActivate.ps1")}"');

    anyvm_util.logger
        .i('Please append the following process to the CmdProfile.bat file.');
    anyvm_util.logger
        .i('SET PATH=${anyvm_util.getApplicationDirectory()};%PATH%');
    anyvm_util.logger
        .i('CALL "${path.join(scriptDirPath, "AnyVmActivate.bat")}"');
  }
}
