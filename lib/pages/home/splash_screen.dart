import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  void _goHome() {
    if (_navigated || !mounted) return;

    _navigated = true;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Lottie.asset(
                'assets/lottie/hospital.json',
                width: 220,
                repeat: false,
                onLoaded: (composition) {
                  Future.delayed(
                    composition.duration,
                    _goHome,
                  );
                },
              ),

              const SizedBox(height: 30),

              const Text(
                'E.S.E HOSPITAL SANTA CRUZ DE URUMITA.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),
                                                                                                                            
              const Text(
                "Cargando sistema...",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}