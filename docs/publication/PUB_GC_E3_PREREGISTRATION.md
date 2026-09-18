# PUB-GC E3 preregistration — controlled coupling-window and feedback characterization

## Status

**PREREGISTERED BEFORE E3 MATRIX EXECUTION**

Date: 2026-09-18.

Publication line: PUB-GC / COUPLE.

Canonical baseline:

`integration/f-ci-canonical @ 06e585cc16710da00267deed878567ca1936fe7e`

E1/E2 are closed as `SUPPORTED_RESTRICTED`. E3 addresses the next manuscript question: when does within-window iterative coupling materially change the SWAP–MODFLOW interface solution, and where does the currently admitted real-SWAP envelope cease to support the requested coupled correction?

No production physics, production coupling semantics or scientific tolerances are changed by E3. The F-GC44 support bridge is parameterized only for publication qualification.

---

## Research question

For a controlled one-column/one-cell system, how do coupling-window duration, interface-flux magnitude and groundwater hydraulic responsiveness affect:

- the mismatch left by a loose/sequential coupling pass;
- the correction introduced by fully iterative coupling;
- the number of component evaluations needed for coupled convergence;
- the boundary between convergent and fail-closed operation?

E3 does **not** yet attempt to identify the finite-window derivative `J_R`; that is E4.

---

## Null hypotheses

E3 is explicitly allowed to return a negative result.

### H0-A — strong coupling adds negligible correction

Across the currently admissible real-SWAP envelope, the loose/sequential solution may already be so close to the converged coupled solution that iterative correction is numerically insignificant.

### H0-B — difficult cases are outside the component envelope, not coupling-limited

Cases with stronger forcing/groundwater response may fail first because the SWAP prescribed-head trial exhausts its admitted transaction/retry envelope rather than because the outer coupling algorithm is inadequate.

Neither null result is to be converted into a positive acceleration claim.

---

## Controlled system

The experiment reuses the real F-GC44 architecture:

- one real FMR/SWAP reference-Richards column;
- one live MODFLOW6 6.8.0 groundwater cell coupled through the API package;
- one immutable accepted SWAP origin for every diagnostic and corrector trial;
- one prepared MODFLOW solve per iterative coupled run;
- fixed analytic accepted-trajectory SWAP predictor slope;
- drainage, root uptake, macropores, snow and soil temperature disabled;
- no state or interface-mass publication during the E3 diagnostics.

MODFLOW geometry remains the three-cell F-GC44 fixture with the coupling cell in the centre and constant-head cells at both ends.

---

## Prespecified matrix

Three axes are crossed completely.

### Coupling-window duration

```text
DeltaT_day =
    1e-4
    1e-3
    1e-2
```

Equivalent durations are 8.64 s, 86.4 s and 864 s.

### Native SWAP predictor/boundary flux

The fixed top flux and flux-driven predictor bottom boundary use the same native value so the axis primarily changes through-flow/interface magnitude rather than deliberately imposing a top-minus-bottom storage imbalance:

```text
q_predictor_cm_per_day =
    1e-6
    1e-3
    1e-2
    1e-1
```

The lowest value reproduces the F-GC44/E1 control. The higher values are characterization points, not pre-admitted production envelopes.

The native sign is retained without assigning rainfall/evaporation semantics in E3. Hydrologically process-specific forcing regimes belong to E6.

### MODFLOW horizontal conductivity

```text
K_m_per_day =
    0.01
    0.1
    1.0
    10.0
```

All other MODFLOW storage and geometry settings remain equal to F-GC44.

Lower `K` is expected to increase the groundwater head response to a given interface flux, but E3 does not label a case “strong” or “weak” in advance. Feedback severity is inferred from observed continuous response metrics.

Total matrix size:

```text
3 * 4 * 4 = 48 cases
```

No cases are dropped after observing results.

---

## Two solves from the same physical origin

Every matrix case runs two independent MODFLOW instances against the same unchanged SWAP accepted origin.

### A. Loose/sequential diagnostic

1. materialize the SWAP predictor affine response;
2. solve MODFLOW to its own nonlinear convergence while keeping that predictor response fixed;
3. evaluate exactly one SWAP prescribed-head corrector at the resulting MODFLOW head;
4. record the SWAP–groundwater flux mismatch;
5. discard the SWAP candidate;
6. do not publish or commit either component.

This is a diagnostic loose-coupling pass. It is not accepted as authoritative hydrological history.

### B. Iterative coupled solve

Start a fresh MODFLOW instance from the same initial groundwater state.

For each outer coupling iteration:

1. publish the current affine response;
2. execute a MODFLOW nonlinear iteration;
3. evaluate the real SWAP corrector from the immutable accepted SWAP origin;
4. compute

```text
r_k = q_SWAP,k - q_GW,k
```

5. if MODFLOW reports nonlinear convergence and

```text
|r_k| <= 1e-15 m/s
```

record convergence;
6. otherwise discard the SWAP candidate and re-anchor only the affine intercept;
7. retain the admitted predictor slope.

Maximum outer iterations remain 40, matching F-GC44 characterization practice.

The final retained SWAP candidate is discarded after measurement. E3 publishes no authoritative state or mass.

---

## Primary recorded metrics

For every case:

```text
window_day
predictor_qbot_cm_per_day
K_m_per_day
predictor_hcof
predictor_rhs
predictor_reference_head

loose_modflow_iterations
H_loose
q_GW_loose
q_SWAP_loose
r_loose

coupling_outer_iterations
H_iterative
q_GW_iterative
q_SWAP_iterative
r_iterative

DeltaH = H_iterative - H_loose
DeltaQ = q_SWAP_iterative - q_SWAP_loose

R_loose =
    |r_loose| /
    max(|q_SWAP_loose|, |q_GW_loose|, 1e-20)

status
failure_stage
```

No post-hoc threshold is used to convert `DeltaH` or `DeltaQ` into a “scientifically important” label in E3. The continuous values are reported.

---

## Structured statuses

Every case must terminate with one of:

```text
CONVERGED
SWAP_PREDICTOR_UNAVAILABLE
SWAP_LOOSE_TRIAL_FAILED
MODFLOW_LOOSE_NOT_CONVERGED
SWAP_ITERATIVE_TRIAL_FAILED
MODFLOW_ITERATIVE_ERROR
COUPLING_ITERATION_LIMIT
```

A bounded physical/numerical failure is data, not a CI failure.

The workflow itself fails only if:

- the F-GC44 control no longer reproduces;
- a case mutates committed SWAP state or ledger authority;
- a case labeled `CONVERGED` violates the existing flux criterion;
- a non-finite value is reported as a valid converged measurement;
- the harness crashes outside the structured status contract;
- any of the 48 prespecified cases is missing.

---

## Control reproduction

The case

```text
DeltaT = 1e-4 day
q_predictor = 1e-6 cm/day
K = 1.0 m/day
```

must reproduce the E1/F-GC44 coupled result within representation-scale tolerance:

```text
H* =
  -0.71499996773317653 m

q_SWAP* =
  -1.2708557527755854e-13 m/s

|r*| <= 1e-15 m/s
```

If this control fails, the E3 matrix is invalid.

---

## Authority invariant

Before and after both the loose and iterative diagnostic solve:

```text
SWAP revision = 0
SWAP committed time = 0
ledger committed count = 0
ledger committed exchange = 0
```

E3 therefore measures coupled candidates without turning characterization runs into model history.

---

## Interpretation rules

### If loose and iterative solutions are nearly identical throughout

This supports H0-A. The paper should report that the tested regime is weakly coupled and should not claim an iterative-coupling benefit from it.

### If iterative corrections grow systematically with the controlled axes

This supplies the regime structure needed for manuscript RQ3 and motivates E4 derivative-based explanation.

### If difficult cases primarily become SWAP trial failures

This supports H0-B and identifies the next required component-envelope qualification. The coupling algorithm must not be blamed for failures that occur before a valid component response exists.

### If outer iteration fails while valid SWAP trials remain available

Those cases become the strongest candidates for later algorithm/ACCELERATE comparison.

---

## Relation to later experiments

E3 answers **whether feedback matters and where convergence fails**.

E4 will then ask **what the finite-window response actually is**, including `u_FD`, `J_S`, `J_R`, local linearity and response drift.

E5 compares black-box and supplied-response acceleration only after E3/E4 identify a meaningful regime.

A separate targeted E1 extension will eventually introduce non-zero net storage forcing; E3 deliberately keeps its flux axis simpler so coupling feedback is not confounded with a second forcing-difference axis.
