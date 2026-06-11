import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/main.dart';

void main() {
  testWidgets('App launches on the Today tab', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WorkoutApp()));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
  });
}
