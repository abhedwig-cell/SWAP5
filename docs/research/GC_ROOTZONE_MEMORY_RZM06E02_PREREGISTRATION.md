# GC-RZM06E02 immutable-pair fixed-Hc H2 probe preregistration

Date: 2026-09-22  
Production changes: none

E02 is the first response experiment allowed after E01 selected and persisted a qualifying state pair.

The pair is immutable:

- A: E01 `EQ`, step 1;
- B: E01 `CLOSED`, step 14.

No E02 code may reselect, reorder by response, or replace either origin.

## Reconstruction gate

Both stored 16-node H/theta profiles are reconstructed as fresh committed BASE states at common canonical time `t0=0`, under the D02R1 common-time authority.

Before any response call, E02 must:

1. recover all 16 nodes from the persisted E01 result;
2. recompute total profile water and M1 from theta and the 10 cm grid;
3. re-establish `|ΔW_profile| <= 1e-4 cm`;
4. re-establish `|ΔM1| >= 1e-2 cm`;
5. prove the committed snapshot is bit-identical to the supplied origin arrays.

Failure of any reconstruction gate stops the experiment before response.

## Frozen response probe

Both origins receive exactly the same strict Reference sample:

- common time: `0 d`;
- duration: `3435974 / 2^32 d`;
- top flux: `0 cm d^-1`;
- bottom mode: 5;
- physical fixed-plane head: `H_c = -1.8979370901690651 m`;
- lower-face datum: `-1.6 m`;
- expected mapped pressure head: `-29.793709016906497 cm`;
- hard mass gate: `1e-12 cm`;
- no commit and no fallback.

The existing groundwater-head materializer must perform the H_c to SWAP bottom-pressure-head mapping.

The primary response is accepted whole-window bottom outward exchange. The frozen support criterion is

`|ΔE_c| > 1e-18 cm`.

Terminal bottom flux and solver/mass diagnostics are descriptive only.

## Hidden-state control

The pair is executed in both orders, A→B and B→A. Every probe starts from a fresh committed origin and fresh backend. The response for a given origin must be bit-identical across the two orders.

This is a research falsification experiment only. It does not admit production coupling behavior or a second MODFLOW state variable.
