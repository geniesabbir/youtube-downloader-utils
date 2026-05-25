import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auto_rule.dart';

class RulesService {
  static final RulesService _instance = RulesService._internal();
  factory RulesService() => _instance;
  RulesService._internal();

  static const String _rulesPrefsKey = 'library_auto_download_rules';

  final List<AutoRule> _rules = [];
  final StreamController<List<AutoRule>> _rulesController = StreamController<List<AutoRule>>.broadcast();

  Stream<List<AutoRule>> get rulesStream => _rulesController.stream;
  List<AutoRule> get rules => List.unmodifiable(_rules);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rulesPrefsKey);
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        _rules.clear();
        _rules.addAll(decoded.map((e) => AutoRule.fromJson(e)));
      } catch (_) {}
    }
    _rulesController.add(_rules);
  }

  Future<void> _persistRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_rules.map((e) => e.toJson()).toList());
    await prefs.setString(_rulesPrefsKey, raw);
    _rulesController.add(_rules);
  }

  Future<void> addRule(AutoRule rule) async {
    _rules.add(rule);
    await _persistRules();
  }

  Future<void> updateRule(AutoRule rule) async {
    final index = _rules.indexWhere((r) => r.ruleId == rule.ruleId);
    if (index != -1) {
      _rules[index] = rule;
      await _persistRules();
    }
  }

  Future<void> deleteRule(String ruleId) async {
    _rules.removeWhere((r) => r.ruleId == ruleId);
    await _persistRules();
  }
}
