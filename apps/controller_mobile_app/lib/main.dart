import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Gemma
  // Model installation and loading is handled in VoiceCommandService
  try {
    await FlutterGemma.initialize();
    await FlutterGemma.installModel(
      modelType: ModelType.functionGemma,
    ).fromAsset('assets/functiongemma-270M-it.task').install();

    debugPrint('[GEMMA] FlutterGemma initialized successfully');
  } catch (e) {
    debugPrint('[GEMMA] Failed to initialize FlutterGemma: $e');
    // Continue anyway - errors will be caught in VoiceCommandService
  }

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Lock orientation to landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  // Hide system UI (fullscreen immersive)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const ControllerApp());
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RC Car Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF), // Neon Blue
          secondary: Color(0xFFB2FF05), // Cyber Lime
          surface: Color(0xFF121212),
        ),
        // elevatedButtonTheme: ElevatedButtonThemeData(
        //   style: ElevatedButton.styleFrom(
        //     shape: const StadiumBorder(),
        //     backgroundColor: Colors.white.withValues(alpha: 0.1),
        //     foregroundColor: const Color(0xFF00E5FF),
        //     elevation: 8,
        //     shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
        //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        //   ),
        // ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF00E5FF),
          inactiveTrackColor: Colors.white24,
          thumbColor: Color(0xFFB2FF05),
          overlayColor: Colors.white12,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
