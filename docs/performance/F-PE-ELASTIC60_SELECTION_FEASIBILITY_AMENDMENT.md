# F-PE-ELASTIC60 — blind profile-selection feasibility amendment

Date: 2026-09-30

Status: SELECTION_FEASIBILITY_CORRECTION_BEFORE_NUMERICAL_HOLDOUT

Parent preregistration:
`F-PE-ELASTIC60_DIRECT_DEFECT_HOLDOUT_PREREGISTRATION.md`.

## Trigger

The first ELASTIC60 workflow stopped before any numerical holdout case executed.

The preregistered rule required the second unique eligible profile from each of
the same first four horizon-count classes used by ELASTIC55.

The frozen BRO artifact contains only one eligible unique profile in
horizon_count class 1 after applying the frozen eligibility/diversity rules.

Therefore class 1 has no blind second candidate.

No ELASTIC60 solver, indicator, D1/D2 or endpoint result existed when this
amendment was made.

## Corrected blind selection

Preserve all original eligibility and diversity rules.

Before horizon-class selection, exclude all development profiles:
- 90116260;
- 11060;
- 10260;
- 8016;
- 3030.

Then:

1. enumerate eligible profiles in ascending profile id;
2. retain only the first profile per unique diversity key;
3. partition the remaining candidates by horizon_count;
4. order non-empty horizon-count classes ascending;
5. select the smallest profile id from each of the first four remaining
   non-empty horizon-count classes;
6. fail closed if fewer than four classes remain.

This remains deterministic, source-only and independent of any ELASTIC60
numerical result.

## Unchanged holdout authority

Unchanged:
- D1 = DEFECT_HEAD_INF;
- D2 = 2*DEFECT_HEAD_INF;
- 0.01-cm head limit;
- 1e-5 theta limit;
- C-SAFE logic;
- physical/numerical bank;
- no scaling/refit;
- all safety gates.
