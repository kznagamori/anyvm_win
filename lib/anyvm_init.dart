import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:anyvm_win/anyvm_dartvm.dart' as anyvm_dartvm;
import 'package:anyvm_win/anyvm_fluttervm.dart' as anyvm_fluttervm;
import 'package:anyvm_win/anyvm_govm.dart' as anyvm_govm;
import 'package:anyvm_win/anyvm_ninjavm.dart' as anyvm_ninjavm;
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

    scriptPath = path.join(scriptDirPath, 'AnyVmActivate.bat');
    scriptText = '';
    scriptText += '@ECHO OFF\n';
    scriptText += 'CALL %~dp0${anyvm_dartvm.vmActivate}.bat\n';
    scriptText += 'CALL %~dp0${anyvm_fluttervm.vmActivate}.bat\n';
    scriptText += 'CALL %~dp0${anyvm_govm.vmActivate}.bat\n';
    scriptText += 'CALL %~dp0${anyvm_ninjavm.vmActivate}.bat\n';
    await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);

    scriptPath = path.join(scriptDirPath, 'AnyVmActivate.ps1');
    scriptText = '';
    scriptText += '. \$PSScriptRoot\\${anyvm_dartvm.vmActivate}.ps1\n';
    scriptText += '. \$PSScriptRoot\\${anyvm_fluttervm.vmActivate}.ps1\n';
    scriptText += '. \$PSScriptRoot\\${anyvm_govm.vmActivate}.ps1\n';
    scriptText += '. \$PSScriptRoot\\${anyvm_ninjavm.vmActivate}.ps1\n';
    await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);

    scriptPath = path.join(scriptDirPath, 'AnyVmDeactivate.bat');
    scriptText = '';
    scriptText += '@ECHO OFF\n';
    scriptText += 'CALL %~dp0${anyvm_dartvm.vmDeactivate}.bat\n';
    scriptText += 'CALL %~dp0${anyvm_fluttervm.vmDeactivate}.bat\n';
    scriptText += 'CALL %~dp0${anyvm_govm.vmDeactivate}.bat\n';
    scriptText += 'CALL %~dp0${anyvm_ninjavm.vmDeactivate}.bat\n';
    await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);

    scriptPath = path.join(scriptDirPath, 'AnyVmDeactivate.ps1');
    scriptText = '';
    scriptText += '. \$PSScriptRoot\\${anyvm_dartvm.vmDeactivate}.ps1\n';
    scriptText += '. \$PSScriptRoot\\${anyvm_fluttervm.vmDeactivate}.ps1\n';
    scriptText += '. \$PSScriptRoot\\${anyvm_govm.vmDeactivate}.ps1\n';
    scriptText += '. \$PSScriptRoot\\${anyvm_ninjavm.vmDeactivate}.ps1\n';
    await anyvm_util.writeStringWithSjisEncoding(scriptPath, scriptText);
  }
}
