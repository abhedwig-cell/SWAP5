# TAB-HYD-KX01 — KSATEXM generated-provider representation preregistration

Date: 2026-09-23

Status: **PREREGISTERED_RESEARCH_ONLY**

## Trigger

F-TAB02 production slices A-E are qualified on `work/f-tab02-generated-k0-provider`, but final whole-Hupsel Gate F stops because the exact admitted M1-C3 Hupsel profile enables the already-qualified F-SI39 KSATEXM extension in both hydraulic layers.

Controlling production blocker:

- `integration/f-tab/F-TAB02_F_BLOCKER.json`
- status: `BLOCKED_SCOPE_EXACT_M1_PROFILE_REQUIRES_KSATEXM_OUTSIDE_FTAB02`

This research slice does not widen F-TAB02. It determines whether a separately qualified generated representation can preserve the already-admitted F-SI39 constitutive semantics.

## Authorities

Current canonical:

- `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`.

F-SI39 authority:

- `src/solver/mod_b110_default_mvg_provider.f90`;
- `tests/fsi/test_fsi39_b110_ksatexm.f90`;
- F-SI39 is explicit opt-in through `ksatexm_extension_enabled`.

F-TAB02 evidence is input evidence only, not canonical authority.

## Scientific question

Can the generated raw-head400 K0 provider preserve the admitted F-SI39 KSATEXM conductivity relation without changing theta/C semantics, adding committed physical state, or reviving generic tabulated input?

## Frozen first candidate

Keep the qualified generated representation for theta/C and the ordinary MvG conductivity branch.

For nodes with F-SI39 active:

1. compute theta from the generated raw-head representation;
2. compute `relsat = (theta-theta_r)/(theta_s-theta_r)`;
3. if `relsat > relsat_threshold`, evaluate the exact admitted F-SI39 branch:

   `f = (relsat-relsat_threshold)/(1-relsat_threshold)`

   `K = f*KSATEXM + (1-f)*K_threshold`;

4. otherwise use the qualified generated ordinary-MvG K representation.

Consequences:

- no spline crosses the F-SI39 branch kink;
- saturated K is KSATEXM, not Ksat;
- the branch uses the same theta value returned by the generated provider;
- no new hydrological state is introduced;
- SWKIMPL remains 0; no dK/dh admission is implied.

## First qualification envelope

Use:

1. exact Hupsel upper and lower hydraulic parameter rows from the recovered exact M1-C3 profile;
2. F-SI39 canonical point oracles:
   - saturated K = KSATEXM;
   - lower-layer K at h=-1 cm = 153.81975964948478 cm/d;
   - below-threshold h=-5 cm extension is exact no-op;
3. dense pressure-head scan across the extension transition and the normal table domain.

Report separately:

- theta max abs;
- C max abs;
- log10(K) max abs;
- absolute and relative K error inside the KSATEXM-active branch;
- branch classification mismatches (analytical active vs generated active).

## Admission gate for next experiment

Proceed to Reference-Richards/FMR trajectory qualification only if:

- no branch-classification mismatch occurs on the dense scan except possibly at floating-point equality of the strict `>` threshold, which must be explicitly characterized;
- canonical F-SI39 point oracles pass;
- K remains finite, positive and continuous at the branch transition;
- theta/C stay in the existing raw-head400 error regime;
- no tolerance or solver policy is changed.

## Explicit exclusions

This slice does not admit:

- generic user-supplied tables;
- legacy `SWSOPHY=1`;
- SWKIMPL=1;
- any new KSATEXM physics;
- production changes on the F-TAB02 branch;
- a whole-Hupsel speedup claim.

## Decision rule

If the explicit-branch representation closes the constitutive gate, continue to a bounded typed Reference-Richards K0 trajectory with exact Hupsel KSATEXM parameters.

If it fails, characterize whether failure comes from theta interpolation moving the branch threshold or from the ordinary-MvG table branch. Do not tune acceptance tolerances after observing results.
