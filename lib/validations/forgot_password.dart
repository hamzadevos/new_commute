import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? errorMessage;
  bool isLoading = false;
  bool showMessage = false;

  void _sendResetEmail() async {
    String rawEmail = _emailController.text.trim();
    String email = rawEmail.toLowerCase();
    print("📩 Raw email input: '$rawEmail', normalized: '$email'");

    if (email.isEmpty) {
      setState(() => errorMessage = "Please enter your email.");
      print("⚠️ Email field empty");
      return;
    }

    if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(email)) {
      setState(() => errorMessage = "Please enter a valid email.");
      print("⚠️ Invalid email format: '$email'");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Check Firebase Auth
      print("🔍 Checking Firebase Auth for '$email'");
      try {
        List<String> methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          print("✅ Found user in Firebase Auth: methods=$methods");
          print("📧 Sending reset email to '$email'");
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          print("✅ Reset email sent successfully");
          _showSuccess();
          return;
        }
        print("⚠️ No user in Firebase Auth for '$email'.");
      } catch (e) {
        print("⚠️ Auth check failed: $e");
      }

      // Check Firestore
      print("🔍 Querying Firestore for '$email'");
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print("🔍 Fallback: Querying Firestore for raw '$rawEmail'");
        query = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: rawEmail)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        var doc = query.docs.first;
        print("✅ Found user in Firestore: id=${doc.id}, data=${doc.data()}");
        print("📧 Sending reset email to '$email'");
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        print("✅ Reset email sent successfully");
        _showSuccess();
        return;
      } else {
        print("⚠️ No user found in Firestore for '$email' or '$rawEmail'");
        setState(() {
          errorMessage = "This email isn't registered.";
          isLoading = false;
        });
      }
    } catch (e) {
      print("⚠️ Error during reset process: $e");
      if (e.toString().contains('permission-denied')) {
        print("⚠️ Firestore rules blocking access! Check Firebase Console rules.");
      }
      setState(() {
        errorMessage = "Failed to send reset link. Try again.";
        isLoading = false;
      });
    }
  }

  void _showSuccess() {
    setState(() => showMessage = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => showMessage = false);
        print("⏳ Navigating back to previous screen");
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
                'Reset Password',
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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Center(
              child: Container(
                width: containerWidth,
                padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.015),
                child: Column(
                  children: [
                    Text(
                      'Reset your password!',
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
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
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
                    SizedBox(height: screenSize.height * 0.02),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: Color(0xffE20000), fontSize: 12 * fontScale),
                        ),
                      ),
                    GestureDetector(
                      onTap: isLoading ? null : _sendResetEmail,
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
                              child: isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                'Send Reset Link',
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
                  ],
                ),
              ),
            ),
          ),
          if (showMessage)
            Center(
              child: AnimatedOpacity(
                opacity: showMessage ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: AnimatedScale(
                  scale: showMessage ? 1.0 : 0.8,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white70,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Reset Link Sent!",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}