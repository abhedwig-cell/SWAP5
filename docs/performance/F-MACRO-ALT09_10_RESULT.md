# F-MACRO-ALT09/10 — dynamic matrix-infiltrability closure and integrated RFM-1B result

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_DIRECTION / ARBITRARY_TC_REJECTED / DYNAMIC_B50_CONTINUES`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Executive decision

The earlier candidate

```text
b50 = K + S/(2*sqrt(t_c))
```

with a fixed characteristic time `t_c` is rejected as the leading design.

It would introduce a new time parameter whose physical meaning and transferability would need calibration.

The stronger candidate is time dependent during an input event:

```text
b50(tau) = K_matrix + S_matrix/(2*sqrt(tau))
```

where `tau` is elapsed time since the current source event began.

This is the short-time Philip infiltration-capacity form.

No additional characteristic-time parameter is introduced.

## Literature alignment

Nimmo's 2016 preferential-flow initiation framework defines matrix infiltrability `b` as the local maximum input flux that the matrix can absorb and explicitly notes that `b` varies temporally with water content and related conditions.

The same paper identifies sorptivity and hydraulic conductivity as physical influences on `b`.

The dynamic ALT09 candidate therefore maps naturally to the framework:

```text
median local matrix infiltrability = b50(tau)
heterogeneity                     = sigma_B
```

rather than treating `b50` as a free storm parameter.

## Why event age is acceptable but t_c is not

`tau` is not a calibration parameter.

It is an event-state variable determined directly from forcing chronology:

```text
new source event -> tau = 0
continued source -> tau += dt
event ended      -> reset
```

This gives the expected infiltration-capacity decay:

```text
early event:
    capillary/sorptivity contribution high

later event:
    capillary contribution declines

long-time:
    b50 -> K_matrix
```

## Hydraulic-state inputs

The candidate needs:

```text
K_matrix
S_matrix
```

at the surface matrix state.

These should ultimately be derived from existing accepted SWAP hydraulic relations.

The standalone harness deliberately treats them as supplied physical state quantities so that the functional form can be tested before binding to production constitutive code.

## Cross-state screen

Four illustrative matrix states are used to span conductivity/sorptivity tradeoffs:

```text
fine_dry    K=2,  S=10
fine_wet    K=5,  S=4
coarse_dry  K=15, S=7
coarse_wet  K=25, S=3
```

These values are not calibration recommendations.

They are designed to test whether the candidate behaves sensibly when:

- conductivity is low but capillary intake is high;
- conductivity is higher but sorptivity is lower;
- both source duration and source intensity vary.

Rain intensities:

```text
5, 15, 30, 60
```

Durations:

```text
0.1, 0.5, 2 h
```

One common:

```text
sigma_B = 0.65
```

is used in every case.

## Structural findings

### 1. No fixed wet/dry ordering is imposed

The model can produce crossover behavior.

A drier state can initially have larger infiltrability because of larger sorptivity, while a wetter or coarser state can dominate later through larger hydraulic conductivity.

This is a desirable property.

A rule such as

```text
wetter always -> more preferential flow
```

or

```text
drier always -> more preferential flow
```

would be physically too rigid.

The ordering emerges from `K`, `S`, source intensity and event age.

### 2. Source-duration response is automatic

For a fixed matrix state and source intensity:

- short pulses see large capillary matrix capacity;
- long pulses progressively approach conductivity-controlled capacity;
- preferential fraction can therefore increase during sustained intense forcing.

No duration-specific parameter is fitted.

### 3. Intensity response remains continuous

For any fixed state/time, the lognormal partition remains smooth with source intensity.

There is no hard threshold and no fixed bypass fraction.

## Integrated RFM-1B screen

The dynamic activation law was connected directly to the existing standalone RFM-1A geometry/fast-routing operator.

For each source step:

```text
atmospheric input
   -> matrix direct intake from E[min(R,B)]
   -> preferential residual
   -> MB + continuous IC fast routing
   -> termination / bottom flux / matrix exchange
```

The whole atmospheric water balance is:

```text
P =
matrix_direct
+ terminating_deposition
+ bottom_fast_flux
+ fast-domain exchange
+ residual fast storage
```

and closes at floating-point level in the screen.

This demonstrates that the activation law composes cleanly with the reduced geometry and compact fast-domain state.

## Key design consequence

RFM-1B no longer requires a free `b50` storm parameter.

The target parameter/state contract becomes:

```text
NEW STRUCTURAL PARAMETER
    sigma_B

DERIVED AT RUNTIME
    K_matrix(theta,h,soil)
    S_matrix(theta,h,soil)
    event age tau
    b50(tau)

EXISTING/REDUCED GEOMETRY
    f_MB
    continuous IC connectivity
```

This is substantially more parsimonious than treating both lognormal distribution parameters as calibration coefficients.

## Important unresolved issue: surface hydraulics

The dynamic form is only as good as the chosen `K_matrix` and `S_matrix` binding.

The next source-bound work must decide:

1. which accepted SWAP surface state supplies `K`;
2. whether `S` should use the existing Parlange/sorptivity machinery or a separately defined matrix-infiltration sorptivity;
3. how rainfall interruption defines an event reset;
4. how ponding modifies the partition;
5. how snowmelt/irrigation and runon enter the same source contract.

These are physics/interface questions, not reasons to introduce new empirical knobs.

## Relationship with current SWAP

The current SWAP macropore surface route includes:

- direct surface-area-proportional macropore inflow;
- an additional ponding/runoff-to-macropore route.

RFM-1B changes that physical partitioning.

It must therefore remain an explicit alternative research physical option until validated.

## Current status of the reduced model

```text
STATE REDUCTION
    fast water + 2-value Philip event memory
    strong research result

GEOMETRY REDUCTION
    MB + continuous IC connectivity
    standalone multi-event PASS for continued research

ACTIVATION FORM
    lognormal infiltrability distribution
    standalone transferability PASS

B50 CLOSURE
    fixed characteristic time REJECTED
    dynamic Philip-capacity form CONTINUES

INTEGRATED RFM-1B
    mass-conserving standalone composition PASS

RFM-2 TRANSFER SIMPLIFICATION
    still not justified / not needed yet
```

## Next large block

ALT11 should bind the dynamic `b50` law to actual SWAP hydraulic functions and the current macropore case.

The priority is not further conceptual expansion.

The priority is:

```text
SWAP theta/h/soil parameters
        ->
K_surface
S_surface
        ->
dynamic b50(tau)
        ->
RFM-1B activation
```

and then compare the resulting source partition with the current reference macropore inflow over the official macropore case.

That will be the first direct reference-level test of the new activation physics.
