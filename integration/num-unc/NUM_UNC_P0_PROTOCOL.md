# NUM-UNC P0 preregistered kill-pilot protocol v0.1

Date: 2026-09-19  
Workstream: NUM-UNC  
Repository observation baseline: `integration/f-ci-canonical@187e30153c890151768e929170d14bb22af1d86d`  
Research branch: `research/num-unc-p0`

## Scientific aim

P0 tests whether physically identifiable hydrological transition regimes can amplify or preserve initially small differences between independently study-admissible numerical realizations sufficiently to change an event- or regime-level scientific inference while governing equations, physical parameters, forcing and process configuration remain fixed.

P0 is a kill-pilot. A null result is retained. The protocol must not be modified after inspecting primary inference outcomes except through a versioned amendment that identifies which analyses become exploratory.

## Primary research question

Which hydrological transition regimes amplify study-admissible numerical perturbations into non-invariant event- or regime-level scientific inferences in a process-based vadose-zone model?

Secondary question: can inferential fragility be described by physical state and transition proximity rather than by the identity of a numerical setting?

## Novelty firewall

P0 does not claim novelty from:

- timestep sensitivity;
- nonlinear tolerance sensitivity;
- solver sensitivity;
- numerical error in Richards' equation;
- groundwater coupling error;
- threshold sensitivity by itself;
- a management decision changing under model discretization;
- numerical uncertainty entering an uncertainty budget.

The candidate contribution is narrower: hydrological transition dynamics must amplify or preserve differences among otherwise admissible numerical trajectories, and that dynamics must be necessary to explain a change in scientific inference.

A threshold flip without trajectory amplification is classified as `THRESHOLD_PROXIMITY_ONLY`, not support for the primary hypothesis.

## Repository authority used as infrastructure

P0 inherits, without claiming novelty from:

- the Reference Richards route and its existing solver contract;
- transactional candidate/accept/retry/rollback semantics;
- typed state and mass diagnostics;
- the existing Reference-only numerical calibration work under PUB-P2;
- root-water uptake and dynamic top-boundary process implementations within their qualified scope.

P0 does not alter production or reference source.

The existing P2E08 Reference calibration is particularly important. It found non-monotone numerical validity over the tested timestep ladder and selected `0.0064 day` as the first preregistered coarse level with 54/54 valid Reference cases paired with `0.0032 day` half steps. Therefore P0 explicitly rejects the assumption that a smaller timestep is automatically a more authoritative solution.

## P0a treatment: temporal policy only

P0a varies only temporal resolution. Nonlinear convergence tolerances, solver identity, grid, constitutive policy, physical parameters, source/sink formulation and process switches are held fixed.

Primary study temporal configurations:

- `N0`: requested target/ceiling `dt = 0.0064 day`;
- `N1`: requested target/ceiling `dt = 0.0032 day`.

These values are inherited from the independent P2E08 Reference-only calibration surface rather than selected from NUM-UNC outcomes.

A finer diagnostic probe at `0.0016 day` may be executed only as a numerical-validity diagnostic. It is not automatically treated as truth and it does not replace N0/N1 merely because it is finer.

P0b may add convergence-tolerance variation only if P0a survives its kill criteria. P0b requires a separate preregistration before execution.

## Study-admissibility

A numerical trajectory can enter the inference comparison only if all of the following hold:

1. every required nonlinear solve reports convergence;
2. no terminal iteration-cap or retry-exhaustion outcome occurs;
3. required mass diagnostics are complete and finite;
4. the applicable hard mass gate passes;
5. no rejected candidate is used as accepted state;
6. state variables remain finite and inside the declared constitutive/application envelope;
7. execution is deterministically reproducible;
8. no known implementation defect or fallback anomaly explains the difference;
9. the same physical case, grid, forcing history and final time are used for all compared configurations.

A failed configuration is recorded as numerical failure evidence. It cannot support the claim that admissible numerical uncertainty changed scientific inference.

## Reference concept

P0 does not define one arbitrarily fine run as exact truth.

The primary object is the admissible numerical set

[
N_{adm}(x) = \{n: n \text{ passes all study-admissibility gates for physical case }x\}.
]

Inference invariance is evaluated over that set.

Reference-only diagnostics may use an adjacent timestep ladder to estimate local self-disagreement, but the ladder is screened for numerical validity before scientific endpoints are examined. Non-monotone validity must remain visible in the evidence.

## Spatial-control gate

The scientific comparison uses one fixed 16 x 10 cm vertical grid inherited from the existing controlled publication harness unless the spatial-control gate rejects it.

Before primary P0 execution, perform one independent grid-refinement control for the selected discovery soil and transition family. The refined grid is used only to test whether the primary event/regime inference is already spatially unstable.

If the primary inference changes under the spatial-control refinement, P0 is blocked until a grid with stable inference is prospectively frozen. Spatial grid is not then counted as a P0 numerical treatment.

## Hydraulic materials

Discovery material: `B01`.

Canonical material parameters:

- theta_r = 0.02;
- theta_s = 0.427494;
- alpha = 0.021659 cm^-1;
- n = 1.734737;
- Ksatfit = 31.225016 cm/day;
- Ksatexm = 312.25016 cm/day;
- lambda = 0.98087.

Replication material if P0a survives discovery: `O14`.

Canonical material parameters:

- theta_r = 0.01;
- theta_s = 0.393878;
- alpha = 0.003288 cm^-1;
- n = 1.616573;
- Ksatfit = 2.495984 cm/day;
- Ksatexm = 4.991968 cm/day;
- lambda = 0.514012.

O14 is selected prospectively because it provides a strong hydraulic contrast to B01, especially in alpha and saturated conductivity. It is not selected based on NUM-UNC response.

## Experiment A: drought-stress transition

### Physical hypothesis

Small water-state differences near drought onset may be preserved or amplified through the feedback

[
h \rightarrow \alpha_{dry} \rightarrow S_{root} \rightarrow \theta \rightarrow h.
]

### Fixed controlled structure

- discovery material B01;
- 16 homogeneous cells x 10 cm;
- top boundary non-ponded during drydown except for the rescue pulse;
- prescribed lower-boundary condition selected and frozen before continuation;
- fixed emerged crop;
- rooted depth 60 cm unless the qualified root profile selected below requires a narrower admitted envelope;
- cumulative root distribution fixed before primary execution;
- potential transpiration fixed during the controlled drydown.

Root-water-uptake parameters must come from one repository-qualified/provenance-complete profile. The selection rule is: use the first qualified active-crop profile encountered in the current canonical evidence chain that supplies all required `hlim3l`, `hlim3h`, `hlim4`, `adcrl` and `adcrh` values without reconstruction from undocumented defaults. Freeze that profile before transition continuation. If no such profile exists, Experiment A is blocked rather than populated with invented Feddes parameters.

### Transition continuation

Continuation variable: initial effective saturation `Se0`.

Use only N0 to locate the bracket, without inspecting N1 outcomes.

1. evaluate a fixed prospective grid of Se0 values;
2. identify adjacent cases for which stress onset changes from before to after a fixed rescue-pulse time;
3. if no bracket exists, extend the prospective Se range according to the manifest rule;
4. bisect using N0 only until the event-order boundary is located to the frozen continuation tolerance;
5. define A-, A0 and A+ at fixed offsets from that boundary;
6. freeze the three physical cases;
7. only then execute N1 and compare scientific inferences.

Primary inference:

`STRESS_BEFORE_RESCUE` versus `STRESS_AFTER_RESCUE`.

Secondary endpoints:

- first drought-reduction time;
- first time actual/potential uptake < 0.95;
- integrated transpiration deficit;
- recovery time;
- number of stress-hours/days.

## Experiment B: capillary-support transition

### Physical hypothesis

Near the loss of hydraulic connection between groundwater and the root zone, small numerical state differences may alter the timing or persistence of capillary support and thereby amplify later stress differences.

### Scope firewall

Use a prescribed-head lower boundary. Do not use MODFLOW, Groundwater Coupling v1 coupling-window variation, outer coupling tolerances or predictor-corrector treatment as numerical factors.

Continuation variable: prescribed lower-boundary head / groundwater-support state.

The same prospective continuation discipline as Experiment A applies: N0 locates B-, B0 and B+ before N1 outcomes are inspected.

Primary inferences:

- stress before/after the fixed rescue/event time;
- recovery inside/outside a fixed recovery window;
- bottom-exchange sign class using a deadband fixed from numerical self-disagreement before the primary comparison.

Secondary endpoints:

- cumulative upward bottom contribution;
- stress duration;
- root-zone storage;
- actual/potential uptake ratio;
- bottom-flux reversal time.

## Experiment C: surface-regime transition

### Physical hypothesis

Near the transition between atmospheric flux control and surface-head/ponding control, a small numerical state difference may be dynamically amplified through boundary switching.

### Isolation

Root uptake is off in the first C experiment so the boundary-switching mechanism is isolated.

Continuation variable: precipitation-pulse intensity, represented as a multiplier of the frozen material conductivity scale.

Initial prospective bracket:

[
q_{pulse} \in [0.25, 2.0] K_{satfit}.
]

If both endpoints have the same boundary regime, expand geometrically by factor 2 within documented model validity until a flux/head bracket is obtained or the experiment is declared `NO_TRANSITION_IN_DECLARED_ENVELOPE`.

N0 alone locates C-, C0 and C+. N1 is executed only after those cases are frozen.

Primary inference:

`NO_PONDING_EVENT` versus `PONDING_EVENT`.

Secondary endpoints:

- ponding onset;
- ponding duration;
- runoff occurrence if active within the admitted route;
- cumulative infiltration;
- bottom-response timing.

## Pairwise trajectory divergence

No single run is privileged as truth for the primary amplification calculation.

For two admissible configurations a and b define

[
D_{\theta}^{a,b}(t)
=
\sqrt{
\frac{\sum_i dz_i[\theta_i^a(t)-\theta_i^b(t)]^2}
{\sum_i dz_i}
}.
]

Analogous pairwise distances are recorded for pressure head, root extraction, actual transpiration, bottom flux and ponding where applicable.

For each preregistered transition time t*, define pre- and post-transition windows.

The pilot classifies an `AMPLIFICATION_SIGNAL` only when:

1. post-transition divergence exceeds pre-transition divergence by at least factor 4;
2. post-transition divergence exceeds twice the independently estimated local reference/self-disagreement floor for the same metric;
3. the increase is not caused by a failed/rejected attempt or unequal physical forcing;
4. a primary or secondary hydrological endpoint changes in the same interval.

Factor 4 is a preregistered pilot discriminator, not a universal hydrological constant. Continuous divergence curves are always preserved.

## Outcome classes

Each frozen physical case is assigned exactly one primary class:

- `INVARIANT`: all study-admissible configurations give the same primary inference;
- `THRESHOLD_PROXIMITY_ONLY`: primary inference differs but no qualifying hydrological amplification signal exists;
- `AMPLIFIED_INFERENCE_FRAGILITY`: primary inference differs and the amplification criteria are met;
- `NUMERICAL_FAILURE_ONLY`: differences arise only because one or more configurations fail admissibility;
- `UNRESOLVED_REFERENCE_ENVELOPE`: numerical validity/reference evidence is insufficient to interpret the comparison.

## Logging

Every run must preserve:

### Provenance
- repository commit;
- experiment and case ID;
- material parameter set;
- grid;
- forcing hash;
- process switches;
- numerical configuration;
- compiler/runtime identity where relevant.

### Accepted state time series
- time;
- pressure_head(:);
- water_content(:);
- ponding_depth;
- groundwater_level where meaningful;
- root-zone storage;
- total profile storage.

### Flux and process time series
- requested and actual top flux;
- top-boundary regime;
- surface head;
- runoff;
- bottom flux;
- cumulative top/bottom exchange;
- potential root uptake;
- actual root uptake;
- drought reduction;
- drought-reduction factors where available.

### Numerical execution
- requested and actual accepted timestep;
- solve status;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- alternative linear-solver calls;
- internal retries;
- transaction retries and rollbacks where exposed;
- integrated mass residual;
- native balance-rate residual where exposed.

Rejected attempts may be stored as diagnostic records but cannot enter accepted hydrological trajectories.

## P0a run order

The order is fixed to limit researcher degrees of freedom:

1. freeze protocol and machine-readable manifest;
2. bind qualified root-uptake parameter profile or block Experiment A;
3. implement output schema and harness without running the N1 primary comparison;
4. run spatial-control gate;
5. locate A/B/C transition brackets with N0 only;
6. freeze A-/A0/A+, B-/B0/B+, C-/C0/C+;
7. freeze local numerical-validity/self-disagreement floors without evaluating inference flips;
8. execute N1;
9. classify admissibility;
10. compute primary inferences;
11. compute amplification;
12. assign outcome classes;
13. replicate surviving mechanisms in O14 without changing the protocol.

## Kill criteria

P0a does not support a standalone NUM-UNC mechanism claim when:

K1. all study-admissible N0/N1 runs are inference-invariant;
K2. inference changes occur only for inadmissible numerical trajectories;
K3. all inference changes classify as THRESHOLD_PROXIMITY_ONLY;
K4. spatial-control instability is of the same size/order as the temporal effect and cannot be separated prospectively;
K5. apparent amplification disappears after correct accepted-state alignment;
K6. a software defect, unequal forcing, hidden process change or inconsistent case construction explains the result;
K7. the surviving discovery mechanism fails prospectively in the hydraulic-contrast replication material;
K8. a later literature audit identifies a direct prior study with the same admissible-numerics, physical-transition-amplification and inference-invariance design.

## Go rule

Proceed from P0a to a larger NUM-UNC study only if at least one transition family yields `AMPLIFIED_INFERENCE_FRAGILITY` in B01 and the same mechanism survives the preregistered O14 replication.

A discovery-only positive result remains `PROMISING_BUT_UNREPLICATED`.

## Claim ceiling

If P0a succeeds, the strongest allowed pilot-level claim is:

> Within the investigated process-based vadose-zone system, a specified hydrological transition regime amplified differences between independently study-admissible temporal realizations sufficiently to change a preregistered event- or regime-level inference, and the mechanism replicated under a contrasting hydraulic material.

P0a does not establish universality, probability distributions for numerical algorithms, full uncertainty decomposition, solver-substitution admissibility, or coupled MODFLOW generality.
