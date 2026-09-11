# F-MR39 qualification run log

Work unit: **F-MR39 Restricted Soil-Temperature Transactional Runtime Composition**

Frozen canonical base: `d201904a85f3b595e028242978e52c02f5122a09`

Qualified immutable source candidate: `87b553094b66980006b69f5ba8b53d70ccd0a8e0`

Scientific authority replayed unchanged: `F-VQ58@5e81e14ad613cff7a72fc3f9cddcebc6696290d7`

## Materialization qualification

GitHub Actions run `34631376676`, job `103368740763`.

The source materializer was fail-closed. Three development/plumbing defects were encountered before publication and each stopped before production source was committed:

1. an ambiguous text anchor in the materializer;
2. a prepublication source-delta check that initially inspected only committed changes rather than the working tree;
3. an incorrect test-helper module name.

After those were repaired, the full gate passed before publication. Only then were the two bounded runtime source files committed.

Materialized source blobs:

- `src/runtime/mod_fmr_serialized_reference_backend.f90`: `07877429f94ccf07c353fa5f8ba969c341ad88dd`
- `src/runtime/mod_fmr_restart_state_contract.f90`: `bb2c37efce37a73441181f14d15847c652ab45ea`

## Immutable exact-head requalification

GitHub Actions run `34631572194`, job `103369388981`.

The workflow detached HEAD at exactly `87b553094b66980006b69f5ba8b53d70ccd0a8e0` and ran the complete F-MR39 gate without materialization or source modification.

Key PASS markers:

- `FMR39_BOUNDED_PRODUCTION_DELTA=PASS`
- `FMR39_SCIENCE_KERNEL_TRANSACTION_AND_HYDRAULIC_SEAM_LOCKS=PASS`
- `FMR39_OPTIONAL_COMMITTED_THERMAL_STATE=PASS`
- `FMR39_WORKER_LOCAL_THERMAL_SCRATCH=PASS`
- `FMR39_RICHARDS_THEN_THERMAL_TRIAL_ORDER=PASS`
- `FMR39_WATER_STORAGE_AND_MASS_EXCLUDE_THERMAL_ENERGY=PASS`
- `FMR39_RESTART_FAIL_CLOSED_THERMAL_SHAPE=PASS`
- `FMR39_DISABLED_PATH_FMR19_PRESERVATION_O0=PASS`
- `FMR39_DISABLED_PATH_FMR19_PRESERVATION_O2=PASS`
- `FMR39_RUNTIME_O0_O2_OUTPUT_IDENTITY=PASS`
- `FMR39_DISABLED_PATH_O0_O2_OUTPUT_IDENTITY=PASS`
- `FMR39_FVQ58_EXACT_SCIENTIFIC_AUTHORITY_REPLAY=PASS`
- `FMR39_ENABLED_WATER_THERMAL_ATOMIC_COMMIT=PASS`
- `FMR39_WATER_MASS_AUTHORITY_WITH_THERMAL_ACTIVE=PASS`
- `FMR39_THERMAL_FAILURE_ROLLS_BACK_WATER_AND_TEMPERATURE=PASS`
- `FMR39_RETRY_FROM_SAME_COMMITTED_STATE=PASS`
- `FMR39_SPLIT_RESTART_WATER_THERMAL_IDENTITY=PASS`
- `FMR39_RESTART_USES_EXISTING_POLYMORPHIC_PHYSICAL_STATE=PASS`
- `FMR39_MIXED_ENABLED_DISABLED_MULTISWAP_ISOLATION=PASS`
- `FMR39_INACTIVE_COLUMN_NO_THERMAL_PHYSICAL_STATE=PASS`
- `FMR39_ALL_30_ARCHITECTURE_INVARIANTS_AUDITED_BY_EVIDENCE=PASS`
- `FMR39_GATE=PASS`
- `FMR39_EXACT_CANDIDATE_HEAD=PASS:87b553094b66980006b69f5ba8b53d70ccd0a8e0`

Deterministic runtime output SHA-256:

`cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942`

## Canonical movement after base freeze

During F-MR39 closeout, `integration/f-ci-canonical` advanced to `536042620038014057427a7915c212a3ac78f84d` through F-CI44.

Therefore F-MR39 is closed as a qualified runtime-composition source authority on its frozen base, but it is **not** a current-canonical admission candidate. A clean current-canonical recomposition and requalification is required before any admission or promotion.
