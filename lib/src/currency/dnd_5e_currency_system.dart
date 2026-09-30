import 'dart:math' as math;
import 'package:vtt_engine_core/currency/i_currency_system.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/crdt/pn_counter.dart';

/// Concrete D&D 5e Currency System supporting standard coin denominations:
/// Copper (cp), Silver (sp), Electrum (ep), Gold (gp), Platinum (pp).
///
/// Anchored to Gold Pieces (gp) with conversion rates:
/// - 1 cp = 0.01 gp (100 cp = 1 gp)
/// - 1 sp = 0.10 gp (10 sp = 1 gp)
/// - 1 ep = 0.50 gp (2 ep = 1 gp)
/// - 1 gp = 1.00 gp
/// - 1 pp = 10.00 gp (1 pp = 10 gp)
class Dnd5eCurrencySystem implements ICurrencySystem {
  const Dnd5eCurrencySystem();

  static const cp = CurrencyDenomination(
    id: 'cp',
    name: 'Copper Piece',
    symbol: 'cp',
    conversionRateToBase: 0.01,
  );

  static const sp = CurrencyDenomination(
    id: 'sp',
    name: 'Silver Piece',
    symbol: 'sp',
    conversionRateToBase: 0.10,
  );

  static const ep = CurrencyDenomination(
    id: 'ep',
    name: 'Electrum Piece',
    symbol: 'ep',
    conversionRateToBase: 0.50,
  );

  static const gp = CurrencyDenomination(
    id: 'gp',
    name: 'Gold Piece',
    symbol: 'gp',
    conversionRateToBase: 1.00,
  );

  static const pp = CurrencyDenomination(
    id: 'pp',
    name: 'Platinum Piece',
    symbol: 'pp',
    conversionRateToBase: 10.00,
  );

  @override
  String get systemId => 'dnd5e_currency';

  @override
  String get displayName => '5E Standard Coinage';

  @override
  List<CurrencyDenomination> get denominations => const [cp, sp, ep, gp, pp];

  @override
  String get baseDenominationId => 'gp';

  @override
  CurrencyDenomination? getDenomination(String id) {
    final clean = id.trim().toLowerCase();
    return switch (clean) {
      'cp' || 'copper' => cp,
      'sp' || 'silver' => sp,
      'ep' || 'electrum' => ep,
      'gp' || 'gold' => gp,
      'pp' || 'platinum' => pp,
      _ => null,
    };
  }

  @override
  double convert({
    required double amount,
    required String fromDenominationId,
    required String toDenominationId,
  }) {
    final fromDenom = getDenomination(fromDenominationId);
    final toDenom = getDenomination(toDenominationId);

    if (fromDenom == null || toDenom == null) return amount;
    if (fromDenom.id == toDenom.id) return amount;

    // Convert to base (gp), then to target
    final inBase = amount * fromDenom.conversionRateToBase;
    return inBase / toDenom.conversionRateToBase;
  }

  @override
  String formatBalances(Map<String, int> balances) {
    final parts = <String>[];
    for (final denom in [pp, gp, ep, sp, cp]) {
      final val = balances[denom.id] ?? 0;
      if (val > 0) {
        parts.add('$val ${denom.symbol}');
      }
    }
    return parts.isEmpty ? '0 gp' : parts.join(', ');
  }
}

/// D&D 5e Per-Player Loot/Vault Split breakdown.
class PartyPurseSplit {
  final int playerCount;
  final double totalGpEquivalent;
  final double perPlayerGpEquivalent;
  final int cpPerPlayer;
  final int spPerPlayer;
  final int epPerPlayer;
  final int gpPerPlayer;
  final int ppPerPlayer;
  final PartyPurse remainderPurse;
  final bool liquidatedGemsAndArtIncluded;

  const PartyPurseSplit({
    required this.playerCount,
    required this.totalGpEquivalent,
    required this.perPlayerGpEquivalent,
    required this.cpPerPlayer,
    required this.spPerPlayer,
    required this.epPerPlayer,
    required this.gpPerPlayer,
    required this.ppPerPlayer,
    required this.remainderPurse,
    required this.liquidatedGemsAndArtIncluded,
  });
}

/// 5e Extension on [PartyPurse] providing standard D&D 5e coin operations,
/// GP equivalence calculations, and auto-currency packaging.
extension Dnd5ePurseExtension on PartyPurse {
  int get cp => getBalance('cp');
  int get sp => getBalance('sp');
  int get ep => getBalance('ep');
  int get gp => getBalance('gp');
  int get pp => getBalance('pp');

  PnCounter get cpCounter => getCounter('cp');
  PnCounter get spCounter => getCounter('sp');
  PnCounter get epCounter => getCounter('ep');
  PnCounter get gpCounter => getCounter('gp');
  PnCounter get ppCounter => getCounter('pp');

  PnCounter get effectiveCpCounter => cpCounter;
  PnCounter get effectiveSpCounter => spCounter;
  PnCounter get effectiveEpCounter => epCounter;
  PnCounter get effectiveGpCounter => gpCounter;
  PnCounter get effectivePpCounter => ppCounter;

  /// Total gold piece equivalent (1 PP = 10 GP, 1 EP = 0.5 GP, 1 SP = 0.1 GP, 1 CP = 0.01 GP)
  double get totalGpEquivalent =>
      (pp * 10.0) + gp.toDouble() + (ep * 0.5) + (sp * 0.1) + (cp * 0.01);

  PartyPurse modifyCoin(String denomination, int delta,
          {String nodeId = 'local'}) =>
      modifyDenomination(denomination, delta, nodeId: nodeId);

  PartyPurse setCoins({
    int? cp,
    int? sp,
    int? ep,
    int? gp,
    int? pp,
    String nodeId = 'local',
  }) {
    var p = this;
    if (cp != null) p = p.setDenomination('cp', cp, nodeId: nodeId);
    if (sp != null) p = p.setDenomination('sp', sp, nodeId: nodeId);
    if (ep != null) p = p.setDenomination('ep', ep, nodeId: nodeId);
    if (gp != null) p = p.setDenomination('gp', gp, nodeId: nodeId);
    if (pp != null) p = p.setDenomination('pp', pp, nodeId: nodeId);
    return p;
  }

  PartyPurse depositCoins({
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    String nodeId = 'local',
  }) {
    var p = this;
    if (cp > 0) p = p.modifyDenomination('cp', cp, nodeId: nodeId);
    if (sp > 0) p = p.modifyDenomination('sp', sp, nodeId: nodeId);
    if (ep > 0) p = p.modifyDenomination('ep', ep, nodeId: nodeId);
    if (gp > 0) p = p.modifyDenomination('gp', gp, nodeId: nodeId);
    if (pp > 0) p = p.modifyDenomination('pp', pp, nodeId: nodeId);
    return p;
  }

  PartyPurse withdrawCoins({
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    String nodeId = 'local',
  }) {
    var p = this;
    if (cp > 0)
      p = p.modifyDenomination('cp', -math.min(cp, p.cp), nodeId: nodeId);
    if (sp > 0)
      p = p.modifyDenomination('sp', -math.min(sp, p.sp), nodeId: nodeId);
    if (ep > 0)
      p = p.modifyDenomination('ep', -math.min(ep, p.ep), nodeId: nodeId);
    if (gp > 0)
      p = p.modifyDenomination('gp', -math.min(gp, p.gp), nodeId: nodeId);
    if (pp > 0)
      p = p.modifyDenomination('pp', -math.min(pp, p.pp), nodeId: nodeId);
    return p;
  }

  PartyPurse deductGpEquivalent(double costGp, {String nodeId = 'local'}) {
    if (costGp <= 0) return this;
    final costInCp = (costGp * 100).round();
    int balanceInCp = (pp * 1000) + (gp * 100) + (ep * 50) + (sp * 10) + cp;

    if (balanceInCp < costInCp) {
      throw StateError(
          'Insufficient funds: purse has $totalGpEquivalent GP, needed $costGp GP');
    }

    balanceInCp -= costInCp;

    final newPp = balanceInCp ~/ 1000;
    balanceInCp %= 1000;

    final newGp = balanceInCp ~/ 100;
    balanceInCp %= 100;

    final newEp = balanceInCp ~/ 50;
    balanceInCp %= 50;

    final newSp = balanceInCp ~/ 10;
    final newCp = balanceInCp % 10;

    return setCoins(
      cp: newCp,
      sp: newSp,
      ep: newEp,
      gp: newGp,
      pp: newPp,
      nodeId: nodeId,
    );
  }

  PartyPurseSplit splitShares(
    int playerCount, {
    bool includeLiquidatedGemsAndArt = false,
    double liquidatedGemsAndArtGp = 0.0,
  }) {
    if (playerCount <= 0) {
      return PartyPurseSplit(
        playerCount: 1,
        totalGpEquivalent: totalGpEquivalent,
        perPlayerGpEquivalent: totalGpEquivalent,
        cpPerPlayer: cp,
        spPerPlayer: sp,
        epPerPlayer: ep,
        gpPerPlayer: gp,
        ppPerPlayer: pp,
        remainderPurse: const PartyPurse(),
        liquidatedGemsAndArtIncluded: includeLiquidatedGemsAndArt,
      );
    }

    if (includeLiquidatedGemsAndArt) {
      final grandTotalGp = totalGpEquivalent + liquidatedGemsAndArtGp;
      final perPlayer = grandTotalGp / playerCount;
      final floorPerPlayer = perPlayer.floorToDouble();
      final remainder = grandTotalGp - (floorPerPlayer * playerCount);

      return PartyPurseSplit(
        playerCount: playerCount,
        totalGpEquivalent: grandTotalGp,
        perPlayerGpEquivalent: perPlayer,
        cpPerPlayer: 0,
        spPerPlayer: 0,
        epPerPlayer: 0,
        gpPerPlayer: floorPerPlayer.toInt(),
        ppPerPlayer: 0,
        remainderPurse: const PartyPurse().setCoins(gp: remainder.round()),
        liquidatedGemsAndArtIncluded: true,
      );
    }

    final ppEach = pp ~/ playerCount;
    final gpEach = gp ~/ playerCount;
    final epEach = ep ~/ playerCount;
    final spEach = sp ~/ playerCount;
    final cpEach = cp ~/ playerCount;

    final ppRem = pp % playerCount;
    final gpRem = gp % playerCount;
    final epRem = ep % playerCount;
    final spRem = sp % playerCount;
    final cpRem = cp % playerCount;

    final perPlayerGpEq = (ppEach * 10.0) +
        gpEach +
        (epEach * 0.5) +
        (spEach * 0.1) +
        (cpEach * 0.01);

    return PartyPurseSplit(
      playerCount: playerCount,
      totalGpEquivalent: totalGpEquivalent,
      perPlayerGpEquivalent: perPlayerGpEq,
      cpPerPlayer: cpEach,
      spPerPlayer: spEach,
      epPerPlayer: epEach,
      gpPerPlayer: gpEach,
      ppPerPlayer: ppEach,
      remainderPurse: const PartyPurse().setCoins(
        cp: cpRem,
        sp: spRem,
        ep: epRem,
        gp: gpRem,
        pp: ppRem,
      ),
      liquidatedGemsAndArtIncluded: false,
    );
  }
}
