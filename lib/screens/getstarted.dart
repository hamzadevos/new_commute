import 'package:new_commute/screens/home.dart';
import 'package:new_commute/screens/mapscreen.dart';
import 'package:new_commute/validations/login.dart';
import 'package:new_commute/validations/signup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../main.dart';

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
        // User cancelled the sign-in
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Navigate to home screen after successful sign-in
      if (userCredential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      }
    } catch (e) {
      print("Google sign-in failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign in with Google'),
        ),
      );
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
            SizedBox(height: 80),
            Text(
              'Let\'s Get Started',
              style: TextStyle(fontSize: 28,
                  fontFamily: 'Outfit',
                  color: Color(0xff022E57), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 60),
            Container(

                child: Image.asset('assets/sn.png',fit: BoxFit.cover, width: double.infinity,),
              ),

            SizedBox(height: 70),
            Padding(
              padding: const EdgeInsets.only(right: 20.0,left: 20),
              child: _buildSocialButton(
                context,
                'Continue With Google',
                'assets/gog.png',
                signInWithGoogle,
              ),

            ),
            SizedBox(height: 15),
            // Padding(
            //   padding: const EdgeInsets.only(right: 20.0,left: 20),
            //   child: _buildSocialButton(
            //     context,
            //     'Continue With Facebook',
            //     'assets/fac.png',
            //         () {},
            //   ),
            // ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(right: 20.0,left: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(context, 'Login', Color(0xffE20000), Signin(),Colors.white ),
                  _buildActionButton(context, 'Sign Up', Color(0xffC4C4C9), SignUp(),Color(0xff022E57)),
                ],
              ),
            ),
            SizedBox(height: 30),
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
            SizedBox(width: 10),
            Text(title, style: TextStyle(color: Color(0xff212121), fontFamily: 'Outfit', fontSize: 20,fontWeight: FontWeight.w600)),
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
              color: textColor, // Now we can control text color
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
