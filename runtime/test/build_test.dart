import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conduit_runtime/runtime.dart';
import 'package:test/test.dart';

/*
need test with normal package, relative package, git package
need to test for local (relative), in pub cache (absolute)
*/

void main() {
  setUpAll(() async {
    var cmd;
    if (Platform.isWindows) {
      cmd = (await Process.run("where", ["pub.bat"])).stdout;
    } else {
      cmd = (await Process.run("which", ["pub"])).stdout;
    }

    final testPackagesUri =
        Directory.current.uri.resolve("../").resolve("runtime_test_packages/");
    await Process.run(cmd, ["get", "--offline"],
        workingDirectory: testPackagesUri
            .resolve("application/")
            .toFilePath(windows: Platform.isWindows),
        runInShell: true);
    await Process.run(cmd, ["get", "--offline"],
        workingDirectory: testPackagesUri
            .resolve("dependency/")
            .toFilePath(windows: Platform.isWindows),
        runInShell: true);

    final appDir = testPackagesUri.resolve("application/");
    final appLib = appDir.resolve("lib/").resolve("application.dart");
    final tmp = Directory.current.uri.resolve("tmp/");
    final ctx = BuildContext(
        appLib,
        tmp,
        tmp.resolve("app.aot"),
        File.fromUri(appDir.resolve("bin/").resolve("main.dart"))
            .readAsStringSync());
    final bm = BuildManager(ctx);
    await bm.build();
  });

  tearDownAll(() {
    Directory.fromUri(Directory.current.uri.resolve("tmp/"))
        .deleteSync(recursive: true);
  });

  test("Non-compiled version returns mirror runtimes", () async {
    final output = await dart(Directory.current.uri
        .resolve("../")
        .resolve("runtime_test_packages/")
        .resolve("application/"));
    expect(json.decode(output), {
      "Consumer": "mirrored",
      "ConsumerSubclass": "mirrored",
      "ConsumerScript": "mirrored",
    });
  });

  test(
      "Compiled version of application returns source generated runtimes and can be AOT compiled",
      () async {
    final output = await runExecutable(
        Directory.current.uri.resolve("tmp/").resolve("app.aot"),
        Directory.current.uri
            .resolve("../")
            .resolve("runtime_test_packages/")
            .resolve("application/"));
    expect(json.decode(output), {
      "Consumer": "generated",
      "ConsumerSubclass": "generated",
      "ConsumerScript": "generated",
    });
  });
}

Future<String> dart(Uri workingDir) async {
  final result = await Process.run(
    "dart",
    ["bin/main.dart"],
    workingDirectory: workingDir.toFilePath(windows: Platform.isWindows),
    runInShell: true,
  );
  return result.stdout.toString();
}

Future<String> runExecutable(Uri buildUri, Uri workingDir) async {
  final result = await Process.run(
      buildUri.toFilePath(windows: Platform.isWindows), [],
      workingDirectory: workingDir.toFilePath(windows: Platform.isWindows),
      runInShell: true);
  return result.stdout.toString();
}
