import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/pages/Pages.dart';
import 'package:flutter_application_1/pages/firebase_options.dart';
import 'package:flutter_application_1/pages/multiple_sensor_display.dart';

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
    return MaterialApp(
      title: 'Monitor de Calidad del Aire',
      debugShowCheckedModeBanner: false, // Quita la banda de "Debug"
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Activa Material 3 para un look más moderno
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'E.S.E HOSPITAL SANTA CRUZ DE URUMITA.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15, // Ajustado ligeramente para que quepa mejor
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
        body: Stack(
          children: [
            // Imagen de fondo con opacidad
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/imagenes/UNIVERSIDAD.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Si la imagen no carga, muestra un fondo gris para que no rompa la app
                    return Container(color: Colors.grey[200]);
                  },
                ),
              ),
            ),
            // Contenido principal
            const SingleChildScrollView(
              child: Center(
                child: MultipleSensorDisplay(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}