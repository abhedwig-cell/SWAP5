# F-PE-NLGLOB13C1 preregistration — failing-half pre-state identity reconciliation

Date: 2026-09-29

Status: `AMENDED_BEFORE_RESULTS`

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

For each target trajectory compare the exact accepted pre-state presented to:

- the failing h/2 parent trial;
- the **first h/4 child trial immediately after rollback of that failing h/2**.

This is the only h/4 trial that is required to share the h/2 parent origin.

If quarter 1 succeeds and quarter 2 later fails, the quarter-2 pre-state is expected to differ because it contains one legitimately accepted h/4 advance. Quarter-2 state difference is therefore a lineage diagnostic, not a rollback-identity failure.

The comparison is nodewise.

## Frozen diagnostics

For each h/2-parent versus first-quarter retry pair record:

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

If 7/7 h/2-parent versus first-quarter retry pairs are NODEWISE_IDENTICAL:

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

If identity is confirmed for 7/7, the transaction/rollback concern is removed.

For trajectories where the first h/4 child itself fails, the original NLGLOB13C same-origin contraction pair remains directly usable.

For trajectories where first-quarter h/4 succeeds and quarter 2 later fails, the original terminal-failure pair is not a same-origin scaling pair. Those cases require a separately preregistered C2 same-origin h/4 admissibility probe from the restored h/2 parent state.

C1 therefore does not itself reclassify NLGLOB13C or authorize h/8. No contraction threshold may be changed.

If a restoration defect is found, temporal subdivision escalation is blocked until transaction semantics are repaired.

## Amendment rationale

This amendment is persisted before any NLGLOB13C1 result exposure. The parent NLGLOB13B execution order shows that a terminal quarter-2 failure is preceded by a successfully accepted quarter-1 state. Comparing that quarter-2 origin with the original h/2 parent origin would incorrectly classify legitimate temporal evolution as rollback drift. The frozen identity target is therefore corrected to the first child trial after rollback, which is the actual transaction-semantics question.

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
