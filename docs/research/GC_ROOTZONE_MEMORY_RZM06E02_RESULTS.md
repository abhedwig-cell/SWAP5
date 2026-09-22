# GC-RZM06E02 immutable-pair fixed-Hc H2 result

Date: 2026-09-22  
Preregistration: `c0291cc0669b0e9022695d495bcf62b4bad40a57`  
Qualified workflow: `35741739776`, job `106792958715`  
Production changes: none

## Decision

E02 is qualified as:

`SUPPORTED_H2_VERTICAL_DISTRIBUTION_MEMORY_FOR_SELECTED_REAL_SWAP_PAIR`.

This is the first direct real-HeadCalc H2 support result in the root-zone-memory workstream.

## State gate

The immutable E01 origins were reconstructed from repository-persisted node profiles at common canonical time.

Reconstructed state separation:

- `W_profile(A) = 58.61918400000001 cm`;
- `W_profile(B) = 58.619184 cm`;
- `|ΔW_profile| = 1.4210854715202004e-14 cm`;
- frozen water-match gate: `1e-4 cm`;
- `M1(A) = -79.99999999999997 cm`;
- `M1(B) = -80.11123947403316 cm`;
- `|ΔM1| = 0.11123947403318368 cm`;
- frozen M1 gate: `0.01 cm`.

Thus the two origins have indistinguishable total profile water at floating-point roundoff while clearly different vertical distribution.

Upper-30-cm water is not equal:

- A: `10.991097 cm`;
- B: `10.947165012700356 cm`;
- difference: about `0.043932 cm`.

That last fact is important for interpretation: E02 proves that total profile water alone is insufficient, but it does not yet prove that a root-zone-storage scalar is insufficient.

## Identical fixed-interface probe

Both origins received the same strict Reference probe:

- common `t0 = 0 d`;
- `dt = 3435974 / 2^32 d = 0.000800000037997961 d`;
- top flux `0 cm d^-1`;
- mode 5;
- `H_c = -1.897937090169065 m`;
- bottom datum `-1.6 m`;
- mapped bottom pressure head `-29.7937090169065 cm`.

Both probes were admitted and mass-complete with zero residual.

Whole-window bottom outward exchange:

- A: `0.0031391986203388456 cm`;
- B: `0.004456805234376304 cm`;
- `ΔE_c = 0.0013176066140374587 cm`.

The preregistered support threshold was `1e-18 cm`, so the observed separation is many orders of magnitude above the decision floor.

Terminal bottom flux also differs:

- A: `3.923998089043649 cm d^-1`;
- B: `5.571006278361781 cm d^-1`.

These terminal values are descriptive; H2 was decided on whole-window accepted exchange.

## Contamination control

The probes were repeated in A→B and B→A order using fresh committed origins and fresh Reference backends. Same-origin results were bit-identical across execution order.

O0 and O2 complete outputs were also byte-identical.

## Scientific interpretation

For this qualified 16-node B01 pure-hydraulics carrier and frozen fixed-Hc window:

- `H_c` is not a complete SWAP state descriptor;
- `H_c + W_profile` is also not a complete descriptor;
- vertical distribution of water within the SWAP column carries hydraulically relevant memory for the next interface exchange.

This does not imply that MODFLOW needs another hydraulic state. The additional state remains SWAP-internal and must be represented explicitly or through a qualified reduced state when constructing coupling response.

The next state-sufficiency question is narrower: whether `H_c + W_profile + W_root` is sufficient, or whether finer vertical distribution is still required.
