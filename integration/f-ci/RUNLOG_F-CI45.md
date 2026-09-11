# F-CI45 qualification run log

Work unit: **F-CI45 F-MR39 Restricted Soil-Temperature Runtime Current-Canonical Admission**

Pinned canonical base: `e342f4f9c9d45e2ec2d23a6be6032cc0498d98e2`

Immutable F-MR39 source authority: `87b553094b66980006b69f5ba8b53d70ccd0a8e0`

F-MR39 closeout authority: `843af75b8545b0644aece5cf58b5f499d7b5b600`

Scientific authority: `F-VQ58@5e81e14ad613cff7a72fc3f9cddcebc6696290d7`

## Mechanical current-canonical recomposition

Materializer run: `34633300589`, job `103375104573`, conclusion `success`.

Published source commit: `97515d75c96e9766f3b8697a7b40b28ec237118f`.

The materializer copied only the two immutable F-MR39 production blobs and verified their Git blob hashes before committing:

- `src/runtime/mod_fmr_serialized_reference_backend.f90` = `07877429f94ccf07c353fa5f8ba969c341ad88dd`
- `src/runtime/mod_fmr_restart_state_contract.f90` = `bb2c37efce37a73441181f14d15847c652ab45ea`

The net production delta relative to the pinned canonical base is exactly those two files.

## Exact-head qualification

Qualification head: `de1bb42e096a870141db543654b05732d13dd4b8`.

GitHub Actions run: `34633372426`, job `103375339565`, conclusion `success`.

The full F-CI45 gate requalified the recomposed runtime on the current canonical postimage. It covered:

- canonical race guard and reference-tree immutability;
- exact donor blob identity and exact two-file production scope;
- pinned F-MR39 closeout evidence and 30-invariant audit;
- pinned F-VQ58 process science, process hydraulic view, kernel and transaction seams;
- preservation of the F-CI44/F-CI44P application-accuracy-contract postimage;
- worker-local thermal scratch and optional compact committed thermal state;
- Richards-before-thermal execution order;
- water/thermal atomic commit and whole-trial rollback after forced thermal failure;
- retry from the same committed origin;
- split/restart exact endpoint identity;
- mixed enabled/disabled MultiSWAP isolation;
- inactive-column no-thermal-state property;
- hard water-mass accounting with thermal energy excluded;
- F-MR19 thermal-disabled preservation at O0 and O2;
- repeated-run and O0/O2 deterministic identity;
- exact F-VQ58 scientific-authority replay;
- explicit reconciliation of all 30 SWAP architecture invariants.

The runtime oracle output remained exactly:

`cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942`

## Scope holds

F-CI45 does not qualify parallel thermal throughput, snow plus thermal composition, frost/latent heat, a new combined water/thermal timestep acceptance policy, production SWAP-MODFLOW coupling, or a numeric application-accuracy policy. RB1 is not reopened.

Promotion is allowed only if a final status-head qualification remains green while `integration/f-ci-canonical` is still exactly the pinned base. Promotion must use a true two-parent merge followed by separate postimage reconciliation.
