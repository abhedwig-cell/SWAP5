# PPA-WU05-C3A E2E05 closeout

Date: 2026-10-03
Status: RESEARCH_CLOSEOUT_DECISION_B
Branch: research/ppa-wu05c3a-e2e05-bofek-eligibility
PR: #1007

## Research question

Does the canonical-admitted PERF02 no-stress eligibility gate occur often enough across physically relevant dynamic hydraulic states to justify a broad production-performance expectation?

E2E05 uses the existing F-PE-BOFEK01 hydraulic trajectories only as a non-stationary accepted-state generator. The BOFEK01 solver, timestep policy and hydraulic results are unchanged. PERF02 is evaluated read-only after accepted Richards steps.

This is hydraulic/research characterization, not a BOFEK production catalogue, growing-season frequency estimate or MultiSWAP speed claim.

## Method

Screening materials: B01, B12, O05, O14.
Regimes: DRY, TRANSITION, MOIST, WET, POND.
Preregistered screening excludes four holdouts: B12/POND, O14/MOIST, O14/WET, O14/POND.

Root-demand scales: 0.001, 0.01, 0.1, 1.0. Both independent production carriers are scaled consistently:
- current w_root, used by MICRO;
- z0 w_root_z0, used by MACRO.

The oxygen soil construction was reconciled with the admitted parameter contract before the final evidence:
- waterfilm capacity term is derived from MVG theta_r, theta_s, alpha, n and m;
- gas diffusivity precompute is derived from MVG theta(-100), theta(-500), Campbell b and gfp100;
- no PERF02 production source or tolerance was changed.

## Invalid intermediate evidence retained as negative finding

Run 37125017055 is not valid demand-sweep evidence: the executable did not read the demand-scale command argument.

After that was fixed, the initial E2E05 fixture still had two research-fixture defects:
1. waterfilm_capac_term was hard-coded to 1 instead of using the production construction;
2. only w_root_z0 was scaled, while current w_root remained at full demand, so the supposed root-demand sweep did not scale MICRO root respiration.

Those intermediate zero-hit results must not be used as physical eligibility evidence.

A further reconciliation replaced the synthetic diffusivity precompute (term1=1, exponent=2, artificial gfp100) with the admitted production construction. Final conclusions below use only the post-reconciliation evidence.

## Final screening

Authority: run 37125862510.

Accepted states per demand scale: 142.

| demand scale | hits | fraction |
| --- | ---: | ---: |
| 0.001 | 65/142 | 45.77% |
| 0.01 | 65/142 | 45.77% |
| 0.1 | 46/142 | 32.39% |
| 1.0 | 0/142 | 0% |

Across all four scales: 176/568 = 30.99%. This pooled number is not a production frequency because the four demand scales are an experimental design, not a frequency-weighted workload.

Regime/material pattern:
- B01 at 0.001/0.01: DRY 8/8, TRANSITION 8/8, MOIST 8/8, WET 3/8, POND 0/15.
- B01 at 0.1: DRY 8/8, TRANSITION 8/8, MOIST 6/8, WET 0/8, POND 0/15.
- B12 at 0.001/0.01: DRY 8/8, TRANSITION 7/8, MOIST 4/8, WET 3/8. POND was held out.
- B12 at 0.1: DRY 8/8, TRANSITION 4/8, MOIST 2/8, WET 0/8.
- O14 at 0.001/0.01: DRY 8/8, TRANSITION 8/8. Wetter O14 cases were held out.
- O14 at 0.1: DRY 8/8, TRANSITION 2/8.
- O05: 0 hits at every scale and regime because n=2.887502 is outside the admitted PERF02 n<=2 analytical bound. This is a deliberate conservative false-negative region, not a physics failure.
- every screening case at 1.0 demand: 0 hits.

The screening therefore identifies a clear two-axis frontier: eligibility is favored by lower root demand and drier hydraulic state. Wetting removes eligibility before drying, and full fixture demand removes it throughout this bank.

## Mechanistic decomposition

The diagnostic decomposition showed why the first research fixture was misleading.

With the incorrect hard-coded waterfilm capacity term, both numerical Reference and conservative film calculations could become negative, causing the gate to fail before a meaningful MICRO comparison. Replacing it with the admitted MVG-derived term restored positive films.

The next decomposition showed that scaling only w_root_z0 made MACRO root term b tiny while MICRO still saw full current w_root. Thus c_micro remained large despite the nominal 0.001 scale. Scaling both carriers exposed the actual demand frontier.

Representative B01 states also show that the conservative film upper bound is larger than the numerically integrated Reference film, as intended. The bound therefore raises c_micro relative to Reference and loses some eligible states conservatively. The observed frontier is not explained by a single GFP threshold.

## Root-demand range context

The canonical PERF02 boundary falsification varied current and z0 root carriers independently from about 0.002 to 2.002 and found zero false skips. Therefore 0.01 and 0.1 lie inside the already falsified carrier range.

The typed production application fixture publishes root density [1.0, 0.8, 0.6] with the same crop respiration constants. Scale 1.0 is therefore an existing stress-oriented production-preservation fixture point, and it is ineligible here.

Repository evidence does not establish how often actual production crops occupy 0.01 or 0.1 relative demand. Physical plausibility of the numerical carrier range is therefore not equivalent to a production frequency distribution.

## Holdout

Expectation was persisted before holdout execution in PPA_WU05C3A_E2E05_HOLDOUT_PREREGISTRATION.md.

Final authority: run 37125862510.

Per 44 holdout accepted states per demand scale:
- 0.001: 1/44 hits;
- 0.01: 1/44 hits;
- 0.1: 0/44;
- 1.0: 0/44.

The only hits were O14/MOIST, 1/8 at 0.001 and 1/8 at 0.01.
B12/POND, O14/WET and O14/POND had zero hits at every scale.

The holdout supports the preregistered relation: wetter states strongly suppress eligibility, and 0.1/full demand do not recover in the held-out wet regimes. No holdout tuning was performed.

## Interpretation and decision

Decision B: PERF02 is a limited but potentially relevant niche, not a broad production shortcut.

The niche demonstrated by E2E05 is:
- n <= 2;
- low root-demand carriers;
- sufficiently dry to transitional hydraulic states, with material-dependent loss of eligibility as saturation is approached.

PERF02 remains worth keeping because canonical safety is already established and non-skip overhead is about 1%. E2E05 does not support a broad production-speed claim. It also does not support spending more effort now on tightening the eligibility waterfilm bound: the dominant limitation in this bank is the physical demand/wetness frontier plus the deliberate n>2 exclusion.

## Claim boundary

Do not infer from E2E05:
- growing-season PERF02 frequency;
- BOFEK production hit rate;
- MultiSWAP speedup;
- national performance gain.

A representative production workload with actual crop/root-density time series would be required for those claims.

## Next performance target

Shift effort to the remaining full Bartholomeus stress route, approximately the oxygen ON versus OFF E2E increment already observed in E2E02.

Profile exact-preserving cost attribution before new approximation:
- PERF01 Reference waterfilm;
- MICRO evaluations;
- scalar residual/bisection;
- per-node response assembly;
- runtime/application overhead;
- repeated calculations outside the factor provider.

Prefer exact-preserving call elimination or reuse. Do not modify admitted PERF01/PERF02 without new falsifying evidence.

Research code remains on PR #1007 and is not an automatic canonical merge candidate.
