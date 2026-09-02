import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneymonk/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MoneyMonk shows empty Money and Loans screens', (tester) async {
    await tester.pumpWidget(const MoneyMonkApp());

    expect(find.text('Home'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();

    // Money screen should show empty state
    expect(find.text('Money'), findsAtLeastNWidgets(1));
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('₹0'), findsWidgets);
    expect(find.text('Add'), findsOneWidget);

    // Navigate to Loans screen
    await tester.tap(find.text('Loans'));
    await tester.pumpAndSettle();

    // Loans screen should show empty state
    expect(find.text('Loans'), findsAtLeastNWidgets(1));
    expect(find.text('Add Loan'), findsOneWidget);
    expect(find.text('No loans added yet'), findsOneWidget);
  });

  testWidgets('Add Money creates income entry and updates totals', (tester) async {
    await tester.pumpWidget(const MoneyMonkApp());

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('money-add-button')));
    await tester.tap(find.byKey(const ValueKey('money-add-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('income-option')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Salary');
    await tester.enterText(find.byKey(const ValueKey('amount-field')), '80000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('₹80,000'), findsWidgets);
  });

  testWidgets('Month and Year view switching works', (tester) async {
    await tester.pumpWidget(const MoneyMonkApp());

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();

    // Check default monthly view
    expect(find.byIcon(Icons.chevron_left), findsWidgets);
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
    
    // Tap Yearly filter chip
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();

    // Yearly view should show forecast
    expect(find.text('Forecast'), findsOneWidget);
  });
}
