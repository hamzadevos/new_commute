import 'package:new_commute/screens/getstarted.dart';
import 'package:new_commute/screens/home.dart';
import 'package:new_commute/screens/logo.dart';
import 'package:new_commute/screens/mapscreen.dart';
import 'package:new_commute/screens/profile_screen.dart';
import 'package:new_commute/services/travelmode.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_options.dart';
import '../services/app_location.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await rootBundle.loadString('assets/stations.json');
  await rootBundle.loadString('assets/locations.json');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commute Pro',
      theme: ThemeData(
        primarySwatch: Colors.red,
        fontFamily: 'Outfit',
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LogoScreen();
        }
        if (snapshot.hasData) {
          // Show LogoScreen for 2 seconds before MainScreen
          return FutureBuilder(
            future: Future.delayed(const Duration(seconds: 2)),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const LogoScreen();
              }
              return const MainScreen();
            },
          );
        }
        return const Starting();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _showTravelOptions = true;
  final GlobalKey<MapScreenState> _mapScreenKey = GlobalKey<MapScreenState>();

  static const List<Widget> _screens = <Widget>[
    SizedBox.shrink(),
    HomeScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _showTravelOptions = index == 0;
      debugPrint('Navigated to tab: $index');
    });
  }

  void _onGetMeSomewhereTapped() {
    _mapScreenKey.currentState?.showSearchBarWidget();
  }

  void _toggleTravelOptions() {
    setState(() {
      _showTravelOptions = !_showTravelOptions;
    });
  }

  void _updateRoute(Set<Polyline> polylines, Set<Marker> markers, LatLngBounds? bounds) {
    _mapScreenKey.currentState?.updateRoute(polylines, markers, bounds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapScreen(key: _mapScreenKey),
          if (_selectedIndex != 0) _screens[_selectedIndex],
          if (_showTravelOptions)
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TravelModeWidget(
                    onGetMeSomewhereTapped: _onGetMeSomewhereTapped,
                    onToggleVisibility: _toggleTravelOptions,
                    onSeeAllRoutesTapped: () {
                      debugPrint('See All Routes tapped');
                      _mapScreenKey.currentState?.showNearestStationRoutes();
                    },
                    mapController: _mapScreenKey.currentState?.mapController,
                    isNavigating: _mapScreenKey.currentState?.isNavigating ?? false,
                    onUpdateRoute: _updateRoute,
                    pickupLocation: _mapScreenKey.currentState?.pickupLocation,
                    locations: _mapScreenKey.currentState?.locations ?? [],
                    googleApiKey: 'YOUR_API_KEY', // Replace with valid key
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.location_city_rounded),
                label: 'Nearby',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.redAccent,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
          ),
        ),
      ),
    );
  }
}