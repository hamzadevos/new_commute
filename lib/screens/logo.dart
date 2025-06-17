import 'package:flutter/material.dart';
import '../main.dart';
import '../resources/shared_preference.dart';
import '../validations/login.dart';
import 'getstarted.dart';


class LogoScreen extends StatefulWidget {
  const LogoScreen({super.key});

  @override
  _LogoScreenState createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    bool isLoggedIn = await SharedPrefHelper.isLoggedIn();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => isLoggedIn ? const MainScreen() : const Starting(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffE20000),
      body: Center(
        child: Image.asset(
          'assets/logo.png',
          height: 200,
          width: 200,
        ),
      ),
    );
  }
}