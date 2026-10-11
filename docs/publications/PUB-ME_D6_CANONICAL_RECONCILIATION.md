# PUB-ME D6 canonical reconciliation

Status: **RECONCILED_PENDING_CURRENT_CANONICAL_REPLAY**

Publication owner: `PUB-ME`

Experiment family: `D6 — rejected-trial external side effect survives`

## Qualified result before reconciliation

D6 result-bearing head before canonical drift:

- `0fd57d46ecc7bfce31e63aad0bde536735b190ff`

Exact-head qualification:

- D6 workflow run `35289051541`: SUCCESS;
- Documentation run `35289051496`: SUCCESS;
- F-CI canonical qualification run `35289051500`: SUCCESS.

Primary classification remains:

- `D6 = EARLIER_DETECTION`.

## Canonical drift

D6 execution base:

- `d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0`

New canonical observed before admission:

- `f2d472cb0e4d935ef39f002d6f21c8d90acf4dd8`
- admitted capability: `PUB-P2E10 broad E0 paired admissibility map`.

Exact compare `d67a96fd... -> f2d472cb...` contains only:

- `.github/workflows/pub-p2e10-e0-broad-paired-matrix.yml`;
- `docs/publication/P2E10_E0_BROAD_PAIRED_MATRIX_PREREGISTRATION.json`;
- `docs/publication/P2E10_E0_BROAD_PAIRED_MATRIX_RESULT.json`;
- `tests/publication/run_pub_p2e10_e0_broad_paired_matrix.sh`;
- `tests/publication/test_pub_p2e10_e0_broad_paired_matrix.f90`.

## Relevance decision

The canonical delta does **not** modify:

- `src/**`;
- `reference/**`;
- `mod_transaction_reference.f90`;
- `mod_soil_water_accepted_step_direction_contract.f90`;
- `mod_accepted_trajectory_directional_sensitivity.f90`;
- `mod_accepted_trajectory_directional_publication.f90`;
- `mod_accepted_trajectory_transaction_binding.f90`;
- the D1-D6 preregistration authority;
- the D6 checkpoint, mutant, observer, B1/B2 comparator or result.

Therefore the scientific D6 result remains applicable, but admission requires a fresh current-canonical merge-postimage replay.

## Next permitted action

Replay D6, documentation and full canonical qualification against `integration/f-ci-canonical@f2d472cb0e4d935ef39f002d6f21c8d90acf4dd8`.

Do not change the D6 result or classification during this replay.
