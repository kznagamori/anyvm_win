import 'dart:core';
import 'dart:io';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:anyvm_win/anyvm_dartvm.dart' as anyvm_dartvm;
import 'package:anyvm_win/anyvm_fluttervm.dart' as anyvm_fluttervm;
import 'package:anyvm_win/anyvm_govm.dart' as anyvm_govm;
import 'package:anyvm_win/anyvm_init.dart' as anyvm_init;
import 'package:anyvm_win/anyvm_ninjavm.dart' as anyvm_ninjavm;
import 'package:args/command_runner.dart';
import 'package:logger/logger.dart';

void main(List<String> args) async {
  var runner = CommandRunner('anyvm', 'Description of any version management.');
  runner.argParser.addFlag('version',
      help: 'Display the version of the tool.',
      negatable: false, callback: (version) {
    if (version) {
      print('version 1.0.0');
      exit(0);
    }
  });
  runner.argParser.addFlag('verbose',
      help: 'Show verbose output.', negatable: false, callback: (verbose) {
    if (verbose) {
      anyvm_util.setupLogging(Level.all);
    } else {
      anyvm_util.setupLogging(Level.info);
    }
  });
  runner.addCommand(anyvm_init.InitVm());
  runner.addCommand(anyvm_dartvm.DartVm());
  runner.addCommand(anyvm_ninjavm.NinjaVm());
  runner.addCommand(anyvm_fluttervm.FlutterVm());
  runner.addCommand(anyvm_govm.GoVm());

  await runner.run(args).catchError((error) {
    if (error is! UsageException) throw error;
    print(error);
    exit(1);
  });
}
