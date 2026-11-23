import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/meeting_provider.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BilingualMeetingIntelligenceApp());
}

class BilingualMeetingIntelligenceApp extends StatelessWidget {
  const BilingualMeetingIntelligenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MeetingProvider()),
      ],
      child: MaterialApp(
        title: 'Meeting Intelligence',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A8A), // Executive deep navy
            primary: const Color(0xFF1E3A8A),
            secondary: const Color(0xFF0D9488), // Teal accent
            surface: Colors.white,
          ),
          textTheme: textTheme,
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            elevation: 0,
            titleTextStyle: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
