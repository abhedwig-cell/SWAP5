# PUB-GC accuracy and reference-adjudication contract

Status: **prospective decision rule; no primary result is encoded here**

Publication owner: `PUB-GC`

Purpose: separate three questions that must not be conflated:

1. is a numerical reference sufficiently refined to act as a comparator?
2. is one coupling method numerically closer to that reference than another?
3. is the remaining error small enough to call a method practically adequate for a stated use?

The first two can be answered in controlled dimensionless/numerical terms. The third requires an explicitly stated application scale and must not be manufactured from the observed method results.

## 1. Reference admission

A candidate finest `GC-REF-A` trajectory is admitted only when the final nested refinement step is stable.

For a three-level ladder `L0, L1, L2`, define the final refinement differences from `L1` to `L2`:

```text
delta_h_ref  = max_t |h_L2(t) - h_L1(t)|
delta_Q_ref  = |Qcum_L2 - Qcum_L1|
delta_X_ref  = selected SWAP state/profile norm difference
```

and retain mass/action-reaction diagnostics independently.

Reference stability is not inferred from a small coupling residual alone.

The case manifest must freeze absolute reference-stability tolerances before running the ladder. Where a later primary adequacy tolerance `T` exists for the same observable, use:

```text
T_ref <= 0.1 T
```

unless a stricter rule is preregistered.

If no scientifically defensible absolute adequacy tolerance exists yet, reference construction may still proceed as `PROSPECTIVE_SUPPORTING`, but the reference cannot be used to label a production/test method “adequate”.

## 2. Method error against reference

For any tested method `M`, report absolute errors first:

```text
E_h_abs(M) = max_t |h_M(t) - h_REF(t)|
E_h_terminal_abs(M) = |h_M(T) - h_REF(T)|
E_Q_abs(M) = |Qcum_M - Qcum_REF|
```

For selected SWAP states, report a declared norm with units and its exact state members.

Never report only percentages.

## 3. Cancellation-safe normalized exchange error

A cumulative net exchange can be near zero after opposing recharge/capillary episodes. Therefore

```text
|Qcum_M-Qcum_REF| / |Qcum_REF|
```

is not a safe universal metric.

For trajectories with multiple accepted windows, define the reference gross transferred-water scale:

```text
Qgross_REF = sum_n |Q_REF,n|
```

and normalized exchange error:

```text
E_Q_norm(M) = |Qcum_M-Qcum_REF| / Qgross_REF
```

only when `Qgross_REF > 0`.

If `Qgross_REF = 0`, normalized exchange error is unavailable and the absolute error is authoritative.

Also retain the signed cumulative error to distinguish systematic bias from cancellation.

## 4. Head-error normalization

For controlled GW-A cases define the reference dynamic head scale:

```text
Hdyn_REF = max_t h_REF(t) - min_t h_REF(t)
```

When `Hdyn_REF > 0`:

```text
E_h_norm(M) = E_h_abs(M) / Hdyn_REF
```

If the reference head is effectively static, normalized head error is not reported; absolute error remains authoritative.

A small normalized error must not hide a large absolute error.

## 5. H2 comparison rule

For `PUB-GC-E2`, `GC-M2-WHOLE` and `GC-M1-TERMINAL-END` must be evaluated against the same admitted `GC-REF-A` trajectory.

Primary H2 comparison variables are:

```text
Delta_E_Q = E_Q_abs(TERMINAL) - E_Q_abs(WHOLE)
Delta_E_h = E_h_abs(TERMINAL) - E_h_abs(WHOLE)
```

with normalized counterparts where defined.

Interpretation:

- positive `Delta_E`: whole-window arm is closer to the numerical reference for that metric;
- zero/roundoff-bounded `Delta_E`: no resolved difference;
- negative `Delta_E`: terminal arm is closer for that metric.

No post-hoc tolerance is required to report the paired numerical difference.

A claim of **practical materiality** requires a separate preregistered application-level tolerance.

## 6. H3 convergence rule

For `PUB-GC-E3`, method errors are plotted against coupling-window duration.

Evidence for convergence requires:

- decreasing error under at least two successive predeclared refinements over a stated regime;
- no hidden change in subsystem solver, forcing, origin policy or acceptance criteria;
- stable `GC-REF-A` comparator;
- conservation reported independently.

Do not infer formal convergence order unless the tested ladder exhibits a credible asymptotic regime and the order calculation is preregistered.

A monotone decrease is not guaranteed and is not required to preserve the result; non-monotone behaviour is reportable evidence.

## 7. Practical adequacy

A method may be labelled practically adequate only for a named case/use if absolute tolerances are frozen before the held-out primary method run.

Candidate tolerances may concern:

- groundwater head in metres;
- cumulative interface exchange in cm or m3 over a declared area;
- selected SWAP profile/state variables;
- coupled mass residual.

The justification must come from one of:

1. measurement/resolution limits relevant to the intended application;
2. operational/model-use decision resolution;
3. a pre-existing project/model acceptance criterion;
4. a published domain standard or defensible literature convention.

A tolerance chosen because one method happens to pass and another happens to fail is prohibited.

Until such justification exists, report numerical closeness and relative method differences without the word “adequate”.

## 8. Conservation is not an accuracy trade

Interface action/reaction and committed mass invariants remain hard validity checks.

A method cannot compensate a conservation failure by having small head error, and a conservative method is not automatically temporally accurate.

Report at least:

```text
interface_action_reaction_residual
SWAP_mass_residual
groundwater_storage_balance_residual
combined_coupled_balance_residual
```

with sign and units.

## 9. Primary-case chronology

Permitted order:

1. qualify comparator and `GC-REF-A` machinery;
2. run separately labelled screening/reference-construction work;
3. select cases by a frozen selection rule;
4. construct and admit stable case-specific references;
5. freeze exact held-out method matrix and any practical adequacy thresholds;
6. execute primary E2/E3 methods once under that manifest;
7. preserve null/negative/non-monotone outcomes.

Screening values may guide case selection but may not be relabelled as held-out primary evidence.

## 10. Publication firewall

- reference-root efficiency is not a PUB-GC claim;
- tangent/response acceleration belongs to `PUB-RC`;
- RossFast/Newton accuracy-cost belongs to `PUB-SQ`;
- software migration/evidence architecture belongs to `PUB-ME`;
- N:1 hydrologic upscaling value belongs to `PUB-SG`.

## 11. Next permitted action

- construct one or more separately labelled `GC-REF-A` screening trajectories;
- use nested coupling-window ladders and this contract to determine which cases possess a stable numerical reference;
- do not run held-out E2/E3 primary method comparisons until their exact reference authority and, where needed, practical absolute tolerances are frozen.
