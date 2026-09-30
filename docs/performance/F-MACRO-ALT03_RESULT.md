# F-MACRO-ALT03 — accepted wet-wall history attribution result

Date: 2026-09-30

Status: `QUALIFIED_ATTRIBUTION_RESULT / INDEPENDENT_PHYSICAL_MEMORY_NOT_PROVEN`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Question

Does historical `FrMpWalWetOld` / `MacroporeAcceptedHistory` represent an independent physical continuation memory that a reduced macropore model must persist, or is it a temporal/numerical representation of the accepted start-of-step macropore wet-wall status?

## Repository evidence

Recovered S12 evidence establishes:

- `FrMpWalWetOld` was deliberately moved to a separate `MacroporeAcceptedHistory` object before S12o;
- current/trial `FrMpWalWet` remains outside the seven-field S12o column state;
- the accepted wet-wall history adds real persistent payload and was treated as checkpoint-relevant historical information.

This proves ownership/history classification in the legacy implementation. It does not by itself prove an independent physical degree of freedom.

## Official-theory evidence

The current SWAP macropore theory states that:

1. in a compartment where macropore or matrix is partly saturated, lateral exchange fluxes are multiplied by the fraction of macropore wall that is wet or dry;
2. the numerical iteration calculates exchange using macropore status at time `t` and matrix state variables / groundwater level at `t + dt` from the current nonlinear iteration.

Thus the physically relevant wet-wall factor for a step is tied to the macropore saturation/interface geometry over that step.

The current theory does not introduce a separate constitutive hysteresis law in which an older wet-wall fraction affects future exchange independently of current/start-of-step macropore status.

## Attribution

The evidence therefore supports the following narrower interpretation:

```text
FrMpWalWetOld
= accepted start-of-step wet-wall/contact status needed by the legacy temporal discretisation
```

rather than:

```text
FrMpWalWetOld
= proven independent long-memory material state
```

This is consistent with its placement in accepted history: a rejected trial must restore the accepted start-of-step value so that a retry recomputes the same time-step interpolation/contact geometry.

## Why elimination is not yet proven

The exact S12n source artifact that created `MacroporeAcceptedHistory` is not currently recovered in a form that exposes every read/use of `FrMpWalWetOld`.

Therefore we cannot yet prove that it is used only to form a within-step average or interpolation.

A production claim that the field can be omitted would require source-bound proof that:

```text
FrMpWalWetOld = deterministic_function(accepted fast-domain state,
                                       accepted geometry/interface state)
```

or that the required within-step quantity can be calculated directly from accepted start state plus candidate end state without additional persistent information.

## Decision

```text
E03_INDEPENDENT_PHYSICAL_MEMORY = NOT_PROVEN
E03_TEMPORAL_ACCEPTED_STATE_ROLE = SUPPORTED
E03_ELIMINATION = OPEN_PENDING_EXACT_SOURCE_TRACE
```

This distinguishes E03 sharply from E02.

E02 is analytically irreducible to current state alone because Philip sorptivity explicitly retains event-start information and elapsed contact time.

E03 currently has no equivalent evidence for constitutive long memory.

## Reduced architecture consequence

The leading reduced-state architecture should therefore not automatically allocate a separate wet-wall-history array.

Instead, test the design:

```text
accepted fast-domain state
+ accepted interface/saturation geometry
        |
        +--> derive start wet-wall fraction
candidate fast-domain state
+ candidate interface/saturation geometry
        |
        +--> derive candidate/average wet-wall fraction
```

If exact source replay confirms equivalence, wet-wall history becomes derived transactional state or worker-local step data rather than persistent physical history.

## Revised candidate state

Current best research hypothesis:

```text
persistent:
    fast-domain water/storage
    dynamic geometry only where not derivable
    Philip-event sorptivity
    Philip-event age

derived per trial/time step:
    wet-wall fraction
    exchange/rate workspace

immutable/config:
    connectivity/topology parameters where possible
```

This is not production-admitted.

## Next step

F-MACRO-ALT04 should investigate dynamic geometry next, especially whether legacy `VlMpDyCp`, `VlMpDmCp` and domain-bottom state can be derived directly from current matrix moisture plus immutable shrinkage/connectivity parameters, or whether additional persistent geometry state is truly required.
