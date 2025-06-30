import 'package:flutter/material.dart';
import 'package:new_commute/resources/shared_preference.dart';
import 'package:new_commute/screens/getstarted.dart';
import 'package:new_commute/screens/splash.dart';

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
    if (mounted) {
      bool isIntroSeen = await SharedPrefHelper.isIntroSeen();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => isIntroSeen ? const Starting() : const SplashScreen(),
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