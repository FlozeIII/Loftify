import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loftify/Widgets/Item/login_input_item.dart';
import 'package:loftify/Widgets/loftify_icons.dart';

void main() {
  testWidgets('captcha tail stays readable while the user enters and refreshes it',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var refreshes = 0;
    const captchaKey = ValueKey('test-photo-captcha');

    await tester.pumpWidget(
      _host(
        LoginInputItem(
          controller: controller,
          tailingConfig: InputItemLeadingTailingConfig(
            type: InputItemLeadingTailingType.widget,
            widget: GestureDetector(
              onTap: () => refreshes++,
              child: const SizedBox(
                key: captchaKey,
                width: 86,
                height: 40,
                child: ColoredBox(color: Colors.teal),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(captchaKey)).width, 86);
    final editable = find.byType(EditableText);
    expect(tester.getSize(editable).width, greaterThan(100));
    await tester.tap(editable);
    await tester.enterText(editable, '123456');
    expect(controller.text, '123456');
    await tester.tap(find.byKey(captchaKey));
    expect(refreshes, 1);
    expect(controller.text, '123456');
    expect(tester.takeException(), isNull);
  });

  testWidgets('login clear action is clickable beyond the icon bounds',
      (tester) async {
    final controller = TextEditingController(text: 'content');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        LoginInputItem(
          controller: controller,
          tailingConfig: InputItemLeadingTailingConfig(
            type: InputItemLeadingTailingType.clear,
          ),
        ),
      ),
    );

    final icon = find.byIcon(LoftifyIcons.clear);
    expect(icon, findsOneWidget);
    // Exercise the edge of the documented 44px target, outside the 20px icon.
    await tester.tapAt(tester.getCenter(icon) + const Offset(21, 0));
    expect(controller.text, isEmpty);
  });

  testWidgets('password action changes meaning without leaving Lucide',
      (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        LoginInputItem(
          controller: controller,
          tailingConfig: InputItemLeadingTailingConfig(
            type: InputItemLeadingTailingType.password,
          ),
        ),
      ),
    );

    expect(find.byIcon(LoftifyIcons.visible), findsOneWidget);
    await tester.tap(find.byIcon(LoftifyIcons.visible));
    await tester.pump();
    expect(find.byIcon(LoftifyIcons.hidden), findsOneWidget);
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      extensions: const <ThemeExtension<dynamic>>[
        ChewieIconThemeData.standard,
      ],
    ),
    home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
  );
}
