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
  String? _profileImagePath; // Local image path
  String? _googlePhotoUrl; // Google profile photo URL
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadProfileImagePath();
  }

  Future<void> _fetchUserData() async {
    if (_user == null) {
      setState(() {
        _errorMessage = 'No user logged in.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Fetch Google photo URL from FirebaseAuth
      final googlePhotoUrl = _user!.photoURL;

      // Fetch Firestore data
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _firstName = doc['firstName'] as String?;
          _surname = doc['surname'] as String?;
          _email = doc['email'] as String? ?? _user!.email;
          _profileImagePath = doc['profileImagePath'] as String?;
          _googlePhotoUrl = googlePhotoUrl;
          _firstNameController.text = _firstName ?? '';
          _surnameController.text = _surname ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _email = _user!.email;
          _googlePhotoUrl = googlePhotoUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [ERROR] Fetch user data failed: $e');
      setState(() {
        _email = _user!.email;
        _googlePhotoUrl = _user!.photoURL;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path_${_user?.uid}');
    if (path != null && await File(path).exists() && mounted) {
      setState(() {
        _profileImagePath = path;
      });
    }
  }

  Future<void> _pickAndSaveImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      setState(() {
        _errorMessage = 'Gallery permission denied.';
      });
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null || !mounted) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      // Get persistent storage directory
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${appDir.path}/profile_images');
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      // Delete old image if it exists
      if (_profileImagePath != null && await File(_profileImagePath!).exists()) {
        await File(_profileImagePath!).delete();
      }

      // Save new image
      final fileName = '${_user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '${profileDir.path}/$fileName';
      final newFile = await File(pickedFile.path).copy(newPath);

      // Save path to SharedPreferences and Firestore
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path_${_user!.uid}', newPath);
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'profileImagePath': newPath,
      });

      if (mounted) {
        setState(() {
          _profileImagePath = newPath;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error saving image: $e';
          _isUploading = false;
        });
        debugPrint('❌ [ERROR] Image save failed: $e');
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    if (_firstNameController.text.isEmpty || _surnameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'firstName': _firstNameController.text.trim(),
        'surname': _surnameController.text.trim(),
      });

      if (mounted) {
        setState(() {
          _firstName = _firstNameController.text.trim();
          _surname = _surnameController.text.trim();
          _isEditing = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error updating profile: $e';
          _isLoading = false;
        });
        debugPrint('❌ [ERROR] Profile update failed: $e');
      }
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
      // Delete local profile image on logout
      if (_profileImagePath != null && await File(_profileImagePath!).exists()) {
        await File(_profileImagePath!).delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image_path_${_user!.uid}');

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
    final fontScale = 0.85;

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
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.redAccent)
                          : ClipOval(
                        child: _googlePhotoUrl != null
                            ? Image.network(
                          _googlePhotoUrl!,
                          width: screenSize.width * 0.3,
                          height: screenSize.width * 0.3,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const CircularProgressIndicator(
                                color: Colors.redAccent);
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackImage(screenSize),
                        )
                            : _buildFallbackImage(screenSize),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickAndSaveImage,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.redAccent,
                          child: const Icon(
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
                leading: const Icon(Icons.person, color: Colors.redAccent, size: 20),
                title: _isEditing
                    ? TextFormField(
                  controller: _firstNameController,
                  style: TextStyle(fontSize: 14 * fontScale),
                  decoration: InputDecoration(
                    hintText: 'First Name',
                    hintStyle: TextStyle(fontSize: 12 * fontScale, color: Colors.grey),
                    border: const OutlineInputBorder(),
                  ),
                )
                    : Text(
                  'First Name',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14 * fontScale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: _isEditing
                    ? null
                    : Text(
                  _firstName ?? 'Not available',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12 * fontScale,
                    color: Colors.grey,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.redAccent, size: 20),
                title: _isEditing
                    ? TextFormField(
                  controller: _surnameController,
                  style: TextStyle(fontSize: 14 * fontScale),
                  decoration: InputDecoration(
                    hintText: 'Surname',
                    hintStyle: TextStyle(fontSize: 12 * fontScale, color: Colors.grey),
                    border: const OutlineInputBorder(),
                  ),
                )
                    : Text(
                  'Surname',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14 * fontScale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: _isEditing
                    ? null
                    : Text(
                  _surname ?? 'Not available',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12 * fontScale,
                    color: Colors.grey,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.email, color: Colors.redAccent, size: 20),
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
                  onPressed: _isEditing ? _saveProfileChanges : () => setState(() => _isEditing = true),
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
                    _isEditing ? 'Save' : 'Edit Profile',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14 * fontScale,
                    ),
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

  Widget _buildFallbackImage(Size screenSize) {
    return _profileImagePath != null && File(_profileImagePath!).existsSync()
        ? Image.file(
      File(_profileImagePath!),
      width: screenSize.width * 0.3,
      height: screenSize.width * 0.3,
      fit: BoxFit.cover,
    )
        : Image.asset(
      'assets/sn.png',
      width: screenSize.width * 0.3,
      height: screenSize.width * 0.3,
      fit: BoxFit.cover,
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }
}