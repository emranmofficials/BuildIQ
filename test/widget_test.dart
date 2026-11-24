import 'package:ai_construction_calculator/core/l10n.dart';
import 'package:ai_construction_calculator/core/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('bilingual catalogue', () {
    test('English and Bangla keys resolve', () {
      const en = AppLocalizations(Locale('en'));
      const bn = AppLocalizations(Locale('bn'));
      expect(en.tr('appTitle'), 'BuildIQ');
      expect(bn.tr('appTitle'), 'BuildIQ');
      expect(en.tr('sharedWallNote'), contains('counted once'));
      expect(bn.tr('sharedWallNote'), contains('একবারই'));
    });

    test('missing key falls back to the key itself', () {
      expect(
        const AppLocalizations(Locale('en')).tr('missing_key'),
        'missing_key',
      );
    });
  });

  group('themes', () {
    test('light and dark themes are Material 3', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });
  });

  testWidgets('a MaterialApp renders with the app theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('BuildIQ')),
      ),
    );
    expect(find.text('BuildIQ'), findsOneWidget);
  });
}
