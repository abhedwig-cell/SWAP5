# PUB-GC E2/E3 macro-window adjudication

Status: **frozen scientific design decision after PUB-GC-TRANSIENT-SCREEN-0001 and before macro-window implementation**

Publication owner: `PUB-GC`

Affected hypotheses: `H2`, `H3`

Controlling screening result: `docs/publications/results/PUB-GC-TRANSIENT-SCREEN-0001.yaml`

## 1. Decision trigger

The prospectively frozen transient screen completed validly under O0 and O2 but produced:

- four `VALID_UNSTABLE` stress families;
- two `VALID_STABLE_UNRESOLVED` groundwater-only families;
- zero `VALID_STABLE_RESOLVED` families;
- zero families eligible for held-out H2/H3 promotion under the frozen rule.

The observed terminal-surrogate mismatch was exactly zero in every reported level of every case.

The screening case values, thresholds and held-out candidates are not changed in response.

## 2. Semantic adjudication of the structural zero

The zero mismatch is not interpreted as evidence that terminal-flux coupling is generally equivalent to whole-window exchange.

At the frozen SWAP authority:

```text
single native step:
Q_step = -q_bottom * delta_t
q_terminal = -q_bottom
```

and the full-step transaction route publishes that one-step exchange directly.

Therefore, when one coupling window is represented by one accepted full native SWAP step,

```text
Q_whole = q_terminal * DeltaT_c
```

by construction.

The step-doubling/two-half route already demonstrates the intended distinct semantics:

```text
Q_whole = Q_half1 + Q_half2
q_terminal = q_half2
```

so the code contract can distinguish integrated exchange from terminal rate when more than one native contribution exists.

The first transient screen therefore exposed an **experimental identifiability problem**: its one-transaction-per-coupling-window construction often made the two E2 arms algebraically identical.

## 3. Additional confounding found by the screen

The original L0/L1/L2 trajectory ladder used one SWAP transaction for each coupling window.

Consequently, refinement of coupling-window duration also refined the subsystem integration interval.

For H3 this confounds:

1. error caused by the external coupling-window duration; and
2. error caused by changing SWAP's own temporal integration.

That is inconsistent with the protected PUB-GC question, which explicitly asks how independently time-integrating subsystems can be coupled while retaining their native numerical integration.

## 4. Scientific design decision

Future PUB-GC E2/E3 work must separate two temporal scales.

### 4.1 Coupling macro-window

Let

```text
I_n = [t_n, t_n + DeltaT_c]
```

be the external vadose-groundwater coupling window.

A coupling candidate prescribes one interface-head candidate over this macro-window.

### 4.2 Native SWAP integration inside the macro-window

Let

```text
delta_t_1, ..., delta_t_m
sum(delta_t_j) = DeltaT_c
```

be the independently controlled SWAP integration intervals inside the coupling window.

The SWAP candidate trajectory evolves sequentially through these internal intervals, but it remains a **disposable macro-candidate trajectory**. No internal candidate step may become authoritative production state merely because it is needed to integrate the subsystem response.

Every new outer coupling candidate over the same macro-window must restart from the same accepted macro origin.

### 4.3 Whole-window response

For candidate interface head `h`:

```text
Q_whole(h; DeltaT_c, delta_t)
  = sum_j Q_j(h)
```

where each `Q_j` is the accepted native SWAP lower-boundary exchange contribution along the disposable candidate trajectory.

The macro endpoint state is the physical endpoint after the final native integration interval.

### 4.4 Terminal-flux comparator

The terminal comparator remains exactly the already frozen E2 comparator concept:

```text
Q_terminal = q_terminal,last * DeltaT_c
```

where `q_terminal,last` is the terminal lower-boundary rate from the final native contribution of the same macro-candidate trajectory.

No fitted, midpoint or averaged correction is introduced.

### 4.5 Groundwater response

For a macro-candidate evaluation, GW-A is evaluated from its unchanged macro-window checkpoint using the aggregate `Q_whole`.

It is not committed after each internal SWAP integration interval.

This preserves the intended partitioned coupling semantics: subsystem-native integration occurs inside a coupling window, while interface exchange is reconciled at the coupling-window boundary.

## 5. H2 isolation rule

H2 may only be tested on macro-windows containing at least two independently reported native SWAP exchange contributions, unless the transaction itself has accepted a demonstrably multi-contribution route such as the qualified two-half path.

A candidate H2 case is not `RESOLVED` merely because forcing is strong. It must first demonstrate:

```text
abs(Q_whole - Q_terminal) > frozen numerical resolution floor
```

under the macro-window semantics above.

This requirement prevents further amplitude tuning of a structurally unidentifiable one-step experiment.

## 6. H3 isolation rule

For the principal coupling-window convergence comparison, refinement of `DeltaT_c` must not silently refine the native SWAP integration policy at the same time.

A publication experiment must therefore freeze an internal-integration policy before varying `DeltaT_c`.

Preferred controlled design:

- choose a qualified maximum native integration interval `delta_t_native`;
- use the same `delta_t_native` across the coupling-window ladder;
- choose coupling windows that are integer multiples of that internal interval;
- keep forcing switch times common across all levels;
- verify independent internal-integration adequacy before interpreting coupling-window convergence.

A separate sensitivity study may refine `delta_t_native`, but it must not be confused with the H3 coupling-window effect.

## 7. Required qualification before new screening

A research-only macro-window response component must be qualified before it can generate E2/E3 screening evidence.

It must prove at least:

1. one-internal-step reduction exactly reproduces the existing one-step response;
2. multiple internal contributions sum exactly to the reported `Q_whole`;
3. `q_terminal,last` comes only from the final native contribution;
4. a synthetic varying-flux oracle produces nonzero `Q_whole - q_terminal,last*DeltaT_c`;
5. same macro origin plus same candidate head is exactly replayable;
6. a different candidate head starts again from the same accepted macro origin;
7. internal progression occurs only inside a disposable research candidate lineage;
8. abort/discard leaves the accepted macro origin unchanged;
9. final macro endpoint state equals the sequential native endpoint;
10. whole-window action/reaction with GW-A closes exactly;
11. no GW-A commit occurs per internal SWAP step;
12. O0/O2 scientific output is identical;
13. `src/**` and all previously qualified publication dependencies remain unchanged.

Qualification values are infrastructure evidence only and cannot become H2/H3 effect estimates.

## 8. Reference redesign

The existing `GC-REF-A` bisection oracle remains valid as a root-search concept.

A new macro-window composition, provisionally `GC-REF-B`, may reuse that derivative-free oracle but must evaluate the new macro SWAP response `Q_whole(h)`.

Reference construction must then separate:

- **internal integration adequacy**, tested by refining `delta_t_native`; and
- **coupling-window convergence**, tested by refining `DeltaT_c` at fixed qualified internal policy.

The previous calm reference and transient screen remain valid supporting evidence for why this separation became necessary. They are not erased or relabelled as primary evidence.

## 9. Consequence for the frozen held-out promotion rule

`PUB-GC-TRANSIENT-SCREEN-0001` promotes no held-out candidate.

The previously listed `HP-*` values remain historically frozen but are **not admitted as primary H2/H3 cases**.

No stronger amplitude may be chosen from the observed screen.

Any future held-out primary matrix must be frozen only after:

1. macro-window response qualification;
2. macro-window screening with cases ineligible for primary reuse;
3. an independently qualified internal-integration policy; and
4. a new prospective held-out promotion rule.

## 10. Publication interpretation

This adjudication strengthens rather than changes the protected PUB-GC question.

The paper is not about forcing a difference between two bookkeeping formulas. It is about retaining native subsystem time integration while exchanging a scientifically coherent finite-window quantity.

The experimental design must therefore make the hierarchy explicit:

```text
accepted coupled state
    -> coupling macro-window
        -> native SWAP integration intervals
        -> integrated subsystem response
    -> coupled interface acceptance
    -> next accepted coupled state
```

## 11. Nonclaims

This decision does not establish:

- H2;
- H3;
- practical coupling-window limits;
- superiority of whole-window exchange;
- a MODFLOW 6 result;
- a response/tangent acceleration result;
- that one-step coupling is invalid;
- that the prior screen failed scientifically.

It records that the prior screen was informative but insufficiently discriminating for H2 and temporally confounded for a clean H3 interpretation.

## 12. Next permitted action

1. freeze a detailed macro-window response qualification specification;
2. implement that research-only component on a separate branch from an immutable qualified publication base;
3. qualify it without primary hydrologic cases;
4. only then preregister a new E2/E3 screening matrix.
