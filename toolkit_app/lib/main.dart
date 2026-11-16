import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/seed_repository.dart';
import 'screens/home_and_aux_screens.dart';
import 'screens/theme_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await SeedRepository.instance.ensureLoaded();
  runApp(const AkkaraphonToolkitApp());
}

class AkkaraphonToolkitApp extends StatelessWidget {
  const AkkaraphonToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: ToolkitColors.royalBlue,
      primary: ToolkitColors.royalBlue,
      surface: Colors.white,
    );

    return MaterialApp(
      title: 'อัครพลกระจกอลูมิเนียม',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Sarabun',
        colorScheme: colorScheme,
        scaffoldBackgroundColor: ToolkitColors.bgScaffold,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ToolkitColors.slateDark,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Sarabun',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ToolkitColors.slateDark,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: ToolkitColors.cardBorder,
          thickness: 1,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
