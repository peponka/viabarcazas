import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viabarcazas_mobile/theme/app_colors.dart';

void main() {
  group('AppColors Design Tokens', () {
    test('backgroundPrimary is correct ViaBarcazas color', () {
      expect(AppColors.backgroundPrimary, const Color(0xFFF8F9FA));
    });

    test('accent blue is correct', () {
      expect(AppColors.accent, const Color(0xFF3B82F6));
    });

    test('textPrimary is dark editorial', () {
      expect(AppColors.textPrimary, const Color(0xFF1A1A2E));
    });

    test('semantic colors are defined', () {
      expect(AppColors.success, isNotNull);
      expect(AppColors.error, isNotNull);
      expect(AppColors.warning, isNotNull);
    });

    test('all system grays are ordered light to dark', () {
      // systemGray6 should be lighter than systemGray1
      expect(AppColors.systemGray6.value, greaterThan(AppColors.systemGray1.value));
    });
  });
}
