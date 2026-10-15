import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../helpers/test_dnd5e_catalog.dart';

void main() {
  group('Dnd5eRuleset catalog installation tests', () {
    setUp(() {
      Dnd5eRuleset.resetForTesting();
    });

    tearDown(() {
      Dnd5eRuleset.resetForTesting();
    });

    test('accessing catalog before install throws CatalogNotInstalledError which is StateError', () {
      expect(
        () => Dnd5eRuleset.catalog,
        throwsA(isA<CatalogNotInstalledError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
      expect(
        () => Dnd5eRuleset.catalog,
        throwsA(isA<StateError>()),
      );
      expect(CatalogNotInstalledError(), isA<StateError>());
    });

    test('installing a second different catalog without reset throws StateError', () {
      const cat1 = TestDnd5eCatalog();
      final cat2 = TestDnd5eCatalog(onFindClass: (_) => null);
      Dnd5eRuleset.install(cat1);
      expect(
        () => Dnd5eRuleset.install(cat2),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('A Dnd5eCatalog is already installed'),
        )),
      );
    });

    test('installing identical catalog instance succeeds idempotently', () {
      const cat = TestDnd5eCatalog();
      Dnd5eRuleset.install(cat);
      expect(() => Dnd5eRuleset.install(cat), returnsNormally);
      expect(Dnd5eRuleset.catalog, same(cat));
    });

    test('resetForTesting allows installing a new catalog', () {
      const cat1 = TestDnd5eCatalog();
      final cat2 = TestDnd5eCatalog(onFindClass: (_) => null);
      Dnd5eRuleset.install(cat1);
      Dnd5eRuleset.resetForTesting();
      Dnd5eRuleset.install(cat2);
      expect(Dnd5eRuleset.catalog, same(cat2));
    });
  });
}
