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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
      ],
      child: MaterialApp(
        title: 'Huawei Health Exporter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
