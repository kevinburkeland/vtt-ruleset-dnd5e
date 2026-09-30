import 'package:vtt_engine_core/models/entity_reference.dart';

/// Abstract contract for resolving entity references within the ruleset domain,
/// decoupling rules calculations from concrete application repository implementations.
abstract interface class IEntityResolver {
  /// Resolves a reference returning a DomainEntity (or UnresolvedReference Null-Object).
  DomainEntity resolve(EntityReference ref);

  /// Strongly typed resolution returning a ResolutionResult container.
  ResolutionResult<T> resolveTyped<T extends DomainEntity>(
      EntityReference<T> ref);
}
