import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sportsphere/pages/login_page.dart';

void main() {
  testWidgets('Login page renders email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
