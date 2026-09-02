import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color moneyMonkNavy = Color(0xFF1E3A5F);
const Color moneyMonkNavyLight = Color(0xFFEAF1F8);
const Color moneyMonkBackground = Color(0xFFF7F9FB);
const Color moneyMonkSurface = Color(0xFFFFFFFF);
const Color moneyMonkPrimaryText = Color(0xFF172033);
const Color moneyMonkSecondaryText = Color(0xFF647084);
const Color moneyMonkMuted = Color(0xFF8B95A5);
const Color moneyMonkBorder = Color(0xFFE1E6ED);
const Color moneyMonkIncome = Color(0xFF15803D);
const Color moneyMonkExpense = Color(0xFFC2410C);
const Color moneyMonkWarning = Color(0xFFB45309);
const Color moneyMonkError = Color(0xFFB91C1C);

void main() {
  runApp(const MoneyMonkApp());
}

enum MoneyEntryType { income, expense }
enum MoneyEntryMode { oneTime, recurring }
enum RecurrenceFrequency { monthly, everyTwoMonths, quarterly, halfYearly, yearly }

class MoneyMonkApp extends StatelessWidget {
  const MoneyMonkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: moneyMonkBackground,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: moneyMonkNavy,
        primary: moneyMonkNavy,
        secondary: moneyMonkNavy,
        surface: moneyMonkSurface,
        brightness: Brightness.light,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: moneyMonkPrimaryText,
        displayColor: moneyMonkPrimaryText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: moneyMonkSurface,
        foregroundColor: moneyMonkPrimaryText,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: moneyMonkSurface,
        indicatorColor: moneyMonkNavyLight,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dividerColor: moneyMonkBorder,
      cardTheme: CardThemeData(
        color: moneyMonkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: moneyMonkBorder),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: moneyMonkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: moneyMonkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: moneyMonkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: moneyMonkNavy),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );

    return MaterialApp(
      title: 'MoneyMonk',
      theme: theme,
      home: const MoneyMonkHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MoneyEntry {
  MoneyEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.amountInPaise,
    required this.mode,
    required this.date,
    this.frequency,
    this.overrides = const {},
  });

  final String id;
  final String name;
  final MoneyEntryType type;
  final int amountInPaise;
  final MoneyEntryMode mode;
  final DateTime date;
  final RecurrenceFrequency? frequency;
  final Map<DateTime, int> overrides;

  String get prettyAmount => _formatCurrency(amountInPaise);

  int getAmountForMonth(DateTime month) {
    final monthKey = DateTime(month.year, month.month);
    return overrides[monthKey] ?? amountInPaise;
  }

  bool appliesToMonth(DateTime month) {
    if (mode == MoneyEntryMode.oneTime) {
      return date.year == month.year && date.month == month.month;
    }
    // Recurring
    if (date.year > month.year || (date.year == month.year && date.month > month.month)) {
      return false;
    }
    
    final monthsSinceStart = (month.year - date.year) * 12 + (month.month - date.month);
    switch (frequency) {
      case RecurrenceFrequency.monthly:
        return true;
      case RecurrenceFrequency.everyTwoMonths:
        return monthsSinceStart % 2 == 0;
      case RecurrenceFrequency.quarterly:
        return monthsSinceStart % 3 == 0;
      case RecurrenceFrequency.halfYearly:
        return monthsSinceStart % 6 == 0;
      case RecurrenceFrequency.yearly:
        return monthsSinceStart % 12 == 0;
      case null:
        return false;
    }
  }

  static String _formatCurrency(int amountInPaise) {
    final rupee = amountInPaise / 100;
    final integerValue = amountInPaise % 100 == 0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: integerValue ? 0 : 2,
    );
    return formatter.format(rupee);
  }
}

class LoanEntry {
  LoanEntry({
    required this.id,
    required this.name,
    required this.originalAmountInPaise,
    required this.outstandingAmountInPaise,
    required this.interestRatePerAnnum,
    required this.emiInPaise,
    required this.startDate,
    required this.tenureMonths,
  });

  final String id;
  final String name;
  final int originalAmountInPaise;
  final int outstandingAmountInPaise;
  final double interestRatePerAnnum;
  final int emiInPaise;
  final DateTime startDate;
  final int tenureMonths;

  String get prettyOriginal => _formatCurrency(originalAmountInPaise);
  String get prettyOutstanding => _formatCurrency(outstandingAmountInPaise);
  String get prettyEmi => _formatCurrency(emiInPaise);

  static String _formatCurrency(int amountInPaise) {
    final rupee = amountInPaise / 100;
    final integerValue = amountInPaise % 100 == 0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: integerValue ? 0 : 2,
    );
    return formatter.format(rupee);
  }

  LoanAmortization calculateAmortization() {
    return LoanAmortization.calculate(
      principal: outstandingAmountInPaise,
      annualRate: interestRatePerAnnum,
      emiInPaise: emiInPaise,
      startDate: startDate,
    );
  }
}

class LoanAmortization {
  LoanAmortization({
    required this.schedule,
    required this.isValid,
    required this.invalidReason,
  });

  final List<LoanMonth> schedule;
  final bool isValid;
  final String invalidReason;

  factory LoanAmortization.calculate({
    required int principal,
    required double annualRate,
    required int emiInPaise,
    required DateTime startDate,
  }) {
    final monthlyRate = annualRate / 100 / 12;
    final schedule = <LoanMonth>[];
    var currentPrincipal = principal;
    var currentDate = DateTime(startDate.year, startDate.month);
    var isValid = true;
    var invalidReason = '';

    while (currentPrincipal > 0) {
      final interestInPaise = (currentPrincipal * monthlyRate).round();
      
      if (interestInPaise >= emiInPaise && currentPrincipal > 0) {
        isValid = false;
        invalidReason = 'EMI is insufficient to cover the current interest.';
        break;
      }

      final principalPaymentInPaise = emiInPaise - interestInPaise;
      var newPrincipal = currentPrincipal - principalPaymentInPaise;
      var actualEmiInPaise = emiInPaise;

      if (newPrincipal < 0) {
        newPrincipal = 0;
        actualEmiInPaise = currentPrincipal + interestInPaise;
      }

      schedule.add(LoanMonth(
        date: currentDate,
        principalPaymentInPaise: principalPaymentInPaise,
        interestPaymentInPaise: interestInPaise,
        emiInPaise: actualEmiInPaise,
        remainingPrincipalInPaise: newPrincipal,
      ));

      currentPrincipal = newPrincipal;
      currentDate = DateTime(currentDate.year + (currentDate.month == 12 ? 1 : 0), 
                            currentDate.month == 12 ? 1 : currentDate.month + 1);

      if (schedule.length > 600) {
        isValid = false;
        invalidReason = 'Loan calculation exceeded 50 years.';
        break;
      }
    }

    return LoanAmortization(
      schedule: schedule,
      isValid: isValid,
      invalidReason: invalidReason,
    );
  }

  int get totalInterestInPaise {
    return schedule.fold<int>(0, (sum, m) => sum + m.interestPaymentInPaise);
  }

  int get remainingMonths => schedule.length;

  DateTime? get completionDate => schedule.isNotEmpty ? schedule.last.date : null;

  List<LoanYear> getYearlyForecast() {
    final yearMap = <int, LoanYear>{};
    
    for (final month in schedule) {
      final year = month.date.year;
      yearMap.putIfAbsent(year, () => LoanYear(year: year));
      yearMap[year]!.addMonth(month);
    }
    
    return yearMap.values.toList()..sort((a, b) => a.year.compareTo(b.year));
  }
}

class LoanMonth {
  LoanMonth({
    required this.date,
    required this.principalPaymentInPaise,
    required this.interestPaymentInPaise,
    required this.emiInPaise,
    required this.remainingPrincipalInPaise,
  });

  final DateTime date;
  final int principalPaymentInPaise;
  final int interestPaymentInPaise;
  final int emiInPaise;
  final int remainingPrincipalInPaise;
}

class LoanYear {
  LoanYear({required this.year});

  final int year;
  int principalPaidInPaise = 0;
  int interestPaidInPaise = 0;
  int remainingPrincipalInPaise = 0;

  void addMonth(LoanMonth month) {
    principalPaidInPaise += month.principalPaymentInPaise;
    interestPaidInPaise += month.interestPaymentInPaise;
    remainingPrincipalInPaise = month.remainingPrincipalInPaise;
  }
}

class MoneyMonkHomePage extends StatefulWidget {
  const MoneyMonkHomePage({super.key});

  @override
  State<MoneyMonkHomePage> createState() => _MoneyMonkHomePageState();
}

class _MoneyMonkHomePageState extends State<MoneyMonkHomePage> {
  int _selectedIndex = 0;
  final List<MoneyEntry> _moneyEntries = <MoneyEntry>[];
  final List<LoanEntry> _loanEntries = <LoanEntry>[];
  DateTime _selectedMonth = DateTime(2026, 9);
  bool _isMonthlyView = true;

  void _handleAddMoney() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddMoneySheet(
        onSave: (MoneyEntry entry) {
          setState(() {
            _moneyEntries.add(entry);
          });
        },
      ),
    );
  }

  void _handleEditMoney(MoneyEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => EditMoneySheet(
        entry: entry,
        onSave: (MoneyEntry updated) {
          setState(() {
            final index = _moneyEntries.indexWhere((e) => e.id == entry.id);
            if (index >= 0) {
              _moneyEntries[index] = updated;
            }
          });
        },
      ),
    );
  }

  void _handleDeleteMoney(MoneyEntry entry) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Delete ${entry.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: moneyMonkError)),
          ),
        ],
      ),
    ).then((delete) {
      if (delete == true) {
        setState(() {
          _moneyEntries.removeWhere((e) => e.id == entry.id);
        });
      }
    });
  }

  void _handleAddLoan() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddLoanSheet(
        onSave: (LoanEntry entry) {
          setState(() {
            _loanEntries.add(entry);
          });
        },
      ),
    );
  }

  void _handleDeleteLoan(LoanEntry entry) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: Text('Delete ${entry.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: moneyMonkError)),
          ),
        ],
      ),
    ).then((delete) {
      if (delete == true) {
        setState(() {
          _loanEntries.removeWhere((e) => e.id == entry.id);
        });
      }
    });
  }

  int _getMoneyTotal(MoneyEntryType type, {DateTime? forMonth}) {
    final month = forMonth ?? _selectedMonth;
    var total = 0;
    
    for (final entry in _moneyEntries) {
      if (entry.type == type && entry.appliesToMonth(month)) {
        total += entry.getAmountForMonth(month);
      }
    }
    
    return total;
  }

  int _getMoneyTotalForYear(MoneyEntryType type) {
    var total = 0;
    for (var month = 1; month <= 12; month++) {
      final monthDate = DateTime(_selectedMonth.year, month);
      total += _getMoneyTotal(type, forMonth: monthDate);
    }
    return total;
  }

  List<MapEntry<DateTime, int>> _generateForecast() {
    final forecast = <MapEntry<DateTime, int>>[];
    final now = DateTime.now();
    
    for (var i = 0; i < 12; i++) {
      final forecastMonth = DateTime(now.year, now.month + i);
      final income = _getMoneyTotal(MoneyEntryType.income, forMonth: forecastMonth);
      final expense = _getMoneyTotal(MoneyEntryType.expense, forMonth: forecastMonth);
      final balance = income - expense;
      
      forecast.add(MapEntry(forecastMonth, balance));
    }
    
    return forecast;
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      MoneyScreen(
        entries: _moneyEntries,
        selectedMonth: _selectedMonth,
        isMonthlyView: _isMonthlyView,
        onMonthChanged: (month) => setState(() => _selectedMonth = month),
        onViewChanged: (isMonthly) => setState(() => _isMonthlyView = isMonthly),
        onAddPressed: _handleAddMoney,
        onEditPressed: _handleEditMoney,
        onDeletePressed: _handleDeleteMoney,
        getMoneyTotal: _getMoneyTotal,
        getMoneyTotalForYear: _getMoneyTotalForYear,
        generateForecast: _generateForecast,
      ),
      LoansScreen(
        entries: _loanEntries,
        onAddPressed: _handleAddLoan,
        onDeletePressed: _handleDeleteLoan,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MoneyMonk',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: moneyMonkNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() {
            _selectedIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Money',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            label: 'Loans',
          ),
        ],
      ),
    );
  }
}

class MoneyScreen extends StatelessWidget {
  const MoneyScreen({
    super.key,
    required this.entries,
    required this.selectedMonth,
    required this.isMonthlyView,
    required this.onMonthChanged,
    required this.onViewChanged,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.getMoneyTotal,
    required this.getMoneyTotalForYear,
    required this.generateForecast,
  });

  final List<MoneyEntry> entries;
  final DateTime selectedMonth;
  final bool isMonthlyView;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<bool> onViewChanged;
  final VoidCallback onAddPressed;
  final ValueChanged<MoneyEntry> onEditPressed;
  final ValueChanged<MoneyEntry> onDeletePressed;
  final int Function(MoneyEntryType, {DateTime? forMonth}) getMoneyTotal;
  final int Function(MoneyEntryType) getMoneyTotalForYear;
  final List<MapEntry<DateTime, int>> Function() generateForecast;

  @override
  Widget build(BuildContext context) {
    final incomeEntries = entries
        .where((e) => e.type == MoneyEntryType.income && e.appliesToMonth(selectedMonth))
        .toList();
    final expenseEntries = entries
        .where((e) => e.type == MoneyEntryType.expense && e.appliesToMonth(selectedMonth))
        .toList();

    final totalIncome = isMonthlyView
        ? getMoneyTotal(MoneyEntryType.income)
        : getMoneyTotalForYear(MoneyEntryType.income);
    final totalExpense = isMonthlyView
        ? getMoneyTotal(MoneyEntryType.expense)
        : getMoneyTotalForYear(MoneyEntryType.expense);
    final balance = totalIncome - totalExpense;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Money',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: moneyMonkPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Month selector and view toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => onMonthChanged(DateTime(
                              selectedMonth.year,
                              selectedMonth.month - 1,
                            )),
                            icon: const Icon(Icons.chevron_left),
                            iconSize: 24,
                          ),
                          Text(
                            isMonthlyView
                                ? DateFormat('MMMM yyyy').format(selectedMonth)
                                : DateFormat('yyyy').format(selectedMonth),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: moneyMonkPrimaryText,
                            ),
                          ),
                          IconButton(
                            onPressed: () => onMonthChanged(DateTime(
                              selectedMonth.year,
                              selectedMonth.month + 1,
                            )),
                            icon: const Icon(Icons.chevron_right),
                            iconSize: 24,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('Monthly'),
                            selected: isMonthlyView,
                            onSelected: (_) => onViewChanged(true),
                            selectedColor: moneyMonkNavyLight,
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Yearly'),
                            selected: !isMonthlyView,
                            onSelected: (_) => onViewChanged(false),
                            selectedColor: moneyMonkNavyLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Money table
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _MoneyColumn(
                                  label: 'Income',
                                  entries: incomeEntries,
                                  accent: moneyMonkIncome,
                                  tint: const Color(0xFFF2FBF4),
                                  onEdit: onEditPressed,
                                  onDelete: onDeletePressed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MoneyColumn(
                                  label: 'Expense',
                                  entries: expenseEntries,
                                  accent: moneyMonkExpense,
                                  tint: const Color(0xFFFEF0EA),
                                  onEdit: onEditPressed,
                                  onDelete: onDeletePressed,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Income',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: moneyMonkSecondaryText,
                                ),
                              ),
                              Text(
                                _formatCurrency(totalIncome),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: moneyMonkIncome,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Expense',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: moneyMonkSecondaryText,
                                ),
                              ),
                              Text(
                                _formatCurrency(totalExpense),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: moneyMonkExpense,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: moneyMonkSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(balance),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: moneyMonkPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    label: 'Add money',
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('money-add-button'),
                        onPressed: onAddPressed,
                        icon: const Icon(Icons.add),
                        label: const Text('+ Add'),
                        style: FilledButton.styleFrom(
                          backgroundColor: moneyMonkNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isMonthlyView) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'Forecast',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: moneyMonkSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('Month')),
                              DataColumn(label: Text('Balance')),
                            ],
                            rows: generateForecast()
                                .map((entry) => DataRow(
                              cells: [
                                DataCell(Text(DateFormat('MMM yyyy').format(entry.key))),
                                DataCell(Text(
                                  _formatCurrency(entry.value),
                                  style: TextStyle(
                                    color: entry.value >= 0 ? moneyMonkIncome : moneyMonkExpense,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )),
                              ],
                            ))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatCurrency(int paise) {
    final rupee = paise / 100;
    final wholeNumber = paise % 100 == 0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: wholeNumber ? 0 : 2,
    ).format(rupee);
  }
}

class _MoneyColumn extends StatelessWidget {
  const _MoneyColumn({
    required this.label,
    required this.entries,
    required this.accent,
    required this.tint,
    required this.onEdit,
    required this.onDelete,
  });

  final String label;
  final List<MoneyEntry> entries;
  final Color accent;
  final Color tint;
  final ValueChanged<MoneyEntry> onEdit;
  final ValueChanged<MoneyEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: moneyMonkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                '₹0',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: moneyMonkPrimaryText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.prettyAmount,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text('Edit'),
                          onTap: () => onEdit(entry),
                        ),
                        PopupMenuItem(
                          child: const Text('Delete'),
                          onTap: () => onDelete(entry),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LoansScreen extends StatelessWidget {
  const LoansScreen({
    super.key,
    required this.entries,
    required this.onAddPressed,
    required this.onDeletePressed,
  });

  final List<LoanEntry> entries;
  final VoidCallback onAddPressed;
  final ValueChanged<LoanEntry> onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Loans',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: moneyMonkPrimaryText,
                  ),
                ),
                const SizedBox(height: 20),
                if (entries.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No loans added yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: moneyMonkSecondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  ...entries.map((loan) => _LoanCard(
                    loan: loan,
                    onDelete: () => onDeletePressed(loan),
                  )),
                  const SizedBox(height: 16),
                ],
                Semantics(
                  label: 'Add loan',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAddPressed,
                      icon: const Icon(Icons.add),
                      label: const Text('+ Add Loan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: moneyMonkNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.onDelete,
  });

  final LoanEntry loan;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amortization = loan.calculateAmortization();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loan.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: moneyMonkPrimaryText,
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: onDelete,
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!amortization.isValid)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF0EA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: moneyMonkWarning),
                ),
                child: Text(
                  amortization.invalidReason,
                  style: const TextStyle(
                    fontSize: 13,
                    color: moneyMonkWarning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _LoanInfoBox('Outstanding', loan.prettyOutstanding),
                  _LoanInfoBox('Original', loan.prettyOriginal),
                  _LoanInfoBox('EMI/month', loan.prettyEmi),
                  _LoanInfoBox('Interest Rate', '${loan.interestRatePerAnnum.toStringAsFixed(2)}%'),
                  _LoanInfoBox(
                    'Remaining',
                    '${amortization.remainingMonths} months',
                  ),
                  _LoanInfoBox(
                    'Total Interest',
                    _formatCurrency(amortization.totalInterestInPaise),
                  ),
                ],
              ),
              if (amortization.completionDate != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Expected completion: ${DateFormat('MMM yyyy').format(amortization.completionDate!)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: moneyMonkSecondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Yearly Forecast'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 12,
                        columns: const [
                          DataColumn(label: Text('Year')),
                          DataColumn(label: Text('Principal')),
                          DataColumn(label: Text('Interest')),
                          DataColumn(label: Text('Balance')),
                        ],
                        rows: amortization.getYearlyForecast().map((year) => DataRow(
                          cells: [
                            DataCell(Text('${year.year}')),
                            DataCell(Text(_formatCurrency(year.principalPaidInPaise))),
                            DataCell(Text(_formatCurrency(year.interestPaidInPaise))),
                            DataCell(Text(_formatCurrency(year.remainingPrincipalInPaise))),
                          ],
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatCurrency(int paise) {
    final rupee = paise / 100;
    final wholeNumber = paise % 100 == 0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: wholeNumber ? 0 : 2,
    ).format(rupee);
  }
}

class _LoanInfoBox extends StatelessWidget {
  const _LoanInfoBox(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: moneyMonkNavyLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: moneyMonkSecondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: moneyMonkNavy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class AddMoneySheet extends StatefulWidget {
  const AddMoneySheet({super.key, required this.onSave});

  final void Function(MoneyEntry entry) onSave;

  @override
  State<AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<AddMoneySheet> {
  MoneyEntryType _type = MoneyEntryType.income;
  MoneyEntryMode _mode = MoneyEntryMode.oneTime;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedRecurringStartDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, {required bool recurring}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: recurring ? _selectedRecurringStartDate : _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (recurring) {
        _selectedRecurringStartDate = picked;
      } else {
        _selectedDate = picked;
      }
    });
  }

  String? _validateName() {
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      return 'Please enter a name.';
    }
    return null;
  }

  String? _validateAmount() {
    final value = _amountController.text.trim();
    if (value.isEmpty) {
      return 'Please enter a valid amount.';
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return 'Please enter a valid amount.';
    }
    return null;
  }

  void _save() {
    final nameError = _validateName();
    final amountError = _validateAmount();
    if (nameError != null || amountError != null) {
      final message = nameError ?? amountError ?? 'Please enter valid details.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final amountInPaise = (amount * 100).round();

    final entry = MoneyEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      type: _type,
      amountInPaise: amountInPaise,
      mode: _mode,
      date: _mode == MoneyEntryMode.oneTime ? _selectedDate : _selectedRecurringStartDate,
      frequency: _mode == MoneyEntryMode.recurring ? _frequency : null,
    );

    widget.onSave(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Add Money',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: moneyMonkSecondaryText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      key: const ValueKey('income-option'),
                      label: const Text('Income'),
                      selected: _type == MoneyEntryType.income,
                      onSelected: (_) => setState(() => _type = MoneyEntryType.income),
                      selectedColor: moneyMonkNavyLight,
                      labelStyle: TextStyle(
                        color: _type == MoneyEntryType.income ? moneyMonkNavy : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Expense'),
                      selected: _type == MoneyEntryType.expense,
                      onSelected: (_) => setState(() => _type = MoneyEntryType.expense),
                      selectedColor: const Color(0xFFFEF0EA),
                      labelStyle: TextStyle(
                        color: _type == MoneyEntryType.expense ? moneyMonkExpense : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const ValueKey('name-field'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Salary',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('amount-field'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '₹0.00',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'When',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: moneyMonkSecondaryText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('One time'),
                      selected: _mode == MoneyEntryMode.oneTime,
                      onSelected: (_) => setState(() => _mode = MoneyEntryMode.oneTime),
                      selectedColor: moneyMonkNavyLight,
                      labelStyle: TextStyle(
                        color: _mode == MoneyEntryMode.oneTime ? moneyMonkNavy : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Recurring'),
                      selected: _mode == MoneyEntryMode.recurring,
                      onSelected: (_) => setState(() => _mode = MoneyEntryMode.recurring),
                      selectedColor: moneyMonkNavyLight,
                      labelStyle: TextStyle(
                        color: _mode == MoneyEntryMode.recurring ? moneyMonkNavy : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_mode == MoneyEntryMode.oneTime)
                InkWell(
                  onTap: () => _pickDate(context, recurring: false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    )
                  ),
                )
              else ...[
                const Text(
                  'Frequency',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: moneyMonkSecondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RecurrenceFrequency>(
                  initialValue: _frequency,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _frequency = value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Monthly')),
                    DropdownMenuItem(value: RecurrenceFrequency.everyTwoMonths, child: Text('Every 2 months')),
                    DropdownMenuItem(value: RecurrenceFrequency.quarterly, child: Text('Quarterly')),
                    DropdownMenuItem(value: RecurrenceFrequency.halfYearly, child: Text('Half-yearly')),
                    DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text('Yearly')),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _pickDate(context, recurring: true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start date',
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(_selectedRecurringStartDate)),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    )
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: moneyMonkNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditMoneySheet extends StatefulWidget {
  const EditMoneySheet({super.key, required this.entry, required this.onSave});

  final MoneyEntry entry;
  final void Function(MoneyEntry entry) onSave;

  @override
  State<EditMoneySheet> createState() => _EditMoneySheetState();
}

class _EditMoneySheetState extends State<EditMoneySheet> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late MoneyEntryType _type;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _amountController = TextEditingController(text: (widget.entry.amountInPaise / 100).toString());
    _type = widget.entry.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _validateName() {
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      return 'Please enter a name.';
    }
    return null;
  }

  String? _validateAmount() {
    final value = _amountController.text.trim();
    if (value.isEmpty) {
      return 'Please enter a valid amount.';
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return 'Please enter a valid amount.';
    }
    return null;
  }

  void _save() {
    final nameError = _validateName();
    final amountError = _validateAmount();
    if (nameError != null || amountError != null) {
      final message = nameError ?? amountError ?? 'Please enter valid details.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final amountInPaise = (amount * 100).round();

    final updated = MoneyEntry(
      id: widget.entry.id,
      name: _nameController.text.trim(),
      type: _type,
      amountInPaise: amountInPaise,
      mode: widget.entry.mode,
      date: widget.entry.date,
      frequency: widget.entry.frequency,
      overrides: widget.entry.overrides,
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Edit Entry',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: moneyMonkSecondaryText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Income'),
                      selected: _type == MoneyEntryType.income,
                      onSelected: (_) => setState(() => _type = MoneyEntryType.income),
                      selectedColor: moneyMonkNavyLight,
                      labelStyle: TextStyle(
                        color: _type == MoneyEntryType.income ? moneyMonkNavy : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Expense'),
                      selected: _type == MoneyEntryType.expense,
                      onSelected: (_) => setState(() => _type = MoneyEntryType.expense),
                      selectedColor: const Color(0xFFFEF0EA),
                      labelStyle: TextStyle(
                        color: _type == MoneyEntryType.expense ? moneyMonkExpense : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Salary',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '₹0.00',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: moneyMonkNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddLoanSheet extends StatefulWidget {
  const AddLoanSheet({super.key, required this.onSave});

  final void Function(LoanEntry entry) onSave;

  @override
  State<AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<AddLoanSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _originalAmountController = TextEditingController();
  final TextEditingController _outstandingAmountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _emiController = TextEditingController();
  final TextEditingController _tenureYearsController = TextEditingController(text: '1');
  final TextEditingController _tenureMonthsController = TextEditingController(text: '0');
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    _originalAmountController.dispose();
    _outstandingAmountController.dispose();
    _interestRateController.dispose();
    _emiController.dispose();
    _tenureYearsController.dispose();
    _tenureMonthsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String? _validate() {
    if (_nameController.text.trim().isEmpty) {
      return 'Please enter a loan name.';
    }
    if (double.tryParse(_originalAmountController.text.trim()) == null ||
        double.parse(_originalAmountController.text.trim()) <= 0) {
      return 'Please enter a valid original amount.';
    }
    if (double.tryParse(_outstandingAmountController.text.trim()) == null ||
        double.parse(_outstandingAmountController.text.trim()) <= 0) {
      return 'Please enter a valid outstanding amount.';
    }
    if (double.tryParse(_interestRateController.text.trim()) == null ||
        double.parse(_interestRateController.text.trim()) < 0) {
      return 'Please enter a valid interest rate.';
    }
    if (double.tryParse(_emiController.text.trim()) == null ||
        double.parse(_emiController.text.trim()) <= 0) {
      return 'Please enter a valid EMI.';
    }
    final years = int.tryParse(_tenureYearsController.text.trim()) ?? 0;
    final months = int.tryParse(_tenureMonthsController.text.trim()) ?? 0;
    if (years == 0 && months == 0) {
      return 'Please enter a valid tenure.';
    }
    return null;
  }

  void _save() {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final originalAmount = double.parse(_originalAmountController.text.trim());
    final outstandingAmount = double.parse(_outstandingAmountController.text.trim());
    final interestRate = double.parse(_interestRateController.text.trim());
    final emi = double.parse(_emiController.text.trim());
    final years = int.tryParse(_tenureYearsController.text.trim()) ?? 0;
    final months = int.tryParse(_tenureMonthsController.text.trim()) ?? 0;
    final tenureMonths = years * 12 + months;

    final entry = LoanEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      originalAmountInPaise: (originalAmount * 100).round(),
      outstandingAmountInPaise: (outstandingAmount * 100).round(),
      interestRatePerAnnum: interestRate,
      emiInPaise: (emi * 100).round(),
      startDate: _selectedDate,
      tenureMonths: tenureMonths,
    );

    widget.onSave(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Add Loan',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Loan name',
                  hintText: 'Home Loan',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _originalAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Original loan amount',
                  hintText: '₹50,00,000',
                  prefixText: '₹ ',
                  helperText: 'Amount originally borrowed',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _outstandingAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Current outstanding amount',
                  hintText: '₹40,00,000',
                  prefixText: '₹ ',
                  helperText: 'Principal still owed today',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interestRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Interest rate / ROI',
                  hintText: '6.5',
                  suffixText: '%',
                  helperText: 'Annual interest rate',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emiController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'EMI',
                  hintText: '50000',
                  prefixText: '₹ ',
                  helperText: 'Amount paid each month',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tenureYearsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Years',
                        hintText: '20',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tenureMonthsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Months',
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Loan tenure / duration',
                style: TextStyle(
                  fontSize: 12,
                  color: moneyMonkSecondaryText,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _pickDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Loan start date',
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                      const Icon(Icons.calendar_today_outlined, size: 18),
                    ],
                  )
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: moneyMonkNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Loan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
