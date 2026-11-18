import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/config/app_design_tokens.dart';
import 'src/controllers/audio_controller.dart';
import 'src/controllers/maze_game_controller.dart';
import 'src/screens/home_screen.dart';
import 'src/services/ad_service.dart';
import 'src/services/maze_level_repository.dart';
import 'src/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-first casual mobile experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storageService = StorageService();
  final levelRepository = MazeLevelRepository();
  final audioController = AudioController();

  // Safe default: live ads disabled until owner compliance review
  final adService = DisabledAdService();

  final controller = MazeGameController(
    storageService: storageService,
    levelRepository: levelRepository,
    adService: adService,
    audioController: audioController,
  );

  await controller.initialize();

  runApp(ParcelEscapeApp(controller: controller));
}

class ParcelEscapeApp extends StatelessWidget {
  final MazeGameController controller;

  const ParcelEscapeApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parcel Escape: Food Maze Adventure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppDesignTokens.coralPrimary,
          surface: AppDesignTokens.warmCream,
        ),
        scaffoldBackgroundColor: AppDesignTokens.warmCream,
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(controller: controller),
    );
  }
}
