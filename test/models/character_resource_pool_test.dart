import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('CharacterResourcePool Extension Tests', () {
    test('default values are initialized properly', () {
      const pool = CharacterResourcePool();
      expect(pool.deathSaveSuccesses, equals(0));
      expect(pool.deathSaveFailures, equals(0));
      expect(pool.exhaustionLevel, equals(0));
      expect(pool.hasHeroicInspiration, isFalse);
    });

    test('clamps death saves to 0-3 and exhaustion to 0-10', () {
      const pool = CharacterResourcePool(
        deathSaveSuccesses: 5,
        deathSaveFailures: -2,
        exhaustionLevel: 15,
      );
      expect(pool.deathSaveSuccesses, equals(3));
      expect(pool.deathSaveFailures, equals(0));
      expect(pool.exhaustionLevel, equals(10));
    });

    test('copyWith preserves and updates extended fields with clamping', () {
      const pool = CharacterResourcePool();
      final updated = pool.copyWith(
        deathSaveSuccesses: 2,
        deathSaveFailures: 1,
        exhaustionLevel: 3,
        hasHeroicInspiration: true,
      );
      expect(updated.deathSaveSuccesses, equals(2));
      expect(updated.deathSaveFailures, equals(1));
      expect(updated.exhaustionLevel, equals(3));
      expect(updated.hasHeroicInspiration, isTrue);
    });

    test('toMap and fromMap preserve all extended fields round-trip', () {
      const pool = CharacterResourcePool(
        currentHp: 25,
        tempHp: 5,
        deathSaveSuccesses: 2,
        deathSaveFailures: 1,
        exhaustionLevel: 4,
        hasHeroicInspiration: true,
      );

      final map = pool.toMap();
      final restored = CharacterResourcePool.fromMap(map);

      expect(restored.currentHp, equals(25));
      expect(restored.tempHp, equals(5));
      expect(restored.deathSaveSuccesses, equals(2));
      expect(restored.deathSaveFailures, equals(1));
      expect(restored.exhaustionLevel, equals(4));
      expect(restored.hasHeroicInspiration, isTrue);
      expect(restored, equals(pool));
      expect(restored.hashCode, equals(pool.hashCode));
    });

    test('composes EntityVitals and synchronizes vitals state via withVitals',
        () {
      const pool = CharacterResourcePool(
        currentHp: 30,
        tempHp: 10,
        deathSaveSuccesses: 1,
        deathSaveFailures: 0,
      );

      expect(pool.vitals.currentHp, equals(30));
      expect(pool.vitals.temporaryHp, equals(10));
      expect(pool.currentHp, equals(30));
      expect(pool.tempHp, equals(10));

      final updatedVitals = pool.vitals.copyWith(
        currentHp: 18,
        temporaryHp: 0,
        auxiliaryPools: {
          'deathSaveSuccesses': 2,
          'deathSaveFailures': 1,
          'exhaustionLevel': 2,
        },
      );

      final updatedPool = pool.withVitals(updatedVitals);
      expect(updatedPool.currentHp, equals(18));
      expect(updatedPool.tempHp, equals(0));
      expect(updatedPool.deathSaveSuccesses, equals(2));
      expect(updatedPool.deathSaveFailures, equals(1));
      expect(updatedPool.exhaustionLevel, equals(2));
      expect(updatedPool.vitals, equals(updatedVitals));
    });
  });
}
