import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:DartCore/data/simulation/theo_lookup_bundle_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate bundled theo lookup table', () {
    final stopwatch = Stopwatch()..start();
    final source = buildGeneratedTheoLookupTableSource(
      onProgress: (label, progress) {
        final progressText = progress == null
            ? label
            : '$label ${(progress * 100).toStringAsFixed(0)}%';
        // ignore: avoid_print
        print(progressText);
      },
    );
    final outputFile = File('lib/data/simulation/generated_theo_lookup_table.dart');
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(source);
    // ignore: avoid_print
    print(
      'generated_theo_lookup=${outputFile.path} bytes=${outputFile.lengthSync()} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}
