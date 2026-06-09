import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const WorkoutApp());
    expect(find.text('Workout App'), findsOneWidget);
  });
}
