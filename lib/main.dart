import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/connection_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/report_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const BlackBoxCompanionApp());
  } catch (e, stackTrace) {
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red[900],
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Initialization Error:\n$e\n\n$stackTrace',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BlackBoxCompanionApp extends StatelessWidget {
  const BlackBoxCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlackBox Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080C14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF111827),
          onSurface: Colors.white,
        ),
        cardColor: const Color(0xFF151D2E),
        dividerColor: Colors.white10,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1E293B),
          contentTextStyle: GoogleFonts.inter(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/dashboard':
            page = const DashboardScreen();
            break;
          case '/report':
            final args = settings.arguments;
            String reportId = '';
            bool fromDashboard = false;
            if (args is String) {
              reportId = args;
            } else if (args is Map) {
              reportId = args['reportId'] as String? ?? '';
              fromDashboard = args['fromDashboard'] as bool? ?? false;
            }
            page = ReportScreen(
              reportId: reportId,
              fromDashboard: fromDashboard,
            );
            break;
          default:
            page = const ConnectionScreen();
        }
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
      },
    );
  }
}
