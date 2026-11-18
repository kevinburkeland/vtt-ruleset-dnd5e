import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

/// In-memory [IEntityResolver] test helper backed by a `Map<String, DomainEntity>`.
///
/// Copies only the slug-keyed lookup and `UnresolvedReference` null-object fallback
/// of the app's `LayeredPriorityRepository` + `ReferenceResolver` that the moved
/// ruleset tests rely on:
/// - `resolve(ref)`: looks up `ref.slug` in the in-memory map, returning the
///   entity if present, or an [UnresolvedReference] with `ref.slug` and
///   `ref.refType` if missing.
/// - `resolveTyped<T>(ref)`: looks up `ref.slug`, returning `ResolutionResult.success`
///   if present and assignable to `T`, or `ResolutionResult.missing` with an
///   [UnresolvedReference] otherwise.
class InMemoryEntityResolver implements IEntityResolver {
  final Map<String, DomainEntity> _entities;

  InMemoryEntityResolver([Iterable<DomainEntity> entities = const []])
      : _entities = {
          for (final entity in entities) entity.id.slug: entity,
        };

  void registerEntity(DomainEntity entity) {
    _entities[entity.id.slug] = entity;
  }

  void registerAll(Iterable<DomainEntity> entities) {
    for (final entity in entities) {
      registerEntity(entity);
    }
  }

  @override
  DomainEntity resolve(EntityReference ref) {
    final found = _entities[ref.slug];
    if (found != null) {
      return found;
    }
    return UnresolvedReference(
      slug: ref.slug,
      entityType: ref.refType,
      reason: 'Entity [${ref.slug}] not found in in-memory test resolver',
    );
  }

  @override
  ResolutionResult<T> resolveTyped<T extends DomainEntity>(
      EntityReference<T> ref) {
    final found = _entities[ref.slug];
    if (found is T) {
      return ResolutionResult.success(found);
    }
    return ResolutionResult.missing(
      UnresolvedReference(
        slug: ref.slug,
        entityType: ref.refType,
        reason: 'Entity [${ref.slug}] not found in in-memory test resolver',
      ),
    );
  }
}
