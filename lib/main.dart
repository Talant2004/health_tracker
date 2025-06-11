import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MyApp());

const String _appsScriptUrl = 'https://script.google.com/macros/s/AKfycbzLWaffIHASknqlirMu72mD9y7M3KvCpa0n8e3UyWB_mPL54EQNiDNtemNm7YGkq1J_/exec';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'AI-Трекер Здоровья',
        theme: ThemeData(primarySwatch: Colors.teal, visualDensity: VisualDensity.adaptivePlatformDensity),
        home: RegistrationScreen(),
      ),
    );
  }
}

class AppState with ChangeNotifier {
  String? _userId;
  String? get userId => _userId;

  Future<void> setUser(String? id) async {
    _userId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setString('userId', id);
    } else {
      await prefs.remove('userId');
    }
    notifyListeners();
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    notifyListeners();
  }
}

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '', _goal = '';
  int _age = 0, _weight = 0, _height = 0;
  bool _isLoading = false;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);
      try {
        final uri = Uri.parse(_appsScriptUrl).replace(queryParameters: {
          'action': 'register',
          'name': _name,
          'age': _age.toString(),
          'weight': _weight.toString(),
          'height': _height.toString(),
          'goal': _goal,
        });
        final response = await http.get(uri);
        final result = jsonDecode(response.body);
        setState(() => _isLoading = false);
        if (result['status'] == 'success') {
          Provider.of<AppState>(context, listen: false).setUser(result['userId']);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${result['message']}')));
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сети: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AppState>(context, listen: false).loadUser();
    return Scaffold(
      appBar: AppBar(title: Text('Регистрация')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            children: [
              _inputField('Имя', onSaved: (v) => _name = v!),
              _inputField('Возраст', number: true, onSaved: (v) => _age = int.parse(v!)),
              _inputField('Вес (кг)', number: true, onSaved: (v) => _weight = int.parse(v!)),
              _inputField('Рост (см)', number: true, onSaved: (v) => _height = int.parse(v!)),
              _inputField('Цель', onSaved: (v) => _goal = v!),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _isLoading ? null : _register, child: Text('Зарегистрироваться')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, {bool number = false, FormFieldSetter<String>? onSaved}) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Введите $label';
        if (number) {
          final num = int.tryParse(v);
          if (num == null) return 'Введите число';
          if (label == 'Возраст' && (num < 1 || num > 120)) return 'Возраст: 1–120';
          if (label == 'Вес (кг)' && (num < 20 || num > 300)) return 'Вес: 20–300 кг';
          if (label == 'Рост (см)' && (num < 50 || num > 250)) return 'Рост: 50–250 см';
        }
        return null;
      },
      onSaved: onSaved,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>(); // Исправлено: добавлены ()
  int _calories = 0, _steps = 0, _sleep = 0;
  String _mood = '';
  bool _isLoading = false;

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final userId = Provider.of<AppState>(context, listen: false).userId;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Пользователь не зарегистрирован')));
        return;
      }
      setState(() => _isLoading = true);
      try {
        final uri = Uri.parse(_appsScriptUrl).replace(queryParameters: {
          'action': 'saveDailyData',
          'userId': userId,
          'calories': _calories.toString(),
          'steps': _steps.toString(),
          'sleep': _sleep.toString(),
          'mood': _mood,
        });
        final response = await http.get(uri);
        final result = jsonDecode(response.body);
        setState(() => _isLoading = false);
        if (result['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Данные сохранены')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${result['message']}')));
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сети: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Мой день'),
        actions: [
          IconButton(
            icon: Icon(Icons.lightbulb_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdviceScreen())),
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            children: [
              _inputField('Калории', onSaved: (v) => _calories = int.parse(v!)),
              _inputField('Шаги', onSaved: (v) => _steps = int.parse(v!)),
              _inputField('Сон (часы)', onSaved: (v) => _sleep = int.parse(v!)),
              _inputField('Настроение', number: false, onSaved: (v) => _mood = v!),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _isLoading ? null : _saveData, child: Text('Сохранить')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, {bool number = true, FormFieldSetter<String>? onSaved}) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Введите $label';
        if (number) {
          final num = int.tryParse(v);
          if (num == null) return 'Введите число';
          if (label == 'Калории' && num < 0) return 'Калории ≥ 0';
          if (label == 'Шаги' && num < 0) return 'Шаги ≥ 0';
          if (label == 'Сон (часы)' && (num < 0 || num > 24)) return 'Сон: 0–24 ч';
        }
        return null;
      },
      onSaved: onSaved,
    );
  }
}

class AdviceScreen extends StatefulWidget {
  @override
  _AdviceScreenState createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  String _advice = 'Загрузка...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(_appsScriptUrl).replace(queryParameters: {'action': 'getAdvice'});
      final response = await http.get(uri);
      final result = jsonDecode(response.body);
      setState(() {
        _advice = result['advice'] ?? 'Совет не найден';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _advice = 'Ошибка загрузки';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Совет дня')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_advice, style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _loadAdvice,
                child: Text(_isLoading ? 'Загрузка...' : 'Новый совет'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}