# F-MACRO-ALT24 — consolidated RFM architecture, state and parameter burden

Date: 2026-10-01

Status: `QUALIFIED_RESEARCH_ARCHITECTURE / ORIGINAL_SIMPLIFICATION_QUESTION_PARTIALLY_ANSWERED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Consolidate ALT01-ALT23 into one leading Reduced Functional Macropore (RFM) architecture and answer the original research question:

> Can an alternative SWAP5 preferential-flow formulation be easier to parameterize, computationally cheaper and architecturally cleaner while retaining the relevant behaviours?

This document deliberately separates those three claims.

They are not assumed to rise or fall together.

## Leading RFM architecture

```text
accepted surface matrix state
    |
    +--> K_surface
    +--> S_surface
    +--> source-event age
    |
    v
distributed matrix-infiltrability activation
    |
    v
activation fraction a_event
    |
    +--> persistent MB pathway class
    |
    +--> fixed structural IC connectivity C_struct(z)
             |
             v
       activation-weighted quantile recruitment
             |
             v
       terminating endpoint/path classes
    |
    v
fast-domain storage / transit
    |
    +--> compact Philip wall exchange
    |
    +--> IC deposition to matrix
    +--> MB deep/bottom receipt
```

The surface-boundary owner remains outside the fast-domain activation law and must handle:

- ponding;
- runoff;
- any accepted surface sealing limitation.

This separation is required by the NEON and Griessfirn evidence.

## 1. Persistent physical/history state

### Leading RFM state

The current research hypothesis needs the following information roles.

#### Fast-domain water storage

```text
W_fast(path/endpoint class)
```

This is unavoidable physical storage where finite transit/storage is represented.

#### Wall-exchange event memory

Per active matrix-fast-domain contact:

```text
S_wall,event
tau_wall,event
```

ALT02/ALT02B showed that these two information roles are the natural sufficient-state candidate for exact Philip-event continuation.

#### Surface activation event memory

A separate scalar/event item:

```text
tau_surface
```

tracks the current continuous surface-input event.

It is not the same history as wall-contact age.

### Legacy comparison

The source-backed historical macropore state evidence identifies at least seven committed physical/history candidates:

```text
ICpBtDm
SorpDmCp
ThtSrpRefDmCp
TimAbsCumDmCp
VlMpDmCp
WaUnMpDmCp
VlMpDyCp
```

plus separate accepted-history/checkpoint concepts such as previous wet-wall state and previous-step geometry/storage fields.

The exact B1.11 census remains owned by PPA-WU05-A and its production audit line.

### Research reduction

ALT01-ALT04 support the following information-role reduction:

```text
persistent:
    fast water
    S_wall,event
    tau_wall,event
    tau_surface

derived:
    dynamic volume
    total volume
    active bottom index
    wet-wall/contact fraction
    active connectivity
```

This is a meaningful state reduction even though array sizes depend on the final endpoint/contact discretisation.

## 2. Derived quantities

The RFM deliberately treats the following as calculations, not restart state:

```text
K_surface
S_surface
b50(tau_surface)
activation fraction
C_active(z | event)
dynamic shrinkage volume
total fast-domain volume
active domain-bottom index
wet-wall/contact fraction
rate/Jacobian intermediates
```

This is consistent with SWAP5's transaction architecture:

recomputable quantities should not silently become committed physical state.

## 3. Trial and scratch ownership

Worker/trial scratch contains:

- rate intermediates;
- exchange intermediates;
- derivative/Jacobian terms;
- candidate flux receipts;
- temporary connectivity/recruitment views.

None belongs in restart state.

This agrees with the recovered A23AU result, where large hidden legacy scratch arrays were reduced to explicit active-sized worker scratch.

## 4. Activation parameter burden

### Current SWAP concept

The current direct atmospheric macropore entry depends structurally on macropore surface area/geometry and then has a separate ponding-entry route.

Dynamic crack geometry and surface macropore volume can therefore directly influence source partition.

### RFM

The unponded source partition is:

```text
B ~ LogNormal(log b50, sigma_B)

b50(tau)
  = K_surface
  + S_surface/(2 sqrt(tau))
```

with:

```text
K_surface = derived from accepted matrix hydraulics
S_surface = derived from constitutive matrix hydraulics
tau       = source-event state
```

The leading activation hypothesis therefore introduces only one new structural activation parameter:

```text
sigma_B
```

provided the surface-hydraulic derivation remains successful.

This is a substantial parameterisation simplification relative to treating activation capacity and threshold as independent event-calibrated quantities.

## 5. Connectivity/geometry burden

### Legacy structural concept

Current SWAP distinguishes Main Bypass and Internal Catchment geometry and can represent multiple terminating subdomains/depths together with static/dynamic macropore geometry.

The input/audit evidence includes structural concepts such as:

- maximum IC depth;
- static depth/volume;
- surface static macropore volume;
- IC/MB partition;
- depth-distribution exponent;
- minimum pore diameter;
- shrinkage-derived geometry.

The complete production parameter census remains the responsibility of the exact-source macropore audit.

### RFM structural concept

The leading RFM geometry is:

```text
f_MB
C_struct(z)
```

with a bounded continuous terminating-path survival.

Current research parameterisation of `C_struct` uses:

```text
Z_AH
Z_IC
R_AH
shape_a
shape_b
```

but these do not all need to be free calibration coefficients.

Preferred ownership is:

```text
Z_AH     -> derive from soil/profile horizon information
Z_IC     -> structural maximum connectivity depth
R_AH     -> remove or derive if possible
shape a,b -> effective structural shape parameters
f_MB     -> effective continuous/deep-path fraction
```

Therefore the likely genuinely calibrated geometry burden is approximately:

```text
f_MB
shape a
shape b
possibly R_AH
```

rather than an explicit list of IC subdomain identities and endpoint depths.

### Important qualification

This reduction is **plausible and structurally demonstrated**, not yet empirically closed.

Until `Z_IC`, `f_MB` and the shape parameters can be tied reproducibly to observations/profile classes, the claim "fewer calibration parameters" is not fully proven.

## 6. Activation-weighted connectivity does not add a new event parameter

ALT21 showed that fixed active geometry was too restrictive.

ALT22/ALT23 replace it with:

```text
fixed C_struct(z)
+
activation-weighted quantile recruitment
```

The selector uses the already calculated event activation fraction.

It does not introduce:

- event-specific depth parameters;
- rainfall-specific geometry coefficients;
- a new activation-to-depth tuning constant.

Therefore the added expressive power does not, at this stage, increase parameter count.

## 7. Wall exchange: simplification is intentionally incomplete

This is the main caveat in the parameter-burden claim.

RFM currently retains the compact Philip wall-exchange physics because ALT02 showed that event memory is genuinely causal.

The existing SWAP macropore input surface includes wall-exchange controls such as sorptivity options/correction factors and related absorption parameters.

RFM has reduced their **state representation** to:

```text
S_wall,event
tau_wall,event
```

but has not yet demonstrated that all user-facing wall-exchange parameters can be removed or derived.

Therefore:

```text
wall-exchange state burden: reduced
wall-exchange calibration burden: not yet proven reduced
```

This distinction is mandatory.

## 8. Surface-boundary burden

External evidence forced an important architectural clarification.

RFM does not own total atmospheric source blindly.

The surface boundary must first resolve:

```text
rain / irrigation
    ->
ponding
runoff
effective infiltrating supply
```

Only the available infiltrating supply enters matrix/preferential partitioning.

This reuses a responsibility SWAP already needs for ordinary infiltration/runoff and should not become a duplicate RFM parameterisation.

The preferred implementation therefore consumes an accepted surface-boundary contract rather than inventing a new runoff law.

## 9. Computational burden

The leading RFM architecture is computationally attractive for three reasons.

### Activation

The lognormal partition has a closed-form evaluation.

No nonlinear dual-domain solve is introduced.

### Connectivity

Endpoint/quantile classes are one-dimensional and active-sized.

ALT23 demonstrates that water can be aggregated by endpoint class rather than tracking individual pathways or timestep parcels.

### Hydraulics

`K_surface` is supplied by the existing constitutive provider.

`S_surface` is a one-dimensional constitutive integral that can later be cached/tabulated/adaptively evaluated.

### Important boundary

No end-to-end SWAP runtime benchmark exists yet.

Therefore:

```text
computational structure = promising
runtime speedup = not yet qualified
```

## 10. Architecture cleanliness

This is the strongest current result.

The RFM formulation maps naturally onto SWAP5 ownership:

```text
immutable structural config
accepted physical/history state
candidate state
worker-local scratch
derived hydraulic views
exact mass receipts
```

There is no conceptual need for hidden SAVE state, partial rollback or geometry/history caches.

Rejected trials can discard:

- candidate fast storage;
- candidate event ages/sorptivity;
- candidate mass receipts;

while the accepted checkpoint remains unchanged.

This is substantially cleaner than the historical implicit ownership exposed by the macropore audit.

## 11. Burden comparison verdict

### Implementation burden

```text
RFM: MATERIALLY SIMPLER / CLEANER IN RESEARCH ARCHITECTURE
```

Reasons:

- explicit typed information roles;
- no multiple explicit IC identities required;
- derived geometry rather than cached geometry history where possible;
- closed-form activation;
- active-sized endpoint representation;
- natural transaction boundaries.

### Persistent-state burden

```text
RFM: MATERIALLY REDUCED IN INFORMATION ROLES
```

The strongest reduction is replacing multiple legacy event/reference/cache fields with:

```text
fast water
S_wall,event
tau_wall,event
tau_surface
```

plus derived geometry.

### Geometry parameter burden

```text
RFM: LIKELY LOWER
```

but final empirical mapping is still required.

### Activation parameter burden

```text
RFM: CLEARLY LOWER IF SURFACE K/S REMAIN DERIVED
```

with `sigma_B` as the single new structural activation parameter.

### Total calibration burden

```text
NOT YET PROVEN LOWER
```

because:

- wall-exchange user parameters are not yet reduced;
- structural connectivity parameters still need empirical identification;
- surface-runoff/sealing ownership must be demonstrated without duplicate calibration.

## 12. Original research question — current answer

The evidence now supports:

> Yes, a substantially cleaner and information-reduced preferential-flow architecture is feasible, and the activation/geometry part can likely be parameterized more compactly than current SWAP.

The evidence does **not yet** support:

> The complete alternative module needs fewer calibrated field parameters in all applications.

That stronger claim requires empirical parameter-identification work.

## 13. Production status

Nothing in ALT24 is production-admitted.

The production macropore migration remains governed by PPA-WU05-A and its exact-source/census/admission sequence.

RFM is an alternative research physical option.

It must not replace or silently alter the current reference route.

## Decision

```text
RFM_RESEARCH_ARCHITECTURE =
    CONSOLIDATED

ARCHITECTURAL_SIMPLIFICATION =
    QUALIFIED RESEARCH CONCLUSION

STATE_INFORMATION_REDUCTION =
    QUALIFIED RESEARCH CONCLUSION

ACTIVATION_PARAMETER_REDUCTION =
    STRONGLY SUPPORTED

GEOMETRY_PARAMETER_REDUCTION =
    PROMISING / EMPIRICAL CLOSURE OPEN

TOTAL_CALIBRATION_REDUCTION =
    NOT YET PROVEN

RUNTIME_ADVANTAGE =
    NOT YET BENCHMARKED

PRODUCTION_ADMISSION =
    NOT REQUESTED
```

## Recommended next phase

The next phase should be **RFM parameter identifiability**, not new physics.

Priority questions:

1. Can `sigma_B` be transferred within a soil/profile class across events?
2. Can `f_MB`, shape-a and shape-b be identified from a small set of observable profile properties or dye/tracer data?
3. Can `R_AH` be removed or derived?
4. Which existing wall-exchange parameters can be derived from matrix hydraulics rather than calibrated?
5. Does the resulting reduced parameter set remain transferable on held-out events?

Only after those questions are answered should a source-level SWAP5 RFM adapter be considered.
