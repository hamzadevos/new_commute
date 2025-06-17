import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../resources/shared_preference.dart';
import '../validations/login.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  String? _firstName;
  String? _surname;
  String? _email;
  String? _profileImagePath;
  bool _isLoading = true;
  File? _selectedImage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadProfileImagePath();
  }

  Future<void> _fetchUserData() async {
    if (_user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();
        if (doc.exists) {
          setState(() {
            _firstName = doc['firstName'];
            _surname = doc['surname'];
            _email = doc['email'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'User data not found.';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error fetching user data.';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'No user logged in.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    if (path != null && File(path).existsSync()) {
      setState(() {
        _profileImagePath = path;
      });
    }
  }

  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
        try {
          // Save image to app's temporary directory
          final tempDir = await getTemporaryDirectory();
          final fileName = '${_user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final newPath = '${tempDir.path}/$fileName';
          final newFile = await File(pickedFile.path).copy(newPath);

          // Save path to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_image_path', newPath);

          setState(() {
            _selectedImage = newFile;
            _profileImagePath = newPath;
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _errorMessage = 'Error saving image.';
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _errorMessage = 'Gallery permission denied.';
      });
    }
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Logout',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(fontFamily: 'Outfit', color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await FirebaseAuth.instance.signOut();
      await SharedPrefHelper.setLoggedIn(false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Signin()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final fontScale = 0.85; // Consistent with previous screens

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Padding(
        padding: EdgeInsets.all(screenSize.width * 0.04),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.03),
              Text(
                'User Profile',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20 * fontScale,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: screenSize.width * 0.15,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : _profileImagePath != null && File(_profileImagePath!).existsSync()
                          ? FileImage(File(_profileImagePath!))
                          : const AssetImage('assets/sn.png') as ImageProvider,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.redAccent,
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              if (_errorMessage != null)
                Padding(
                  padding: EdgeInsets.only(bottom: screenSize.height * 0.01),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 12 * fontScale),
                  ),
                ),
              ListTile(
                leading: Icon(Icons.person, color: Colors.redAccent, size: 20 * fontScale),
                title: Text(
                  'Name',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14 * fontScale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _firstName != null && _surname != null
                      ? '$_firstName $_surname'
                      : 'Not available',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12 * fontScale,
                    color: Colors.grey,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.email, color: Colors.redAccent, size: 20 * fontScale),
                title: Text(
                  'Email',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14 * fontScale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _email ?? 'Not available',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12 * fontScale,
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              Center(
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.06,
                      vertical: screenSize.height * 0.015,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Logout',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14 * fontScale,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
