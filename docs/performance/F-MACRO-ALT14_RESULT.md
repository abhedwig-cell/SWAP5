# F-MACRO-ALT14 — falsification matrix and first regime screen

Date: 2026-10-01

Status: `QUALIFIED_RESEARCH_DESIGN / SYNTHETIC_REGIME_SCREEN_COMPLETE`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Stop extending the RFM equations and define the experiments that can reject them.

ALT14 combines the already fixed research choices:

- compact fast-domain state;
- MB + continuous terminating-path connectivity;
- dynamic matrix-infiltrability activation;
- source-event age;
- separate Philip wall-exchange history.

The main question becomes:

> Which event regimes most strongly discriminate RFM from the current SWAP direct-entry hypothesis?

## Fixed competing hypotheses

### Current SWAP direct atmospheric component

For the structural comparison:

```text
q_pref / P = A_mp = 0.04
```

before the separately handled ponding contribution.

### RFM-1B unponded component

```text
b50(tau) = K_surface + S_surface/(2 sqrt(tau))
B ~ LogNormal(log b50, sigma_B)
sigma_B = 0.65
q_pref = P - E[min(P,B)]
```

No event-specific retuning is allowed.

## Synthetic regime matrix

Representative top states use the ALT12 default-MvG research screen.

Five high-information cases are carried forward.

### Case 1 — weak structural event

```text
h = -100 cm
P = 4
duration = 0.5 h
```

Result:

```text
total source        2.0
legacy direct pref  0.080
RFM pref            0.0143
RFM fraction        0.0071
RFM onset           ~0.045 h
```

This is the strongest low-intensity discriminator.

RFM predicts that visible/structural macropores can remain almost inactive during a weak unponded event.

### Case 2 — short intense pulse

```text
h = -100 cm
P = 60
duration = 0.1 h
```

Result:

```text
total source        6.0
legacy direct pref  0.240
RFM pref            2.390
RFM fraction        0.398
onset               immediate at diagnostic resolution
```

RFM predicts strong preferential activation even though the pulse is short.

### Case 3 — long intense pulse

```text
h = -100 cm
P = 30
duration = 2.0 h
```

Result:

```text
total source        60
legacy direct pref  2.40
RFM pref            39.28
RFM fraction        0.655
```

This is the strongest duration/intensity discriminator.

The dynamic-capacity model predicts large activation as the sorptivity contribution decays and sustained source exceeds matrix intake.

### Case 4 — wet moderate event

```text
h = -10 cm
P = 15
duration = 0.5 h
```

```text
legacy direct pref  0.300
RFM pref            0.600
RFM fraction        0.080
```

### Case 5 — very dry moderate event

```text
h = -1000 cm
P = 15
duration = 0.5 h
```

```text
legacy direct pref  0.300
RFM pref            0.766
RFM fraction        0.102
```

The dry/wet difference is not imposed monotonically; it follows from the competition between conductivity and sorptivity.

## Synthetic arrival diagnostic

The same reduced MB+continuous-IC routing operator is used only as a diagnostic to rank event observables.

For the weak event, the screen gives approximately:

```text
first 50-cm fast arrival   0.86 h
first bottom arrival      2.91 h
bottom receipt            extremely small
```

For the short intense event:

```text
first 50-cm fast arrival   0.34 h
first bottom arrival       1.82 h
```

For the long intense event:

```text
first 50-cm fast arrival   0.40 h
first bottom arrival       1.88 h
```

Absolute arrival times are not validation results because the transfer operator is synthetic.

The useful result is the ranking:

```text
weak source -> delayed and tiny deep signal
strong source -> early and material deep signal
```

This defines the observational signature to seek.

## Preregistered falsification rules

### F1 — weak-event activation

Reject the RFM activation hypothesis if independent observations show substantial immediate preferential entry/deep response under weak, unponded source conditions where matrix intake capacity should dominate.

### F2 — source-intensity response

Reject if preferential fraction does not increase materially with source intensity under otherwise comparable conditions.

### F3 — duration response

Reject the dynamic `b50(tau)` formulation if sustained forcing does not produce increasing preferential activation as transient capillary intake decays.

### F4 — antecedent-state transferability

Reject the one-`sigma_B` structure if dry/wet behavior cannot be explained using state-derived `K_surface` and `S_surface` without event-specific adjustment of `sigma_B`.

### F5 — connectivity transferability

Reject the continuous IC representation if a single geometry parameter set cannot preserve across held-out forcing states:

- arrival timing;
- termination/deposition depth;
- deep/bottom receipt;
- matrix exchange.

### F6 — mass conservation

Reject any implementation whose accepted whole-column balance does not close to the applicable SWAP mass standard.

## Experimental priority

The most informative empirical sequence is now:

1. weak unponded event on a structurally macroporous soil;
2. intense short pulse on the same profile;
3. intense sustained pulse;
4. repeat selected events under contrasting antecedent moisture;
5. ponding transition;
6. conservative tracer or high-frequency moisture sensors at multiple depths.

The same soil/profile is much more valuable than unrelated cases because it tests parameter transferability rather than recalibration skill.

## Role of current SWAP

Current SWAP is retained as:

- executable reference implementation;
- alternative physical hypothesis;
- synthetic comparison source.

It is not treated as observational truth for activation.

The key comparison is therefore three-way where data permit:

```text
observations
vs current SWAP
vs RFM
```

## Result

ALT14 does not validate RFM.

It does something more important for this phase:

```text
RFM now has preregistered failure conditions.
```

The model is no longer being developed only in directions that can make it look successful.

## Persisted harness

`tools/research/macropore_alt14_falsification_matrix.py`

The routing part is explicitly diagnostic and must not be cited as full SWAP physics.

## Next decision gate

Before introducing RFM-2 transfer simplification, the project should seek one of:

1. event-scale observational data capable of testing F1-F4;
2. exact current-SWAP event traces from the official macropore case for a three-way synthetic comparison;
3. a published benchmark dataset with rainfall, antecedent state and preferential arrival/tracer observations.

If none is available, the correct status is research hypothesis awaiting evidence, not further equation proliferation.
