import 'dart:core';
import 'dart:mirrors';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:anyvm_win/anyvm_dartvm.dart' as anyvm_dartvm;

import 'package:args/args.dart';

//dart compile exe  .\bin\anyvm_win.dart -o .\build\anyvm_win.exe
////mklink /J D:\repo\anyvm_win\envs\python\current D:\repo\anyvm_win\envs\python\3.10.11
void main(List<String> arguments) {
  anyvm_util.setupLogging();
  final parser = ArgParser();
  var dartVm = anyvm_dartvm.DartVm();
  parser.addCommand(dartVm.runtimeType.toString());

  final results = parser.parse(arguments);
  if (results.command == null) {
    return;
  }

  ClassMirror? classMirror;
  for (var library in currentMirrorSystem().libraries.values) {
    classMirror =
        library.declarations[MirrorSystem.getSymbol(results.command!.name!)]
            as ClassMirror?;
    if (classMirror != null) {
      break;
    }
  }
}
