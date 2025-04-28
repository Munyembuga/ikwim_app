import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/globalapi.dart';
import '../providers/logged_in_user.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String _errorMessage = '';
  LoggedInUser? _user;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String get errorMessage => _errorMessage;
  LoggedInUser? get user => _user;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final String loginUrl = "${AppConfig.baseUrl}/android_access/login";

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "login-username": email,
          "login-password": password,
        },
      );

      print('Response body: ${response.headers}');
      final data = json.decode(response.body);
      print("fffffffffffffffffffff  $data");
      if (response.statusCode == 200 && data["status"] == "Success") {
        final userJson = data["user"];
        final siteJson = data["site"];
        final companyJson = data["company"];

        LoggedInUser user =
            LoggedInUser.fromJson(userJson, siteJson, companyJson);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('user', jsonEncode(user.toJson()));

        _user = user;
        _isLoggedIn = true;
        _isLoading = false;

        print('===== LOGGED IN USER DATA =====');
        print('User ID: ${user.userId}');
        print('Name: ${user.fName}');
        print('Email: ${user.email}');
        print('Role: ${user.role}');
        print('Role: ${user.phone}');
        print('Site ID: ${user.siteId}');
        print('Site Name: ${user.siteName}');
        print('==============================');

        notifyListeners();
        return true;
      } else {
        _errorMessage = data["message"] ?? "Invalid phone or password";
      }
    } catch (error) {
      print('Login error: $error');
      _errorMessage = "Invalid phone or password";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _user = null;
    notifyListeners();
  }

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (_isLoggedIn) {
      String? userJson = prefs.getString('user');
      if (userJson != null) {
        _user = LoggedInUser.fromJsonStored(json.decode(userJson));
      }
    }
    notifyListeners();
  }

  Future<LoggedInUser?> getUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('user');
    if (userJson != null) {
      return LoggedInUser.fromJsonStored(json.decode(userJson));
    }
    return null;
  }
}
