# F-PE-NLGLOB13C1 preregistration — failing-half pre-state identity reconciliation

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@84aabef0f199fc8d1136f7ef66d90fba15033ffd`

Parent authority:

- NLGLOB13B: all 7 frozen O05/TG target trajectories still fail accepted-state retention admissibility at h/4;
- NLGLOB13C: raw overshoot contraction is observed in 7/7 h/2 -> h/4 pairs, with median ratio about 0.462, but qualification is blocked because the frozen same-pre-state fingerprint fails in 2/7 pairs.

## Purpose

NLGLOB13C1 determines whether the two identity failures reflect:

1. a real rollback/subdivision state-restoration defect; or
2. an insufficient aggregate fingerprint despite nodewise physical-state identity.

This workunit is diagnostic only.

No solver behavior, subdivision depth, acceptance rule or tolerance changes.

## Frozen target bank

Reuse exactly the seven NLGLOB13C target trajectories.

For each target pair compare the exact accepted pre-state presented to:

- the failing h/2 parent trial;
- the corresponding h/4 retry after rollback.

The comparison is nodewise.

## Frozen diagnostics

For each paired state record:

### Moisture

- max absolute nodewise difference:
  `D_theta_abs = max_i |theta_i^(h/2 pre) - theta_i^(h/4 pre)|`;
- max ULP-normalized nodewise difference:
  `D_theta_ulp = max_i |delta theta_i| / max(ulp(theta_i^p)+ulp(theta_i^q), tiny)`;
- volume-weighted absolute storage difference:
  `D_storage = sum_i f_i dz_i |delta theta_i|`.

### Pressure head

- max absolute nodewise difference:
  `D_h_abs`;
- max ULP-normalized nodewise difference:
  `D_h_ulp`.

### Surface state

- absolute ponding difference;
- top-head difference;
- route identity.

Also record finite-state status for both paired states.

## Frozen identity criterion

A pair is `NODEWISE_IDENTICAL` iff all hold:

1. both states finite;
2. route identity matches;
3. `D_theta_abs <= 1e-14`;
4. `D_storage <= 1e-12 cm`;
5. `D_h_abs <= 1e-10 cm`;
6. ponding difference <= `1e-12 cm`.

The ULP-normalized metrics are diagnostic only and do not gate identity, because near-zero or differently scaled head components can make raw ULP counts misleading.

These absolute bounds are fixed before result exposure and are several orders below any physical mass or head convergence authority used in the project.

## Frozen classifications

If 7/7 pairs are NODEWISE_IDENTICAL:

`NLGLOB13C1_PRESTATE_IDENTITY_CONFIRMED`.

If any pair has:

- `D_storage > 5e-8 cm`; or
- `D_h_abs > 1e-6 cm`; or
- route mismatch; or
- nonfinite state,

classify:

`NLGLOB13C1_PRESTATE_RESTORATION_DEFECT`.

Otherwise:

`NLGLOB13C1_PRESTATE_IDENTITY_MIXED`.

If the exact nodewise paired states cannot be observed:

`BLOCKED_NLGLOB13C1_IDENTITY_COVERAGE`.

## Consequence

If identity is confirmed for 7/7, NLGLOB13C may be re-evaluated under its original frozen contraction gates because the only coverage blocker is removed.

No contraction threshold may be changed.

A positive NLGLOB13C result would then authorize a separately preregistered bounded h/8 falsification.

If a restoration defect is found, temporal subdivision escalation is blocked until transaction semantics are repaired.

## Stop rules

Do not:

- execute h/8;
- change subdivision behavior;
- change the NLGLOB13C contraction gates;
- clip accepted theta;
- alter S0/R0, BALTOL02, MAXIT, backtracking or route physics.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 26, 30.

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
