# F-PE-APPROX01 Lever01 preregistration — lagged bottom-head coupling tangent

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent exact authority:
`F-PE-DIR01@584af6ce2e6e4a6cd2c790e6341805e56085127b`

Canonical authority underneath the stack:
`integration/f-ci-canonical@c52454b31d6f5d6ae6ed6af56460f158ddb45008`

## Motivation

The exact performance phase is closed.

On the retained DIR01 postimage, the production bottom-head directional route still costs approximately 73% more than the corresponding Reference route, despite exact removal of:

- repeated directional ownership copies;
- request-vector allocation waste;
- one complete repeated default-MvG conductivity value pass.

The remaining tangent cost is increasingly tied to genuine derivative construction.

For the practical SWAP5-MODFLOW6 target, the next question is therefore not how to make every tangent exact and cheaper, but whether every coupling evaluation needs a freshly recomputed tangent.

## Approximation lever

Lever01 tests:

**reuse the most recently accepted bottom-head response tangent for a bounded number of subsequent coupling evaluations instead of recomputing it every time.**

The physical SWAP solve remains exact.

Only the coupling response derivative is lagged.

This is deliberately narrower than:
- looser Richards convergence;
- approximate constitutive state;
- altered mass balance;
- altered accepted SWAP state.

## Why this lever is first

The directional tangent is the largest clearly measured remaining incremental cost.

Skipping one tangent evaluation can therefore avoid a much larger block of work than small residual allocation or publication repairs.

At the same time, keeping the physical state solve exact isolates the approximation to the coupling accelerator rather than the hydrological state trajectory itself.

## Experimental modes

Initial experiments shall compare:

- `fresh-1`: exact reference, fresh tangent every evaluation;
- `lag-2`: reuse the last accepted tangent for at most one subsequent evaluation;
- `lag-4`: reuse for at most three subsequent evaluations;
- `lag-8`: reuse for at most seven subsequent evaluations.

These are experiment labels, not production settings.

No mode is admitted in advance.

## Mandatory refresh conditions

A lagged tangent may never be reused across an invalid provenance boundary.

At minimum, force a fresh tangent when:

- no prior accepted tangent exists;
- worker / column identity changes;
- bottom-head control coordinate changes;
- accepted trajectory generation is discontinuous;
- solver route changes;
- a trial is rejected or retried in a way that invalidates the accepted response;
- a configured error indicator exceeds its bound.

Additional refresh conditions may be added when evidence requires them.

## Qualification metrics

Every candidate must be compared with `fresh-1` for:

### Performance
- directional evaluations avoided;
- end-to-end coupling/runtime speedup;
- solver wall clock;
- tangent wall clock separately where available.

### Response error
- instantaneous bottom-exchange tangent error;
- predicted versus realized bottom-flux response to head perturbation;
- accumulated groundwater exchange;
- coupled MODFLOW head response where the fixture supports it.

### Physical preservation
Because the physical SWAP solve remains exact:
- accepted pressure head;
- water content;
- water balance;
- physical top/bottom flux of the solved state

must remain identical for a given forcing sequence.

If they do not, the experiment has unintentionally broadened beyond tangent lagging and must fail.

## Error measures

Report both absolute and relative errors.

Do not use relative error alone near a zero tangent.

At minimum retain:
- absolute derivative error;
- relative derivative error when the denominator is well conditioned;
- induced bottom-flux prediction error for a prescribed small head perturbation.

## Initial envelope discovery

The first phase does not set a production tolerance.

It maps the speedup/error frontier for `lag-2`, `lag-4` and `lag-8` over representative wet/mid/dry cases.

The purpose is to learn:
- how quickly the tangent changes;
- which hydraulic regimes tolerate lagging;
- whether a simple fixed cadence is viable;
- whether an adaptive refresh indicator is necessary.

## Admission rule

No production approximate mode is allowed until:

1. the error frontier is measured on representative production cases;
2. a bounded refresh rule is defined;
3. the mode is opt-in and default OFF;
4. diagnostics expose that tangent reuse occurred;
5. end-to-end speedup is materially larger than the remaining exact optimization gains.

## Rejection rule

Reject fixed-cadence lagging if:
- tangent error grows abruptly or non-monotonically in relevant regimes;
- small derivative errors create large coupling-response errors;
- speedup is too small to justify approximation;
- a robust refresh rule cannot be defined.

If fixed cadence is rejected but tangent evolution is predictable from accepted-state changes, the next experiment may test an adaptive refresh trigger. That is not assumed in advance.
