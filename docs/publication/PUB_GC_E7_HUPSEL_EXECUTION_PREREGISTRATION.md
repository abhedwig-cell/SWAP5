# PUB-GC E7 preregistration — Hupselbrook realistic application

## Status

**PREREGISTERED BEFORE E7 COUPLED OUTPUT**

Date: 2026-09-18.

Publication line: PUB-GC / COUPLE.

Canonical basis at preregistration: `integration/f-ci-canonical@f7bd4d470d14bdedcbe60ef2b674fce4f1575e9c`.

## Purpose

E7 tests whether the solver-autonomous coupling contract remains usable and scientifically interpretable under an independently authoritative SWAP application with authentic forcing and active process composition. It is an external-validity experiment, not a search for the largest possible loose-versus-strong coupling difference.

Hupselbrook is selected before any E7 coupling result because the repository already contains exact SWAP 4.3.1 application authority, a three-year historical run, typed application-process qualifications and transaction/replay evidence.

## Hard execution prerequisite

E7 coupled execution is forbidden until M1-C3 closes its existing final gate:

> one final whole-Hupsel file-driven adapter execution against the exact authorized SWAP 4.3.1 distribution.

The frozen distribution SHA-256 is `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and the expected size is 8,959,314 bytes.

If the raw distribution bytes remain unavailable to the execution environment, E7 remains blocked. Historical outputs or partial process qualifications are not substituted for this gate.

## Standalone case authority before selection

After M1-C3 closes, run the complete typed Hupsel application without MODFLOW coupling over the authoritative historical period. Before any coupled result is generated, verify:

- exact application-route availability for every selected interval;
- complete standalone mass accounting;
- agreement with the controlling whole-Hupsel reference evidence at the already governed precision;
- no hidden legacy runtime supplying process state outside the typed participant;
- lower coupling-plane datum and units are defined for the selected profile.

A failure of this standalone gate stops E7.

## Candidate-day population

The selection population consists of complete civil days in the authoritative Hupsel simulation after any spin-up period that is explicitly documented by the controlling application authority. If no spin-up interval is documented, no days are removed under a newly invented spin-up rule.

A day is eligible only if the typed standalone participant completes every application interval required to reconstruct that day and returns complete water-balance accounting.

## Frozen standalone dynamics score

Episode selection uses standalone quantities only. For every eligible day d calculate:

```text
I(d) = total precipitation + irrigation input
E(d) = total actual evapotranspiration / root-water extraction reported by the authoritative daily balance
D(d) = total drainage outflow magnitude
S(d) = |storage_end - storage_start|
```

All quantities are daily integrated depths in the native authoritative balance basis. If a named term is represented by several authoritative components, their documented water-balance sum is used; no component is added because it correlates with a later coupling result.

For each metric m in {I,E,D,S}, transform the eligible-day values to empirical percentile ranks `R_m(d)` in [0,1]. Ties receive the mean rank. The dimensionless standalone dynamics score is

```text
Phi(d) = 0.25 * [R_I(d) + R_E(d) + R_D(d) + R_S(d)].
```

Equal percentile weighting is used to avoid unit-scale dominance and is frozen before coupled output.

## Frozen episode selection

Select exactly two primary E7 days:

1. **median-dynamics control**: the eligible day minimizing `|Phi(d) - median(Phi)|`;
2. **high-dynamics day**: the eligible day with maximum `Phi(d)`.

Ties are resolved by earliest chronological date.

The two selected dates, all four raw metrics, percentile ranks and `Phi` values are persisted before MODFLOW coupling is constructed.

If both rules select the same day, the control becomes the next-nearest day to the median score, again using earliest-date tie-breaking.

No selected date may be replaced because its coupled result is weak, inconvenient or fails to converge.

## Coupling-window rule

E7 uses the exact event-aligned typed application interval boundaries already required by the standalone Hupsel execution as the primary coupling windows. It does not merge intervals after inspecting coupled behaviour.

This choice makes E7 an application-transferability test rather than a second coupling-window optimization experiment; E3 already characterizes synthetic window sensitivity.

If the production participant cannot expose a prescribed-head coupling trial on one of these authoritative intervals, that interval is recorded as a component-domain failure. Numerical tolerances, retry budgets and event boundaries are not changed to force a valid trial.

## Groundwater model rule

Groundwater parameters are not calibrated against E7 loose-versus-strong differences.

Priority is frozen as follows:

1. if an independently authoritative Hupsel groundwater geometry and parameter set is already available in canonical evidence before the first E7 coupled run, use that set and record its provenance;
2. otherwise reuse the already qualified local MODFLOW conceptual fixture/parameterization, re-anchored only through the explicit coupling-plane datum required by the Hupsel participant.

Under rule 2 the manuscript must describe E7 as a **real-forcing hydrological demonstration**, not as regional Hupsel groundwater validation.

## Compared coupling modes

For each selected day execute from identical accepted SWAP and groundwater origins:

### Loose / sequential

- materialize the normal SWAP predictor response for each event-aligned window;
- solve the groundwater component with that response held fixed;
- evaluate one SWAP prescribed-head corrector at the resulting groundwater head;
- record residual, head, exchange, storage and work;
- do not use the corrector to re-iterate the window.

### Strong / production coupling

- use the production finite-window coupling service;
- replay every SWAP corrector from the immutable accepted origin of that window;
- retain MODFLOW inside its qualified prepared solve;
- require the existing component and coupled acceptance criteria;
- publish accepted state and interface mass exactly once.

No alternative algorithm is chosen after seeing which gives the more interesting result.

## Primary outputs

For every coupling window and for both selected days persist:

- loose and strong groundwater head;
- loose and strong SWAP-groundwater exchange;
- loose interface residual and final strong residual;
- loose-to-strong head and exchange correction;
- SWAP storage change;
- accepted whole-window interface transfer;
- component evaluation counts and wall-clock time;
- component failure/retry diagnostics;
- SWAP, MODFLOW and interface-ledger authority before and after publication;
- combined-system interface mass cancellation after sign/unit normalization.

Daily aggregates are derived from accepted window outputs only.

## Primary interpretation

E7 does not require strong coupling to produce a large correction.

Possible reportable outcomes include:

- **REALISTIC_WEAK_FEEDBACK**: realistic forcing remains close to the loose solution;
- **REALISTIC_MATERIAL_FEEDBACK**: strong coupling produces a materially larger continuous head/exchange correction than the synthetic E3 control;
- **REALISTIC_COMPONENT_DOMAIN_LIMIT**: authentic application windows expose participant-admission limits before coupled iteration can be interpreted;
- **REALISTIC_COUPLING_LIMIT**: both components remain valid but the production outer coupling cannot meet its unchanged criterion.

Continuous effects are reported. No post-hoc threshold is introduced to label a head correction scientifically important.

## Stop rules

- Do not run E7 before M1-C3 whole-Hupsel closure.
- Do not select dates using coupled output.
- Do not replace a selected date after a weak or negative result.
- Do not relax solver, temporal, mass or coupling tolerances.
- Do not shorten or merge event intervals post hoc to rescue a failed coupled trial.
- Do not substitute a synthetic fixture and call it realistic.
- Do not infer regional validation from the fallback conceptual MODFLOW fixture.

## Relation to E8 and SCALE

E7 is sufficient to test realistic transferability of the coupling contract. E8 regional scaling remains optional and follows only after E7. Physical validity of heterogeneous N:1 aggregation is explicitly excluded and belongs to PUB-SG / SCALE.


## Execution-prerequisite closure note — 2026-09-18

The hard M1-C3 prerequisite defined above has now passed and is canonically admitted. This note does not alter any preregistered E7 selection, groundwater-model, comparison, interpretation or stop rule.

Authority: PR #313, merge `d91c159c3685d8eedc7c94afc38edf827408c1de`; formal M1 closeout PR #316; `M1_CLOSED_CURRENT_CANONICAL`.
