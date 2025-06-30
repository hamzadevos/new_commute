import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../resources/shared_preference.dart';
import 'forgot_password.dart';
import 'signup.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
        _isLoading = false;
      });
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text)) {
      setState(() {
        _errorMessage = 'Please enter a valid email';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Ensure user data exists in Firestore
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'firstName': user.displayName?.split(' ').first ?? 'User',
            'surname': user.displayName?.split(' ').last ?? '',
            'email': user.email ?? _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await SharedPrefHelper.setLoggedIn(true);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = {
          'user-not-found': 'No user found with this email.',
          'wrong-password': 'Incorrect password. Please try again.',
          'invalid-email': 'Invalid email address.',
        }[e.code] ?? 'An error occurred. Please try again.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double containerWidth = screenSize.width * 0.85;
    final double textFieldHeight = 45;
    final double buttonHeight = 53;
    final double fontScale = 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenSize.height * 0.12),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: -1,
              child: Container(
                width: screenSize.width,
                height: screenSize.height * 0.12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Positioned(
              top: screenSize.height * 0.06,
              left: screenSize.width * 0.05,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xff022E57)),
                onPressed: () => Navigator.pop(context),
                iconSize: 22,
              ),
            ),
            Positioned(
              top: screenSize.height * 0.065,
              left: screenSize.width * 0.15,
              child: Text(
                'Login',
                style: TextStyle(
                  color: const Color(0xff022E57),
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 20 * fontScale,
                ),
              ),
            ),
            Positioned(
              top: screenSize.height * 0.04,
              right: screenSize.width * 0.05,
              child: Image.asset(
                'assets/sn.png',
                width: 160,
                height: 62,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            width: containerWidth,
            padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.015),
            child: Column(
              children: [
                Text(
                  'Login to continue!',
                  style: TextStyle(
                    fontSize: 24 * fontScale,
                    fontFamily: 'Outfit',
                    color: const Color(0xff022E57),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: screenSize.height * 0.04),
                SizedBox(
                  width: containerWidth,
                  height: textFieldHeight,
                  child: TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: Colors.black, fontSize: 14 * fontScale),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Image.asset('assets/email.png', height: 20, width: 20),
                      ),
                      hintText: 'Email',
                      hintStyle: TextStyle(
                        fontFamily: 'Outfit',
                        color: const Color(0xFFBCBCBC),
                        fontSize: 14 * fontScale,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(width: 1, color: Color(0xFFBCBCBC)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenSize.height * 0.03),
                SizedBox(
                  width: containerWidth,
                  height: textFieldHeight,
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(fontSize: 14 * fontScale),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Image.asset('assets/pass.png', height: 20, width: 20),
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: IconButton(
                          icon: Image.asset(
                            _obscurePassword ? 'assets/seepass.png' : 'assets/pass.png',
                            height: 20,
                            width: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      hintText: 'Password',
                      hintStyle: TextStyle(
                        fontFamily: 'Outfit',
                        color: const Color(0xFFBCBCBC),
                        fontSize: 14 * fontScale,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(width: 1, color: Color(0xFFBCBCBC)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenSize.height * 0.02),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14 * fontScale,
                      fontFamily: 'Outfit',
                      color: const Color(0xFFBCBCBC),
                    ),
                    children: [
                      const TextSpan(text: ""),
                      TextSpan(
                        text: "Forgot Password",
                        style: TextStyle(
                          fontSize: 16 * fontScale,
                          fontFamily: 'Outfit',
                          color: const Color(0xffE20000),
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenSize.height * 0.02),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: const Color(0xffE20000), fontSize: 12 * fontScale),
                    ),
                  ),
                GestureDetector(
                  onTap: _isLoading ? null : _handleSignIn,
                  child: Container(
                    width: containerWidth,
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xffE20000),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Outfit',
                              fontSize: 18 * fontScale,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: screenSize.width * 0.04),
                            child: Image.asset('assets/arrow.png', height: 25, width: 25),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: screenSize.height * 0.02),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16 * fontScale,
                      fontFamily: 'Outfit',
                      color: const Color(0xFFBCBCBC),
                    ),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: "Sign Up",
                        style: TextStyle(
                          fontSize: 17 * fontScale,
                          fontFamily: 'Outfit',
                          color: const Color(0xffE20000),
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignUp()),
                            );
                          },
                      ),
                    ],
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