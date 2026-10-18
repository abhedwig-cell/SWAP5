# Kalmthout atmosphere sensitivity, 2026-10-18

## Exact evidence

- Current-workbranch source: `de4358ce854335c8d5b3cb0e2a318a5eda48b095`.
- GitHub Actions run: https://github.com/abhedwig-cell/SWAP5/actions/runs/39116652486
- Artifact: `kalmthout-current-pilot`, id `12132726361`.
- Grid: 1024 500-m cells; one representative column simulated.
- Hourly ERA5 inputs: 2024-01-01 through 2026-10-01 inclusive, 24120 hours.
- Owner bootstrap qualification gate: PASS.
- Rutter 48-hour physical smoke: 48/48 hours PASS.
- Rainfall-only Rutter/Reference physics: 24120/24120 hours PASS.

## Atmospheric sensitivity

| Scale of SWAP PM evaporation demand | Completed hours | First failed hour | Solver rejections | Temporal rejections | Mass rejections |
| ---: | ---: | --- | ---: | ---: | ---: |
| 0.25 | 4334 | 2024-06-29T14:00 | 428 | 0 | 0 |
| 0.50 | 3185 | 2024-05-12T17:00 | 571 | 0 | 0 |
| 0.75 | 2486 | 2024-04-13T14:00 | 410 | 0 | 0 |
| 1.00 | 1645 | 2024-03-09T13:00 | 507 | 0 | 0 |

All four failures were `ADMITTED` profiles with `completed=false`, `committed=false`;
the failing hour had no rainfall and the reported solver status was 2 (`legacy-reference-retry` for all but 0.25, where last route was `not-run`).
The 0.25, 0.50, 0.75 and 1.00 failures occurred under daily PM reference ET of approximately
4.4953, 4.8847, 3.6281 and 1.9793 mm/d respectively.
Recent preceding accepted hours carried finite, near-roundoff mass residuals.

## Interpretation and next scientific gate

The failure is not explained by temporal-error or mass-admission tolerances. A stronger
evaporation demand causes earlier failure, consistent with cumulative drying and the dry
atmospheric boundary / Richards constitutive trajectory reaching a difficult regime.
This is a diagnostic association, not yet proof of a specific constitutive or boundary bug.

Do not weaken mass conservation or silently add water/evaporation caps to force completion.
Pin an accepted-state checkpoint just before first failure and record top-layer head,
water content, ponding, actual evaporation, atmospheric potential, top flux, bottom flux,
solver nonlinear route and candidate failure stage. Compare dry-top state/flux with
the SWAP 4.3.1 reference policy and qualify any fix against the permanent owner gate
and representative wet/dry transitions. RossFast is out of scope.

## Reproducibility

The 2026-10-18 diagnostic matrix run is a failed overall CI job *by design* while
any full-atmosphere case fails. The failure must not hide the independent successful
rainfall-only baseline. Earlier experimental `pure-flux preflight` was removed because
it changed the failure to hour 23 for all evaporation factors, including zero.
That modification has no positive scientific evidence and must not be promoted.
