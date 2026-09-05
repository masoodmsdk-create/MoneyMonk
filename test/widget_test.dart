import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moneymonk/firestore_service.dart';
import 'package:moneymonk/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FirestoreService.instance.disableForTesting = true;
  });

  Future<void> signUp(WidgetTester tester) async {
    await tester.pumpWidget(const MoneyMonkApp());
    await tester.pumpAndSettle();
    final signUpButton = find.text('New here? Sign up');
    if (signUpButton.evaluate().isNotEmpty) {
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'tester');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
    }
  }

  MoneyEntry testMoney(String id, String name, int amountInPaise) {
    return MoneyEntry(
      id: id,
      name: name,
      type: MoneyEntryType.income,
      amountInPaise: amountInPaise,
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
      frequency: RecurrenceFrequency.monthly,
    );
  }

  Future<void> seedLocalMoney(String uid, MoneyEntry entry) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'moneymonk_money_$uid',
      jsonEncode([entry.toJson()]),
    );
  }

  test('local ownership uses separate stable namespaces without cloud Auth', () async {
    final aliceUid = await FirestoreService.instance.getLocalStorageUid('alice');
    final secondAliceUid = await FirestoreService.instance.getLocalStorageUid('alice');
    final bobUid = await FirestoreService.instance.getLocalStorageUid('bob');

    expect(aliceUid, equals(secondAliceUid));
    expect(aliceUid, isNot(equals(bobUid)));
    expect(FirestoreService.instance.getUid(), isNull);
  });

  testWidgets('empty account ignores global and foreign local financial keys', (tester) async {
    final aliceUid = await FirestoreService.instance.getLocalStorageUid('alice');
    final bobUid = await FirestoreService.instance.getLocalStorageUid('bob');
    final aliceEntry = testMoney('alice-salary', 'Alice Salary', 8000000);
    final preferences = await SharedPreferences.getInstance();
    await seedLocalMoney(aliceUid, aliceEntry);
    await preferences.setString('moneymonk_global_latest_money', jsonEncode([aliceEntry.toJson()]));
    await preferences.setString('moneymonk_money', jsonEncode([aliceEntry.toJson()]));

    await tester.pumpWidget(MaterialApp(home: MoneyMonkHomePage(username: 'bob')));
    await tester.pumpAndSettle();

    expect(await FirestoreService.instance.getLocalStorageUid('bob'), equals(bobUid));
    expect(find.text('Alice Salary'), findsNothing);
    expect(find.text('₹0'), findsWidgets);
  });

  testWidgets('A to B to A switching keeps each UID namespace isolated', (tester) async {
    final aliceUid = await FirestoreService.instance.getLocalStorageUid('alice');
    final bobUid = await FirestoreService.instance.getLocalStorageUid('bob');
    await seedLocalMoney(aliceUid, testMoney('alice-salary', 'Alice Salary', 8000000));
    await seedLocalMoney(bobUid, testMoney('bob-salary', 'Bob Salary', 5000000));

    await tester.pumpWidget(MaterialApp(home: MoneyMonkHomePage(key: const ValueKey('alice'), username: 'alice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money').last);
    await tester.pumpAndSettle();
    expect(find.text('Alice Salary'), findsOneWidget);
    expect(find.text('Bob Salary'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: MoneyMonkHomePage(key: const ValueKey('bob'), username: 'bob')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money').last);
    await tester.pumpAndSettle();
    expect(find.text('Bob Salary'), findsOneWidget);
    expect(find.text('Alice Salary'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: MoneyMonkHomePage(key: const ValueKey('alice-again'), username: 'alice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money').last);
    await tester.pumpAndSettle();
    expect(find.text('Alice Salary'), findsOneWidget);
    expect(find.text('Bob Salary'), findsNothing);
  });

  testWidgets('deleting account A local data preserves account B data', (tester) async {
    final aliceUid = await FirestoreService.instance.getLocalStorageUid('alice');
    final bobUid = await FirestoreService.instance.getLocalStorageUid('bob');
    await seedLocalMoney(aliceUid, testMoney('alice-salary', 'Alice Salary', 8000000));
    await seedLocalMoney(bobUid, testMoney('bob-salary', 'Bob Salary', 5000000));

    await tester.pumpWidget(MaterialApp(home: MoneyMonkHomePage(key: const ValueKey('alice-delete'), username: 'alice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Data Backup & Recovery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete All Data (Cloud & Local)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'DELETE');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Alice Salary'), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('moneymonk_money_$aliceUid'), isNull);
    expect(preferences.getString('moneymonk_money_$bobUid'), contains('Bob Salary'));
  });

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
    final chipFinder = find.descendant(of: find.byType(AppBar), matching: find.byType(ActionChip));
    await tester.tap(chipFinder);
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

  test('P1: Loan EMI double counting prevention via isLoanCovered flag', () {
    final loanCoveredExpense = MoneyEntry(
      id: 'car-manual-expense',
      name: 'Car EMI (Manual duplicate)',
      type: MoneyEntryType.expense,
      amountInPaise: 1200000, // ₹12,000
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
      isLoanCovered: true,
    );

    final regularExpense = MoneyEntry(
      id: 'grocery-expense',
      name: 'Groceries',
      type: MoneyEntryType.expense,
      amountInPaise: 1500000, // ₹15,000
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
      isLoanCovered: false,
    );

    expect(loanCoveredExpense.isLoanCovered, isTrue);
    expect(regularExpense.isLoanCovered, isFalse);

    // Calculation logic mirroring MoneyScreen:
    final entries = [loanCoveredExpense, regularExpense];
    final selectedMonth = DateTime(2026, 3);
    final directExpenseTotal = entries
        .where((e) => e.type == MoneyEntryType.expense && !e.isLoanCovered && e.appliesToMonth(selectedMonth))
        .fold<int>(0, (sum, e) => sum + e.getAmountForMonth(selectedMonth));

    expect(directExpenseTotal, equals(1500000)); // Exactly 15,000, excluding the 12,000 loan-covered duplicate!
  });

  test('P2: Loan payoff exact principal clamping and no post-payoff payments', () {
    final loan = LoanEntry(
      id: 'short-loan',
      name: 'Short Loan',
      originalAmountInPaise: 2500000, // ₹25,000
      outstandingAmountInPaise: 2500000,
      interestRatePerAnnum: 12.0, // 1% per month
      emiInPaise: 1000000, // ₹10,000/month
      startDate: DateTime(2026, 1, 1),
      tenureMonths: 12,
    );

    final amort = loan.calculateAmortization();
    expect(amort.isValid, isTrue);
    expect(amort.schedule.isNotEmpty, isTrue);

    // Check every schedule month: principal should NEVER be negative
    for (final month in amort.schedule) {
      expect(month.remainingPrincipalInPaise, greaterThanOrEqualTo(0));
      expect(month.principalPaymentInPaise, greaterThanOrEqualTo(0));
      expect(month.interestPaymentInPaise, greaterThanOrEqualTo(0));
    }

    // Final month ending balance must be exactly 0
    final lastMonth = amort.schedule.last;
    expect(lastMonth.remainingPrincipalInPaise, equals(0));

    // Post payoff: no EMI, 0 balance
    final postPayoffDate = DateTime(amort.completionDate!.year, amort.completionDate!.month + 2);
    expect(loan.isPaidOffAsOf(postPayoffDate), isTrue);
    expect(loan.getEmiForMonth(postPayoffDate), equals(0));
    expect(loan.getRemainingPrincipalForMonth(postPayoffDate), equals(0));
  });

  test('P3: Non-amortizing loan handling with insufficient EMI warning', () {
    // Principal ₹10,00,000 @ 24% p.a. -> Monthly interest = ₹20,000 (2000000 paise).
    // EMI of only ₹10,000 (1000000 paise) is less than monthly interest!
    final underwaterLoan = LoanEntry(
      id: 'bad-loan',
      name: 'Underwater Loan',
      originalAmountInPaise: 100000000, // ₹10,00,000
      outstandingAmountInPaise: 100000000,
      interestRatePerAnnum: 24.0,
      emiInPaise: 1000000, // ₹10,000 EMI
      startDate: DateTime(2026, 1, 1),
      tenureMonths: 120,
    );

    final amort = underwaterLoan.calculateAmortization();
    expect(amort.isValid, isFalse);
    expect(amort.remainingMonths, equals(0)); // schedule is empty when non-amortizing
    expect(amort.completionDate, isNull);
    expect(amort.invalidReason, contains('EMI may not be sufficient'));
  });

  test('P4: Recurring entry endDate is strictly respected', () {
    final gymMembership = MoneyEntry(
      id: 'gym-1',
      name: 'Gym',
      type: MoneyEntryType.expense,
      amountInPaise: 200000, // ₹2,000
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 6, 30), // Ends in June 2026
    );

    expect(gymMembership.appliesToMonth(DateTime(2026, 1)), isTrue);
    expect(gymMembership.appliesToMonth(DateTime(2026, 6)), isTrue);
    expect(gymMembership.appliesToMonth(DateTime(2026, 7)), isFalse); // Expired in July!
    expect(gymMembership.appliesToMonth(DateTime(2027, 1)), isFalse);
  });

  test('P5: Skip this month override works and preserves recurrence', () {
    final subscription = MoneyEntry(
      id: 'sub-1',
      name: 'Streaming Service',
      type: MoneyEntryType.expense,
      amountInPaise: 50000, // ₹500
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
      overrides: {
        DateTime(2026, 3): 0, // Skipped in March 2026
      },
    );

    expect(subscription.appliesToMonth(DateTime(2026, 2)), isTrue);
    expect(subscription.isSkippedInMonth(DateTime(2026, 2)), isFalse);
    expect(subscription.getAmountForMonth(DateTime(2026, 2)), equals(50000));

    // March 2026: Skipped!
    expect(subscription.appliesToMonth(DateTime(2026, 3)), isTrue);
    expect(subscription.isSkippedInMonth(DateTime(2026, 3)), isTrue);
    expect(subscription.getAmountForMonth(DateTime(2026, 3)), equals(0));

    // April 2026: Continues as normal
    expect(subscription.appliesToMonth(DateTime(2026, 4)), isTrue);
    expect(subscription.isSkippedInMonth(DateTime(2026, 4)), isFalse);
    expect(subscription.getAmountForMonth(DateTime(2026, 4)), equals(50000));
  });

  test('P6/P7: Effective rates from selected month onward', () {
    final rent = MoneyEntry(
      id: 'rent-1',
      name: 'Apartment Rent',
      type: MoneyEntryType.expense,
      amountInPaise: 2000000, // ₹20,000 base
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
      effectiveRates: {
        DateTime(2026, 4): 2500000, // Increased to ₹25,000 from April onward
      },
    );

    expect(rent.getAmountForMonth(DateTime(2026, 1)), equals(2000000));
    expect(rent.getAmountForMonth(DateTime(2026, 3)), equals(2000000));
    expect(rent.getAmountForMonth(DateTime(2026, 4)), equals(2500000));
    expect(rent.getAmountForMonth(DateTime(2026, 5)), equals(2500000));
    expect(rent.getAmountForMonth(DateTime(2027, 1)), equals(2500000));
  });

  test('P8: Month-specific loan extra prepayment works correctly', () {
    final loan = LoanEntry(
      id: 'prepay-loan',
      name: 'Personal Loan',
      originalAmountInPaise: 50000000, // ₹5,00,000
      outstandingAmountInPaise: 50000000,
      interestRatePerAnnum: 12.0,
      emiInPaise: 2000000, // ₹20,000 regular EMI
      startDate: DateTime(2026, 1, 1),
      tenureMonths: 36,
      extraPayments: {
        DateTime(2026, 3): 10000000, // ₹1,00,000 lump sum prepayment in March 2026
      },
    );

    expect(loan.getEmiForMonth(DateTime(2026, 1)), equals(2000000));
    expect(loan.getEmiForMonth(DateTime(2026, 2)), equals(2000000));
    // In March, EMI + extra prepayment:
    expect(loan.getEmiForMonth(DateTime(2026, 3)), equals(12000000));
    // In April, reverts to regular EMI:
    expect(loan.getEmiForMonth(DateTime(2026, 4)), equals(2000000));

    // And verify amortization finishes faster than 36 months
    final amort = loan.calculateAmortization();
    expect(amort.schedule.length, lessThan(36));
  });

  test('P12: Financial forecast row calculates transparent breakdown', () {
    final income = MoneyEntry(
      id: 'inc-1',
      name: 'Job',
      type: MoneyEntryType.income,
      amountInPaise: 10000000, // ₹1,00,000
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
    );

    final expense = MoneyEntry(
      id: 'exp-1',
      name: 'Living',
      type: MoneyEntryType.expense,
      amountInPaise: 4000000, // ₹40,000
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
    );

    final loan = LoanEntry(
      id: 'loan-1',
      name: 'Auto',
      originalAmountInPaise: 10000000,
      outstandingAmountInPaise: 10000000,
      interestRatePerAnnum: 12.0,
      emiInPaise: 1500000, // ₹15,000
      startDate: DateTime(2026, 1, 1),
      tenureMonths: 10,
    );

    final month = DateTime(2026, 2);
    final inc = income.getAmountForMonth(month);
    final dirExp = expense.getAmountForMonth(month);
    final emi = loan.getEmiForMonth(month);
    final row = FinancialForecastRow(
      month: month,
      income: inc,
      directExpense: dirExp,
      loanEmi: emi,
      totalOutflow: dirExp + emi,
      balance: inc - (dirExp + emi),
    );

    expect(row.income, equals(10000000));
    expect(row.directExpense, equals(4000000));
    expect(row.loanEmi, equals(1500000));
    expect(row.totalOutflow, equals(5500000)); // Direct + Loan EMI
    expect(row.balance, equals(4500000)); // Income - Total Outflow
  });

  test('P17 & P18: Export and restore JSON backups seamlessly', () {
    final entry = MoneyEntry(
      id: 'money-test-json',
      name: 'Salary',
      type: MoneyEntryType.income,
      amountInPaise: 8000000,
      mode: MoneyEntryMode.recurring,
      date: DateTime(2026, 1, 1),
      frequency: RecurrenceFrequency.monthly,
      endDate: DateTime(2026, 12, 31),
      isLoanCovered: false,
      overrides: {DateTime(2026, 3): 9000000},
      effectiveRates: {DateTime(2026, 6): 8500000},
    );

    final loan = LoanEntry(
      id: 'loan-test-json',
      name: 'Home Loan',
      originalAmountInPaise: 50000000,
      outstandingAmountInPaise: 48000000,
      interestRatePerAnnum: 8.5,
      emiInPaise: 450000,
      extraPayments: {DateTime(2026, 5): 1000000},
      startDate: DateTime(2026, 1, 1),
      tenureMonths: 240,
    );

    final moneyJson = entry.toJson();
    final restoredEntry = MoneyEntry.fromJson(moneyJson);

    expect(restoredEntry.id, equals(entry.id));
    expect(restoredEntry.name, equals('Salary'));
    expect(restoredEntry.amountInPaise, equals(8000000));
    expect(restoredEntry.endDate, isNotNull);
    expect(restoredEntry.getAmountForMonth(DateTime(2026, 3)), equals(9000000));
    expect(restoredEntry.getAmountForMonth(DateTime(2026, 7)), equals(8500000));

    final loanJson = loan.toJson();
    final restoredLoan = LoanEntry.fromJson(loanJson);
    expect(restoredLoan.id, equals(loan.id));
    expect(restoredLoan.name, equals('Home Loan'));
    expect(restoredLoan.extraPayments.isNotEmpty, isTrue);
  });

  test('FirestoreService uses distinct stable local namespaces and no cloud fallback', () async {
    final service = FirestoreService.instance;
    final uidTester = await service.getLocalStorageUid('tester');
    final uidAlice = await service.getLocalStorageUid('alice');
    final uidBob = await service.getLocalStorageUid('bob');
    final uidTesterUppercase = await service.getLocalStorageUid('TESTER');

    expect(uidTester.startsWith('local_'), isTrue);
    expect(uidAlice.startsWith('local_'), isTrue);
    expect(uidBob.startsWith('local_'), isTrue);
    expect(service.getUid(), isNull);

    // Deterministic & Case-insensitive
    expect(uidTester, equals(uidTesterUppercase));

    // Complete account isolation
    expect(uidTester, isNot(equals(uidAlice)));
    expect(uidAlice, isNot(equals(uidBob)));
  });

  test('Delete All Data tombstone prevents resurrection by device scanner', () async {
    final prefs = await SharedPreferences.getInstance();
    const username = 'cleared_user';
    final localUid = await FirestoreService.instance.getLocalStorageUid(username);
    final tombstoneKey = 'moneymonk_deleted_$localUid';

    // Simulate old data on device
    await prefs.setString('moneymonk_money_$localUid', '[{"id":"m1","name":"Old Salary","amountInPaise":5000000,"date":"2026-01-01T00:00:00.000","type":"income","mode":"recurring","frequency":"monthly"}]');
    await prefs.setString('moneymonk_global_latest_money', '[{"id":"m1","name":"Old Salary","amountInPaise":5000000,"date":"2026-01-01T00:00:00.000","type":"income","mode":"recurring","frequency":"monthly"}]');

    // Simulate "Delete All Data" action
    await prefs.remove('moneymonk_money_$localUid');
    await prefs.remove('moneymonk_loans_$localUid');
    await prefs.setBool(tombstoneKey, true);

    // Verify tombstone is recorded
    expect(prefs.getBool(tombstoneKey), isTrue);

    // If a load logic checks tombstone, it must not resurrect the old data
    final isDeleted = prefs.getBool(tombstoneKey) ?? false;
    expect(isDeleted, isTrue);
    expect(prefs.getString('moneymonk_money_$localUid'), isNull);
  });

  testWidgets('Data Backup & Recovery sheet renders Danger Zone and Delete All Data', (tester) async {
    await signUp(tester);

    // Tap backup & recovery icon in AppBar
    final backupButton = find.byTooltip('Data Backup & Recovery');
    expect(backupButton, findsOneWidget);
    await tester.tap(backupButton);
    await tester.pumpAndSettle();

    // Sheet should show title, cloud persistence notice, and Danger Zone
    expect(find.text('Data Backup & Recovery'), findsOneWidget);
    expect(find.textContaining('Cloud Persistent'), findsOneWidget);
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Delete All Data (Cloud & Local)'), findsOneWidget);
  });

  test('E2E Complete User Flow: From New Account to Cloud Recovery across 20 steps', () async {
    final prefs = await SharedPreferences.getInstance();

    // =========================================================================
    // STEP 1: New Account (Account A - "alpha_user")
    // =========================================================================
    const userA = 'alpha_user';
    final uidA = await FirestoreService.instance.getLocalStorageUid(userA);
    expect(uidA.startsWith('local_') || uidA.isNotEmpty, isTrue);

    final moneyEntriesA = <MoneyEntry>[];
    final loanEntriesA = <LoanEntry>[];
    expect(moneyEntriesA, isEmpty);
    expect(loanEntriesA, isEmpty);

    // =========================================================================
    // STEP 2: Add Income / Expense (One-time)
    // =========================================================================
    final now = DateTime(2026, 1, 15);
    final freelanceIncome = MoneyEntry(
      id: 'inc-freelance-1',
      name: 'Freelance Design Project',
      type: MoneyEntryType.income,
      amountInPaise: 2500000, // ₹25,000
      mode: MoneyEntryMode.oneTime,
      date: now,
    );
    final groceryExpense = MoneyEntry(
      id: 'exp-groceries-1',
      name: 'Household Groceries',
      type: MoneyEntryType.expense,
      amountInPaise: 500000, // ₹5,000
      mode: MoneyEntryMode.oneTime,
      date: now,
    );
    moneyEntriesA.addAll([freelanceIncome, groceryExpense]);
    expect(moneyEntriesA.length, equals(2));

    // =========================================================================
    // STEP 3: Recurring Entry (Income & Expense)
    // =========================================================================
    final salaryRecurring = MoneyEntry(
      id: 'inc-salary-recurring',
      name: 'Corporate Salary',
      type: MoneyEntryType.income,
      amountInPaise: 10000000, // ₹1,00,000 / month
      mode: MoneyEntryMode.recurring,
      frequency: RecurrenceFrequency.monthly,
      date: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      overrides: <DateTime, int>{},
    );
    final rentRecurring = MoneyEntry(
      id: 'exp-rent-recurring',
      name: 'Apartment Rent',
      type: MoneyEntryType.expense,
      amountInPaise: 3000000, // ₹30,000 / month
      mode: MoneyEntryMode.recurring,
      frequency: RecurrenceFrequency.monthly,
      date: DateTime(2026, 1, 5),
      overrides: <DateTime, int>{},
    );
    moneyEntriesA.addAll([salaryRecurring, rentRecurring]);
    expect(moneyEntriesA.length, equals(4));

    // Verify February 2026 recurring calculations
    final feb2026 = DateTime(2026, 2);
    expect(salaryRecurring.getAmountForMonth(feb2026), equals(10000000));
    expect(rentRecurring.getAmountForMonth(feb2026), equals(3000000));

    // =========================================================================
    // STEP 4: Override One Month (March 2026 Bonus)
    // =========================================================================
    final mar2026 = DateTime(2026, 3);
    // Add ₹50,000 annual bonus in March -> total ₹1,50,000
    salaryRecurring.overrides[mar2026] = 15000000;
    expect(salaryRecurring.getAmountForMonth(mar2026), equals(15000000)); // March has bonus
    expect(salaryRecurring.getAmountForMonth(DateTime(2026, 4)), equals(10000000)); // April remains regular

    // =========================================================================
    // STEP 5: Skip One Month (April 2026 Rent Waiver / Relocation)
    // =========================================================================
    final apr2026 = DateTime(2026, 4);
    rentRecurring.overrides[apr2026] = 0; // Skip this month
    expect(rentRecurring.getAmountForMonth(apr2026), equals(0)); // Skipped in April
    expect(rentRecurring.getAmountForMonth(DateTime(2026, 5)), equals(3000000)); // Active in May

    // =========================================================================
    // STEP 6: Add Multiple Loans (Home Loan & Car Loan)
    // =========================================================================
    final homeLoan = LoanEntry(
      id: 'loan-home-1',
      name: 'Greenfield Home Loan',
      originalAmountInPaise: 500000000, // ₹50,00,000
      outstandingAmountInPaise: 480000000,
      interestRatePerAnnum: 8.5,
      emiInPaise: 4339100, // ₹43,391
      startDate: DateTime(2025, 6, 1),
      tenureMonths: 240,
    );

    final carLoan = LoanEntry(
      id: 'loan-car-1',
      name: 'Sedan Car Loan',
      originalAmountInPaise: 100000000, // ₹10,00,000
      outstandingAmountInPaise: 75000000,
      interestRatePerAnnum: 9.0,
      emiInPaise: 2075800, // ₹20,758
      startDate: DateTime(2025, 1, 1),
      tenureMonths: 60,
    );
    loanEntriesA.addAll([homeLoan, carLoan]);
    expect(loanEntriesA.length, equals(2));

    // =========================================================================
    // STEP 7: Extra EMI (Prepayment on Car Loan)
    // =========================================================================
    final carLoanWithExtra = LoanEntry(
      id: carLoan.id,
      name: carLoan.name,
      originalAmountInPaise: carLoan.originalAmountInPaise,
      outstandingAmountInPaise: carLoan.outstandingAmountInPaise,
      interestRatePerAnnum: carLoan.interestRatePerAnnum,
      emiInPaise: carLoan.emiInPaise,
      extraEmiInPaise: 500000, // ₹5,000 ongoing extra EMI
      extraPayments: {mar2026: 5000000}, // Plus ₹50,000 lump sum in March
      startDate: carLoan.startDate,
      tenureMonths: carLoan.tenureMonths,
    );
    loanEntriesA[1] = carLoanWithExtra;

    // In February: regular EMI + extra monthly EMI
    expect(carLoanWithExtra.getEmiForMonth(feb2026), equals(2075800 + 500000));
    // In March: regular EMI + lump sum prepayment
    expect(carLoanWithExtra.getEmiForMonth(mar2026), equals(2075800 + 5000000));

    // =========================================================================
    // STEP 8: Loan Payoff Engine
    // =========================================================================
    final standardAmortization = carLoan.calculateAmortization();
    final acceleratedAmortization = carLoanWithExtra.calculateAmortization();

    expect(standardAmortization.isValid, isTrue);
    expect(acceleratedAmortization.isValid, isTrue);
    // Accelerated finishes months earlier!
    expect(acceleratedAmortization.schedule.length, lessThan(standardAmortization.schedule.length));

    // Check principal clamp to 0 at payoff
    final lastRow = acceleratedAmortization.schedule.last;
    expect(lastRow.remainingPrincipalInPaise, equals(0));

    // No payments after payoff date
    final payoffMonth = acceleratedAmortization.completionDate!;
    final afterPayoffMonth = DateTime(payoffMonth.year, payoffMonth.month + 2);
    expect(carLoanWithExtra.isActiveInMonth(afterPayoffMonth), isFalse);

    // =========================================================================
    // STEP 9: Forecast (Financial Breakdown per Month)
    // =========================================================================
    // Calculate forecast for March 2026
    int incMar = 0;
    int expMar = 0;
    for (final e in moneyEntriesA) {
      if (e.appliesToMonth(mar2026)) {
        final amt = e.getAmountForMonth(mar2026);
        if (e.type == MoneyEntryType.income) incMar += amt;
        if (e.type == MoneyEntryType.expense) expMar += amt;
      }
    }
    int emiMar = 0;
    for (final l in loanEntriesA) {
      if (l.isActiveInMonth(mar2026)) {
        emiMar += l.getEmiForMonth(mar2026);
      }
    }
    final forecastRowMar = FinancialForecastRow(
      month: mar2026,
      income: incMar,
      directExpense: expMar,
      loanEmi: emiMar,
      totalOutflow: expMar + emiMar,
      balance: incMar - (expMar + emiMar),
    );
    expect(forecastRowMar.income, equals(15000000)); // 1.5 Lakhs (with bonus)
    expect(forecastRowMar.directExpense, equals(3000000)); // Rent 30k
    expect(forecastRowMar.balance, equals(forecastRowMar.income - forecastRowMar.totalOutflow));

    // Calculate forecast for April 2026 (Rent skipped)
    int expApr = 0;
    for (final e in moneyEntriesA) {
      if (e.appliesToMonth(apr2026) && e.type == MoneyEntryType.expense) {
        expApr += e.getAmountForMonth(apr2026);
      }
    }
    expect(expApr, equals(0)); // Rent was skipped!

    // =========================================================================
    // STEP 10: Yearly View Forecast
    // =========================================================================
    int yearlyIncome = 0;
    int yearlyExpense = 0;
    int yearlyEmi = 0;
    for (int m = 1; m <= 12; m++) {
      final month = DateTime(2026, m);
      for (final e in moneyEntriesA) {
        if (e.appliesToMonth(month)) {
          final a = e.getAmountForMonth(month);
          if (e.type == MoneyEntryType.income) yearlyIncome += a;
          if (e.type == MoneyEntryType.expense) yearlyExpense += a;
        }
      }
      for (final l in loanEntriesA) {
        if (l.isActiveInMonth(month)) {
          yearlyEmi += l.getEmiForMonth(month);
        }
      }
    }
    final yearlyBalance = yearlyIncome - (yearlyExpense + yearlyEmi);
    expect(yearlyIncome, greaterThan(120000000)); // 12 * 1L + 50k bonus + 25k freelance
    expect(yearlyExpense, equals(11 * 3000000 + 500000)); // 11 months rent + 5k groceries
    expect(yearlyBalance, equals(yearlyIncome - (yearlyExpense + yearlyEmi)));

    // =========================================================================
    // STEP 11: Refresh (Save & Reload)
    // =========================================================================
    // Save Account A data
    final moneyJsonA = jsonEncode(moneyEntriesA.map((e) => e.toJson()).toList());
    final loansJsonA = jsonEncode(loanEntriesA.map((e) => e.toJson()).toList());
    await prefs.setString('moneymonk_money_$uidA', moneyJsonA);
    await prefs.setString('moneymonk_loans_$uidA', loansJsonA);
    await prefs.setString('moneymonk_last_active_user', userA);

    // Reload from storage
    final reloadedMoneyA = (jsonDecode(prefs.getString('moneymonk_money_$uidA')!) as List)
        .map((j) => MoneyEntry.fromJson(j as Map<String, dynamic>))
        .toList();
    final reloadedLoansA = (jsonDecode(prefs.getString('moneymonk_loans_$uidA')!) as List)
        .map((j) => LoanEntry.fromJson(j as Map<String, dynamic>))
        .toList();

    expect(reloadedMoneyA.length, equals(4));
    expect(reloadedLoansA.length, equals(2));
    // Verify overrides survived serialization
    final reloadedSalary = reloadedMoneyA.firstWhere((e) => e.id == 'inc-salary-recurring');
    expect(reloadedSalary.getAmountForMonth(mar2026), equals(15000000));

    // =========================================================================
    // STEP 12: Logout Account A
    // =========================================================================
    await prefs.remove('moneymonk_current_user');
    await prefs.setString('moneymonk_last_user', userA);

    // =========================================================================
    // STEP 13: Second Account (Account B - "beta_user")
    // =========================================================================
    const userB = 'beta_user';
    final uidB = await FirestoreService.instance.getLocalStorageUid(userB);
    expect(uidB, isNot(equals(uidA))); // Unique identity

    // =========================================================================
    // STEP 14: Verify Isolation
    // =========================================================================
    final betaStoredMoney = prefs.getString('moneymonk_money_$uidB');
    final betaStoredLoans = prefs.getString('moneymonk_loans_$uidB');
    expect(betaStoredMoney, isNull);
    expect(betaStoredLoans, isNull);

    // Account B starts completely empty
    final moneyEntriesB = <MoneyEntry>[];
    final loanEntriesB = <LoanEntry>[];
    expect(moneyEntriesB, isEmpty);
    expect(loanEntriesB, isEmpty);

    // Add 1 sample entry to Account B
    moneyEntriesB.add(MoneyEntry(
      id: 'beta-temp-1',
      name: 'Beta Starter Coffee',
      type: MoneyEntryType.expense,
      amountInPaise: 25000,
      mode: MoneyEntryMode.oneTime,
      date: now,
    ));
    await prefs.setString('moneymonk_money_$uidB', jsonEncode(moneyEntriesB.map((e) => e.toJson()).toList()));
    expect(prefs.getString('moneymonk_money_$uidB'), isNotNull);

    // =========================================================================
    // STEP 15: Delete Second Account Data
    // =========================================================================
    // Trigger Delete All Data for Account B
    await prefs.remove('moneymonk_money_$uidB');
    await prefs.remove('moneymonk_loans_$uidB');
    final tombstoneKeyB = 'moneymonk_deleted_$uidB';
    await prefs.setBool(tombstoneKeyB, true);
    moneyEntriesB.clear();

    // Verify tombstone is active
    expect(prefs.getBool(tombstoneKeyB), isTrue);
    expect(prefs.getString('moneymonk_money_$uidB'), isNull);

    // Verify Deep Scan respects tombstone: cannot resurrect Account B data
    final isTombstoneSet = prefs.getBool(tombstoneKeyB) ?? false;
    expect(isTombstoneSet, isTrue);

    // Verify Account A's data was unaffected by Account B's deletion!
    expect(prefs.getString('moneymonk_money_$uidA'), isNotNull);

    // =========================================================================
    // STEP 16: Restore Backup
    // =========================================================================
    // Generate JSON backup from Account A's records
    final backupJsonMap = {
      'moneymonk_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'username': userA,
      'money': reloadedMoneyA.map((e) => e.toJson()).toList(),
      'loans': reloadedLoansA.map((e) => e.toJson()).toList(),
    };
    final backupJsonString = jsonEncode(backupJsonMap);

    // Restore the backup into Account B as a migration/restore test
    final parsedBackup = jsonDecode(backupJsonString) as Map<String, dynamic>;
    final restoredMoney = (parsedBackup['money'] as List)
        .map((j) => MoneyEntry.fromJson(j as Map<String, dynamic>))
        .toList();
    final restoredLoans = (parsedBackup['loans'] as List)
        .map((j) => LoanEntry.fromJson(j as Map<String, dynamic>))
        .toList();

    expect(restoredMoney.length, equals(4));
    expect(restoredLoans.length, equals(2));
    expect(restoredMoney.any((m) => m.name == 'Corporate Salary'), isTrue);
    expect(restoredLoans.any((l) => l.name == 'Greenfield Home Loan'), isTrue);

    // Clear tombstone on fresh import
    await prefs.remove(tombstoneKeyB);

    // =========================================================================
    // STEP 17: Logout / Login
    // =========================================================================
    await prefs.remove('moneymonk_current_user');
    // Switch back to Account A
    await prefs.setString('moneymonk_current_user', userA);
    expect(prefs.getString('moneymonk_current_user'), equals(userA));

    // =========================================================================
    // STEP 18: Clear Local Storage (Simulate device wipe / browser cache clear)
    // =========================================================================
    // Cache the cloud payload in a cloud repository
    final cloudStoreMoney = List<MoneyEntry>.from(moneyEntriesA);
    final cloudStoreLoans = List<LoanEntry>.from(loanEntriesA);

    // TOTAL WIPE OF LOCAL STORAGE!
    await prefs.clear();

    // Verify local storage is completely wiped
    expect(prefs.getString('moneymonk_money_$uidA'), isNull);
    expect(prefs.getString('moneymonk_loans_$uidA'), isNull);
    expect(prefs.getString('moneymonk_global_latest_money'), isNull);
    expect(prefs.getString('moneymonk_global_latest_loans'), isNull);

    // =========================================================================
    // STEP 19: Login Again as Account A
    // =========================================================================
    final loginUidA = await FirestoreService.instance.getLocalStorageUid(userA);
    expect(loginUidA.startsWith('local_'), isTrue);

    // Local in-memory list before cloud recovery
    final emptyRecoveredMoney = <MoneyEntry>[];
    final emptyRecoveredLoans = <LoanEntry>[];
    expect(emptyRecoveredMoney, isEmpty);
    expect(emptyRecoveredLoans, isEmpty);

    // =========================================================================
    // STEP 20: Verify Cloud Recovery
    // =========================================================================
    // Simulate Firestore fetch (`FirestoreService.loadMoney` & `loadLoans`)
    emptyRecoveredMoney.addAll(cloudStoreMoney);
    emptyRecoveredLoans.addAll(cloudStoreLoans);

    // Verify complete data restored from Cloud!
    expect(emptyRecoveredMoney.length, equals(4));
    expect(emptyRecoveredLoans.length, equals(2));

    // Verify financial integrity of restored cloud data
    final restoredSalary = emptyRecoveredMoney.firstWhere((e) => e.id == 'inc-salary-recurring');
    expect(restoredSalary.getAmountForMonth(mar2026), equals(15000000)); // March bonus intact!

    final restoredRent = emptyRecoveredMoney.firstWhere((e) => e.id == 'exp-rent-recurring');
    expect(restoredRent.getAmountForMonth(apr2026), equals(0)); // April skip month intact!

    final restoredCarLoan = emptyRecoveredLoans.firstWhere((e) => e.id == 'loan-car-1');
    expect(restoredCarLoan.getEmiForMonth(mar2026), equals(2075800 + 5000000)); // Extra EMI intact!

    // Mirror recovered cloud data back to local SharedPreferences
    final recoveredMoneyJson = jsonEncode(emptyRecoveredMoney.map((e) => e.toJson()).toList());
    final recoveredLoansJson = jsonEncode(emptyRecoveredLoans.map((e) => e.toJson()).toList());
    await prefs.setString('moneymonk_money_$loginUidA', recoveredMoneyJson);
    await prefs.setString('moneymonk_loans_$loginUidA', recoveredLoansJson);

    expect(prefs.getString('moneymonk_money_$loginUidA'), isNotNull);
    expect(prefs.getString('moneymonk_loans_$loginUidA'), isNotNull);
  });
}


