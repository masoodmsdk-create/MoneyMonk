import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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

// Default Free Tier Gemini API key (injected securely via --dart-define=GEMINI_API_KEY)
const String defaultFreeGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

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
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignup = false;
  bool _isBusy = true;
  String? _error;
  String? _currentUser;
  List<String> _savedAccounts = [];
  Map<String, int> _accountCounts = {};

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final users = jsonDecode(preferences.getString('moneymonk_users') ?? '{}') as Map<String, dynamic>;
    final lastUser = preferences.getString('moneymonk_last_user');
    final currentUser = preferences.getString('moneymonk_current_user');
    
    if (currentUser != null && !users.containsKey(currentUser)) {
      users[currentUser] = _hashPassword(currentUser, 'password123');
      await preferences.setString('moneymonk_users', jsonEncode(users));
    }

    final counts = <String, int>{};
    for (final acc in users.keys) {
      final raw = preferences.getString('moneymonk_money_$acc');
      if (raw != null && raw.isNotEmpty) {
        try {
          counts[acc] = (jsonDecode(raw) as List).length;
        } catch (_) {}
      }
    }

    // Seamless Zero-Lockout Auto-Session:
    // If no active user is set, automatically restore the last active account,
    // or whichever profile has existing entries, or default to 'masood'.
    // The user will NEVER be blocked by session expiry or lost logins!
    String activeUser = (currentUser != null && currentUser.isNotEmpty)
        ? currentUser
        : (lastUser != null && lastUser.isNotEmpty)
            ? lastUser
            : '';
    if (activeUser.isEmpty) {
      final accWithData = users.keys.firstWhere(
        (a) => (counts[a] ?? 0) > 0,
        orElse: () => users.isNotEmpty ? users.keys.first : 'masood',
      );
      activeUser = accWithData;
    }
    
    if (!users.containsKey(activeUser)) {
      users[activeUser] = _hashPassword(activeUser, 'password123');
      await preferences.setString('moneymonk_users', jsonEncode(users));
    }
    await preferences.setString('moneymonk_current_user', activeUser);
    await preferences.setString('moneymonk_last_user', activeUser);

    if (!mounted) return;
    setState(() {
      _savedAccounts = users.keys.toList();
      _accountCounts = counts;
      _currentUser = activeUser;
      _usernameController.text = activeUser;
      _isBusy = false;
    });
  }

  String _hashPassword(String username, String password) {
    return sha256.convert(utf8.encode('$username:$password')).toString();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final users = jsonDecode(preferences.getString('moneymonk_users') ?? '{}') as Map<String, dynamic>;
    final hash = _hashPassword(username, password);

    if (_isSignup) {
      if (users.containsKey(username)) {
        setState(() => _error = 'That username already exists. Sign in with your password.');
        return;
      }
      users[username] = hash;
      await preferences.setString('moneymonk_users', jsonEncode(users));
      final legacyMoney = preferences.getString('moneymonk_money');
      final legacyLoans = preferences.getString('moneymonk_loans');
      if (legacyMoney != null && preferences.getString('moneymonk_money_$username') == null) {
        await preferences.setString('moneymonk_money_$username', legacyMoney);
      }
      if (legacyLoans != null && preferences.getString('moneymonk_loans_$username') == null) {
        await preferences.setString('moneymonk_loans_$username', legacyLoans);
      }
    } else {
      // Seamless Zero-Friction: If account doesn't exist on this browser yet,
      // automatically register it with this password and sign straight in!
      if (!users.containsKey(username)) {
        users[username] = hash;
        await preferences.setString('moneymonk_users', jsonEncode(users));
        final legacyMoney = preferences.getString('moneymonk_money');
        final legacyLoans = preferences.getString('moneymonk_loans');
        if (legacyMoney != null && preferences.getString('moneymonk_money_$username') == null) {
          await preferences.setString('moneymonk_money_$username', legacyMoney);
        }
        if (legacyLoans != null && preferences.getString('moneymonk_loans_$username') == null) {
          await preferences.setString('moneymonk_loans_$username', legacyLoans);
        }
      } else if (users[username] != hash) {
        setState(() => _error = 'Incorrect password for "$username". Use "Forgot Password?" below to reset.');
        return;
      }
    }

    await preferences.setString('moneymonk_current_user', username);
    await preferences.setString('moneymonk_last_user', username);
    if (!mounted) return;
    setState(() {
      _currentUser = username;
      _error = null;
    });
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final resetUserCtrl = TextEditingController(text: _usernameController.text.trim());
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? dialogError;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_reset_outlined, color: moneyMonkNavy, size: 26),
                            SizedBox(width: 10),
                            Text('Reset Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your registered username and set a new password.',
                      style: TextStyle(fontSize: 13, color: moneyMonkSecondaryText),
                    ),
                    const SizedBox(height: 18),

                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          border: Border.all(color: moneyMonkError),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: moneyMonkError, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(dialogError!, style: const TextStyle(color: moneyMonkError, fontWeight: FontWeight.w600, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: resetUserCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password (min 6 characters) *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Update Password'),
                        onPressed: () async {
                          final user = resetUserCtrl.text.trim().toLowerCase();
                          final newPass = newPassCtrl.text;
                          final confirmPass = confirmPassCtrl.text;

                          if (user.length < 3) {
                            setSheetState(() => dialogError = 'Username must be at least 3 characters.');
                            return;
                          }
                          if (newPass.length < 6) {
                            setSheetState(() => dialogError = 'New password must be at least 6 characters.');
                            return;
                          }
                          if (newPass != confirmPass) {
                            setSheetState(() => dialogError = 'Passwords do not match.');
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final prefs = await SharedPreferences.getInstance();
                          final users = jsonDecode(prefs.getString('moneymonk_users') ?? '{}') as Map<String, dynamic>;

                          if (!users.containsKey(user)) {
                            setSheetState(() => dialogError = "No account found with username '$user'.");
                            return;
                          }

                          final newHash = _hashPassword(user, newPass);
                          users[user] = newHash;
                          await prefs.setString('moneymonk_users', jsonEncode(users));

                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }

                          _usernameController.text = user;
                          _passwordController.text = newPass;
                          setState(() => _error = null);

                          messenger.showSnackBar(
                            const SnackBar(content: Text('Password reset successfully! You can now sign in.')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBusy) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_currentUser != null) return MoneyMonkHomePage(username: _currentUser!);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('MoneyMonk', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: moneyMonkNavy)),
                  const SizedBox(height: 8),
                  Text(_isSignup ? 'Create your account' : 'Sign in to your account', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 16),
                  TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
                  if (!_isSignup) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Forgot Password?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: moneyMonkNavy)),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: moneyMonkError)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: Text(_isSignup ? 'Sign up' : 'Sign in'))),
                  TextButton(onPressed: () => setState(() { _isSignup = !_isSignup; _error = null; }), child: Text(_isSignup ? 'Already have an account? Sign in' : 'New here? Sign up')),
                  if (_savedAccounts.isNotEmpty && !_isSignup) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Saved accounts on this device:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _savedAccounts.map((account) {
                        final count = _accountCounts[account] ?? 0;
                        return ActionChip(
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: moneyMonkNavy,
                            child: Text(account[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                          label: Text(
                            count > 0 ? '$account ($count ${count == 1 ? "entry" : "entries"})' : account,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              _usernameController.text = account;
                              _error = null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserProfile {
  UserProfile({
    required this.username,
    required this.displayName,
    this.email = '',
    required this.createdAt,
  });

  final String username;
  final String displayName;
  final String email;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? json['username']?.toString() ?? 'User',
        email: json['email']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class FinancialMetrics {
  FinancialMetrics({
    required this.income,
    required this.directExpense,
    required this.loanEmi,
  });

  final int income;
  final int directExpense;
  final int loanEmi;

  int get totalOutflow => directExpense + loanEmi;
  int get balance => income - totalOutflow;
  double get savingsRate => income > 0 ? (balance / income) * 100 : 0.0;
  double get debtToIncome => income > 0 ? (loanEmi / income) * 100 : 0.0;
  bool get isSurplus => balance >= 0;
}

class FinancialForecastRow {
  const FinancialForecastRow({
    required this.month,
    required this.income,
    required this.directExpense,
    required this.loanEmi,
    required this.totalOutflow,
    required this.balance,
  });

  final DateTime month;
  final int income;
  final int directExpense;
  final int loanEmi;
  final int totalOutflow;
  final int balance;
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
    this.endDate,
    this.overrides = const {},
    this.effectiveRates = const {},
    this.isLoanCovered = false,
  });

  final String id;
  final String name;
  final MoneyEntryType type;
  final int amountInPaise;
  final MoneyEntryMode mode;
  final DateTime date;
  final RecurrenceFrequency? frequency;
  final DateTime? endDate;
  final Map<DateTime, int> overrides;
  final Map<DateTime, int> effectiveRates;
  final bool isLoanCovered;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'amount': amountInPaise,
        'mode': mode.name,
        'date': date.toIso8601String(),
        'frequency': frequency?.name,
        'endDate': endDate?.toIso8601String(),
        'overrides': overrides.map((key, value) => MapEntry(key.toIso8601String(), value)),
        'effectiveRates': effectiveRates.map((key, value) => MapEntry(key.toIso8601String(), value)),
        'isLoanCovered': isLoanCovered,
      };

  factory MoneyEntry.fromJson(Map<String, dynamic> json) {
    final rawOverrides = (json['overrides'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawEffectiveRates = (json['effectiveRates'] as Map?)?.cast<String, dynamic>() ?? {};
    
    // Defensive type resolution
    MoneyEntryType type = MoneyEntryType.income;
    final rawType = (json['type'] ?? '').toString().toLowerCase();
    if (rawType.contains('expense')) {
      type = MoneyEntryType.expense;
    }

    // Defensive mode resolution
    MoneyEntryMode mode = MoneyEntryMode.oneTime;
    final rawMode = (json['mode'] ?? '').toString().toLowerCase();
    if (rawMode.contains('recurring')) {
      mode = MoneyEntryMode.recurring;
    }

    // Defensive frequency resolution
    RecurrenceFrequency? frequency;
    final rawFreq = json['frequency']?.toString();
    if (rawFreq != null && rawFreq.isNotEmpty) {
      for (final f in RecurrenceFrequency.values) {
        if (f.name.toLowerCase() == rawFreq.toLowerCase()) {
          frequency = f;
          break;
        }
      }
    }

    DateTime date;
    try {
      date = DateTime.parse(json['date'] as String);
    } catch (_) {
      date = DateTime.now();
    }

    DateTime? endDate;
    if (json['endDate'] != null && json['endDate'].toString().isNotEmpty) {
      try {
        endDate = DateTime.parse(json['endDate'] as String);
      } catch (_) {}
    }

    final parsedOverrides = <DateTime, int>{};
    rawOverrides.forEach((key, value) {
      try {
        final d = DateTime.parse(key);
        final v = (value as num?)?.toInt() ?? 0;
        parsedOverrides[d] = v;
      } catch (_) {}
    });

    final parsedEffectiveRates = <DateTime, int>{};
    rawEffectiveRates.forEach((key, value) {
      try {
        final d = DateTime.parse(key);
        final v = (value as num?)?.toInt() ?? 0;
        parsedEffectiveRates[d] = v;
      } catch (_) {}
    });

    return MoneyEntry(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Item',
      type: type,
      amountInPaise: (json['amount'] as num?)?.toInt() ?? (json['amountInPaise'] as num?)?.toInt() ?? 0,
      mode: mode,
      date: date,
      frequency: frequency,
      endDate: endDate,
      overrides: parsedOverrides,
      effectiveRates: parsedEffectiveRates,
      isLoanCovered: json['isLoanCovered'] as bool? ?? false,
    );
  }

  String get prettyAmount => _formatCurrency(amountInPaise);

  bool isSkippedInMonth(DateTime month) {
    final monthKey = DateTime(month.year, month.month);
    return overrides.containsKey(monthKey) && overrides[monthKey] == 0;
  }

  bool isOverriddenInMonth(DateTime month) {
    final monthKey = DateTime(month.year, month.month);
    return overrides.containsKey(monthKey) && overrides[monthKey] != 0;
  }

  int getAmountForMonth(DateTime month) {
    final monthKey = DateTime(month.year, month.month);
    if (overrides.containsKey(monthKey)) {
      return overrides[monthKey]!;
    }
    // Check if there are stepped effective changes on or before this month
    if (effectiveRates.isNotEmpty) {
      DateTime? bestDate;
      for (final effDate in effectiveRates.keys) {
        final effMonth = DateTime(effDate.year, effDate.month);
        if (!monthKey.isBefore(effMonth)) {
          if (bestDate == null || effMonth.isAfter(DateTime(bestDate.year, bestDate.month))) {
            bestDate = effDate;
          }
        }
      }
      if (bestDate != null) {
        return effectiveRates[bestDate]!;
      }
    }
    return amountInPaise;
  }

  bool appliesToMonth(DateTime month) {
    if (mode == MoneyEntryMode.oneTime) {
      return date.year == month.year && date.month == month.month;
    }
    // Recurring
    if (date.year > month.year || (date.year == month.year && date.month > month.month)) {
      return false;
    }
    if (endDate != null) {
      if (month.year > endDate!.year || (month.year == endDate!.year && month.month > endDate!.month)) {
        return false;
      }
    }
    
    final monthsSinceStart = (month.year - date.year) * 12 + (month.month - date.month);
    switch (frequency ?? RecurrenceFrequency.monthly) {
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
    this.extraPayments = const {},
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
  final Map<DateTime, int> extraPayments;
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
        'extraPayments': extraPayments.map((key, value) => MapEntry(key.toIso8601String(), value)),
        'startDate': startDate.toIso8601String(),
        'tenure': tenureMonths,
      };

  factory LoanEntry.fromJson(Map<String, dynamic> json) {
    DateTime date;
    try {
      date = DateTime.parse(json['startDate'] as String);
    } catch (_) {
      date = DateTime.now();
    }

    final rawExtraPayments = (json['extraPayments'] as Map?)?.cast<String, dynamic>() ?? {};
    final parsedExtraPayments = <DateTime, int>{};
    rawExtraPayments.forEach((key, value) {
      try {
        final d = DateTime.parse(key);
        final v = (value as num?)?.toInt() ?? 0;
        parsedExtraPayments[d] = v;
      } catch (_) {}
    });

    return LoanEntry(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Loan',
      originalAmountInPaise: (json['original'] as num?)?.toInt() ?? (json['originalAmountInPaise'] as num?)?.toInt() ?? 0,
      outstandingAmountInPaise: (json['outstanding'] as num?)?.toInt() ?? (json['outstandingAmountInPaise'] as num?)?.toInt() ?? 0,
      interestRatePerAnnum: (json['rate'] as num?)?.toDouble() ?? (json['interestRatePerAnnum'] as num?)?.toDouble() ?? 0.0,
      emiInPaise: (json['emi'] as num?)?.toInt() ?? (json['emiInPaise'] as num?)?.toInt() ?? 0,
      extraEmiInPaise: (json['extraEmi'] as num?)?.toInt() ?? (json['extraEmiInPaise'] as num?)?.toInt() ?? 0,
      extraPayments: parsedExtraPayments,
      startDate: date,
      tenureMonths: (json['tenure'] as num?)?.toInt() ?? (json['tenureMonths'] as num?)?.toInt() ?? 12,
    );
  }

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
      extraPayments: extraPayments,
      startDate: startDate,
    );
  }

  LoanMonth? getStatusForMonth(DateTime month) {
    final amort = calculateAmortization();
    for (final item in amort.schedule) {
      if (item.date.year == month.year && item.date.month == month.month) {
        return item;
      }
    }
    return null;
  }

  bool isActiveInMonth(DateTime month) {
    final targetMonth = DateTime(month.year, month.month);
    final startMonth = DateTime(startDate.year, startDate.month);
    if (targetMonth.isBefore(startMonth)) return false;
    final amort = calculateAmortization();
    if (!amort.isValid) return true; // Non-amortizing loan remains active
    if (amort.schedule.isEmpty) return false;
    final lastMonth = DateTime(amort.schedule.last.date.year, amort.schedule.last.date.month);
    return !targetMonth.isAfter(lastMonth);
  }

  int getEmiForMonth(DateTime month) {
    final targetMonth = DateTime(month.year, month.month);
    final startMonth = DateTime(startDate.year, startDate.month);
    if (targetMonth.isBefore(startMonth)) return 0;
    if (isPaidOffAsOf(month)) return 0;

    final status = getStatusForMonth(month);
    if (status != null) {
      return status.emiInPaise;
    }
    final amort = calculateAmortization();
    if (!amort.isValid) {
      final monthKey = DateTime(month.year, month.month);
      return emiInPaise + (extraPayments[monthKey] ?? extraEmiInPaise);
    }
    return 0;
  }

  int getRemainingPrincipalForMonth(DateTime month) {
    final targetMonth = DateTime(month.year, month.month);
    final startMonth = DateTime(startDate.year, startDate.month);
    if (targetMonth.isBefore(startMonth)) {
      return outstandingAmountInPaise;
    }
    if (isPaidOffAsOf(month)) {
      return 0;
    }
    final status = getStatusForMonth(month);
    if (status != null) {
      return status.remainingPrincipalInPaise;
    }
    final amort = calculateAmortization();
    if (!amort.isValid) {
      return outstandingAmountInPaise;
    }
    if (amort.schedule.isNotEmpty) {
      final lastMonth = DateTime(amort.schedule.last.date.year, amort.schedule.last.date.month);
      if (targetMonth.isAfter(lastMonth)) {
        return 0;
      }
    }
    return outstandingAmountInPaise;
  }

  int getRemainingMonthsAsOf(DateTime month) {
    final targetMonth = DateTime(month.year, month.month);
    final amort = calculateAmortization();
    if (!amort.isValid) return -1; // Flag as non-amortizing
    if (amort.schedule.isEmpty) return 0;
    final startMonth = DateTime(startDate.year, startDate.month);
    if (targetMonth.isBefore(startMonth)) {
      return amort.remainingMonths;
    }
    final remaining = amort.schedule.where((m) => !DateTime(m.date.year, m.date.month).isBefore(targetMonth)).length;
    return remaining;
  }

  bool isPaidOffAsOf(DateTime month) {
    final targetMonth = DateTime(month.year, month.month);
    final amort = calculateAmortization();
    if (!amort.isValid) return false;
    if (amort.schedule.isEmpty) return false;
    final lastMonth = DateTime(amort.schedule.last.date.year, amort.schedule.last.date.month);
    return targetMonth.isAfter(lastMonth);
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
    Map<DateTime, int> extraPayments = const {},
    required DateTime startDate,
  }) {
    final monthlyRate = annualRate / 100 / 12;
    final schedule = <LoanMonth>[];
    var currentPrincipal = principal;
    var currentDate = DateTime(startDate.year, startDate.month);
    var isValid = true;
    var invalidReason = '';

    while (currentPrincipal > 0) {
      final monthKey = DateTime(currentDate.year, currentDate.month);
      final monthExtra = extraPayments[monthKey] ?? extraEmiInPaise;
      final interestInPaise = (currentPrincipal * monthlyRate).round();
      final scheduledPaymentInPaise = emiInPaise + monthExtra;
      
      if (interestInPaise >= scheduledPaymentInPaise && currentPrincipal > 0) {
        isValid = false;
        invalidReason = '⚠️ EMI may not be sufficient to repay this loan.';
        break;
      }

      var principalPaymentInPaise = scheduledPaymentInPaise - interestInPaise;
      var newPrincipal = currentPrincipal - principalPaymentInPaise;
      var actualEmiInPaise = scheduledPaymentInPaise;

      // Exact payoff clamping: never overpay principal, never create negative principal
      if (newPrincipal <= 0) {
        newPrincipal = 0;
        principalPaymentInPaise = currentPrincipal;
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
  const MoneyMonkHomePage({super.key, required this.username});

  final String username;

  @override
  State<MoneyMonkHomePage> createState() => _MoneyMonkHomePageState();
}

class _MoneyMonkHomePageState extends State<MoneyMonkHomePage> {
  int _selectedIndex = 0;
  final List<MoneyEntry> _moneyEntries = <MoneyEntry>[];
  final List<LoanEntry> _loanEntries = <LoanEntry>[];
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isMonthlyView = true;
  bool _showAllTransactions = false;
  bool _isLoadingSavedData = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _parseMoneyJson(String? raw, List<MoneyEntry> target) {
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      for (final item in list) {
        try {
          if (item is Map<String, dynamic>) {
            target.add(MoneyEntry.fromJson(item));
          } else if (item is Map) {
            target.add(MoneyEntry.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _parseLoansJson(String? raw, List<LoanEntry> target) {
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      for (final item in list) {
        try {
          if (item is Map<String, dynamic>) {
            target.add(LoanEntry.fromJson(item));
          } else if (item is Map) {
            target.add(LoanEntry.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _loadSavedData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final loadedMoney = <MoneyEntry>[];
      final loadedLoans = <LoanEntry>[];
      final seenMoneyKeys = <String>{};
      final seenLoanKeys = <String>{};

      void addMoneyFromRaw(String? raw) {
        if (raw == null || raw.isEmpty) return;
        final temp = <MoneyEntry>[];
        _parseMoneyJson(raw, temp);
        for (final entry in temp) {
          final dedupeKey = '${entry.id}_${entry.name}_${entry.amountInPaise}_${entry.date.millisecondsSinceEpoch}';
          if (!seenMoneyKeys.contains(dedupeKey)) {
            seenMoneyKeys.add(dedupeKey);
            loadedMoney.add(entry);
          }
        }
      }

      void addLoansFromRaw(String? raw) {
        if (raw == null || raw.isEmpty) return;
        final temp = <LoanEntry>[];
        _parseLoansJson(raw, temp);
        for (final loan in temp) {
          final dedupeKey = '${loan.id}_${loan.name}_${loan.originalAmountInPaise}_${loan.outstandingAmountInPaise}';
          if (!seenLoanKeys.contains(dedupeKey)) {
            seenLoanKeys.add(dedupeKey);
            loadedLoans.add(loan);
          }
        }
      }

      // 1. Check user-specific storage keys
      final moneyKey = 'moneymonk_money_${widget.username}';
      final loansKey = 'moneymonk_loans_${widget.username}';
      addMoneyFromRaw(preferences.getString(moneyKey));
      addLoansFromRaw(preferences.getString(loansKey));

      // 2. Check redundant global device backups
      addMoneyFromRaw(preferences.getString('moneymonk_global_latest_money'));
      addLoansFromRaw(preferences.getString('moneymonk_global_latest_loans'));

      // 3. Check legacy unnamespaced keys
      addMoneyFromRaw(preferences.getString('moneymonk_money'));
      addLoansFromRaw(preferences.getString('moneymonk_loans'));

      // 4. DEEP SCAN: Check every saved profile key on this browser / device
      for (final key in preferences.getKeys()) {
        if (key.startsWith('moneymonk_money_')) {
          addMoneyFromRaw(preferences.getString(key));
        } else if (key.startsWith('moneymonk_loans_')) {
          addLoansFromRaw(preferences.getString(key));
        }
      }

      // If data was recovered or loaded, mirror it across all keys immediately
      if (loadedMoney.isNotEmpty || loadedLoans.isNotEmpty) {
        final moneyJson = jsonEncode(loadedMoney.map((e) => e.toJson()).toList());
        final loansJson = jsonEncode(loadedLoans.map((e) => e.toJson()).toList());
        await preferences.setString(moneyKey, moneyJson);
        await preferences.setString(loansKey, loansJson);
        await preferences.setString('moneymonk_global_latest_money', moneyJson);
        await preferences.setString('moneymonk_global_latest_loans', loansJson);
        await preferences.setString('moneymonk_money', moneyJson);
        await preferences.setString('moneymonk_loans', loansJson);
      }

      if (!mounted) return;
      setState(() {
        _moneyEntries.clear();
        _moneyEntries.addAll(loadedMoney);
        _loanEntries.clear();
        _loanEntries.addAll(loadedLoans);
        _isLoadingSavedData = false;
      });
      debugPrint('Loaded ${_moneyEntries.length} money entries & ${_loanEntries.length} loans for ${widget.username}');
    } catch (e) {
      debugPrint('Error in _loadSavedData: $e');
      if (mounted) {
        setState(() => _isLoadingSavedData = false);
      }
    }
  }

  Future<bool> _saveData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final moneyJson = jsonEncode(_moneyEntries.map((entry) => entry.toJson()).toList());
      final loansJson = jsonEncode(_loanEntries.map((entry) => entry.toJson()).toList());
      
      // 1. User namespace
      final s1 = await preferences.setString('moneymonk_money_${widget.username}', moneyJson);
      final s2 = await preferences.setString('moneymonk_loans_${widget.username}', loansJson);
      
      // 2. Redundant global device backups (guarantees data survives across any account switches/typos/sessions)
      await preferences.setString('moneymonk_global_latest_money', moneyJson);
      await preferences.setString('moneymonk_global_latest_loans', loansJson);
      await preferences.setString('moneymonk_money', moneyJson);
      await preferences.setString('moneymonk_loans', loansJson);
      await preferences.setString('moneymonk_last_active_user', widget.username);
      await preferences.setString('moneymonk_last_saved_time', DateTime.now().toIso8601String());

      debugPrint('Saved data for ${widget.username}: money=$s1 (${_moneyEntries.length}), loans=$s2 (${_loanEntries.length}) + global backup');
      return s1 && s2;
    } catch (e) {
      debugPrint('Error in _saveData: $e');
      return false;
    }
  }

  Future<void> _signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('moneymonk_last_user', widget.username);
    await preferences.remove('moneymonk_current_user');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  void _handleAddMoney() {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddMoneySheet(
        initialDate: _selectedMonth,
        onSave: (List<MoneyEntry> entries) async {
          setState(() {
            _moneyEntries.addAll(entries);
          });
          await _saveData();
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Saved ${entries.length} ${entries.length == 1 ? "entry" : "entries"} successfully!'),
                backgroundColor: moneyMonkIncome,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void _handleEditMoney(MoneyEntry entry) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => EditMoneySheet(
        entry: entry,
        selectedMonth: _selectedMonth,
        onSave: (MoneyEntry updated) async {
          setState(() {
            final index = _moneyEntries.indexWhere((e) => e.id == entry.id);
            if (index >= 0) {
              _moneyEntries[index] = updated;
            }
          });
          await _saveData();
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Entry updated successfully!'),
                backgroundColor: moneyMonkIncome,
                duration: Duration(seconds: 2),
              ),
            );
          }
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
    ).then((delete) async {
      if (delete == true) {
        setState(() {
          _moneyEntries.removeWhere((e) => e.id == entry.id);
        });
        await _saveData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry deleted.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _handleAddLoan() {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddLoanSheet(
        onSave: (LoanEntry entry) async {
          setState(() {
            _loanEntries.add(entry);
          });
          await _saveData();
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Loan saved successfully!'),
                backgroundColor: moneyMonkIncome,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void _handleEditLoan(LoanEntry loan) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddLoanSheet(
        existingLoan: loan,
        onSave: (updated) async {
          setState(() {
            final index = _loanEntries.indexWhere((entry) => entry.id == loan.id);
            if (index >= 0) _loanEntries[index] = updated;
          });
          await _saveData();
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Loan updated successfully!'),
                backgroundColor: moneyMonkIncome,
                duration: Duration(seconds: 2),
              ),
            );
          }
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
    ).then((delete) async {
      if (delete == true) {
        setState(() {
          _loanEntries.removeWhere((e) => e.id == entry.id);
        });
        await _saveData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loan deleted.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _showUserManagementSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final navigator = Navigator.of(context);
        return _UserManagementSheetContent(
          currentUsername: widget.username,
          moneyEntriesCount: _moneyEntries.length,
          loansCount: _loanEntries.length,
          onSwitchUser: (String targetUser) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('moneymonk_current_user', targetUser);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            if (mounted) {
              navigator.pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                (_) => false,
              );
            }
          },
          onSignOut: () {
            Navigator.pop(sheetContext);
            _signOut();
          },
        );
      },
    );
  }

  int _getMoneyTotal(MoneyEntryType type, {DateTime? forMonth}) {
    final month = forMonth ?? _selectedMonth;
    var total = 0;
    
    for (final entry in _moneyEntries) {
      if (entry.type == type && entry.appliesToMonth(month)) {
        if (type == MoneyEntryType.expense && entry.isLoanCovered) {
          continue; // P1: Prevent Loan EMI double counting
        }
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

  int _getLoanEmiTotal({DateTime? forMonth}) {
    final month = forMonth ?? _selectedMonth;
    var total = 0;
    for (final loan in _loanEntries) {
      total += loan.getEmiForMonth(month);
    }
    return total;
  }

  int _getLoanEmiTotalForYear({DateTime? forYear}) {
    final year = (forYear ?? _selectedMonth).year;
    var total = 0;
    for (var m = 1; m <= 12; m++) {
      total += _getLoanEmiTotal(forMonth: DateTime(year, m));
    }
    return total;
  }

  List<FinancialForecastRow> _generateForecast() {
    final forecast = <FinancialForecastRow>[];
    final now = DateTime.now();
    
    for (var i = 0; i < 12; i++) {
      final forecastMonth = DateTime(now.year, now.month + i);
      final income = _getMoneyTotal(MoneyEntryType.income, forMonth: forecastMonth);
      final directExpense = _getMoneyTotal(MoneyEntryType.expense, forMonth: forecastMonth);
      final loanEmi = _getLoanEmiTotal(forMonth: forecastMonth);
      final totalOutflow = directExpense + loanEmi;
      final balance = income - totalOutflow;
      
      forecast.add(FinancialForecastRow(
        month: forecastMonth,
        income: income,
        directExpense: directExpense,
        loanEmi: loanEmi,
        totalOutflow: totalOutflow,
        balance: balance,
      ));
    }
    
    return forecast;
  }

  void _handleToggleSkipMoney(MoneyEntry entry, Map<DateTime, int> updatedOverrides) async {
    final messenger = ScaffoldMessenger.of(context);
    final monthKey = DateTime(_selectedMonth.year, _selectedMonth.month);
    final isNowSkipped = updatedOverrides.containsKey(monthKey) && updatedOverrides[monthKey] == 0;
    setState(() {
      final idx = _moneyEntries.indexWhere((e) => e.id == entry.id);
      if (idx >= 0) {
        _moneyEntries[idx] = MoneyEntry(
          id: entry.id,
          name: entry.name,
          type: entry.type,
          amountInPaise: entry.amountInPaise,
          mode: entry.mode,
          date: entry.date,
          frequency: entry.frequency,
          endDate: entry.endDate,
          overrides: updatedOverrides,
          effectiveRates: entry.effectiveRates,
          isLoanCovered: entry.isLoanCovered,
        );
      }
    });
    await _saveData();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isNowSkipped
              ? 'Skipped "${entry.name}" for ${DateFormat('MMM yyyy').format(_selectedMonth)}.'
              : 'Restored "${entry.name}" for ${DateFormat('MMM yyyy').format(_selectedMonth)}.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleLoanPrepayment(LoanEntry loan, int prepaymentInPaise) async {
    final messenger = ScaffoldMessenger.of(context);
    final monthKey = DateTime(_selectedMonth.year, _selectedMonth.month);
    final updatedPayments = Map<DateTime, int>.from(loan.extraPayments);
    if (prepaymentInPaise <= 0) {
      updatedPayments.remove(monthKey);
    } else {
      updatedPayments[monthKey] = prepaymentInPaise;
    }
    final updated = LoanEntry(
      id: loan.id,
      name: loan.name,
      originalAmountInPaise: loan.originalAmountInPaise,
      outstandingAmountInPaise: loan.outstandingAmountInPaise,
      interestRatePerAnnum: loan.interestRatePerAnnum,
      emiInPaise: loan.emiInPaise,
      extraEmiInPaise: loan.extraEmiInPaise,
      extraPayments: updatedPayments,
      startDate: loan.startDate,
      tenureMonths: loan.tenureMonths,
    );
    setState(() {
      final idx = _loanEntries.indexWhere((e) => e.id == loan.id);
      if (idx >= 0) {
        _loanEntries[idx] = updated;
      }
    });
    await _saveData();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Prepayment for ${DateFormat('MMM yyyy').format(_selectedMonth)} saved.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showBackupSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _BackupSheet(
        username: widget.username,
        moneyEntries: _moneyEntries,
        loanEntries: _loanEntries,
        onImport: (newMoney, newLoans) async {
          setState(() {
            final seenMoney = _moneyEntries.map((e) => e.id).toSet();
            for (final m in newMoney) {
              if (!seenMoney.contains(m.id)) {
                _moneyEntries.add(m);
                seenMoney.add(m.id);
              }
            }
            final seenLoans = _loanEntries.map((e) => e.id).toSet();
            for (final l in newLoans) {
              if (!seenLoans.contains(l.id)) {
                _loanEntries.add(l);
                seenLoans.add(l.id);
              }
            }
          });
          await _saveData();
        },
        onScanRecover: () async {
          await _loadSavedData();
        },
        onLoadTemplate: () async {
          final now = DateTime.now();
          final sampleMoney = [
            MoneyEntry(
              id: 'sample-sal-${now.millisecondsSinceEpoch}',
              name: 'Salary (Primary Income)',
              type: MoneyEntryType.income,
              amountInPaise: 8500000,
              mode: MoneyEntryMode.recurring,
              frequency: RecurrenceFrequency.monthly,
              date: DateTime(now.year, now.month, 1),
            ),
            MoneyEntry(
              id: 'sample-rent-${now.millisecondsSinceEpoch}',
              name: 'House Rent',
              type: MoneyEntryType.expense,
              amountInPaise: 2400000,
              mode: MoneyEntryMode.recurring,
              frequency: RecurrenceFrequency.monthly,
              date: DateTime(now.year, now.month, 5),
            ),
            MoneyEntry(
              id: 'sample-groc-${now.millisecondsSinceEpoch}',
              name: 'Groceries & Household',
              type: MoneyEntryType.expense,
              amountInPaise: 1200000,
              mode: MoneyEntryMode.recurring,
              frequency: RecurrenceFrequency.monthly,
              date: DateTime(now.year, now.month, 7),
            ),
            MoneyEntry(
              id: 'sample-util-${now.millisecondsSinceEpoch}',
              name: 'Electricity & Utilities',
              type: MoneyEntryType.expense,
              amountInPaise: 450000,
              mode: MoneyEntryMode.recurring,
              frequency: RecurrenceFrequency.monthly,
              date: DateTime(now.year, now.month, 10),
            ),
          ];
          final sampleLoan = LoanEntry(
            id: 'sample-loan-${now.millisecondsSinceEpoch}',
            name: 'Car Loan',
            originalAmountInPaise: 65000000,
            outstandingAmountInPaise: 48000000,
            interestRatePerAnnum: 8.7,
            emiInPaise: 1450000,
            extraEmiInPaise: 200000,
            startDate: DateTime(now.year - 1, now.month, 1),
            tenureMonths: 48,
          );
          setState(() {
            _moneyEntries.addAll(sampleMoney);
            _loanEntries.add(sampleLoan);
          });
          await _saveData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeSummaryScreen(
        username: widget.username,
        moneyEntries: _moneyEntries,
        loanEntries: _loanEntries,
        selectedMonth: _selectedMonth,
        monthlyIncome: _getMoneyTotal(MoneyEntryType.income),
        monthlyExpense: _getMoneyTotal(MoneyEntryType.expense),
        onMoneyTap: () => setState(() => _selectedIndex = 1),
        onLoansTap: () => setState(() => _selectedIndex = 2),
      ),
      MoneyScreen(
        entries: _moneyEntries,
        loanEntries: _loanEntries,
        selectedMonth: _selectedMonth,
        isMonthlyView: _isMonthlyView,
        showAllTransactions: _showAllTransactions,
        onMonthChanged: (month) => setState(() => _selectedMonth = month),
        onViewChanged: (isMonthly) => setState(() {
          _isMonthlyView = isMonthly;
          _showAllTransactions = false;
        }),
        onToggleAllTransactions: (showAll) => setState(() {
          _showAllTransactions = showAll;
        }),
        onAddPressed: _handleAddMoney,
        onEditPressed: _handleEditMoney,
        onDeletePressed: _handleDeleteMoney,
        onToggleSkip: _handleToggleSkipMoney,
        getMoneyTotal: _getMoneyTotal,
        getMoneyTotalForYear: _getMoneyTotalForYear,
        getLoanEmiTotal: _getLoanEmiTotal,
        getLoanEmiTotalForYear: _getLoanEmiTotalForYear,
        generateForecast: _generateForecast,
      ),
      LoansScreen(
        entries: _loanEntries,
        selectedMonth: _selectedMonth,
        onMonthChanged: (month) => setState(() => _selectedMonth = month),
        onAddPressed: _handleAddLoan,
        onEditPressed: _handleEditLoan,
        onDeletePressed: _handleDeleteLoan,
        onPrepayment: _handleLoanPrepayment,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: moneyMonkNavy),
            tooltip: 'Data Backup & Recovery',
            onPressed: () => _showBackupSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: moneyMonkNavy),
            tooltip: 'MoneyMonk AI Advisor',
            onPressed: () {
              setState(() {
                _selectedIndex = 0;
              });
            },
          ),
          // User Avatar & Multi-User Switcher Badge
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: CircleAvatar(
                radius: 12,
                backgroundColor: moneyMonkNavy,
                child: Text(
                  widget.username.isNotEmpty ? widget.username[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              label: Text(
                widget.username,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: moneyMonkNavy),
              ),
              onPressed: () => _showUserManagementSheet(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: _isLoadingSavedData
              ? const Center(child: CircularProgressIndicator())
              : screens[_selectedIndex],
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
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

class _UserManagementSheetContent extends StatefulWidget {
  const _UserManagementSheetContent({
    required this.currentUsername,
    required this.moneyEntriesCount,
    required this.loansCount,
    required this.onSwitchUser,
    required this.onSignOut,
  });

  final String currentUsername;
  final int moneyEntriesCount;
  final int loansCount;
  final ValueChanged<String> onSwitchUser;
  final VoidCallback onSignOut;

  @override
  State<_UserManagementSheetContent> createState() => _UserManagementSheetContentState();
}

class _UserManagementSheetContentState extends State<_UserManagementSheetContent> {
  List<String> _allUsers = [];
  Map<String, int> _userEntryCounts = {};
  Map<String, int> _userLoanCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersMap = jsonDecode(prefs.getString('moneymonk_users') ?? '{}') as Map<String, dynamic>;
    final counts = <String, int>{};
    final loanCounts = <String, int>{};
    for (final u in usersMap.keys) {
      final moneyRaw = prefs.getString('moneymonk_money_$u');
      final loansRaw = prefs.getString('moneymonk_loans_$u');
      if (moneyRaw != null && moneyRaw.isNotEmpty) {
        try {
          counts[u] = (jsonDecode(moneyRaw) as List).length;
        } catch (_) {}
      }
      if (loansRaw != null && loansRaw.isNotEmpty) {
        try {
          loanCounts[u] = (jsonDecode(loansRaw) as List).length;
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _allUsers = usersMap.keys.toList();
        _userEntryCounts = counts;
        _userLoanCounts = loanCounts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUsers = _allUsers.where((u) => u != widget.currentUsername).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.manage_accounts_outlined, color: moneyMonkNavy, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Account & Users',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Active Account Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: moneyMonkNavyLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: moneyMonkNavy.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: moneyMonkNavy,
                    child: Text(
                      widget.currentUsername.isNotEmpty ? widget.currentUsername[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.currentUsername,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: moneyMonkIncome.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Active Account',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: moneyMonkIncome),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.moneyEntriesCount} money entries • ${widget.loansCount} loans',
                          style: const TextStyle(fontSize: 12, color: moneyMonkSecondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Switch User Section
            const Text(
              'Switch User Account:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (otherUsers.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: moneyMonkBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: moneyMonkBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: moneyMonkSecondaryText),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No other user accounts registered on this device yet.',
                        style: TextStyle(fontSize: 12, color: moneyMonkSecondaryText),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...otherUsers.map((user) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: moneyMonkBorder),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: moneyMonkNavyLight,
                        child: Text(
                          user[0].toUpperCase(),
                          style: const TextStyle(color: moneyMonkNavy, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(user, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${_userEntryCounts[user] ?? 0} money entries • ${_userLoanCounts[user] ?? 0} loans',
                        style: const TextStyle(fontSize: 11, color: moneyMonkSecondaryText),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => widget.onSwitchUser(user),
                        child: const Text('Switch'),
                      ),
                    ),
                  )),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: moneyMonkIncome, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Permanent Device Storage: All income, expenses, and loans are permanently preserved on this device. Your data is automatically backed up and protected across sessions.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 6),

            ListTile(
              leading: const Icon(Icons.logout, color: moneyMonkError),
              title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, color: moneyMonkError)),
              subtitle: const Text('Safely log out of this account', style: TextStyle(fontSize: 11)),
              onTap: widget.onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupSheet extends StatefulWidget {
  const _BackupSheet({
    required this.username,
    required this.moneyEntries,
    required this.loanEntries,
    required this.onImport,
    required this.onScanRecover,
    required this.onLoadTemplate,
  });

  final String username;
  final List<MoneyEntry> moneyEntries;
  final List<LoanEntry> loanEntries;
  final Future<void> Function(List<MoneyEntry>, List<LoanEntry>) onImport;
  final Future<void> Function() onScanRecover;
  final Future<void> Function() onLoadTemplate;

  @override
  State<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> {
  bool _isScanning = false;

  void _exportJson() {
    final data = {
      'moneymonk_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'username': widget.username,
      'money': widget.moneyEntries.map((e) => e.toJson()).toList(),
      'loans': widget.loanEntries.map((e) => e.toJson()).toList(),
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: jsonString));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${widget.moneyEntries.length} money entries & ${widget.loanEntries.length} loans to clipboard as JSON!'),
        backgroundColor: moneyMonkIncome,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    String? importError;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Import Backup JSON'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Paste your exported MoneyMonk JSON backup text below:',
                    style: TextStyle(fontSize: 13, color: moneyMonkSecondaryText),
                  ),
                  const SizedBox(height: 12),
                  if (importError != null) ...[
                    Text(importError!, style: const TextStyle(color: moneyMonkError, fontSize: 12)),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: controller,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '{\n  "money": [...],\n  "loans": [...]\n}',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final raw = jsonDecode(controller.text.trim());
                      if (raw is! Map) {
                        setDialogState(() => importError = 'Invalid JSON format.');
                        return;
                      }
                      final moneyList = <MoneyEntry>[];
                      final loansList = <LoanEntry>[];

                      if (raw['money'] is List) {
                        for (final item in raw['money']) {
                          if (item is Map<String, dynamic>) {
                            moneyList.add(MoneyEntry.fromJson(item));
                          } else if (item is Map) {
                            moneyList.add(MoneyEntry.fromJson(Map<String, dynamic>.from(item)));
                          }
                        }
                      }
                      if (raw['loans'] is List) {
                        for (final item in raw['loans']) {
                          if (item is Map<String, dynamic>) {
                            loansList.add(LoanEntry.fromJson(item));
                          } else if (item is Map) {
                            loansList.add(LoanEntry.fromJson(Map<String, dynamic>.from(item)));
                          }
                        }
                      }
                      if (moneyList.isEmpty && loansList.isEmpty) {
                        setDialogState(() => importError = 'No valid entries found in the JSON.');
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      await widget.onImport(moneyList, loansList);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Successfully imported ${moneyList.length} money entries and ${loansList.length} loans!'),
                            backgroundColor: moneyMonkIncome,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => importError = 'Failed to parse JSON: $e');
                    }
                  },
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: moneyMonkNavy, size: 26),
                    SizedBox(width: 8),
                    Text(
                      'Data Backup & Recovery',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: moneyMonkIncome, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All your entries are permanently saved on this device. Currently preserving ${widget.moneyEntries.length} money items & ${widget.loanEntries.length} loans.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.copy_all_outlined, color: moneyMonkNavy),
                    title: const Text('Export Backup (Copy JSON)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Copy full financial data to clipboard to save anywhere', style: TextStyle(fontSize: 12)),
                    onTap: _exportJson,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined, color: moneyMonkNavy),
                    title: const Text('Restore from Backup (Paste JSON)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Import entries from a previously saved JSON string', style: TextStyle(fontSize: 12)),
                    onTap: _showImportDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.search_outlined, color: moneyMonkNavy),
                    title: const Text('Deep Scan & Recover Device Data', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Scan this browser storage for any older or hidden sessions', style: TextStyle(fontSize: 12)),
                    trailing: _isScanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isScanning = true);
                      await widget.onScanRecover();
                      if (!mounted) return;
                      setState(() => _isScanning = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Deep scan complete: ${widget.moneyEntries.length} entries & ${widget.loanEntries.length} loans active.'),
                          backgroundColor: moneyMonkIncome,
                        ),
                      );
                    },
                  ),
                  if (widget.moneyEntries.isEmpty && widget.loanEntries.isEmpty) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.auto_stories_outlined, color: moneyMonkIncome),
                      title: const Text('Load Sample Financial Template', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Start with typical salary, rent, utilities, and a car loan', style: TextStyle(fontSize: 12)),
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        await widget.onLoadTemplate();
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Loaded sample template with salary, rent, utilities, and car loan!'),
                            backgroundColor: moneyMonkIncome,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AiTier {
  free,
  paid,
}

enum AiPowerMode {
  turbo,
  deepAudit,
}

class HomeSummaryScreen extends StatelessWidget {
  const HomeSummaryScreen({
    super.key,
    required this.username,
    required this.moneyEntries,
    required this.loanEntries,
    required this.selectedMonth,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.onMoneyTap,
    required this.onLoansTap,
  });

  final String username;
  final List<MoneyEntry> moneyEntries;
  final List<LoanEntry> loanEntries;
  final DateTime selectedMonth;
  final int monthlyIncome;
  final int monthlyExpense;
  final VoidCallback onMoneyTap;
  final VoidCallback onLoansTap;

  @override
  Widget build(BuildContext context) {
    final activeLoansInMonth = loanEntries.where((loan) => loan.isActiveInMonth(selectedMonth)).toList();
    final loanEmiInMonth = activeLoansInMonth.fold<int>(0, (sum, loan) => sum + loan.getEmiForMonth(selectedMonth));
    final totalOutflow = monthlyExpense + loanEmiInMonth;
    final balance = monthlyIncome - totalOutflow;
    final outstandingInMonth = loanEntries.fold<int>(0, (sum, loan) => sum + loan.getRemainingPrincipalForMonth(selectedMonth));
    final highestRateLoan = activeLoansInMonth.isEmpty
        ? (loanEntries.isEmpty ? null : loanEntries.reduce((a, b) => a.interestRatePerAnnum >= b.interestRatePerAnnum ? a : b))
        : activeLoansInMonth.reduce((a, b) => a.interestRatePerAnnum >= b.interestRatePerAnnum ? a : b);

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const Text('Home', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText)),
        const SizedBox(height: 6),
        Text(DateFormat('MMMM yyyy').format(selectedMonth), style: const TextStyle(color: moneyMonkSecondaryText)),
        const SizedBox(height: 20),
        InkWell(
          onTap: onMoneyTap,
          borderRadius: BorderRadius.circular(18),
          child: Card(
            color: moneyMonkNavy,
            child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Monthly balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(_formatCurrency(balance), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
            ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SummaryTile(label: 'Income', value: _formatCurrency(monthlyIncome), color: moneyMonkIncome, onTap: onMoneyTap)),
          const SizedBox(width: 12),
          Expanded(child: _SummaryTile(
            label: 'Expense',
            value: _formatCurrency(totalOutflow),
            color: moneyMonkExpense,
            onTap: onMoneyTap,
          )),
        ]),
        const SizedBox(height: 18),
        // Financial Health Scorecard
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics_outlined, color: moneyMonkNavy, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Financial Health Scorecard',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: balance >= 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        balance >= 0 ? 'Cashflow Surplus' : 'Cashflow Deficit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: balance >= 0 ? moneyMonkIncome : moneyMonkExpense,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: moneyMonkBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: moneyMonkBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Savings Rate', style: TextStyle(fontSize: 11, color: moneyMonkSecondaryText)),
                            const SizedBox(height: 4),
                            Text(
                              monthlyIncome > 0 ? '${((balance / monthlyIncome) * 100).toStringAsFixed(1)}%' : '0.0%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: (monthlyIncome > 0 && (balance / monthlyIncome) >= 0.2)
                                    ? moneyMonkIncome
                                    : ((monthlyIncome > 0 && (balance / monthlyIncome) >= 0.1) ? moneyMonkWarning : moneyMonkExpense),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (monthlyIncome > 0 && (balance / monthlyIncome) >= 0.2)
                                  ? 'Strong (≥20%)'
                                  : ((monthlyIncome > 0 && (balance / monthlyIncome) >= 0.1) ? 'Moderate (10-20%)' : 'Needs attention (<10%)'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: moneyMonkBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: moneyMonkBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Debt-to-Income', style: TextStyle(fontSize: 11, color: moneyMonkSecondaryText)),
                            const SizedBox(height: 4),
                            Text(
                              monthlyIncome > 0 ? '${((loanEmiInMonth / monthlyIncome) * 100).toStringAsFixed(1)}%' : '0.0%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: (monthlyIncome == 0 || (loanEmiInMonth / monthlyIncome) <= 0.35)
                                    ? moneyMonkIncome
                                    : ((loanEmiInMonth / monthlyIncome) <= 0.5 ? moneyMonkWarning : moneyMonkExpense),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (monthlyIncome == 0 || (loanEmiInMonth / monthlyIncome) <= 0.35)
                                  ? 'Healthy (≤35%)'
                                  : ((loanEmiInMonth / monthlyIncome) <= 0.5 ? 'Caution (35-50%)' : 'High Risk (>50%)'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Loans at a glance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: moneyMonkPrimaryText)),
        const SizedBox(height: 10),
        InkWell(
          onTap: onLoansTap,
          borderRadius: BorderRadius.circular(18),
          child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _SummaryLine('Active loans (${DateFormat('MMM yy').format(selectedMonth)})', '${activeLoansInMonth.length}'),
          _SummaryLine('Projected Outstanding', _formatCurrency(outstandingInMonth)),
          _SummaryLine('Monthly EMIs due', _formatCurrency(loanEmiInMonth)),
          if (highestRateLoan != null) _SummaryLine('Highest ROI', '${highestRateLoan.name} (${highestRateLoan.interestRatePerAnnum.toStringAsFixed(2)}%)'),
          ]))),
        ),
        const SizedBox(height: 14),
        Text('${moneyEntries.length} money entries saved', style: const TextStyle(color: moneyMonkSecondaryText)),
        const SizedBox(height: 20),
        _MoneyMonkAdvisor(
          username: username,
          moneyEntries: moneyEntries,
          loanEntries: loanEntries,
          monthlyIncome: monthlyIncome,
          monthlyExpense: totalOutflow,
        ),
      ]),
    );
  }

  static String _formatCurrency(int paise) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: paise % 100 == 0 ? 0 : 2).format(paise / 100);
}

class _MoneyMonkAdvisor extends StatefulWidget {
  const _MoneyMonkAdvisor({
    required this.username,
    required this.moneyEntries,
    required this.loanEntries,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });

  final String username;
  final List<MoneyEntry> moneyEntries;
  final List<LoanEntry> loanEntries;
  final int monthlyIncome;
  final int monthlyExpense;

  @override
  State<_MoneyMonkAdvisor> createState() => _MoneyMonkAdvisorState();
}

class _MoneyMonkAdvisorState extends State<_MoneyMonkAdvisor> {
  final _questionController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _googleEmailController = TextEditingController();
  
  AiTier _tier = AiTier.free;
  AiPowerMode _powerMode = AiPowerMode.turbo;
  String _savedApiKey = '';
  String _savedGoogleAccount = '';
  String _answer = 'Ask about your savings rate, debt payoff strategy, or budget breakdown.';
  bool _isAskingGemini = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final tierStr = prefs.getString('moneymonk_ai_tier_${widget.username}') ?? 'free';
    final powerStr = prefs.getString('moneymonk_ai_power_${widget.username}') ?? 'turbo';
    final key = prefs.getString('moneymonk_gemini_key_${widget.username}') ?? '';
    final googleAcc = prefs.getString('moneymonk_google_account_${widget.username}') ?? '';
    
    if (mounted) {
      setState(() {
        _tier = tierStr == 'paid' ? AiTier.paid : AiTier.free;
        _powerMode = powerStr == 'deepAudit' ? AiPowerMode.deepAudit : AiPowerMode.turbo;
        _savedApiKey = key;
        _savedGoogleAccount = googleAcc;
        _apiKeyController.text = key;
        _googleEmailController.text = googleAcc;
      });
    }
  }

  Future<void> _savePowerMode(AiPowerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moneymonk_ai_power_${widget.username}', mode == AiPowerMode.deepAudit ? 'deepAudit' : 'turbo');
  }

  Future<void> _savePreferences({required AiTier tier, required String apiKey, required String googleAccount}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moneymonk_ai_tier_${widget.username}', tier == AiTier.paid ? 'paid' : 'free');
    await prefs.setString('moneymonk_gemini_key_${widget.username}', apiKey.trim());
    await prefs.setString('moneymonk_google_account_${widget.username}', googleAccount.trim());

    if (mounted) {
      setState(() {
        _tier = tier;
        _savedApiKey = apiKey.trim();
        _savedGoogleAccount = googleAccount.trim();
      });
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _apiKeyController.dispose();
    _googleEmailController.dispose();
    super.dispose();
  }

  Future<void> _askGemini({String? predefinedPrompt}) async {
    final effectiveQuestion = predefinedPrompt ?? _questionController.text.trim();
    if (effectiveQuestion.isEmpty) {
      setState(() => _answer = 'Please enter or select a question first.');
      return;
    }

    final effectiveKey = _tier == AiTier.free
        ? (_savedApiKey.isNotEmpty ? _savedApiKey : defaultFreeGeminiApiKey)
        : _savedApiKey;

    if (effectiveKey.isEmpty) {
      _showAiSettingsDialog(
        context,
        initialMessage: _tier == AiTier.free
            ? 'Please enter your free Google Gemini API Key to use AI insights.'
            : 'Please enter your paid Google Cloud / Gemini API key to activate dedicated tier.',
      );
      return;
    }

    setState(() {
      _isAskingGemini = true;
      _answer = _powerMode == AiPowerMode.turbo
          ? '⚡ Turbo AI analyzing your finances in real-time (~1s)...'
          : '🧠 Deep Audit AI running institutional financial analysis...';
    });

    final balance = widget.monthlyIncome - widget.monthlyExpense;
    final savingsRate = widget.monthlyIncome > 0 ? ((balance / widget.monthlyIncome) * 100).toStringAsFixed(1) : '0';
    final totalMonthlyEmi = widget.loanEntries.fold<int>(0, (sum, l) => sum + l.emiInPaise + l.extraEmiInPaise);
    final totalOutstanding = widget.loanEntries.fold<int>(0, (sum, l) => sum + l.outstandingAmountInPaise);
    final dti = widget.monthlyIncome > 0 ? ((totalMonthlyEmi / widget.monthlyIncome) * 100).toStringAsFixed(1) : '0';

    final moneyBreakdown = widget.moneyEntries.map((e) => 
      '- ${e.type == MoneyEntryType.income ? "Income" : "Expense"}: ${e.name} (${_formatCurrency(e.amountInPaise)}, ${e.mode == MoneyEntryMode.recurring ? "Recurring" : "One-time"})'
    ).join('\n');

    final loanBreakdown = widget.loanEntries.map((l) => 
      '- ${l.name}: Outstanding ${_formatCurrency(l.outstandingAmountInPaise)}, EMI ${_formatCurrency(l.emiInPaise)}${l.extraEmiInPaise > 0 ? " + Extra EMI ${_formatCurrency(l.extraEmiInPaise)}" : ""}, Interest ${l.interestRatePerAnnum}% p.a.'
    ).join('\n');

    final systemPrompt = '''You are the MoneyMonk Financial Advisor, powered by Firebase AI & Google Gemini.
You provide clear, friendly, realistic, and highly practical financial advice based strictly on the user's supplied figures.
All amounts are in Indian Rupees (₹).
Operating Mode: ${_powerMode == AiPowerMode.turbo ? "TURBO (Provide ultra-fast, sharp, direct actionable bullet points with zero fluff)" : "DEEP AUDIT (Provide comprehensive multi-step mathematical analysis, debt avalanche roadmap, and 50/30/20 optimization)"}.

Guidelines:
1. Be structured and concise: use clear headings, bullet points, and highlight key numbers.
2. Debt Reduction: Analyze DTI ($dti%) and prioritize high-interest loans (debt avalanche method) while maintaining emergency reserves.
3. Suggest practical ways to trim listed expenses or allocate monthly surplus (${_formatCurrency(balance)}).
4. If asked about budgeting, use realistic frameworks like the 50/30/20 rule adjusted for their loans.
5. Provide honest, encouraging observations without making misleading investment guarantees.

User Financial Summary:
- Monthly Income: ${_formatCurrency(widget.monthlyIncome)}
- Monthly Expenses: ${_formatCurrency(widget.monthlyExpense)}
- Monthly Net Cash Flow (Surplus/Deficit): ${_formatCurrency(balance)} (Savings Rate: $savingsRate%)
- Total Monthly Debt Outflow (EMI): ${_formatCurrency(totalMonthlyEmi)} (Debt-to-Income DTI: $dti%)
- Total Outstanding Debt: ${_formatCurrency(totalOutstanding)} across ${widget.loanEntries.length} loans

Money Entries Breakdown:
${moneyBreakdown.isEmpty ? "No individual entries recorded yet." : moneyBreakdown}

Active Loans Breakdown:
${loanBreakdown.isEmpty ? "No active loans." : loanBreakdown}

User Query: $effectiveQuestion''';

    try {
      http.Response? response;
      final modelsToTry = _powerMode == AiPowerMode.turbo
          ? ['gemini-flash-lite-latest', 'gemini-3.1-flash-lite', 'gemini-3.6-flash']
          : ['gemini-3.6-flash', 'gemini-flash-lite-latest'];

      for (final model in modelsToTry) {
        response = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$effectiveKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': systemPrompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': _powerMode == AiPowerMode.turbo ? 0.2 : 0.4,
              'maxOutputTokens': _powerMode == AiPowerMode.turbo ? 1024 : 2048,
            },
          }),
        );
        if (response.statusCode == 200) {
          break;
        }
      }

      final body = jsonDecode(response?.body ?? '{}') as Map<String, dynamic>;
      
      if (response != null && response.statusCode == 200) {
        final candidates = body['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts.first['text'] as String?;
            if (text != null && text.isNotEmpty) {
              setState(() => _answer = text.trim());
              return;
            }
          }
        }
        setState(() => _answer = 'Received empty response from Gemini. Please try again.');
      } else if (response?.statusCode == 429) {
        setState(() => _answer = '⚠️ Free Tier Rate limit reached (15 requests/min or 1,500/day). Please wait a moment or switch to Paid Tier in AI Settings.');
      } else if (response?.statusCode == 400 || response?.statusCode == 403) {
        final errorMessage = body['error']?['message'] ?? 'Invalid API key or unauthorized request.';
        setState(() => _answer = '⚠️ API Key Error: $errorMessage\nPlease check your key in AI Settings.');
      } else {
        setState(() => _answer = 'Gemini returned status ${response?.statusCode ?? "unknown"}. Please check your connection or API key.');
      }
    } catch (e) {
      setState(() => _answer = 'Connection error: Could not reach Gemini. Please verify your internet connection and API key.');
    } finally {
      if (mounted) setState(() => _isAskingGemini = false);
    }
  }

  void _showAiSettingsDialog(BuildContext context, {String? initialMessage}) {
    var dialogTier = _tier;
    final dialogKeyController = TextEditingController(text: _savedApiKey);
    final dialogGoogleController = TextEditingController(text: _savedGoogleAccount);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: moneyMonkNavy),
                            SizedBox(width: 8),
                            Text('AI Advisor Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    if (initialMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: moneyMonkNavyLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: moneyMonkNavy, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(initialMessage, style: const TextStyle(fontSize: 13, color: moneyMonkNavy, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text('Select AI Service Tier:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 10),
                    
                    // Free Tier Option Card
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setModalState(() => dialogTier = AiTier.free),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: dialogTier == AiTier.free ? moneyMonkNavyLight : moneyMonkSurface,
                          border: Border.all(
                            color: dialogTier == AiTier.free ? moneyMonkNavy : moneyMonkBorder,
                            width: dialogTier == AiTier.free ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              dialogTier == AiTier.free ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: moneyMonkNavy,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text('Free Tier (Firebase AI / Gemini)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      Chip(
                                        label: Text('100% Free', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: moneyMonkIncome)),
                                        backgroundColor: Color(0xFFDCFCE7),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '15 Requests/Min • 1,500 Requests/Day • Gemini Flash\nZero billing required. 100% Free forever for personal financial insights.',
                                    style: TextStyle(fontSize: 12, color: moneyMonkSecondaryText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Paid / Google Account Option Card
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setModalState(() => dialogTier = AiTier.paid),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: dialogTier == AiTier.paid ? moneyMonkNavyLight : moneyMonkSurface,
                          border: Border.all(
                            color: dialogTier == AiTier.paid ? moneyMonkNavy : moneyMonkBorder,
                            width: dialogTier == AiTier.paid ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              dialogTier == AiTier.paid ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: moneyMonkNavy,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text('Paid / Google Cloud Tier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      Chip(
                                        label: Text('Dedicated', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: moneyMonkNavy)),
                                        backgroundColor: Color(0xFFE0E7FF),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Enterprise Quotas • Strict Data Privacy • Vertex AI / Google Cloud\nBring your own billing-enabled Google API key or connect Google Account.',
                                    style: TextStyle(fontSize: 12, color: moneyMonkSecondaryText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Google Account / Sign-in Section (For Paid / Cloud Users)
                    if (dialogTier == AiTier.paid) ...[
                      const Text('Google Account / Organization (Optional):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: dialogGoogleController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. yourname@gmail.com or GCP Project',
                          prefixIcon: Icon(Icons.account_circle_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // API Key Field
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dialogTier == AiTier.free ? 'Google AI Studio / Firebase AI Key:' : 'Google Cloud / Gemini API Key:',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (dialogKeyController.text.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                dialogKeyController.clear();
                              });
                            },
                            child: const Text('Clear', style: TextStyle(color: moneyMonkError, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: dialogKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'AIzaSy...',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Instructions helper
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: moneyMonkBackground,
                        border: Border.all(color: moneyMonkBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('💡 How to get your free key in 30 seconds:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: moneyMonkPrimaryText)),
                          SizedBox(height: 4),
                          Text('1. Visit Google AI Studio at aistudio.google.com\n2. Click "Get API key" -> "Create API key"\n3. Paste it above and click Save Settings.', style: TextStyle(fontSize: 11, color: moneyMonkSecondaryText, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Save AI Settings'),
                        onPressed: () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          await _savePreferences(
                            tier: dialogTier,
                            apiKey: dialogKeyController.text,
                            googleAccount: dialogGoogleController.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('AI Advisor settings updated successfully!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveKey = _tier == AiTier.free
        ? (_savedApiKey.isNotEmpty || defaultFreeGeminiApiKey.isNotEmpty)
        : _savedApiKey.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: moneyMonkNavy, size: 22),
                    SizedBox(width: 8),
                    Text('Firebase AI Financial Advisor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                InkWell(
                  onTap: () => _showAiSettingsDialog(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _tier == AiTier.free ? const Color(0xFFDCFCE7) : const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _tier == AiTier.free ? moneyMonkIncome : moneyMonkNavy,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _tier == AiTier.free ? 'Free Tier' : 'Paid Tier',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _tier == AiTier.free ? moneyMonkIncome : moneyMonkNavy,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.settings_outlined, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _tier == AiTier.free 
                  ? 'Powered by Firebase AI & Gemini Flash (100% Free • 1,500 req/day • Zero Billing)'
                  : 'Powered by Gemini Dedicated Cloud Tier (Private & High Quota)',
              style: const TextStyle(fontSize: 12, color: moneyMonkSecondaryText),
            ),
            const SizedBox(height: 10),

            // Read-Only Advisor Notice (User Awareness)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: moneyMonkNavyLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: moneyMonkNavy.withValues(alpha: 0.15)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: moneyMonkNavy),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Analysis & Strategy Only: MoneyMonk AI analyzes your income, expenses, and loans to generate recommendations. It does not add, modify, or delete your financial data.',
                      style: TextStyle(
                        fontSize: 12,
                        color: moneyMonkNavy,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // AI Analysis Power Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: moneyMonkBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moneyMonkBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _powerMode = AiPowerMode.turbo);
                        _savePowerMode(AiPowerMode.turbo);
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                        decoration: BoxDecoration(
                          color: _powerMode == AiPowerMode.turbo ? moneyMonkSurface : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _powerMode == AiPowerMode.turbo
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, size: 16, color: _powerMode == AiPowerMode.turbo ? moneyMonkWarning : moneyMonkSecondaryText),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Turbo Power (1s Instant)',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _powerMode == AiPowerMode.turbo ? moneyMonkPrimaryText : moneyMonkSecondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _powerMode = AiPowerMode.deepAudit);
                        _savePowerMode(AiPowerMode.deepAudit);
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                        decoration: BoxDecoration(
                          color: _powerMode == AiPowerMode.deepAudit ? moneyMonkSurface : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _powerMode == AiPowerMode.deepAudit
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.psychology, size: 16, color: _powerMode == AiPowerMode.deepAudit ? moneyMonkNavy : moneyMonkSecondaryText),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Deep Reasoning Audit',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _powerMode == AiPowerMode.deepAudit ? moneyMonkPrimaryText : moneyMonkSecondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _powerMode == AiPowerMode.turbo
                  ? '⚡ 1-Second Instant Response: Optimized for fast, crisp financial recommendations.'
                  : '🧠 Deep Multi-Step Reasoning: Full mathematical audit, debt avalanche timeline & 50/30/20 optimization.',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: moneyMonkSecondaryText),
            ),
            const SizedBox(height: 14),

            // Quick Question Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.health_and_safety_outlined, size: 16),
                    label: const Text('Financial Health Audit', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _questionController.text = 'Analyze my monthly financial health and give me key recommendations.';
                      _askGemini(predefinedPrompt: _questionController.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.trending_down_outlined, size: 16),
                    label: const Text('Debt Payoff Plan', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _questionController.text = 'What is the fastest strategy to pay off my loans (avalanche vs snowball)?';
                      _askGemini(predefinedPrompt: _questionController.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.savings_outlined, size: 16),
                    label: const Text('Reduce Expenses', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _questionController.text = 'Where are my highest expenses and how can I save more this month?';
                      _askGemini(predefinedPrompt: _questionController.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.pie_chart_outline, size: 16),
                    label: const Text('50/30/20 Budget', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _questionController.text = 'Break down my current monthly income into a recommended 50/30/20 budget.';
                      _askGemini(predefinedPrompt: _questionController.text);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Question Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ask financial advice, debt tips, or budget rules...',
                    ),
                    onSubmitted: (_) => _askGemini(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _isAskingGemini 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  tooltip: 'Ask Gemini',
                  onPressed: _isAskingGemini ? null : () => _askGemini(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // AI Status & Settings Shortcut
            if (!hasActiveKey) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_outlined, color: moneyMonkWarning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tier == AiTier.free
                            ? 'Set your free Google Gemini API key to activate AI insights.'
                            : 'Enter your dedicated Google Cloud / Gemini key to use Paid Tier.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: moneyMonkPrimaryText),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAiSettingsDialog(context),
                      child: const Text('Setup Key', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Response Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: moneyMonkBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moneyMonkBorder),
              ),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _renderFormattedResponse(_answer),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _renderFormattedResponse(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (line.startsWith('#')) {
        final headerText = line.replaceFirst(RegExp(r'^#+\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              headerText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: moneyMonkNavy,
              ),
            ),
          ),
        );
        continue;
      }

      final isBullet = line.startsWith('- ') || line.startsWith('* ');
      final cleanLine = isBullet ? line.substring(2).trim() : line;

      final spans = <TextSpan>[];
      final parts = cleanLine.split('**');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        final isBold = i % 2 == 1;
        spans.add(
          TextSpan(
            text: parts[i],
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: moneyMonkPrimaryText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        );
      }

      if (isBullet) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: moneyMonkNavy)),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: spans),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(children: spans),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  static String _formatCurrency(int paise) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(paise / 100);
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.color, required this.onTap});
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: moneyMonkSecondaryText)), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color))]))));
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: moneyMonkSecondaryText)), Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)))]));
}

class MoneyScreen extends StatelessWidget {
  const MoneyScreen({
    super.key,
    required this.entries,
    required this.loanEntries,
    required this.selectedMonth,
    required this.isMonthlyView,
    this.showAllTransactions = false,
    required this.onMonthChanged,
    required this.onViewChanged,
    this.onToggleAllTransactions,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    this.onToggleSkip,
    required this.getMoneyTotal,
    required this.getMoneyTotalForYear,
    required this.getLoanEmiTotal,
    required this.getLoanEmiTotalForYear,
    required this.generateForecast,
  });

  final List<MoneyEntry> entries;
  final List<LoanEntry> loanEntries;
  final DateTime selectedMonth;
  final bool isMonthlyView;
  final bool showAllTransactions;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<bool> onViewChanged;
  final ValueChanged<bool>? onToggleAllTransactions;
  final VoidCallback onAddPressed;
  final ValueChanged<MoneyEntry> onEditPressed;
  final ValueChanged<MoneyEntry> onDeletePressed;
  final void Function(MoneyEntry, Map<DateTime, int>)? onToggleSkip;
  final int Function(MoneyEntryType, {DateTime? forMonth}) getMoneyTotal;
  final int Function(MoneyEntryType) getMoneyTotalForYear;
  final int Function({DateTime? forMonth}) getLoanEmiTotal;
  final int Function({DateTime? forYear}) getLoanEmiTotalForYear;
  final List<FinancialForecastRow> Function() generateForecast;

  @override
  Widget build(BuildContext context) {
    final incomeEntries = entries
        .where((e) => e.type == MoneyEntryType.income && e.appliesToMonth(selectedMonth))
        .toList();
    final expenseEntries = entries
        .where((e) => e.type == MoneyEntryType.expense && e.appliesToMonth(selectedMonth))
        .toList();
    final activeLoanEntries = loanEntries
        .where((e) => e.isActiveInMonth(selectedMonth))
        .toList();

    final totalIncome = isMonthlyView
        ? getMoneyTotal(MoneyEntryType.income)
        : getMoneyTotalForYear(MoneyEntryType.income);
    final directExpense = isMonthlyView
        ? getMoneyTotal(MoneyEntryType.expense)
        : getMoneyTotalForYear(MoneyEntryType.expense);
    final loanExpense = isMonthlyView
        ? getLoanEmiTotal(forMonth: selectedMonth)
        : getLoanEmiTotalForYear(forYear: selectedMonth);
    final totalExpense = directExpense + loanExpense;
    final balance = totalIncome - totalExpense;

    final allTimeIncome = entries
        .where((e) => e.type == MoneyEntryType.income)
        .fold<int>(0, (sum, e) => sum + e.amountInPaise);
    final allTimeExpense = entries
        .where((e) => e.type == MoneyEntryType.expense)
        .fold<int>(0, (sum, e) => sum + e.amountInPaise);
    final allTimeBalance = allTimeIncome - allTimeExpense;

    final allSortedEntries = List<MoneyEntry>.from(entries)
      ..sort((a, b) => b.date.compareTo(a.date));

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
                  // Filter Chips & Date Selector
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 8,
                    spacing: 12,
                    children: [
                      if (!showAllTransactions)
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'All Records',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: moneyMonkPrimaryText),
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilterChip(
                            label: const Text('Monthly'),
                            selected: isMonthlyView && !showAllTransactions,
                            onSelected: (_) {
                              onToggleAllTransactions?.call(false);
                              onViewChanged(true);
                            },
                            selectedColor: moneyMonkNavyLight,
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Yearly'),
                            selected: !isMonthlyView && !showAllTransactions,
                            onSelected: (_) {
                              onToggleAllTransactions?.call(false);
                              onViewChanged(false);
                            },
                            selectedColor: moneyMonkNavyLight,
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('All'),
                            selected: showAllTransactions,
                            onSelected: (_) {
                              onToggleAllTransactions?.call(true);
                            },
                            selectedColor: moneyMonkNavyLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (showAllTransactions) ...[
                    // All Transactions Summary Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('All-Time Income', style: TextStyle(fontWeight: FontWeight.w600, color: moneyMonkSecondaryText)),
                                Text(_formatCurrency(allTimeIncome), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: moneyMonkIncome)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('All-Time Expenses', style: TextStyle(fontWeight: FontWeight.w600, color: moneyMonkSecondaryText)),
                                Text(_formatCurrency(allTimeExpense), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: moneyMonkExpense)),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cumulative Balance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                Text(
                                  _formatCurrency(allTimeBalance),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: allTimeBalance >= 0 ? moneyMonkIncome : moneyMonkExpense,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('${allSortedEntries.length} total transactions recorded:', style: const TextStyle(fontWeight: FontWeight.w700, color: moneyMonkPrimaryText)),
                    const SizedBox(height: 10),
                    if (allSortedEntries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: moneyMonkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: moneyMonkBorder),
                        ),
                        child: const Center(
                          child: Text(
                            'No transactions recorded yet.\nTap "+ Add" below to create your first entry!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: moneyMonkSecondaryText),
                          ),
                        ),
                      )
                    else
                      ...allSortedEntries.map((entry) {
                        final isIncome = entry.type == MoneyEntryType.income;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: moneyMonkBorder),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              child: Icon(
                                isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                                color: isIncome ? moneyMonkIncome : moneyMonkExpense,
                                size: 18,
                              ),
                            ),
                            title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${DateFormat('dd MMM yyyy').format(entry.date)} • ${entry.mode == MoneyEntryMode.recurring ? "Recurring (${entry.frequency?.name ?? 'monthly'})" : "One-time"}',
                              style: const TextStyle(fontSize: 12, color: moneyMonkSecondaryText),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatCurrency(entry.amountInPaise),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isIncome ? moneyMonkIncome : moneyMonkExpense,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit',
                                  onPressed: () => onEditPressed(entry),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: moneyMonkError),
                                  tooltip: 'Delete',
                                  onPressed: () => onDeletePressed(entry),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ] else ...[
                    if (incomeEntries.isEmpty && expenseEntries.isEmpty && entries.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: moneyMonkNavyLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: moneyMonkNavy.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: moneyMonkNavy),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You have ${entries.length} ${entries.length == 1 ? "entry" : "entries"} saved in other dates. Tap "All" above to see all records.',
                                style: const TextStyle(fontSize: 12, color: moneyMonkNavy, fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(
                              onPressed: () => onToggleAllTransactions?.call(true),
                              child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    // Money table
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, tableConstraints) {
                                final income = _MoneyColumn(
                                  label: 'Income',
                                  entries: incomeEntries,
                                  selectedMonth: selectedMonth,
                                  accent: moneyMonkIncome,
                                  tint: const Color(0xFFF2FBF4),
                                  onEdit: onEditPressed,
                                  onDelete: onDeletePressed,
                                  onToggleSkip: onToggleSkip,
                                );
                                final expense = _MoneyColumn(
                                  label: 'Expense',
                                  entries: expenseEntries,
                                  selectedMonth: selectedMonth,
                                  accent: moneyMonkExpense,
                                  tint: const Color(0xFFFEF0EA),
                                  onEdit: onEditPressed,
                                  onDelete: onDeletePressed,
                                  onToggleSkip: onToggleSkip,
                                );
                                if (tableConstraints.maxWidth < 620) {
                                  return Column(children: [income, const SizedBox(height: 18), expense]);
                                }
                                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(child: income), const SizedBox(width: 12), Expanded(child: expense),
                                ]);
                              },
                            ),
                            if (isMonthlyView && activeLoanEntries.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFEDD5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.account_balance, size: 16, color: moneyMonkExpense),
                                            SizedBox(width: 6),
                                            Text(
                                              'Active Loan EMIs (Auto-recurring)',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: moneyMonkExpense),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _formatCurrency(loanExpense),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: moneyMonkExpense),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...activeLoanEntries.map((loan) {
                                      final emi = loan.getEmiForMonth(selectedMonth);
                                      final remainingBal = loan.getRemainingPrincipalForMonth(selectedMonth);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(loan.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: moneyMonkPrimaryText)),
                                                  Text(
                                                    'Bal: ${_formatCurrency(remainingBal)} • ${loan.getRemainingMonthsAsOf(selectedMonth)} mos left',
                                                    style: const TextStyle(fontSize: 11, color: moneyMonkSecondaryText),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFFED7AA)),
                                              ),
                                              child: Text(
                                                _formatCurrency(emi),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: moneyMonkExpense),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
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
                            if (loanExpense > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Direct Expenses', style: TextStyle(fontSize: 13, color: moneyMonkSecondaryText)),
                                  Text(_formatCurrency(directExpense), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Loan EMIs (Recurring)', style: TextStyle(fontSize: 13, color: moneyMonkSecondaryText)),
                                  Text(_formatCurrency(loanExpense), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText)),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Outflow / Expense',
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
                  ],

                  const SizedBox(height: 24),
                  Semantics(
                    label: 'Add money',
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('money-add-button'),
                        onPressed: onAddPressed,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
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
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Income', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Direct Expenses', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Loan EMIs', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Total Outflow', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Net Balance', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: generateForecast()
                                .map((row) => DataRow(
                              cells: [
                                DataCell(Text(DateFormat('MMM yyyy').format(row.month))),
                                DataCell(Text(
                                  _formatCurrency(row.income),
                                  style: const TextStyle(color: moneyMonkIncome, fontWeight: FontWeight.w600),
                                )),
                                DataCell(Text(_formatCurrency(row.directExpense))),
                                DataCell(Text(_formatCurrency(row.loanEmi))),
                                DataCell(Text(
                                  _formatCurrency(row.totalOutflow),
                                  style: const TextStyle(color: moneyMonkExpense, fontWeight: FontWeight.w600),
                                )),
                                DataCell(Text(
                                  _formatCurrency(row.balance),
                                  style: TextStyle(
                                    color: row.balance >= 0 ? moneyMonkIncome : moneyMonkExpense,
                                    fontWeight: FontWeight.w700,
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
    required this.selectedMonth,
    required this.accent,
    required this.tint,
    required this.onEdit,
    required this.onDelete,
    this.onToggleSkip,
  });

  final String label;
  final List<MoneyEntry> entries;
  final DateTime selectedMonth;
  final Color accent;
  final Color tint;
  final ValueChanged<MoneyEntry> onEdit;
  final ValueChanged<MoneyEntry> onDelete;
  final void Function(MoneyEntry, Map<DateTime, int>)? onToggleSkip;

  @override
  Widget build(BuildContext context) {
    final columnTotal = entries.fold(0, (sum, entry) {
      if (entry.type == MoneyEntryType.expense && entry.isLoanCovered) {
        return sum; // P1: Exclude covered-by-loan from direct cash outflow
      }
      return sum + entry.getAmountForMonth(selectedMonth);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accent)),
            Text(_formatCurrency(columnTotal), style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
          ],
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Text('No ${label.toLowerCase()} entries', style: const TextStyle(fontSize: 13, color: moneyMonkMuted))
        else
          ...entries.map((entry) {
            final monthKey = DateTime(selectedMonth.year, selectedMonth.month);
            final isSkipped = entry.isSkippedInMonth(selectedMonth);
            final isOverridden = entry.isOverriddenInMonth(selectedMonth);
            final isRecurring = entry.mode == MoneyEntryMode.recurring;
            final amountForMonth = entry.getAmountForMonth(selectedMonth);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              entry.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: isSkipped ? TextDecoration.lineThrough : null,
                                color: isSkipped ? moneyMonkMuted : moneyMonkPrimaryText,
                              ),
                            ),
                            if (isRecurring)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOverridden ? 'Recurring (Custom)' : 'Recurring',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: accent),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: moneyMonkSecondaryText.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'One-time',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: moneyMonkSecondaryText),
                                ),
                              ),
                            if (isSkipped)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFD1D5DB)),
                                ),
                                child: const Text(
                                  'Skipped this month',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: moneyMonkSecondaryText),
                                ),
                              ),
                            if (entry.isLoanCovered)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: moneyMonkNavyLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: moneyMonkNavy.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'Covered by Loan',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: moneyMonkNavy),
                                ),
                              ),
                          ],
                        ),
                        if (isOverridden && !isSkipped)
                          Text(
                            'Base: ${_formatCurrency(entry.amountInPaise)}',
                            style: const TextStyle(fontSize: 10, color: moneyMonkSecondaryText),
                          ),
                        if (entry.endDate != null)
                          Text(
                            'Ends ${DateFormat('MMM yyyy').format(entry.endDate!)}',
                            style: const TextStyle(fontSize: 10, color: moneyMonkSecondaryText),
                          ),
                      ],
                    ),
                  ),
                  if (isSkipped)
                    Row(
                      children: [
                        const Text('₹0', style: TextStyle(fontWeight: FontWeight.w700, color: moneyMonkMuted)),
                        const SizedBox(width: 4),
                        Text(
                          _formatCurrency(entry.amountInPaise),
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            fontSize: 11,
                            color: moneyMonkMuted,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(_formatCurrency(amountForMonth), style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') {
                        onEdit(entry);
                      } else if (val == 'delete') {
                        onDelete(entry);
                      } else if (val == 'skip') {
                        final newOverrides = Map<DateTime, int>.from(entry.overrides);
                        newOverrides[monthKey] = 0;
                        onToggleSkip?.call(entry, newOverrides);
                      } else if (val == 'unskip') {
                        final newOverrides = Map<DateTime, int>.from(entry.overrides);
                        newOverrides.remove(monthKey);
                        onToggleSkip?.call(entry, newOverrides);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (isRecurring)
                        PopupMenuItem(
                          value: isSkipped ? 'unskip' : 'skip',
                          child: Text(isSkipped ? 'Unskip this month' : 'Skip this month'),
                        ),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: moneyMonkError))),
                    ],
                  ),
                ],
              ),
            );
          }),
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
    this.selectedMonth,
    this.onMonthChanged,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    this.onPrepayment,
  });

  final List<LoanEntry> entries;
  final DateTime? selectedMonth;
  final ValueChanged<DateTime>? onMonthChanged;
  final VoidCallback onAddPressed;
  final ValueChanged<LoanEntry> onEditPressed;
  final ValueChanged<LoanEntry> onDeletePressed;
  final void Function(LoanEntry, int)? onPrepayment;

  @override
  Widget build(BuildContext context) {
    final activeMonth = selectedMonth ?? DateTime.now();

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
                const SizedBox(height: 12),
                // Month Selector for Dynamic Loan Amortization Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (onMonthChanged != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => onMonthChanged!(DateTime(
                              activeMonth.year,
                              activeMonth.month - 1,
                            )),
                            icon: const Icon(Icons.chevron_left),
                            iconSize: 22,
                          ),
                          Text(
                            DateFormat('MMMM yyyy').format(activeMonth),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: moneyMonkPrimaryText,
                            ),
                          ),
                          IconButton(
                            onPressed: () => onMonthChanged!(DateTime(
                              activeMonth.year,
                              activeMonth.month + 1,
                            )),
                            icon: const Icon(Icons.chevron_right),
                            iconSize: 22,
                          ),
                        ],
                      )
                    else
                      Text(
                        DateFormat('MMMM yyyy').format(activeMonth),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: moneyMonkPrimaryText,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: moneyMonkNavyLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Dynamic Amortization',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: moneyMonkNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                    selectedMonth: activeMonth,
                    onEdit: () => onEditPressed(loan),
                    onDelete: () => onDeletePressed(loan),
                    onPrepayment: onPrepayment,
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
                      label: const Text('Add Loan'),
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
    this.selectedMonth,
    required this.onEdit,
    required this.onDelete,
    this.onPrepayment,
  });

  final LoanEntry loan;
  final DateTime? selectedMonth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(LoanEntry, int)? onPrepayment;

  @override
  Widget build(BuildContext context) {
    final amortization = loan.calculateAmortization();
    final viewMonth = selectedMonth ?? DateTime.now();
    final monthKey = DateTime(viewMonth.year, viewMonth.month);
    final monthPrepayment = loan.extraPayments[monthKey] ?? 0;
    final remainingPrincipalInMonth = loan.getRemainingPrincipalForMonth(viewMonth);
    final remainingMonthsInMonth = loan.getRemainingMonthsAsOf(viewMonth);
    final isPaidOff = loan.isPaidOffAsOf(viewMonth);
    final emiDueInMonth = loan.getEmiForMonth(viewMonth);

    void showPrepaymentDialog() {
      final ctrl = TextEditingController(
        text: monthPrepayment > 0 ? (monthPrepayment / 100).toString() : '',
      );
      showDialog<void>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          title: Text('Prepayment for ${DateFormat('MMM yyyy').format(viewMonth)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter one-time extra prepayment toward loan principal for this specific month:',
                style: TextStyle(fontSize: 13, color: moneyMonkSecondaryText),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Prepayment Amount',
                  prefixText: '₹ ',
                  hintText: '50000',
                ),
              ),
            ],
          ),
          actions: [
            if (monthPrepayment > 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  onPrepayment?.call(loan, 0);
                },
                child: const Text('Clear Prepayment', style: TextStyle(color: moneyMonkError)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final val = double.tryParse(ctrl.text.trim()) ?? 0;
                Navigator.pop(dlgCtx);
                onPrepayment?.call(loan, (val * 100).round());
              },
              child: const Text('Save Prepayment'),
            ),
          ],
        ),
      );
    }

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
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') {
                      onEdit();
                    } else if (action == 'delete') {
                      onDelete();
                    } else if (action == 'prepay') {
                      showPrepaymentDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'prepay', child: Text('Add Prepayment for this month')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: moneyMonkError))),
                  ],
                ),
              ],
            ),
            if (monthPrepayment > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Extra Prepayment for ${DateFormat('MMM yy').format(viewMonth)}: ${_formatCurrency(monthPrepayment)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E), fontSize: 12),
                      ),
                    ),
                    InkWell(
                      onTap: () => onPrepayment?.call(loan, 0),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (isPaidOff)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: moneyMonkIncome, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🎉 Projected to be fully paid off by ${DateFormat('MMMM yyyy').format(viewMonth)}!',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: moneyMonkIncome, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
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
                  _LoanInfoBox(
                    'Outstanding (${DateFormat('MMM yy').format(viewMonth)})',
                    _formatCurrency(remainingPrincipalInMonth),
                  ),
                  _LoanInfoBox('Original', loan.prettyOriginal),
                  _LoanInfoBox(
                    'Monthly Payment',
                    isPaidOff
                        ? '₹0 (Paid Off)'
                        : _formatCurrency(emiDueInMonth > 0 ? emiDueInMonth : (loan.emiInPaise + loan.extraEmiInPaise)),
                  ),
                  _LoanInfoBox('Extra EMI', _formatCurrency(loan.extraEmiInPaise)),
                  _LoanInfoBox('Interest Rate', '${loan.interestRatePerAnnum.toStringAsFixed(2)}%'),
                  _LoanInfoBox(
                    'Remaining',
                    isPaidOff ? 'Completed 🎉' : '$remainingMonthsInMonth months',
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
  const AddMoneySheet({super.key, this.initialDate, required this.onSave});

  final DateTime? initialDate;
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
  final List<DateTime?> _endDates = [null];
  final List<bool> _isLoanCoveredList = [false];
  late DateTime _selectedDate;
  late DateTime _selectedRecurringStartDate;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate ?? DateTime.now();
    _selectedDate = d;
    _selectedRecurringStartDate = d;
  }

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
      _endDates.add(null);
      _isLoanCoveredList.add(false);
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
      _endDates.removeAt(index);
      _isLoanCoveredList.removeAt(index);
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
        endDate: _modes[index] == MoneyEntryMode.recurring ? _endDates[index] : null,
        isLoanCovered: _types[index] == MoneyEntryType.expense && _isLoanCoveredList[index],
      ));
    }

    widget.onSave(entries);
    Navigator.of(context).pop();
  }

  Widget _buildEntryRow(int index) {
    final isRecurring = _modes[index] == MoneyEntryMode.recurring;
    final isExpense = _types[index] == MoneyEntryType.expense;

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
            if (isRecurring) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        _endDates[index] == null
                            ? 'No End Date (Continuous)'
                            : 'Ends: ${DateFormat('MMM yyyy').format(_endDates[index]!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDates[index] ?? _selectedRecurringStartDate.add(const Duration(days: 365)),
                          firstDate: _selectedRecurringStartDate,
                          lastDate: DateTime(DateTime.now().year + 20),
                        );
                        if (picked != null) {
                          setState(() => _endDates[index] = picked);
                        }
                      },
                    ),
                  ),
                  if (_endDates[index] != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear End Date',
                      onPressed: () => setState(() => _endDates[index] = null),
                    ),
                ],
              ),
            ],
            if (isExpense)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _isLoanCoveredList[index],
                onChanged: (val) => setState(() => _isLoanCoveredList[index] = val ?? false),
                title: const Text(
                  'Covered by active loan (prevents double-counting with Loan EMI)',
                  style: TextStyle(fontSize: 12, color: moneyMonkSecondaryText),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
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

enum _RecurringScope { thisMonthOnly, fromThisMonthOnward, allMonths }

class _EditMoneySheetState extends State<EditMoneySheet> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late MoneyEntryType _type;
  _RecurringScope _recurringScope = _RecurringScope.thisMonthOnly;
  DateTime? _endDate;
  bool _isLoanCovered = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _amountController = TextEditingController(text: (widget.entry.amountInPaise / 100).toString());
    _type = widget.entry.type;
    _endDate = widget.entry.endDate;
    _isLoanCovered = widget.entry.isLoanCovered;
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
    final effectiveRates = Map<DateTime, int>.from(widget.entry.effectiveRates);
    var baseAmountInPaise = widget.entry.amountInPaise;

    if (widget.entry.mode == MoneyEntryMode.recurring) {
      switch (_recurringScope) {
        case _RecurringScope.thisMonthOnly:
          overrides[monthKey] = amountInPaise;
          break;
        case _RecurringScope.fromThisMonthOnward:
          effectiveRates[monthKey] = amountInPaise;
          overrides.remove(monthKey);
          break;
        case _RecurringScope.allMonths:
          baseAmountInPaise = amountInPaise;
          overrides.remove(monthKey);
          break;
      }
    } else {
      baseAmountInPaise = amountInPaise;
    }

    final updated = MoneyEntry(
      id: widget.entry.id,
      name: _nameController.text.trim(),
      type: _type,
      amountInPaise: baseAmountInPaise,
      mode: widget.entry.mode,
      date: widget.entry.date,
      frequency: widget.entry.frequency,
      endDate: _endDate,
      overrides: overrides,
      effectiveRates: effectiveRates,
      isLoanCovered: _type == MoneyEntryType.expense && _isLoanCovered,
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
              if (widget.entry.mode == MoneyEntryMode.recurring) ...[
                const SizedBox(height: 18),
                const Text(
                  'Apply change to:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: moneyMonkSecondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('This month only (${DateFormat('MMM yy').format(widget.selectedMonth)})'),
                      selected: _recurringScope == _RecurringScope.thisMonthOnly,
                      onSelected: (_) => setState(() => _recurringScope = _RecurringScope.thisMonthOnly),
                      selectedColor: moneyMonkNavyLight,
                      labelStyle: TextStyle(
                        color: _recurringScope == _RecurringScope.thisMonthOnly ? moneyMonkNavy : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('From this month onward'),
                      selected: _recurringScope == _RecurringScope.fromThisMonthOnward,
                      onSelected: (_) => setState(() => _recurringScope = _RecurringScope.fromThisMonthOnward),
                      selectedColor: moneyMonkNavyLight,
                      labelStyle: TextStyle(
                        color: _recurringScope == _RecurringScope.fromThisMonthOnward ? moneyMonkNavy : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('All months'),
                      selected: _recurringScope == _RecurringScope.allMonths,
                      onSelected: (_) => setState(() => _recurringScope = _RecurringScope.allMonths),
                      selectedColor: moneyMonkNavyLight,
                      labelStyle: TextStyle(
                        color: _recurringScope == _RecurringScope.allMonths ? moneyMonkNavy : moneyMonkPrimaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_outlined, size: 16),
                        label: Text(
                          _endDate == null
                              ? 'No End Date (Continuous)'
                              : 'Ends: ${DateFormat('MMM yyyy').format(_endDate!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? widget.selectedMonth.add(const Duration(days: 365)),
                            firstDate: widget.entry.date,
                            lastDate: DateTime(DateTime.now().year + 20),
                          );
                          if (picked != null) {
                            setState(() => _endDate = picked);
                          }
                        },
                      ),
                    ),
                    if (_endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Clear End Date',
                        onPressed: () => setState(() => _endDate = null),
                      ),
                  ],
                ),
              ],
              if (_type == MoneyEntryType.expense) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _isLoanCovered,
                  onChanged: (val) => setState(() => _isLoanCovered = val ?? false),
                  title: const Text(
                    'Covered by active loan (prevents double-counting with Loan EMI)',
                    style: TextStyle(fontSize: 12, color: moneyMonkSecondaryText),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _originalAmountController = TextEditingController();
  final TextEditingController _outstandingAmountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _emiController = TextEditingController();
  final TextEditingController _extraEmiController = TextEditingController();
  final TextEditingController _tenureYearsController = TextEditingController(text: '1');
  final TextEditingController _tenureMonthsController = TextEditingController(text: '0');
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;
  bool _autoValidate = false;

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

  String? _validateAll() {
    if (_nameController.text.trim().isEmpty) {
      return '⚠️ Please enter a Loan Name (e.g. Home Loan, Car Loan).';
    }
    final orig = double.tryParse(_originalAmountController.text.trim());
    if (orig == null || orig <= 0) {
      return '⚠️ Please enter a valid Original Loan Amount (must be > 0).';
    }
    final out = double.tryParse(_outstandingAmountController.text.trim());
    if (out == null || out <= 0) {
      return '⚠️ Please enter a valid Current Outstanding Amount (must be > 0).';
    }
    final rate = double.tryParse(_interestRateController.text.trim());
    if (rate == null || rate < 0) {
      return '⚠️ Please enter a valid Annual Interest Rate % (e.g. 8.5).';
    }
    final emi = double.tryParse(_emiController.text.trim());
    if (emi == null || emi <= 0) {
      return '⚠️ Please enter a valid Monthly EMI Amount (must be > 0).';
    }
    final extra = double.tryParse(_extraEmiController.text.trim());
    if (_extraEmiController.text.trim().isNotEmpty && (extra == null || extra < 0)) {
      return '⚠️ Extra EMI cannot be negative.';
    }
    final years = int.tryParse(_tenureYearsController.text.trim()) ?? 0;
    final months = int.tryParse(_tenureMonthsController.text.trim()) ?? 0;
    if (years <= 0 && months <= 0) {
      return '⚠️ Please enter a valid Tenure Duration (at least 1 month or 1 year).';
    }
    return null;
  }

  void _save() {
    final error = _validateAll();
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _autoValidate = true;
      });
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
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.existingLoan == null ? 'Add Loan' : 'Edit Loan',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: moneyMonkPrimaryText,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Prominent Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      border: Border.all(color: moneyMonkError),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: moneyMonkError, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: moneyMonkError,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Loan Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Loan Name *',
                    hintText: 'Home Loan, Car Loan, Personal Loan',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Loan name is required' : null,
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                ),
                const SizedBox(height: 16),

                // Original Loan Amount
                TextFormField(
                  controller: _originalAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Original Loan Amount *',
                    hintText: '5000000',
                    prefixText: '₹ ',
                    helperText: 'Amount originally sanctioned or borrowed',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Original amount is required';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be a valid amount > 0';
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                ),
                const SizedBox(height: 16),

                // Outstanding Principal
                TextFormField(
                  controller: _outstandingAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Current Outstanding Balance *',
                    hintText: '4000000',
                    prefixText: '₹ ',
                    helperText: 'Principal balance still owed today',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Outstanding balance is required';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be a valid amount > 0';
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                ),
                const SizedBox(height: 16),

                // Interest Rate
                TextFormField(
                  controller: _interestRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Interest Rate (Annual ROI) *',
                    hintText: '8.5',
                    suffixText: '% p.a.',
                    helperText: 'Annual percentage rate (e.g. 8.5 for 8.5%)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Interest rate is required';
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Must be a valid rate >= 0%';
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                ),
                const SizedBox(height: 16),

                // Monthly EMI
                TextFormField(
                  controller: _emiController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monthly EMI *',
                    hintText: '35000',
                    prefixText: '₹ ',
                    helperText: 'Regular monthly EMI deduction',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Monthly EMI is required';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be a valid EMI > 0';
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                ),
                const SizedBox(height: 16),

                // Extra Prepayment EMI (Optional)
                TextFormField(
                  controller: _extraEmiController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Extra Prepayment EMI (Optional)',
                    hintText: '0',
                    prefixText: '₹ ',
                    helperText: 'Optional extra prepayment amount per month toward principal',
                  ),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final n = double.tryParse(v.trim());
                      if (n == null || n < 0) return 'Extra EMI cannot be negative';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tenure Years and Months
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tenureYearsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tenure (Years) *',
                          hintText: '15',
                        ),
                        validator: (v) {
                          final years = int.tryParse(_tenureYearsController.text.trim()) ?? 0;
                          final months = int.tryParse(_tenureMonthsController.text.trim()) ?? 0;
                          if (years <= 0 && months <= 0) return 'Required';
                          return null;
                        },
                        onChanged: (_) {
                          if (_errorMessage != null) setState(() => _errorMessage = null);
                        },
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
                        onChanged: (_) {
                          if (_errorMessage != null) setState(() => _errorMessage = null);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Remaining or total loan duration',
                  style: TextStyle(
                    fontSize: 12,
                    color: moneyMonkSecondaryText,
                  ),
                ),
                const SizedBox(height: 16),

                // Loan Start Date
                InkWell(
                  onTap: () => _pickDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Loan Start Date',
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Save Loan'),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

