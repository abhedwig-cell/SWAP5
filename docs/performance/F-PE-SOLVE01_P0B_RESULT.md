# F-PE-SOLVE01 P0B result — bounded refresh frontier

Date: 2026-09-26

Status: `PASS_BOUNDED_REFRESH_FRONTIER`

PR:
`#654 — F-PE-SOLVE01: bounded discarded-trial Richards solve elimination`

Workflow run:
`36274543159 — F-PE-SOLVE01 EF upper bound`

Job:
`p0b-refresh-frontier`

## Scope

P0B measures bounded refresh policies between exact-every-trial and the aggressive EF upper bound.

Frozen matrix:

- six difficult PROFILE06 material/regime origins;
- both +/-10% dynamic-history directions;
- eight-request same-origin corrector block:
  `+0.001, +0.01, -0.001, -0.01, +0.001, -0.001, +0.01, -0.01 cm`;
- c=0.50 temporal policy used only as a research enabler;
- BALTOL02 dt-scaled balance floor replayed in the research harness;
- exact final validation before commit;
- no production source modification.

Response approximation uses only the most recent exact local linear response:

`q(h) = q_anchor + J_anchor * (h - h_anchor)`.

## Aggregate result

### E2

- median solve reduction: `37.5%`;
- median runtime ratio: `0.703327658`;
- median wall-clock speedup: `29.667234%`;
- maximum relative response-excursion error: `1.00607000998469883e-4`;
- advancement gate: FAIL.

E2 is retained only as a low-aggression reference point.

### E4

- median solve reduction: `62.5%`;
- median runtime ratio: `0.435460365`;
- median wall-clock speedup: `56.453964%`;
- maximum relative response-excursion error: `1.22796428632301251e-4`;
- advancement gate: PASS.

Equivalent median speedup factor:

`1 / 0.435460365 ~= 2.30x`.

### EH

Frozen head-window:

`|h_request - h_anchor| <= 0.010 cm`

- median solve reduction: `50.0%`;
- median runtime ratio: `0.573021568`;
- median wall-clock speedup: `42.697843%`;
- maximum relative response-excursion error: `1.00607000998469883e-4`;
- advancement gate: PASS.

Equivalent median speedup factor:

`1 / 0.573021568 ~= 1.75x`.

### EF

Aggressive upper-bound comparator:

- median solve reduction: `75.0%`;
- median runtime ratio: `0.298499823`;
- median wall-clock speedup: `70.150018%`;
- maximum relative response-excursion error: `1.22796428632301251e-4`;
- advancement gate: PASS.

Equivalent median speedup factor:

`1 / 0.298499823 ~= 3.35x`.

## Ownership and final-state result

All passing arms preserve exact final-state identity on all 12 groups.

Verified per arm/group:

- final exact q identity;
- final pressure-head state identity;
- final water-content state identity;
- one committed revision;
- one committed ledger entry;
- exact final validation before commit.

No approximate candidate state is committed.

## Interpretation

The refresh frontier is monotonic in the expected direction.

More skipped discarded-trial solves produce larger wall-clock gains:

- E2: approximately 30%;
- EH: approximately 43%;
- E4: approximately 56%;
- EF: approximately 70%.

The measured runtime gains track solve-count reduction closely enough that no hidden dominant fixed overhead appears in this research fixture.

The intermediate response errors remain small across all tested bounded arms, of order `1e-4` relative to the exact response excursion.

This does not by itself qualify any arm for production because the scripted same-origin sequence does not measure whether approximate responses alter the external coupled iteration path.

## Decision

Advance:

- `E4` as the primary bounded cadence candidate;
- `EH` as the more conservative adaptive comparator;
- `EF` only as an aggressive upper-bound comparator.

Do not advance E2.

The next gate must be coupled-iteration robustness.

The key question is whether E4 or EH causes enough additional external groundwater corrector iterations to erase the solve-count and wall-clock gain.

No production admission is authorized by P0B.
