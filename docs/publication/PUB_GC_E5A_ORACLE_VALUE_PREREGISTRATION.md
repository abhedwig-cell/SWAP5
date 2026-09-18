# PUB-GC / PUB-RC E5a preregistration — zero-cost oracle information-value upper bound

## Status

**PREREGISTERED BEFORE E5a EXECUTION**

Date: 2026-09-18.

Research branch:

`work/pub-gc-e5a-oracle-upper-bound`

Canonical branch at preregistration:

`integration/f-ci-canonical`

E5a is the first computational falsification gate after PUB-GC E4 response identity.

E4 numerical evidence is already frozen and successful. Admission of the E4 documentation into canonical may still be in progress when this preregistration is created; E5a execution must not begin until the E4 result and its response values are available on the execution baseline.

No production coupling semantics, SWAP physics, MODFLOW physics, transaction tolerances, retry budgets or solver tolerances are changed by this study.

---

## 1. Scientific question

E5a asks a deliberately adversarial upper-bound question:

> If a coupler is given the actual local finite-window head-to-exchange response `J_R` for free, does that information materially reduce full-window SWAP work or enlarge the convergence domain relative to a credible black-box multisecant method?

This is an upper-bound test for ACCELERATE.

If a **zero-cost oracle** does not provide material value, then a practical response method with non-zero acquisition cost cannot justify a standalone ACCELERATE claim inside the currently admitted hydrological envelope.

E5a is not a test of whether derivatives, quasi-Newton methods or hydrological response coefficients are novel. They are not.

---

## 2. E4 result that E5a takes as fixed input

E4 distinguished two finite-window maps:

```text
flux-driven predictor map:
    q_bot -> H_end

head-driven corrector map:
    H -> V_u
```

and established:

```text
u_A ~= u_FD
```

for all five tested baselines, where `u_A` is the accepted-trajectory predictor response and `u_FD` is an independent pure-bottom-flux finite difference.

E4 also showed that `u_A` is **not** a universal head-to-exchange Jacobian.

The decisive response values used by E5a are:

| baseline | window (day) | q predictor (cm/day) | u_A | J_R |
| --- | ---: | ---: | ---: | ---: |
| B1 | 1e-4 | 1e-6 | 3.402936037279093e-5 | -3.402833570476105e-5 |
| B3 | 1e-3 | 1e-4 | 2.665743709457589e-4 | -2.8821767195098304e-4 |
| B4 | 1e-2 | 1e-6 | 1.19027208545508e-3 | -1.190272325146675e-3 |

B3 is the response-separation case:

```text
|J_R| / u_A = 1.08119048
```

so the actual head-driven response magnitude is approximately 8.1% larger than the predictor response.

B5 is not a primary E5a case because E4 found no symmetrically identifiable local head-driven `J_R` inside the unchanged corrector transaction envelope.

---

## 3. Controlled physical matrix

E5a deliberately remains small.

Three SWAP baselines are used:

```text
B1  weak short-window negative control
B3  100x-flux response-separation case
B4  long-window low-flux case
```

For each baseline, MODFLOW specific yield is varied:

```text
Sy = 0.001
Sy = 0.002
Sy = 0.005
Sy = 0.02
Sy = 0.15
```

This matrix was revised **before the first E5a execution began**. The initial preregistration draft used only `0.02, 0.15, 0.30`. A pre-execution coupling-strength sanity check showed that this would leave every case in a weak-feedback regime.

For a storage-dominated one-cell estimate:

```text
dH/dV ~= 1/Sy

C_approx ~= |J_R| / Sy.
```

For B4, this gives approximately:

```text
Sy=0.15   -> C_approx ~ 0.008
Sy=0.02   -> C_approx ~ 0.060
Sy=0.005  -> C_approx ~ 0.238
Sy=0.002  -> C_approx ~ 0.595
Sy=0.001  -> C_approx ~ 1.19
```

The original matrix would therefore have repeated the already demonstrated weak-coupling null and would have been an inadequate oracle-value falsification test.

The lower `Sy` cases are controlled numerical feedback-strength fixtures. They are not presented as representative regional aquifer parameters. Component/corrector failures reached at these stronger feedback levels remain valid convergence-domain evidence and must not be repaired by relaxing SWAP qualification criteria.

The groundwater fixture otherwise remains fixed:

```text
K = 1.0 m/day
CHD background offset = 0.0 m
one 1 m2 centre coupling cell
same 3-cell transient MODFLOW6 fixture
same MODFLOW6 6.8.0 execution path
```

This gives fifteen physical cases.

Specific yield is used as a controlled groundwater-buffering axis. Lower `Sy` is expected to increase head response to the same transferred amount, but no monotonic algorithm ranking is assumed.

---

## 4. Common accepted origin and predictor

Every method in one physical case starts from exactly the same real-SWAP accepted origin.

The common predictor is executed once and provides:

```text
H_ref
q_ref = predictor exchange evaluated at H_ref
u_A
```

where:

```text
q_ref =
    (hcof_predictor * H_ref - rhs_predictor)
    / (A * 86400)
```

in m/s.

The predictor evaluation is common work and is counted for every method.

No method is allowed to commit a SWAP trial, advance authoritative SWAP state, or publish interface mass during E5a characterization.

---

## 5. Common affine boundary representation

All methods are expressed through the same MODFLOW API boundary representation:

```text
q_model(H) = q_anchor + s * (H - H_anchor)
```

with `q_model` in m/s and slope `s` in s^-1.

For one square metre:

```text
hcof = A * 86400 * s

rhs  = hcof * H_anchor
       - q_anchor * A * 86400
```

The actual SWAP corrector evaluation returns:

```text
q_swap(H)
```

and the coupling residual is:

```text
r = q_swap(H) - q_model(H).
```

A method is converged only when:

```text
MODFLOW nonlinear convergence = true
and
|r| <= 1e-15 m/s.
```

The `1e-15 m/s` threshold is the existing publication qualification criterion. E5a does not reinterpret it as an operational hydrological-error threshold.

Maximum coupling outer iterations:

```text
40
```

as in the existing E3 characterization.

---

## 6. Comparator methods

### M0 — FP

Plain fixed-point / sequential exchange.

Initial boundary:

```text
H_anchor = H_ref
q_anchor = q_ref
s = 0
```

After every successful SWAP corrector at `(H_k,q_k)`:

```text
H_anchor <- H_k
q_anchor <- q_k
s        <- 0
```

No derivative or history information is used.

### M1 — Aitken

Scalar dynamic relaxation of the constant exchange.

Let:

```text
x_k = constant exchange supplied to MODFLOW
F_k = q_swap(H_k)
f_k = F_k - x_k
```

Start with:

```text
x_0 = q_ref
omega_0 = 1
```

Update:

```text
x_(k+1) = x_k + omega_k * f_k.
```

After at least two residuals:

```text
omega_k =
    -omega_(k-1) * f_(k-1)
    / (f_k - f_(k-1)).
```

Numerical safeguard fixed before execution:

- if the denominator is non-finite or no larger than a representation-scale residual floor, retain the previous finite `omega`;
- clamp the applied relaxation to:

```text
-1.0 <= omega <= 1.5
```

to prevent a single noise-dominated scalar update from making the comparator artificially fragile.

The exact clamp is a benchmark-stability rule, not a novelty claim. IQN/multisecant is the decisive black-box comparator.

The MODFLOW boundary remains constant-flux:

```text
s = 0.
```

### M2 — scalar multisecant / IQN-cold analogue

This is the strong black-box baseline for the one-dimensional interface.

It uses only actual main-loop samples:

```text
(H_i, q_swap_i)
```

and no component-provided derivative.

At the latest sample `k`, use up to the five most recent previous samples and form:

```text
DeltaH_i = H_i - H_k
Deltaq_i = q_i - q_k.
```

Discard a sample difference when:

```text
|DeltaH_i|
<= 1024 * eps * max(1, |H_i|, |H_k|).
```

If at least one usable difference remains, fit the scalar multisecant slope by least squares:

```text
s_IQN =
    sum(DeltaH_i * Deltaq_i)
    / sum(DeltaH_i^2).
```

If the denominator is non-finite or representation-scale, the learned slope is unavailable and the method falls back to:

```text
s = 0.
```

No extra SWAP evaluation is used to learn the slope.

After each successful trial, the affine line is re-anchored at the latest actual point:

```text
H_anchor = H_k
q_anchor = q_swap_k
s        = s_IQN
```

This is explicitly described as the scalar one-interface specialization of a black-box multisecant/IQN/Anderson concept, not as a claim that the harness reproduces every implementation detail of a particular multidimensional IQN-ILS package.

No warm history is supplied in E5a.

### M3 — current u_A-informed coupling

This reproduces the response structure used by the present F-GC44/E3 strong-coupling route.

The slope is frozen for the whole coupling window:

```text
s_uA = u_A / DeltaT_s.
```

The initial affine boundary is the existing predictor boundary.

After each successful SWAP corrector, the line is re-anchored at the latest actual point while the slope remains fixed:

```text
H_anchor = H_k
q_anchor = q_swap_k
s        = s_uA.
```

E5a therefore does **not** label the existing E3 strong route as fixed point.

### M4 — zero-cost J_R oracle

The oracle uses the E4 plateau value for the actual head-driven finite-window exchange response:

```text
s_oracle = J_R / DeltaT_s.
```

The initial point is the same common predictor anchor:

```text
H_anchor = H_ref
q_anchor = q_ref.
```

After each successful SWAP corrector the line is re-anchored at the latest actual point while `s_oracle` stays fixed.

For E5a only, acquisition of `J_R` is assigned:

```text
kappa_oracle = 0
```

full-window equivalents.

This is deliberately unrealistic and favorable to the response-information hypothesis. It defines an upper bound.

The real perturbation work used to obtain the E4 oracle is retained in provenance but excluded from the primary E5a work score.

---

## 7. One MODFLOW iteration and one SWAP trial per coupling outer

To keep the algorithms comparable, one coupling outer consists of:

```text
1. publish the method's current affine boundary;
2. execute one MODFLOW prepared-solve iteration;
3. evaluate one real SWAP corrector at the returned centre-cell head;
4. compute q_model, q_swap and residual;
5. test joint MODFLOW + coupling convergence;
6. discard the SWAP candidate;
7. if not converged, update only the method-specific boundary information.
```

All corrector trials start from the same immutable accepted SWAP origin.

No method receives additional main-loop SWAP samples.

---

## 8. Work accounting

Iteration count is not the primary metric.

For every method record:

```text
N_predictor
N_corrector_attempted
N_corrector_successful
N_MODFLOW_iteration_calls
wall-clock diagnostic time
```

A failed SWAP corrector attempt still counts as one attempted full-window evaluation because work was spent obtaining the failure.

Common predictor work:

```text
N_predictor = 1
```

for every method.

Primary E5a SWAP work score:

```text
W_SWAP_upper =
    N_predictor
    + N_corrector_attempted
    + kappa_method.
```

with:

```text
kappa_FP      = 0
kappa_Aitken  = 0
kappa_IQN     = 0
kappa_uA      = 0 full-window solves
kappa_oracle  = 0 in E5a by construction
```

The accepted-trajectory computation used to obtain `u_A` may have non-zero arithmetic overhead, but E4 established that it requires no additional full nonlinear window solve. E5a reports wall-clock timing separately and does not convert that arithmetic overhead into an invented fractional solve cost.

---

## 9. Failure classification

A method may terminate as:

```text
CONVERGED
SWAP_CORRECTOR_UNAVAILABLE
MODFLOW_ERROR
COUPLING_ITERATION_LIMIT
NONFINITE_UPDATE
```

A SWAP corrector failure is not relabelled as outer-coupling nonconvergence.

No failure is repaired by:

- changing SWAP retry limits;
- changing temporal or mass tolerances;
- weakening MODFLOW convergence;
- reducing the coupling residual criterion;
- skipping failed component states;
- extrapolating through a failed SWAP corrector.

A difference in the set of physically executable candidate heads is part of the method's convergence-domain result.

---

## 10. Common-solution requirement

Work rankings are interpreted only among methods that converge to the same coupled solution to qualification precision.

For each physical case, after convergence compare all converged methods.

Flag:

```text
SOLUTION_DISAGREEMENT
```

and suppress the work ranking if either:

```text
max pairwise |DeltaH| > 1e-10 m

or

max pairwise |Deltaq_swap| > 1e-14 m/s.
```

These are numerical consistency thresholds tied to the existing MODFLOW and coupling tolerances; they are not hydrological materiality thresholds.

Every method must independently satisfy the common `1e-15 m/s` coupling residual criterion.

---

## 11. E5a primary comparisons

The primary adversarial comparison is:

```text
M4 zero-cost J_R oracle
versus
M2 scalar multisecant / IQN-cold.
```

M0 FP and M1 Aitken establish lower-strength black-box baselines.

M3 `u_A` measures the value of the response object that SWAP5 actually supplies.

The weak B1 cases are negative controls and cannot by themselves establish an ACCELERATE information-value result.

The B3 row is the primary response-separation regime.

The B4 row tests a longer window in which E4 already observed a bounded local linearity regime.

---

## 12. E5a oracle-value screening gate

E5a is an **upper-bound screening gate**, not the complete RC-2/RC-5 demonstration.

Define an `ORACLE_VALUE_SIGNAL` only if at least one of the following preregistered conditions holds in B3 or B4:

### A. convergence-domain expansion

The zero-cost oracle converges under the 40-outer budget in a preregistered physical case where the scalar multisecant method does not converge, while the oracle's required SWAP correctors remain valid.

### B. material full-window work reduction

For at least one of the B3 or B4 baseline rows, consider the preregistered **strong-feedback subset**:

```text
Sy = 0.001, 0.002, 0.005.
```

The work gate is met only when:

- the oracle uses at least two fewer full-window SWAP evaluations than scalar multisecant in at least two of these three low-storage cases; **and**
- the reduction in those qualifying cases is at least 25% of the scalar-multisecant work.

The `Sy=0.02` and `0.15` cases remain weak-feedback controls and do not by themselves satisfy the work gate.

This is a demanding publication-screening threshold chosen before execution. It is not a universal definition of numerical significance.

A one-evaluation saving in an easy weak-coupling case is not sufficient.

---

## 13. Stop/go rules after E5a

### E5a FAIL_UPPER_BOUND

If no `ORACLE_VALUE_SIGNAL` occurs in B3 or B4:

- do not implement a production J_R acceleration path;
- do not spend publication effort on derivative acquisition economics;
- retain E5a as a negative result inside PUB-GC;
- place standalone ACCELERATE in **inactive / not supported by the current admitted envelope** status.

A later reopening requires E6 to establish a qualitatively different, scientifically admitted hydrological regime before the ACCELERATE claim is retested. The same weak fixture must not simply be reparameterized until a positive result appears.

### E5a PROCEED

If the zero-cost oracle passes the screening gate:

- proceed to E5b with `IQN_warm` / scientifically admissible cross-window history;
- measure response drift `D`;
- test practical acquisition cost and refresh frequency;
- only then evaluate RC-2 through RC-5 for independent-paper status.

### u_A-specific interpretation

Regardless of the oracle gate:

- if M3 performs like M4 only where `u_A ~= -J_R`, but loses value in B3, E4 provides a mechanistic explanation;
- if M3 matches or exceeds M4 in B3, inspect the nonlinear trajectory rather than concluding that the “wrong” derivative is superior in general;
- if M3 is consistently worse than M2, the current response remains useful for predictor construction but gains no ACCELERATE claim.

---

## 14. No warm-history claim in E5a

E5a uses isolated one-window accepted origins.

Therefore:

```text
IQN_warm
response reuse
inter-window drift D
```

are intentionally excluded.

They become meaningful only in an E5b multi-window experiment after the zero-cost oracle passes E5a.

This staging prevents benchmark inflation and avoids spending effort on history-management questions before direct response information has shown any upper-bound value.

---

## 15. Expected output artifacts

E5a should persist:

```text
PUB_GC_E5A_ORACLE_VALUE_RESULT.md
PUB_GC_E5A_ORACLE_VALUE_RESULT.json
PUB_GC_E5A_ORACLE_VALUE_TABLE.csv
PUB_GC_E5A_TRACE.csv
```

with one method/case record containing:

```text
baseline
Sy
method
status
outer count
N_predictor
N_corrector_attempted
N_corrector_successful
N_MODFLOW_iteration_calls
W_SWAP_upper
final H
final q_swap
final q_model
final residual
candidate failure stage
residual trace
head trace
exchange trace
learned/fixed slope trace
Aitken omega trace where applicable
```

The raw traces are evidence; the summary tables are derived artifacts.

---

## 16. Publication interpretation

E5a is designed so that a negative result is decisive and useful.

A negative oracle result would mean:

> within the strongest currently admitted one-window SWAP5-MODFLOW6 regimes tested, even perfect local head-response information has insufficient incremental value over black-box multisecant learning to justify a dedicated acceleration method or paper.

A positive result would mean only:

> there is enough upper-bound information value to justify the next, harder test.

It would **not** yet establish a standalone ACCELERATE paper.

---

## 17. Governance

This preregistration freezes before execution:

- physical cases;
- revised pre-execution groundwater `Sy` values and the documented reason for the revision;
- comparator definitions;
- oracle values;
- convergence criterion;
- history depth;
- representation filtering;
- work accounting;
- solution-consistency checks;
- oracle screening thresholds;
- stop/go interpretation.

Implementation may fix harness defects, but must not change these scientific rules after inspecting E5a rankings.

Any required scientific design change after execution starts must be recorded as a new E5 revision rather than silently editing this preregistration.


## 18. Pre-execution revision record

Revision E5a-v1.1 was made before any E5a method result was produced.

Change:

```text
old Sy set: 0.02, 0.15, 0.30
new Sy set: 0.001, 0.002, 0.005, 0.02, 0.15
```

Reason:

The E4 `J_R` values imply that the old matrix would keep the approximate storage-controlled fixed-point factor below about 0.06, even for B4. That matrix was too weak to provide a fair upper-bound test of supplied response information. The revision deliberately adds a feedback-strength range approaching and exceeding unity for B4.

No algorithm result was inspected because the first E5a workflow was still queued and had not begun execution. All comparator definitions, work accounting, convergence criteria and oracle-value thresholds remain unchanged except that the work gate now explicitly uses the three low-storage cases.
