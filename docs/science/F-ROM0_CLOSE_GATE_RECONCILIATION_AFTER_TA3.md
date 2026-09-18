# ROM-0 close-gate reconciliation through R3D4

## Purpose

This document binds the live ROM-0 evidence to the original preregistered close gates. Earlier intermediate results remain preserved, but the strongest non-conflicting authority governs each gate.

## Ownership

**PASS_WITH_RESEARCH_SCOPE.**

F-ROM0TA3 introduced the separate F-KT Reference-floor sample/candidate/commit path. Research code cannot directly publish an arbitrary solver candidate. R3D4 uses that same path for both the strict first attempt and the conditional accepted fallback. Failed attempts leave lineage, revision, committed time and physical state unchanged.

## Reproducibility

**PASS.**

F-ROM0TA4 qualified the retained 0.0008-day fixed-resolution candidate under exact restart/replay. All four B01/B14 TOP_PLUS/TOP_MINUS cases replayed bit-identically after restart, wrong-parameter restore failed closed, and no solver scratch continuation was required.

## Conservation

**PASS for retained Reference-floor trajectories.**

TA3/TA4/TA5 and the R3 diagnostic/qualification chain preserve the independent hard transaction mass gate of 1e-12 cm. R3D4's maximum absolute committed transaction mass residual is 8.673617379884035e-19 cm.

## Prescribed-head sample binding

**PASS.**

F-ROM0TA5 qualified mode-5 prescribed-head Reference-floor sampling for B01 and B14 without changing the kernel sample core, canonical interval runtime or Reference solver.

## Bidirectional lower-boundary reachability

**PASS under the qualified ROM research Reference policy; original fixed-total R3 remains a recorded no-go.**

The original frozen R3 control at 0.0008 d, 16 iterations and fixed 1e-12 cm/day total-balance rate criterion remains:
- B14 rise/fall: full-horizon PASS with directional separation;
- B01 rise: retry at step 11;
- B01 fall: retry at step 10.

R3D1 proved both B01 failures are RETRY_TOTAL_ONLY: zero local-balance flags, zero head flags, and only the signed total-column residual slightly exceeds the fixed total criterion.

R3D2 proved before any remedy that both integrated residuals lie inside the independently derived PUB-P2E21 prospective representation bound:
- bound = 8.881784197001252e-15 cm;
- rise residual = 8.4821039081362e-16 cm = 0.0955 of bound;
- fall residual = 1.2569500995596178e-15 cm = 0.14152 of bound.

R3D3 tested an always-on representation-bounded total criterion. It completed all four trajectories but failed the preregistered bit-level overlap-neutrality gate because it changed Newton stopping points before the original control failed. That policy is NO-GO.

R3D4 then qualified the stricter fail-closed policy:
1. compute the prospective representation bound from the accepted pre-solve state;
2. attempt the exact original R3 criterion first;
3. if it succeeds, commit the original candidate unchanged and forbid fallback;
4. only after an immutable failed attempt, independently classify the failure;
5. fallback is permitted only for RETRY_TOTAL_ONLY with integrated residual inside the pre-solve representation bound;
6. reattempt the same interval once on a fresh backend with only total_balance_tolerance=max(1e-12, B_rep/dt);
7. retain the unchanged hard 1e-12 cm transaction mass gate.

Observed R3D4 qualification:
- 51/51 original accepted overlap steps bit-identical;
- B01: exactly two fallbacks, one per direction;
- B14: zero fallbacks;
- 4/4 full trajectories complete;
- directional lower-storage and bottom-exchange ordering PASS for B01 and B14;
- O0/O2 bit identity PASS;
- no production/reference source mutation.

Decision: **R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_QUALIFIED** for this frozen ROM research Reference domain.

### Reconciliation of R3Q1/R3Q2

R3Q1/R3Q2 remain useful supporting evidence, but they use a weaker P2E budget-based endpoint-neutrality definition for an always-active representation policy. R3D4 preserves every original accepted overlap endpoint bit-for-bit and is therefore the stronger, governing ROM-0 lower-boundary authority. R3Q1/R3Q2 must not be used to relax R3D4's exact-overlap rule.

## Reference floor

**PARTIAL; vertical-resolution measurement is the only remaining scientific gate.**

The temporal fixed-resolution component is available and the 0.0008-day trajectory is restart/replay qualified.

The original ROM-0 preregistration still requires:
- B01:E1_NOMINAL_FLUX, 16x10 cm versus 32x5 cm;
- B14:E2_DRYING_FLUX, 16x10 cm versus 32x5 cm;
- same 160-cm physical profile;
- measure only, with no post-result accuracy threshold selection.

The vertical diagnostic is now authorized to preregister and execute.

## Production semantic mutation

**PASS_WITH_SCOPE.**

TA5 only widened the research sample admission guard from bottom mode 2 to already-supported bottom mode 5. R3D1-D4 are test/evidence work only. No production Reference default or general fallback policy is admitted.

## Current bounded-execution state

ROM-1A remains blocked until the vertical 16x10 versus 32x5 Reference-floor diagnostic is measured reproducibly and the six original ROM-0 close gates are re-adjudicated.

No threshold may be selected or retuned from the vertical result inside ROM-0.
