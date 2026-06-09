import 'package:flutter/material.dart';

void main() {
  runApp(const WorkoutApp());
}

class WorkoutApp extends StatelessWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Workout',
      home: Scaffold(
        body: Center(
          child: Text('Workout App'),
        ),
      ),
    );
  }
}
