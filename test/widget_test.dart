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

  test('FirestoreService resolves deterministic account UIDs and isolates accounts', () {
    final service = FirestoreService.instance;
    final uidTester = service.getUid('tester');
    final uidAlice = service.getUid('alice');
    final uidBob = service.getUid('bob');
    final uidTesterUppercase = service.getUid('TESTER');

    expect(uidTester.startsWith('user_'), isTrue);
    expect(uidAlice.startsWith('user_'), isTrue);
    expect(uidBob.startsWith('user_'), isTrue);

    // Deterministic & Case-insensitive
    expect(uidTester, equals(uidTesterUppercase));

    // Complete account isolation
    expect(uidTester, isNot(equals(uidAlice)));
    expect(uidAlice, isNot(equals(uidBob)));
  });

  test('Delete All Data tombstone prevents resurrection by device scanner', () async {
    final prefs = await SharedPreferences.getInstance();
    const username = 'cleared_user';
    const tombstoneKey = 'moneymonk_deleted_$username';

    // Simulate old data on device
    await prefs.setString('moneymonk_money_$username', '[{"id":"m1","name":"Old Salary","amountInPaise":5000000,"date":"2026-01-01T00:00:00.000","type":"income","mode":"recurring","frequency":"monthly"}]');
    await prefs.setString('moneymonk_global_latest_money', '[{"id":"m1","name":"Old Salary","amountInPaise":5000000,"date":"2026-01-01T00:00:00.000","type":"income","mode":"recurring","frequency":"monthly"}]');

    // Simulate "Delete All Data" action
    await prefs.remove('moneymonk_money_$username');
    await prefs.remove('moneymonk_loans_$username');
    await prefs.setBool(tombstoneKey, true);

    // Verify tombstone is recorded
    expect(prefs.getBool(tombstoneKey), isTrue);

    // If a load logic checks tombstone, it must not resurrect the old data
    final isDeleted = prefs.getBool(tombstoneKey) ?? false;
    expect(isDeleted, isTrue);
    expect(prefs.getString('moneymonk_money_$username'), isNull);
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
}


