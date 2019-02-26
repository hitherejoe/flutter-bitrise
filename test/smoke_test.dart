// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gallery/gallery/demos.dart';
import 'package:flutter_gallery/gallery/app.dart' show GalleryApp;

// This title is visible on the home and demo category pages. It's
// not visible when the demos are running.
const String kGalleryTitle = 'Flutter gallery';

// All of the classes printed by debugDump etc, must have toString()
// values approved by verityToStringOutput().
int toStringErrors = 0;

// There are 3 places where the Gallery demos are traversed.
// 1- In widget tests such as examples/flutter_gallery/test/smoke_test.dart
// 2- In driver tests such as examples/flutter_gallery/test_driver/transitions_perf_test.dart
// 3- In on-device instrumentation tests such as examples/flutter_gallery/test/live_smoketest.dart
//
// If you change navigation behavior in the Gallery or in the framework, make
// sure all 3 are covered.

void reportToStringError(String name, String route, int lineNumber, List<String> lines, String message) {
  // If you're on line 12, then it has index 11.
  // If you want 1 line before and 1 line after, then you want lines with index 10, 11, and 12.
  // That's (lineNumber-1)-margin .. (lineNumber-1)+margin, or lineNumber-(margin+1) .. lineNumber+(margin-1)
  const int margin = 5;
  final int firstLine = math.max(0, lineNumber - margin);
  final int lastLine = math.min(lines.length, lineNumber + margin);
  print('$name : $route : line $lineNumber of ${lines.length} : $message; nearby lines were:\n  ${lines.sublist(firstLine, lastLine).join("\n  ")}');
  toStringErrors += 1;
}

void verifyToStringOutput(String name, String route, String testString) {
  int lineNumber = 0;
  final List<String> lines = testString.split('\n');
  if (!testString.endsWith('\n'))
    reportToStringError(name, route, lines.length, lines, 'does not end with a line feed');
  for (String line in lines) {
    lineNumber += 1;
    if (line == '' && lineNumber != lines.length) {
      reportToStringError(name, route, lineNumber, lines, 'found empty line');
    } else if (line.contains('Instance of ')) {
      reportToStringError(name, route, lineNumber, lines, 'found a class that does not have its own toString');
    } else if (line.endsWith(' ')) {
      reportToStringError(name, route, lineNumber, lines, 'found a line with trailing whitespace');
    }
  }
}

Future<void> smokeDemo(WidgetTester tester, GalleryDemo demo) async {
  // Don't use pumpUntilNoTransientCallbacks in this function, because some of
  // the smoketests have infinitely-running animations (e.g. the progress
  // indicators demo).

  await tester.tap(find.text(demo.title));
  await tester.pump(); // Launch the demo.
  await tester.pump(const Duration(milliseconds: 400)); // Wait until the demo has opened.
  expect(find.text(kGalleryTitle), findsNothing);

  // Leave the demo on the screen briefly for manual testing.
  await tester.pump(const Duration(milliseconds: 400));

  // Scroll the demo around a bit.
  await tester.flingFrom(const Offset(400.0, 300.0), const Offset(-100.0, 0.0), 500.0);
  await tester.flingFrom(const Offset(400.0, 300.0), const Offset(0.0, -100.0), 500.0);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 400));

  // Verify that the dumps are pretty.
  final String routeName = demo.routeName;
  verifyToStringOutput('debugDumpApp', routeName, WidgetsBinding.instance.renderViewElement.toStringDeep());
  verifyToStringOutput('debugDumpRenderTree', routeName, RendererBinding.instance?.renderView?.toStringDeep());
  verifyToStringOutput('debugDumpLayerTree', routeName, RendererBinding.instance?.renderView?.debugLayer?.toStringDeep());

  // Scroll the demo around a bit more.
  await tester.flingFrom(const Offset(400.0, 300.0), const Offset(-200.0, 0.0), 500.0);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.flingFrom(const Offset(400.0, 300.0), const Offset(100.0, 0.0), 500.0);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.flingFrom(const Offset(400.0, 300.0), const Offset(0.0, 400.0), 1000.0);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // Go back
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.pump(); // Start the pop "back" operation.
  await tester.pump(); // Complete the willPop() Future.
  await tester.pump(const Duration(milliseconds: 400)); // Wait until it has finished.
}

Future<void> smokeOptionsPage(WidgetTester tester) async {
  final Finder showOptionsPageButton = find.byTooltip('Toggle options page');

  // Show the options page
  await tester.tap(showOptionsPageButton);
  await tester.pumpAndSettle();

  // Switch to the dark theme: first switch control
  await tester.tap(find.byType(Switch).first);
  await tester.pumpAndSettle();

  // Switch back to the light theme: first switch control again
  await tester.tap(find.byType(Switch).first);
  await tester.pumpAndSettle();

  // Popup the text size menu: first menu button, choose 'Small'
  await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Small'));
  await tester.pumpAndSettle();

  // Popup the text size menu: first menu button, choose 'Normal'
  await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Normal'));
  await tester.pumpAndSettle();

  // Scroll the 'Send feedback' item into view
  await tester.drag(find.text('Normal'), const Offset(0.0, -1000.0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send feedback'));
  await tester.pumpAndSettle();

  // Close the options page
  expect(showOptionsPageButton, findsOneWidget);
  await tester.tap(showOptionsPageButton);
  await tester.pumpAndSettle();
}

Future<void> smokeGallery(WidgetTester tester) async {
  bool sendFeedbackButtonPressed = false;

  await tester.pumpWidget(
    GalleryApp(
      testMode: true,
      onSendFeedback: () {
        sendFeedbackButtonPressed = true; // see smokeOptionsPage()
      },
    ),
  );
  await tester.pump(); // see https://github.com/flutter/flutter/issues/1865
  await tester.pump(); // triggers a frame

  expect(find.text(kGalleryTitle), findsOneWidget);

  for (GalleryDemoCategory category in kAllGalleryDemoCategories) {
    await Scrollable.ensureVisible(tester.element(find.text(category.name)), alignment: 0.5);
    await tester.tap(find.text(category.name));
    await tester.pumpAndSettle();
    for (GalleryDemo demo in kGalleryCategoryToDemos[category]) {
      await Scrollable.ensureVisible(tester.element(find.text(demo.title)), alignment: 0.0);
      await smokeDemo(tester, demo);
      tester.binding.debugAssertNoTransientCallbacks('A transient callback was still active after running $demo');
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
  }
  expect(toStringErrors, 0);

  await smokeOptionsPage(tester);
  expect(sendFeedbackButtonPressed, true);
}

void main() {
  testWidgets('Flutter Gallery app smoke test', smokeGallery);

  testWidgets('Flutter Gallery app smoke test with semantics', (WidgetTester tester) async {
    RendererBinding.instance.setSemanticsEnabled(true);
    await smokeGallery(tester);
    RendererBinding.instance.setSemanticsEnabled(false);
  });
}
