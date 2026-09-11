# F-TB06 — Restricted Soil-Temperature Transaction, Restart & MultiSWAP Testbank Adoption

## Purpose

F-TB06 permanently adopts the newly canonical restricted soil-temperature runtime evidence into the SWAP5 testbank without reopening F-TB04, F-TB05 or RB1.

The workunit is testbank-only. Production source and reference material remain byte-identical to current canonical `c7379b6b5b5f529ff96de3087379712bd665276a`.

## Authorities

- current canonical and F-CI45P: `c7379b6b5b5f529ff96de3087379712bd665276a`
- F-TB05 exact-head authority: `81d4f0479a99bc456803f583457862387c267ec0`
- F-MR39 runtime source authority: `87b553094b66980006b69f5ba8b53d70ccd0a8e0`
- F-VQ58 scientific authority: `5e81e14ad613cff7a72fc3f9cddcebc6696290d7`
- F-CI45 canonical admission: `14db7be4827e73650da18d494af5cf190e687490`

## Adopted cases

F-TB06 adds eight stable F-TB01-compatible case identities. They cover atomic water-plus-thermal commit, thermal-failure rollback, retry from the same committed origin, split/restart identity, mixed active/inactive serialized MultiSWAP isolation, compact optional thermal state, deterministic O0/O2 runtime transcript, and the separately replayed F-VQ58 scientific authority.

The cases are additive. The 35-case F-TB04 transaction/restart/determinism/MultiSWAP catalog is not edited or renumbered.

## Execution model

`FAST` performs registry, provenance, source/reference immutability and architecture checks. `CANONICAL`, `RELEASE` and `DEEP` additionally rebound the inherited F-TB04/F-TB05 moving-current replays to the F-CI45P canonical source and execute the exact F-CI45 thermal runtime gate with only its obsolete prepromotion race check rebound to the promoted canonical head.

The thermal replay therefore retains the immutable F-MR39 source-test blob and the admitted runtime fingerprint:

`cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942`

F-VQ58 is executed independently from its exact authority commit. F-TB06 does not reinterpret scientific or mass tolerances.

## Mass and energy semantics

Water mass remains a hard gate. Thermal energy accounting remains a separate process quantity and is never added to water storage or water mass closure. A thermal failure after a successful Richards trial rejects the complete outer physical transaction.

## Explicit nonclaims

F-TB06 does not qualify frost, latent heat, snow-plus-thermal interaction, thermal-active parallel throughput, a new combined water/thermal timestep policy, production SWAP-MODFLOW coupling, or a new application-accuracy policy.

## Architecture

All 30 SWAP core architecture invariants are audited in `integration/f-tb/F-TB06_INVARIANT_AUDIT.json`. Particularly material are invariants 3, 4, 5, 6, 7, 8, 9, 13, 16, 21, 23, 24, 25, 26, 27, 29 and 30.
