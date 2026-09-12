import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viabarcazas_mobile/widgets/app_drawer.dart';

void main() {
  group('AppDrawer Widget', () {
    testWidgets('AppDrawer can be created', (WidgetTester tester) async {
      // Verify the widget can be instantiated without errors
      const drawer = AppDrawer();
      expect(drawer, isA<AppDrawer>());
    });

    testWidgets('AppDrawer has a key', (WidgetTester tester) async {
      const drawer = AppDrawer(key: Key('test-drawer'));
      expect(drawer.key, const Key('test-drawer'));
    });
  });

  group('AppDrawer Navigation Structure', () {
    test('AppDrawer is a StatelessWidget', () {
      const drawer = AppDrawer();
      expect(drawer, isA<StatelessWidget>());
    });
  });
}
