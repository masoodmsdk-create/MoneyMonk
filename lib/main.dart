import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'amount': amountInPaise,
        'mode': mode.name,
        'date': date.toIso8601String(),
        'frequency': frequency?.name,
        'overrides': overrides.map((key, value) => MapEntry(key.toIso8601String(), value)),
      };

  factory MoneyEntry.fromJson(Map<String, dynamic> json) {
    final rawOverrides = (json['overrides'] as Map?)?.cast<String, dynamic>() ?? {};
    return MoneyEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      type: MoneyEntryType.values.byName(json['type'] as String),
      amountInPaise: json['amount'] as int,
      mode: MoneyEntryMode.values.byName(json['mode'] as String),
      date: DateTime.parse(json['date'] as String),
      frequency: json['frequency'] == null ? null : RecurrenceFrequency.values.byName(json['frequency'] as String),
      overrides: rawOverrides.map((key, value) => MapEntry(DateTime.parse(key), value as int)),
    );
  }

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
    this.extraEmiInPaise = 0,
    required this.startDate,
    required this.tenureMonths,
  });

  final String id;
  final String name;
  final int originalAmountInPaise;
  final int outstandingAmountInPaise;
  final double interestRatePerAnnum;
  final int emiInPaise;
  final int extraEmiInPaise;
  final DateTime startDate;
  final int tenureMonths;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'original': originalAmountInPaise,
        'outstanding': outstandingAmountInPaise,
        'rate': interestRatePerAnnum,
        'emi': emiInPaise,
        'extraEmi': extraEmiInPaise,
        'startDate': startDate.toIso8601String(),
        'tenure': tenureMonths,
      };

  factory LoanEntry.fromJson(Map<String, dynamic> json) => LoanEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        originalAmountInPaise: json['original'] as int,
        outstandingAmountInPaise: json['outstanding'] as int,
        interestRatePerAnnum: (json['rate'] as num).toDouble(),
        emiInPaise: json['emi'] as int,
        extraEmiInPaise: (json['extraEmi'] as int?) ?? 0,
        startDate: DateTime.parse(json['startDate'] as String),
        tenureMonths: json['tenure'] as int,
      );

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
      extraEmiInPaise: extraEmiInPaise,
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
    required int extraEmiInPaise,
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
      
      final scheduledPaymentInPaise = emiInPaise + extraEmiInPaise;
      if (interestInPaise >= scheduledPaymentInPaise && currentPrincipal > 0) {
        isValid = false;
        invalidReason = 'EMI is insufficient to cover the current interest.';
        break;
      }

      final principalPaymentInPaise = scheduledPaymentInPaise - interestInPaise;
      var newPrincipal = currentPrincipal - principalPaymentInPaise;
      var actualEmiInPaise = scheduledPaymentInPaise;

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

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final preferences = await SharedPreferences.getInstance();
    final money = preferences.getString('moneymonk_money');
    final loans = preferences.getString('moneymonk_loans');
    if (!mounted) return;
    setState(() {
      if (money != null) {
        _moneyEntries.addAll((jsonDecode(money) as List).map((item) => MoneyEntry.fromJson(item as Map<String, dynamic>)));
      }
      if (loans != null) {
        _loanEntries.addAll((jsonDecode(loans) as List).map((item) => LoanEntry.fromJson(item as Map<String, dynamic>)));
      }
    });
  }

  Future<void> _saveData() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('moneymonk_money', jsonEncode(_moneyEntries.map((entry) => entry.toJson()).toList()));
    await preferences.setString('moneymonk_loans', jsonEncode(_loanEntries.map((entry) => entry.toJson()).toList()));
  }

  void _handleAddMoney() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddMoneySheet(
        onSave: (List<MoneyEntry> entries) {
          setState(() {
            _moneyEntries.addAll(entries);
          });
          _saveData();
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
        selectedMonth: _selectedMonth,
        onSave: (MoneyEntry updated) {
          setState(() {
            final index = _moneyEntries.indexWhere((e) => e.id == entry.id);
            if (index >= 0) {
              _moneyEntries[index] = updated;
            }
          });
          _saveData();
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
        _saveData();
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
          _saveData();
        },
      ),
    );
  }

  void _handleEditLoan(LoanEntry loan) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddLoanSheet(
        existingLoan: loan,
        onSave: (updated) {
          setState(() {
            final index = _loanEntries.indexWhere((entry) => entry.id == loan.id);
            if (index >= 0) _loanEntries[index] = updated;
          });
          _saveData();
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
        _saveData();
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
        onEditPressed: _handleEditLoan,
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 8,
                      spacing: 12,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accent)),
            Text(_formatCurrency(entries.fold(0, (sum, entry) => sum + entry.amountInPaise)), style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
          ],
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Text('No ${label.toLowerCase()} entries', style: const TextStyle(fontSize: 13, color: moneyMonkMuted))
        else
          ...entries.map((entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.name, overflow: TextOverflow.ellipsis)),
                    Text(entry.prettyAmount, style: TextStyle(fontWeight: FontWeight.w600, color: accent)),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(onTap: () => onEdit(entry), child: const Text('Edit')),
                        PopupMenuItem(onTap: () => onDelete(entry), child: const Text('Delete')),
                      ],
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  static String _formatCurrency(int paise) {
    final rupee = paise / 100;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: paise % 100 == 0 ? 0 : 2).format(rupee);
  }
}

class LoansScreen extends StatelessWidget {
  const LoansScreen({
    super.key,
    required this.entries,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  final List<LoanEntry> entries;
  final VoidCallback onAddPressed;
  final ValueChanged<LoanEntry> onEditPressed;
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
                if (entries.isNotEmpty) ...[
                  _LoanAdvisor(entries: entries),
                  const SizedBox(height: 20),
                ],
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
                    onEdit: () => onEditPressed(loan),
                    onDelete: () => onDeletePressed(loan),
                  )),
                  const SizedBox(height: 16),
                  if (entries.length > 1) ...[
                    _LoanComparison(entries: entries),
                    const SizedBox(height: 16),
                  ],
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

class _LoanAdvisor extends StatefulWidget {
  const _LoanAdvisor({required this.entries});

  final List<LoanEntry> entries;

  @override
  State<_LoanAdvisor> createState() => _LoanAdvisorState();
}

class _LoanAdvisorState extends State<_LoanAdvisor> {
  final _questionController = TextEditingController();
  String _answer = 'Ask which loan to review first, total interest, or expected completion.';

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _answerQuestion() {
    final question = _questionController.text.toLowerCase();
    final valid = widget.entries
        .map((loan) => (loan: loan, forecast: loan.calculateAmortization()))
        .where((item) => item.forecast.isValid)
        .toList();
    if (valid.isEmpty) {
      setState(() => _answer = 'Please correct the loan values before asking for an outcome.');
      return;
    }
    final loan = valid.reduce((a, b) => a.loan.interestRatePerAnnum >= b.loan.interestRatePerAnnum ? a : b);
    final interest = valid.reduce((a, b) => a.forecast.totalInterestInPaise >= b.forecast.totalInterestInPaise ? a : b);
    if (question.contains('interest')) {
      _answer = '${interest.loan.name} has the highest remaining interest: ${_formatCurrency(interest.forecast.totalInterestInPaise)}.';
    } else if (question.contains('finish') || question.contains('when') || question.contains('completion')) {
      final completion = loan.forecast.completionDate;
      _answer = '${loan.loan.name} is expected to finish in ${completion == null ? 'an unavailable date' : DateFormat('MMM yyyy').format(completion)}.';
    } else {
      _answer = 'Review ${loan.loan.name} first because it has the highest ROI (${loan.loan.interestRatePerAnnum.toStringAsFixed(2)}%). Check prepayment charges before paying extra.';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ask MoneyMonk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _questionController, decoration: const InputDecoration(hintText: 'Which loan should I review first?'))),
            const SizedBox(width: 8),
            IconButton(onPressed: _answerQuestion, icon: const Icon(Icons.send), tooltip: 'Ask'),
          ]),
          const SizedBox(height: 10),
          Text(_answer, style: const TextStyle(color: moneyMonkSecondaryText)),
        ]),
      ),
    );
  }

  String _formatCurrency(int paise) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(paise / 100);
}

class _LoanComparison extends StatelessWidget {
  const _LoanComparison({required this.entries});

  final List<LoanEntry> entries;

  @override
  Widget build(BuildContext context) {
    final validLoans = entries
        .map((loan) => (loan: loan, amortization: loan.calculateAmortization()))
        .where((item) => item.amortization.isValid)
        .toList();

    if (validLoans.isEmpty) {
      return const SizedBox.shrink();
    }

    final highestRate = validLoans.reduce(
      (a, b) => a.loan.interestRatePerAnnum >= b.loan.interestRatePerAnnum ? a : b,
    );
    final highestInterest = validLoans.reduce(
      (a, b) => a.amortization.totalInterestInPaise >= b.amortization.totalInterestInPaise ? a : b,
    );
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Loan comparison',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText),
        ),
        const SizedBox(height: 10),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              columns: const [
                DataColumn(label: Text('Loan')),
                DataColumn(label: Text('Outstanding')),
                DataColumn(label: Text('EMI')),
                DataColumn(label: Text('ROI')),
                DataColumn(label: Text('Months left')),
                DataColumn(label: Text('Interest left')),
              ],
              rows: validLoans.map((item) => DataRow(cells: [
                DataCell(Text(item.loan.name)),
                DataCell(Text(currency.format(item.loan.outstandingAmountInPaise / 100))),
                DataCell(Text(currency.format(item.loan.emiInPaise / 100))),
                DataCell(Text('${item.loan.interestRatePerAnnum.toStringAsFixed(2)}%')),
                DataCell(Text('${item.amortization.remainingMonths}')),
                DataCell(Text(currency.format(item.amortization.totalInterestInPaise / 100))),
              ])).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Next step: ${highestRate.loan.name} has the highest interest rate '
              '(${highestRate.loan.interestRatePerAnnum.toStringAsFixed(2)}%). '
              'It may be the first loan to review. ${highestInterest.loan.name} '
              'has the highest remaining interest cost '
              '(${currency.format(highestInterest.amortization.totalInterestInPaise / 100)}). '
              'Check prepayment charges or restrictions before paying extra.',
              style: const TextStyle(fontSize: 14, height: 1.4, color: moneyMonkPrimaryText),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.onEdit,
    required this.onDelete,
  });

  final LoanEntry loan;
  final VoidCallback onEdit;
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
                      onTap: onEdit,
                      child: const Text('Edit'),
                    ),
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
                  _LoanInfoBox('Extra EMI', _formatCurrency(loan.extraEmiInPaise)),
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

  final void Function(List<MoneyEntry> entries) onSave;

  @override
  State<AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<AddMoneySheet> {
  final List<TextEditingController> _nameControllers = [TextEditingController()];
  final List<TextEditingController> _amountControllers = [TextEditingController()];
  final List<MoneyEntryType> _types = [MoneyEntryType.income];
  final List<MoneyEntryMode> _modes = [MoneyEntryMode.oneTime];
  final List<RecurrenceFrequency> _frequencies = [RecurrenceFrequency.monthly];
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedRecurringStartDate = DateTime.now();

  @override
  void dispose() {
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    for (final controller in _amountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _nameControllers.add(TextEditingController());
      _amountControllers.add(TextEditingController());
      _types.add(MoneyEntryType.income);
      _modes.add(MoneyEntryMode.oneTime);
      _frequencies.add(RecurrenceFrequency.monthly);
    });
  }

  void _removeRow(int index) {
    if (_nameControllers.length == 1) {
      return;
    }
    setState(() {
      _nameControllers.removeAt(index).dispose();
      _amountControllers.removeAt(index).dispose();
      _types.removeAt(index);
      _modes.removeAt(index);
      _frequencies.removeAt(index);
    });
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

  void _save() {
    final entries = <MoneyEntry>[];
    for (var index = 0; index < _nameControllers.length; index++) {
      final name = _nameControllers[index].text.trim();
      final amount = double.tryParse(_amountControllers[index].text.trim());
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a name for row ${index + 1}.')),
        );
        return;
      }
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid amount for row ${index + 1}.')),
        );
        return;
      }
      entries.add(MoneyEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}-$index',
        name: name,
        type: _types[index],
        amountInPaise: (amount * 100).round(),
        mode: _modes[index],
        date: _modes[index] == MoneyEntryMode.oneTime ? _selectedDate : _selectedRecurringStartDate,
        frequency: _modes[index] == MoneyEntryMode.recurring ? _frequencies[index] : null,
      ));
    }

    widget.onSave(entries);
    Navigator.of(context).pop();
  }

  Widget _buildEntryRow(int index) {
    final isRecurring = _modes[index] == MoneyEntryMode.recurring;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<MoneyEntryType>(
                initialValue: _types[index],
                decoration: const InputDecoration(labelText: 'Type'),
                onChanged: (value) { if (value != null) setState(() => _types[index] = value); },
                items: const [
                  DropdownMenuItem(value: MoneyEntryType.income, child: Text('Income')),
                  DropdownMenuItem(value: MoneyEntryType.expense, child: Text('Expense')),
                ],
              )),
              if (_nameControllers.length > 1) IconButton(
                onPressed: () => _removeRow(index),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove row',
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(flex: 3, child: TextFormField(
                key: index == 0 ? const ValueKey('name-field') : null,
                controller: _nameControllers[index],
                decoration: const InputDecoration(labelText: 'Item / description'),
              )),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: TextFormField(
                key: index == 0 ? const ValueKey('amount-field') : null,
                controller: _amountControllers[index],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: DropdownButtonFormField<MoneyEntryMode>(
                initialValue: _modes[index],
                decoration: const InputDecoration(labelText: 'Schedule'),
                onChanged: (value) { if (value != null) setState(() => _modes[index] = value); },
                items: const [
                  DropdownMenuItem(value: MoneyEntryMode.oneTime, child: Text('One time')),
                  DropdownMenuItem(value: MoneyEntryMode.recurring, child: Text('Recurring')),
                ],
              )),
              if (isRecurring) ...[
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<RecurrenceFrequency>(
                  initialValue: _frequencies[index],
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  onChanged: (value) { if (value != null) setState(() => _frequencies[index] = value); },
                  items: const [
                    DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Monthly')),
                    DropdownMenuItem(value: RecurrenceFrequency.everyTwoMonths, child: Text('Every 2 months')),
                    DropdownMenuItem(value: RecurrenceFrequency.quarterly, child: Text('Quarterly')),
                    DropdownMenuItem(value: RecurrenceFrequency.halfYearly, child: Text('Half-yearly')),
                    DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text('Yearly')),
                  ],
                )),
              ],
            ]),
          ],
        ),
      ),
    );
  }
    /*
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<MoneyEntryType>(
                    initialValue: _types[index],
                    decoration: const InputDecoration(labelText: 'Type'),
                    onChanged: (value) {
                      if (value != null) setState(() => _types[index] = value);
                    },
                    items: const [
                      DropdownMenuItem(value: MoneyEntryType.income, child: Text('Income')),
                      DropdownMenuItem(value: MoneyEntryType.expense, child: Text('Expense')),
                    ],
                  ),
                ),
                if (_nameControllers.length > 1)
                  IconButton(
                    onPressed: () => _removeRow(index),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove row',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: index == 0 ? const ValueKey('name-field') : null,
                    controller: _nameControllers[index],
                    decoration: const InputDecoration(labelText: 'Item / description', hintText: 'Salary or Rent'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: index == 0 ? const ValueKey('amount-field') : null,
                    controller: _amountControllers[index],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<MoneyEntryMode>(
                      initialValue: _modes[index],
                      decoration: const InputDecoration(labelText: 'Schedule'),
                      onChanged: (value) {
                        if (value != null) setState(() => _modes[index] = value);
                      },
                      items: const [
                        DropdownMenuItem(value: MoneyEntryMode.oneTime, child: Text('One time')),
                        DropdownMenuItem(value: MoneyEntryMode.recurring, child: Text('Recurring')),
                      ],
                    ),
                  ),
                  if (isRecurring) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<RecurrenceFrequency>(
                        initialValue: _frequencies[index],
                        decoration: const InputDecoration(labelText: 'Frequency'),
                        onChanged: (value) {
                          if (value != null) setState(() => _frequencies[index] = value);
                        },
                        items: const [
                          DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Monthly')),
                          DropdownMenuItem(value: RecurrenceFrequency.everyTwoMonths, child: Text('Every 2 months')),
                          DropdownMenuItem(value: RecurrenceFrequency.quarterly, child: Text('Quarterly')),
                          DropdownMenuItem(value: RecurrenceFrequency.halfYearly, child: Text('Half-yearly')),
                          DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text('Yearly')),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
    */

  Widget _buildDateSelector(BuildContext context) {
        final hasRecurring = _modes.contains(MoneyEntryMode.recurring);
        return InkWell(
          onTap: () => _pickDate(context, recurring: hasRecurring),
          child: InputDecorator(
            decoration: InputDecoration(labelText: hasRecurring ? 'Recurring start date' : 'Date'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('dd MMM yyyy').format(hasRecurring ? _selectedRecurringStartDate : _selectedDate)),
                const Icon(Icons.calendar_today_outlined, size: 18),
              ],
            ),
          ),
        );
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
                    'Add multiple rows',
                    key: ValueKey('income-option'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_nameControllers.length, (index) => _buildEntryRow(index)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Add another row'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDateSelector(context),
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
    /*
            initialValue: _types[index],
                    decoration: const InputDecoration(labelText: 'Type'),
                    onChanged: (value) {
                      if (value != null) setState(() => _types[index] = value);
                    },
                    items: const [
                      DropdownMenuItem(value: MoneyEntryType.income, child: Text('Income')),
                      DropdownMenuItem(value: MoneyEntryType.expense, child: Text('Expense')),
                    ],
                  ),
                ),
                if (_nameControllers.length > 1)
                  IconButton(
                    onPressed: () => _removeRow(index),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove row',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: index == 0 ? const ValueKey('name-field') : null,
                    controller: _nameControllers[index],
                    decoration: const InputDecoration(labelText: 'Item / description', hintText: 'Salary or Rent'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: index == 0 ? const ValueKey('amount-field') : null,
                    controller: _amountControllers[index],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<MoneyEntryMode>(
                    initialValue: _modes[index],
                    decoration: const InputDecoration(labelText: 'Schedule'),
                    onChanged: (value) {
                      if (value != null) setState(() => _modes[index] = value);
                    },
                    items: const [
                      DropdownMenuItem(value: MoneyEntryMode.oneTime, child: Text('One time')),
                      DropdownMenuItem(value: MoneyEntryMode.recurring, child: Text('Recurring')),
                    ],
                  ),
                ),
                if (isRecurring) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<RecurrenceFrequency>(
                      initialValue: _frequencies[index],
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      onChanged: (value) {
                        if (value != null) setState(() => _frequencies[index] = value);
                      },
                      items: const [
                        DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Monthly')),
                        DropdownMenuItem(value: RecurrenceFrequency.everyTwoMonths, child: Text('Every 2 months')),
                        DropdownMenuItem(value: RecurrenceFrequency.quarterly, child: Text('Quarterly')),
                        DropdownMenuItem(value: RecurrenceFrequency.halfYearly, child: Text('Half-yearly')),
                        DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text('Yearly')),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final hasRecurring = _modes.contains(MoneyEntryMode.recurring);
    return InkWell(
      onTap: () => _pickDate(context, recurring: hasRecurring),
      child: InputDecorator(
        decoration: InputDecoration(labelText: hasRecurring ? 'Recurring start date' : 'Date'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd MMM yyyy').format(hasRecurring ? _selectedRecurringStartDate : _selectedDate)),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
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
              const Text('Add multiple rows', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText)),
              const SizedBox(height: 8),
              ...List.generate(_nameControllers.length, (index) => _buildEntryRow(index)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add another row'),
                ),
              ),
              const SizedBox(height: 8),
              _buildDateSelector(context),
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
    */

class EditMoneySheet extends StatefulWidget {
  const EditMoneySheet({
    super.key,
    required this.entry,
    required this.selectedMonth,
    required this.onSave,
  });

  final MoneyEntry entry;
  final DateTime selectedMonth;
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

    final monthKey = DateTime(widget.selectedMonth.year, widget.selectedMonth.month);
    final overrides = Map<DateTime, int>.from(widget.entry.overrides);
    if (widget.entry.mode == MoneyEntryMode.recurring) {
      overrides[monthKey] = amountInPaise;
    }

    final updated = MoneyEntry(
      id: widget.entry.id,
      name: _nameController.text.trim(),
      type: _type,
      amountInPaise: amountInPaise,
      mode: widget.entry.mode,
      date: widget.entry.date,
      frequency: widget.entry.frequency,
      overrides: overrides,
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
  const AddLoanSheet({super.key, this.existingLoan, required this.onSave});

  final LoanEntry? existingLoan;
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
  final TextEditingController _extraEmiController = TextEditingController();
  final TextEditingController _tenureYearsController = TextEditingController(text: '1');
  final TextEditingController _tenureMonthsController = TextEditingController(text: '0');
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final loan = widget.existingLoan;
    if (loan != null) {
      _nameController.text = loan.name;
      _originalAmountController.text = (loan.originalAmountInPaise / 100).toString();
      _outstandingAmountController.text = (loan.outstandingAmountInPaise / 100).toString();
      _interestRateController.text = loan.interestRatePerAnnum.toString();
      _emiController.text = (loan.emiInPaise / 100).toString();
      _extraEmiController.text = (loan.extraEmiInPaise / 100).toString();
      _tenureYearsController.text = (loan.tenureMonths ~/ 12).toString();
      _tenureMonthsController.text = (loan.tenureMonths % 12).toString();
      _selectedDate = loan.startDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _originalAmountController.dispose();
    _outstandingAmountController.dispose();
    _interestRateController.dispose();
    _emiController.dispose();
    _extraEmiController.dispose();
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
    final extraEmi = double.tryParse(_extraEmiController.text.trim());
    if (_extraEmiController.text.trim().isNotEmpty && (extraEmi == null || extraEmi < 0)) {
      return 'Extra EMI cannot be negative.';
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
    final extraEmi = double.tryParse(_extraEmiController.text.trim()) ?? 0;
    final years = int.tryParse(_tenureYearsController.text.trim()) ?? 0;
    final months = int.tryParse(_tenureMonthsController.text.trim()) ?? 0;
    final tenureMonths = years * 12 + months;

    final entry = LoanEntry(
      id: widget.existingLoan?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      originalAmountInPaise: (originalAmount * 100).round(),
      outstandingAmountInPaise: (outstandingAmount * 100).round(),
      interestRatePerAnnum: interestRate,
      emiInPaise: (emi * 100).round(),
      extraEmiInPaise: (extraEmi * 100).round(),
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
                  Text(
                    widget.existingLoan == null ? 'Add Loan' : 'Edit Loan',
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
              TextFormField(
                controller: _extraEmiController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Extra EMI (optional)',
                  hintText: '0',
                  prefixText: '₹ ',
                  helperText: 'Additional amount paid every month toward principal',
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
