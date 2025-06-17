import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../resources/navigation_manager.dart';
import '../resources/shared_preference.dart';
import '../services/location_service.dart';
import '../validations/login.dart';
import 'profile_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? selectedIndex;
  final NavigationHelper _navigationHelper = NavigationHelper();
  final LocationService _locationService = LocationService();
  final User? _user = FirebaseAuth.instance.currentUser;
  String? _firstName;
  String? _profileImagePath;
  bool _isLoading = true;
  String? _errorMessage;

  final List<Map<String, String>> items = [
    {'icon': 'assets/icons/bank.svg', 'label': 'Bank'},
    {'icon': 'assets/icons/parking.svg', 'label': 'Car Park'},
    {'icon': 'assets/icons/hospital.svg', 'label': 'Hospital'},
    {'icon': 'assets/icons/rstarant.svg', 'label': 'Restaurant'},
    {'icon': 'assets/icons/power.svg', 'label': 'Power Unit'},
    {'icon': 'assets/icons/oil.svg', 'label': 'Oil Station'},
  ];

  @override
  void initState() {
    super.initState();
    _verifyAssets();
    _fetchUserData();
    _loadProfileImagePath();
  }

  Future<void> _verifyAssets() async {
    for (var item in items) {
      try {
        final exists = await _checkAssetExists(item['icon']!);
        debugPrint('${item['icon']} exists: $exists');
      } catch (e) {
        debugPrint('Error checking ${item['icon']}: $e');
      }
    }
  }

  Future<bool> _checkAssetExists(String path) async {
    try {
      await DefaultAssetBundle.of(context).loadString(path);
      return true;
    } catch (_) {
      return false;
    }
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

  Widget _buildSvgIcon(String path, bool isSelected) {
    return FutureBuilder<bool>(
      future: _checkAssetExists(path),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return SvgPicture.asset(
            path,
            width: 25,
            height: 25,
            colorFilter: ColorFilter.mode(
              isSelected ? Colors.white : const Color(0xFFC4C4C9),
              BlendMode.srcIn,
            ),
            placeholderBuilder: (context) => const CircularProgressIndicator(),
          );
        } else {
          return Icon(
            Icons.error_outline,
            size: 70,
            color: isSelected ? Colors.white : const Color(0xffE20000),
          );
        }
      },
    );
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      selectedIndex = index;
    });

    final category = items[index]['label']!;
    final LatLng? currentLocation = await _locationService.getCurrentLocation(context);
    final LatLng location = currentLocation ?? const LatLng(31.5216, 74.4036);

    await _navigationHelper.launchGoogleMapsPoiQuery(
      context,
      location,
      category.toLowerCase(),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        selectedIndex = null;
      });
    });
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
    final fontScale = 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenSize.height * 0.1),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Padding(
            padding: EdgeInsets.only(top: screenSize.height * 0.04),
            child: _isLoading
                ? const CircularProgressIndicator(color: Color(0xffE20000))
                : Text(
              _firstName ?? 'User',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18 * fontScale,
                fontWeight: FontWeight.w400,
                color: const Color(0xff022E57),
              ),
            ),
          ),
          centerTitle: true,
          leading: Padding(
            padding: EdgeInsets.only(top: screenSize.height * 0.04),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundImage: _profileImagePath != null && File(_profileImagePath!).existsSync()
                    ? FileImage(File(_profileImagePath!))
                    : const AssetImage('assets/sm.png') as ImageProvider,
                onBackgroundImageError: (_, __) => const Icon(Icons.person),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(top: screenSize.height * 0.03),
              child: IconButton(
                icon: Icon(
                  Icons.logout,
                  color: const Color(0xffE20000),
                  size: 20 * fontScale,
                ),
                onPressed: _logout,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: screenSize.height * 0.03),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.08),
              child: Text(
                'Find Nearby',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 24 * fontScale,
                  color: const Color(0xffE20000),
                ),
              ),
            ),
          ),
          SizedBox(height: screenSize.height * 0.015),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(screenSize.width * 0.08),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                bool isSelected = selectedIndex == index;
                return GestureDetector(
                  onTap: () => _onItemTapped(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xffE20000) : const Color(0xffF9F9F9),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSvgIcon(items[index]['icon']!, isSelected),
                        SizedBox(height: screenSize.height * 0.01),
                        Text(
                          items[index]['label']!,
                          style: TextStyle(
                            fontSize: 10 * fontScale,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w200,
                            color: isSelected ? Colors.white : const Color(0xff6D6D72),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}