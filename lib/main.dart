import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/controllers/workout_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(const HuaweiHealthExportApp());
}

class HuaweiHealthExportApp extends StatelessWidget {
  const HuaweiHealthExportApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0B0E14);
    const surfaceDark = Color(0xFF161B22);
    const surfaceHigh = Color(0xFF1E242C);
    const coralAccent = Color(0xFFFC4C02);
    const neonMint = Color(0xFF00E5BE);
    const textLight = Color(0xFFF0F6FC);
    const textDim = Color(0xFF8B949E);
    const outlineDark = Color(0xFF30363D);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
      ],
      child: MaterialApp(
        title: 'Huawei Health Exporter',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: coralAccent,
            primary: coralAccent,
            secondary: neonMint,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bgDark,
          colorScheme: const ColorScheme.dark(
            primary: coralAccent,
            onPrimary: Colors.white,
            secondary: neonMint,
            onSecondary: Color(0xFF0B0E14),
            surface: surfaceDark,
            onSurface: textLight,
            onSurfaceVariant: textDim,
            surfaceContainerLow: surfaceDark,
            surfaceContainer: surfaceHigh,
            surfaceContainerHigh: surfaceHigh,
            outline: outlineDark,
            outlineVariant: outlineDark,
          ),
          cardTheme: CardThemeData(
            color: surfaceDark,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: outlineDark, width: 1),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: bgDark,
            foregroundColor: textLight,
            centerTitle: false,
            elevation: 0,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: surfaceDark,
            selectedColor: coralAccent.withValues(alpha: 0.25),
            side: const BorderSide(color: outlineDark, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            labelStyle: const TextStyle(fontSize: 12, color: textLight),
          ),
          dividerTheme: const DividerThemeData(
            color: outlineDark,
            thickness: 1,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
