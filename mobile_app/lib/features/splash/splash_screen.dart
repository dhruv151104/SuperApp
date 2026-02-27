import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Slate 950
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E293B), // Slate 800
              Color(0xFF0F172A), // Slate 950
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // Logo Animation
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 180,
                height: 180,
              ),
            )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(
                  duration: 800.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                )
                .shimmer(delay: 1000.ms, duration: 1500.ms, color: Colors.white24),

            const SizedBox(height: 32),

            // Text Animation
            Column(
              children: [
                Text(
                  "Super App",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 40,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 800.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutQuad)
                    .blurXY(begin: 10, end: 0, delay: 500.ms, duration: 800.ms),
                
                const SizedBox(height: 8),
                
                Text(
                  "TRACEABILITY • BLOCKCHAIN • TRUST",
                  style: TextStyle(
                    color: Colors.blueAccent.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 1200.ms, duration: 1000.ms)
                    .shimmer(delay: 2000.ms, duration: 2000.ms),
              ],
            ),

            const Spacer(flex: 2),

            // Loading indicator
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white10,
                color: Colors.blueAccent,
                minHeight: 2,
              ),
            )
                .animate()
                .fadeIn(delay: 1500.ms)
                .scaleX(begin: 0, end: 1, delay: 1500.ms, duration: 1000.ms),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
