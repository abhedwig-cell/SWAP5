# F-VQ12 — F-KT05 / F-SI05 source-bound admission

## Decision

`QUALIFIED_FKT05_FSI05_SOURCE_BOUND_NONCONFLICT_ONLY`

F-VQ12 admits the exact qualified F-KT05 reusable-checkpoint contract and the exact qualified F-SI05 production HeadCalc workspace seam on its focused qualified routes. It also qualifies their contractual non-conflict across transaction ownership, generic time semantics and shared F-KT types.

This is **not** a composed-runtime qualification. No one executable production postimage containing both development lines has been qualified here.

## Qualified basis

- F-VQ11 final qualification ancestor: `efdc11f35e2251eebbab888e05d74085892e05fd`.
- F-CI18 canonical closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`.
- F-KT05 tested postimage: `f7d2ee5e81f1d6686c96114984239e97ba6a8a8a`.
- F-KT05 qualification evidence: `6911549acbcb62ef8af9ae2d96d5b4f938daf1e2`.
- F-KT05 status promotion: `f50b8cd20221fac27a2059b6c6192ed0b7384be8`.
- F-SI05 tested implementation: `56c21448a2a0be716d497ac34db8c5eec60dd246`.
- F-SI05 documented postimage: `11b3138e05b1a5c59033134e870f6ffb58e6a9f6`.
- F-SI05 final qualification: `0227ae94edc3364b013f831f1efa6aaccac29b11`.

## Qualification replay

Pre-promotion F-VQ12 tested postimage: `373fafaa08ab30cc38fcedabd3f67ae9d61e7b8f`.

- F-VQ12 dedicated run `34127787286`, job `101760436814`: PASS.
- Exact F-KT05 focused O0/O2 gate plus selected F-CI regressions: PASS.
- Exact F-SI05 tested implementation replay: PASS.
- F-SI05 documented postimage replay: PASS.
- Immutable F-VQ11 run `34127787144`, job `101760437029`: PASS.
- Immutable VQ-reference run `34127787049`: PASS.
- Documentation run `34127787186`: PASS.
- Compiler: GNU Fortran 13.3.0.

An earlier F-VQ11 workflow run on the initial F-VQ12 head failed only because the historical F-VQ11 gate was evaluated against later F-VQ12 qualification paths. F-VQ11 orchestration is now immutable on its exact qualified final head; the F-VQ11 gate itself was not weakened or modified.

## Transaction and ownership boundary

The reusable checkpoint remains F-KT-owned. It captures committed physical state plus lineage/revision/time provenance, contains no solver scratch or warm start, and cannot publish or restore committed state by itself.

F-SI05 owns main Newton/Jacobian/tridiagonal and band-solver scratch per worker or active solve job. It changes neither transaction semantics nor generic time semantics and does not change the shared F-KT type. F-SI therefore gains no commit or rollback authority.

## Mass conservation

Mass conservation remains absolute. F-KT05 preserves the existing unrounded trial-mass gate and changes no mass accounting. F-SI05 qualifies a focused unrounded equation-residual identity only. F-VQ12 explicitly does **not** promote that focused residual into full SWAP water-balance qualification.

## Still fail-closed

The following remain unqualified:

- one composed F-KT05 + F-SI05 executable production postimage;
- full reference Richards reentrancy;
- parallel real HeadCalc execution with 1/2/4/8 workers;
- full unrounded SWAP water-balance identity;
- production B1.10 reference execution;
- production MultiSWAP runtime admission;
- macropore, implicit-conductivity, minimum-timestep and all non-free-drainage bottom workspace paths;
- MODFLOW coupling qualification.

F-VQ12 changes no production source, reference source, physics, numerical policy, mass policy or production routing.
