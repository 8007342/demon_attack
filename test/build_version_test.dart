// build-version: the version format (lib/build_info.dart) and its label
// (lib/widgets/build_version_label.dart). The cases are shared with the
// build script's test (test-worker/build-version.test.mjs).
import 'dart:convert';
import 'dart:io';

import 'package:demon_attack/build_info.dart';
import 'package:demon_attack/widgets/build_version_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the major is years since 1970: 2026-11-17 is v56.11.17', () {
    expect(epochMajor(2026), 56);
    expect(
      formatBuildVersion(
        day: DateTime(2026, 11, 17),
        build: 1,
        production: true,
      ),
      'v56.11.17.1',
    );
  });

  test('formatBuildVersion agrees with the build script on every case', () {
    final file = File('test/fixtures/build_version_cases.json');
    final cases = (jsonDecode(file.readAsStringSync())['cases'] as List)
        .cast<Map<String, dynamic>>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      expect(
        formatBuildVersion(
          day: DateTime.parse(c['day'] as String),
          build: c['build'] as int,
          production: c['channel'] == 'production',
          commit: c['commit'] as String,
        ),
        c['version'],
        reason: '$c',
      );
    }
  });

  test('buildVersion prefers the stamp, else a dev version for today', () {
    expect(buildVersion(stamped: 'v56.11.17.1'), 'v56.11.17.1');
    expect(
      buildVersion(stamped: '', now: DateTime(2026, 11, 17, 23, 59)),
      'v56.11.17-dev',
    );
  });

  testWidgets('the label sits in the corner and the footer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: withBuildVersion,
        home: Scaffold(
          body: const Stack(children: [BuildVersionCorner()]),
          bottomNavigationBar: const BuildVersionFooter(),
        ),
      ),
    );
    // The app-wide footer, the corner and the Scaffold footer.
    expect(find.byKey(const ValueKey('build-version')), findsNWidgets(3));
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('build-version')).first,
    );
    expect(text.data, buildVersion());
    expect(text.style!.fontSize, lessThanOrEqualTo(10));
  });
}
