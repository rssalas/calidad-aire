import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/config/router/app_router.dart';
import 'package:flutter_application_1/pages/data/data_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Si ya existe una app, no hacemos nada
    if (Firebase.apps.isEmpty) {
      // Inicializamos sin pasarle 'options' para que lea directamente 
      // el archivo google-services.json que ya tienes en android/app
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase ya estaba listo o hubo un error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      
      title: 'AirGuard',
      debugShowCheckedModeBanner: false, // Quita la banda de "Debug"
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Activa Material 3 para un look más moderno
      ),
      routerConfig: appRouter,
    );
  }
}