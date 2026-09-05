import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneymonk/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> signUp(WidgetTester tester) async {
    await tester.pumpWidget(const MoneyMonkApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New here? Sign up'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'tester');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
  }

  testWidgets('MoneyMonk shows empty Money and Loans screens', (tester) async {
    await signUp(tester);

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
    await signUp(tester);

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
    await signUp(tester);

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

    // Tap All filter chip
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('All Records'), findsOneWidget);
    expect(find.text('All-Time Income'), findsOneWidget);
  });

  testWidgets('Financial Health Scorecard renders on Home screen', (tester) async {
    await signUp(tester);

    expect(find.text('Financial Health Scorecard'), findsOneWidget);
    expect(find.text('Savings Rate'), findsOneWidget);
    expect(find.text('Debt-to-Income'), findsOneWidget);
  });

  testWidgets('User Management Sheet opens via account chip', (tester) async {
    await signUp(tester);

    // Find and tap the user chip in AppBar
    await tester.tap(find.text('tester'));
    await tester.pumpAndSettle();

    expect(find.text('Account & Users'), findsOneWidget);
    expect(find.text('Active Account'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  test('LoanEntry dynamic month-by-month amortization engine works correctly', () {
    final loan = LoanEntry(
      id: 'loan-1',
      name: 'Car Loan',
      originalAmountInPaise: 10000000, // ₹1,00,000
      outstandingAmountInPaise: 10000000,
      interestRatePerAnnum: 12.0, // 1% per month
      emiInPaise: 1000000, // ₹10,000
      extraEmiInPaise: 200000, // ₹2,000 extra
      startDate: DateTime(2026, 1, 1),
      tenureMonths: 10,
    );

    // January 2026: Month 1
    expect(loan.isActiveInMonth(DateTime(2026, 1)), isTrue);
    final janEmi = loan.getEmiForMonth(DateTime(2026, 1));
    expect(janEmi, equals(1200000)); // ₹12,000

    final janPrincipal = loan.getRemainingPrincipalForMonth(DateTime(2026, 1));
    // Interest = 1,00,000 * 1% = 1,000. Principal paid = 12,000 - 1,000 = 11,000.
    // Remaining principal = 89,000 (8900000 paise).
    expect(janPrincipal, equals(8900000));

    // February 2026: Month 2
    expect(loan.isActiveInMonth(DateTime(2026, 2)), isTrue);
    final febPrincipal = loan.getRemainingPrincipalForMonth(DateTime(2026, 2));
    expect(febPrincipal, lessThan(janPrincipal));

    // After loan is completed:
    final amort = loan.calculateAmortization();
    expect(amort.isValid, isTrue);
    expect(amort.schedule.length, lessThan(10)); // Extra EMI accelerated payoff
    final completionMonth = amort.completionDate!;
    final postCompletion = DateTime(completionMonth.year, completionMonth.month + 1);

    expect(loan.isPaidOffAsOf(postCompletion), isTrue);
    expect(loan.isActiveInMonth(postCompletion), isFalse);
    expect(loan.getEmiForMonth(postCompletion), equals(0));
    expect(loan.getRemainingPrincipalForMonth(postCompletion), equals(0));
  });

  test('MoneyEntry recurring and one-time monthly population engine works correctly', () {
    final recurringSalary = MoneyEntry(
      id: 'salary-1',
      name: 'Salary',
      type: MoneyEntryType.income,
      amountInPaise: 8000000, // ₹80,000
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
      frequency: RecurrenceFrequency.monthly,
    );

    final oneTimeBonus = MoneyEntry(
      id: 'bonus-1',
      name: 'Diwali Bonus',
      type: MoneyEntryType.income,
      amountInPaise: 2500000, // ₹25,000
      mode: MoneyEntryMode.oneTime,
      date: DateTime(2026, 10, 15),
    );

    // Recurring salary automatically applies to all months on or after start
    expect(recurringSalary.appliesToMonth(DateTime(2026, 1)), isTrue);
    expect(recurringSalary.appliesToMonth(DateTime(2026, 5)), isTrue);
    expect(recurringSalary.appliesToMonth(DateTime(2026, 10)), isTrue);
    expect(recurringSalary.appliesToMonth(DateTime(2027, 3)), isTrue);
    expect(recurringSalary.appliesToMonth(DateTime(2025, 12)), isFalse);

    // One-time bonus only applies to October 2026
    expect(oneTimeBonus.appliesToMonth(DateTime(2026, 10)), isTrue);
    expect(oneTimeBonus.appliesToMonth(DateTime(2026, 9)), isFalse);
    expect(oneTimeBonus.appliesToMonth(DateTime(2026, 11)), isFalse);

    // Overriding recurring salary in a specific month
    final overriddenSalary = MoneyEntry(
      id: recurringSalary.id,
      name: recurringSalary.name,
      type: recurringSalary.type,
      amountInPaise: recurringSalary.amountInPaise,
      mode: recurringSalary.mode,
      date: recurringSalary.date,
      frequency: recurringSalary.frequency,
      overrides: {
        DateTime(2026, 10): 9500000, // ₹95,000 in October
      },
    );

    expect(overriddenSalary.getAmountForMonth(DateTime(2026, 9)), equals(8000000));
    expect(overriddenSalary.getAmountForMonth(DateTime(2026, 10)), equals(9500000));
    expect(overriddenSalary.getAmountForMonth(DateTime(2026, 11)), equals(8000000));
  });
}
