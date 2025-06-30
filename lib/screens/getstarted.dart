import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../validations/login.dart';
import '../validations/signup.dart';
import '../resources/shared_preference.dart';

class Starting extends StatefulWidget {
  const Starting({super.key});

  @override
  _StartState createState() => _StartState();
}

class _StartState extends State<Starting> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        debugPrint('ℹ️ [INFO] Google sign-in cancelled');
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null && mounted) {
        // Save user data to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'firstName': googleUser.displayName?.split(' ').first ?? 'User',
          'surname': googleUser.displayName?.split(' ').last ?? '',
          'email': googleUser.email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await SharedPrefHelper.setLoggedIn(true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
        debugPrint('✅ [INFO] Google sign-in successful: ${user.email}');
      }
    } catch (e) {
      debugPrint('❌ [ERROR] Google sign-in failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign in with Google')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 80),
            const Text(
              'Let\'s Get Started',
              style: TextStyle(
                fontSize: 28,
                fontFamily: 'Outfit',
                color: Color(0xff022E57),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),
            Image.asset(
              'assets/sn.png',
              fit: BoxFit.cover,
              width: double.infinity,
            ),
            const SizedBox(height: 70),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSocialButton(
                context,
                'Continue With Google',
                'assets/gog.png',
                signInWithGoogle,
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(context, 'Login', const Color(0xffE20000), const Signin(), Colors.white),
                  _buildActionButton(context, 'Sign Up', const Color(0xffC4C4C9), const SignUp(), const Color(0xff022E57)),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context, String title, String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 65,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 24),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xff212121),
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String title, Color color, Widget navigateTo, Color textColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => navigateTo));
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.42,
        height: 65,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}