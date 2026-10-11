# TRACE-ELEM-SWAP-B01-001 reconciliation

Date closed: 2026-09-19
Prospective result: `NO_CONFIRMED_DISCREPANCY`
Candidate IDs: none

## Element

Drainage-v1 formulation family, selected before inspection as the process-relation stratum of Exposure Batch 01.

## Representation trace

Reviewer-facing scientific documentation:

- `docs/science/drainage.md`
- `docs/science/drainage-formulations.md`

Documentation-control authority:

- `integration/f-doc/F-DOC22_AUTHORITY_MATRIX.md`

Implementation identities directly inspected on the current canonical line:

- `src/process/mod_drainage_process.f90` blob `dbacd49da3bb0b94f822f9ee0478d15183e9c0fa`
- `src/process/mod_drainage_spatial_distribution.f90` blob `1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a`
- `src/process/mod_drainage_tabulated_response.f90` blob `738f57c334910ab73bc8870e3aa8dda1c1a48c7a`
- `src/process/mod_drainage_hooghoudt_ipos1_response.f90` blob `89f26e2d2b77bef5bdd0c5fdb2ce9ca1f03206fa`
- `src/process/mod_drainage_hooghoudt_equivalent_depth.f90` blob `6b7b2bb1fd259879d3f26c46abfc071ea2b2f108`
- `src/process/mod_drainage_hooghoudt_ipos23_response.f90` blob `5637ddb4d33141f00b4ebf737d1c7f7fe1824164`
- `src/process/mod_drainage_ernst_ipos45_preparation.f90` blob `fa1d5d400bb32be42e78889c0ff2a3bcab335142`
- `src/process/mod_drainage_ernst_ipos45_response.f90` blob `b00ef0ae1f10182af2d0a8ea636d10b196e93379`
- `src/process/mod_drainage_empirical_interflow_response.f90` blob `eb53096b678d08b76d3fb1adb2247bc2a58ee748`
- `src/process/mod_drainage_multilevel_aggregation.f90` blob `70d35512ef7c5958f7e4bf284cba104a7b641fdb`
- `src/process/mod_restricted_fixed_weir_surface_water.f90` blob `16da4f6ec3d120b5a40f17ef04fb8faa457f4eaa`

The F-DOC22 matrix pins the same implementation identities for the seven detailed non-linear/non-simple families. Direct reconciliation found the documented equations and branch semantics represented in the inspected current source:

- one-way linear activation and exact-kink derivative nonclaim;
- positive DIVDRA scalar-to-node transmissivity partition and exact closure correction;
- tabulated interpolation/clamping and knot derivative nonclaim;
- Hooghoudt cutoff, equivalent-depth branches and IPOS1..3 response algebra;
- Ernst IPOS4..5 prepared/vertical resistance branches and interface derivative nonclaim;
- empirical interflow activation and singular-tangent semantics;
- deterministic multi-level aggregation with derivative unavailability not erasing mass transfer;
- fixed-weir storage mapping, supply, rating solve and exact mass-equation accepted discharge.

No conflicting current formula, sign convention, branch sidedness or mass-booking rule was identified.

## Executable evidence trace

The branch-pinned F-PM19 final completion authority records an unchanged eight-variant denominator with all eight variants `PASS_COMPLETE`. Its evidence chain includes F-VQ73/F-VQ74 runtime and cross-cutting qualification, F-CI61/F-CI61P/F-CI62P admission/preservation and F-VQ76 current-postimage behavioral requalification.

F-PM19 records:

- hard mass: PASS;
- rollback: PASS;
- restart: PASS;
- MultiSWAP: PASS;
- diagnostics: PASS;
- F-VQ76 run `34821111681`: success.

This evidence is pre-existing evidence, not newly created TRACE evidence.

## TRACE disposition

No prospectively new discrepancy was observed. Known historical drainage development decisions and excluded capability bounds remain historical context and are not reclassified as TRACE cases.

This null result remains in the denominator.
