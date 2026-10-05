# PPA-WU05-MIGMAC02 operator experiment

Date: 2026-10-05
Canonical parent: `9605fbb1622d96f4691117f66264f13b6dd3a47b`
Branch: `work/ppa-wu05-migmac02-crack-geometry`
Status: `CLAY_OPTION1_AND_MPVOLUME_SOURCE_BOUND_OPERATOR_EXPERIMENT`

## Purpose and authority boundary

The exact B1.11 `macropore.f90` member was reconstructed from checked B0 plus
the repository-pinned SWAP-001 patch and verified against SHA-256
`f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f`. The
operator implements source-bound clay option-1 `SHRINKPAR`, `SHRINK`, and
`MPVOLUME(1)` behavior. Peat and other shrinkage input modes are outside this
implementation and evidence.

The separate E4 diagnostic remains a source-bound history example for the
captured MPVOLUME branch: with theta 0.35, previous theta 0.30, theta-s 0.45,
crack threshold 0.30, dz 10 cm, geometry factor 3, matrix area 0.92 and shrink
fraction 0.05, no prior crack returns zero; prior local or neighbour volume
0.08 cm returns about 0.30928 cm. It does not validate runtime accepted receipt identity or macro-water handling.

## Experiment checks

The pure operator gate checks drying/wetting transitions, local and neighbour
history, unchanged geometry, saturation closure, a bounded large change,
invalid NaN moisture, Kim algebra for the source-bound clay option-1 law, groundwater-node
cutoff and fixed-head/full-saturation cases, and A/B/A replay
from the same accepted history. The operator and provider geometry scripts
compile/run at `-O0` and `-O2`; both report PASS. The provider experiment also
checks accepted-carrier immutability, copy/replay identity, geometry displacement
ownership, and unchanged behavior with dynamic shrinkage disabled.

The operator is source-bound to the verified clay law, while the focused
numeric outputs remain a narrow operator qualification only. Full transaction
qualification and production admission remain open.
