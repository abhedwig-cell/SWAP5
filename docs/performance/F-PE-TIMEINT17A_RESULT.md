# F-PE-TIMEINT17A result — same-route dynamic-top Thomas-Gladwell bank

Date: 2026-09-29

Status:

`BLOCKED_TIMEINT17A_BANK_NOT_SAME_ROUTE`

Canonical base:

`integration/f-ci-canonical@4a45a599093c6ed6da458dc35fbb71f462439ef4`

Qualification authority:

- workflow run: `36528763178`;
- job: `109277488084`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17A asked whether the qualified TIMEINT16C provider-consistent Thomas-Gladwell mechanism remains second order and conservative on dynamic-top intervals that stay on one physical boundary route for the entire four-level dt ladder.

The bank deliberately rejected any ladder in which origin route, BE predictor route, or accepted TG route changed.

## Result

The numerical job completed successfully, but zero ladders satisfy the frozen same-route eligibility definition.

Final classification:

`BLOCKED_TIMEINT17A_BANK_NOT_SAME_ROUTE`

This is a bank-design blocker, not a negative result against the TG temporal mechanism.

## Why the bank is ineligible

Every one of the 12 material/route fixtures contains at least one route transition on at least one member of the four-level dt ladder.

Examples:

- B01 / FLUX has transition steps `[0,0,7,1]`;
- B12 / FLUX has `[0,0,3,1]`;
- O05 / FLUX has `[0,0,9,1]`;
- O14 / FLUX has `[0,8,1,1]`;
- most HEAD and RUNOFF fixtures transition at step 1 or within the first few steps.

Therefore no four-level ladder can be used to estimate smooth within-route order without mixing event semantics into the measurement.

## Positive diagnostics preserved

Although the bank is ineligible for order qualification, the completed pre-transition segments show no evidence of a mass or constitutive defect.

Across observed TG segments:

- physical per-step ledgers are at roundoff scale, order `1e-14 cm`;
- cumulative ledgers are at roundoff scale;
- theta/head roundtrip is at roundoff scale;
- native endpoint balance residual remains far below the frozen `5e-8 cm/d` gate;
- surface-rate collocation residual is at or near roundoff;
- predicted-K diagnostics remain finite.

The median work ratio over comparable eligible partial segments is approximately `0.98` versus KLAG.

These diagnostics are supporting observations only. They do not qualify same-route second-order accuracy because the frozen ladder requirement was not met.

## Interpretation

The failure mode is structural to the chosen fixtures:

the initial states and forcing place the trajectories close enough to a dynamic-top regime surface that refining dt exposes a route event inside the nominal horizon.

Coarse-step route persistence is not evidence that the underlying continuous trajectory is same-route.

The finer ladders correctly reveal that the bank crosses a physical route boundary.

Therefore:

- do not relax the requirement that all four dt levels remain same-route;
- do not drop fine-grid members after seeing the result;
- do not reinterpret a transition-containing ladder as a smooth-order ladder;
- do not proceed to event localization under the parent P0 gate yet.

## Required next step

Open a separately preregistered same-route bank repair.

The repaired bank must choose initial states and forcing by explicit route-margin criteria derived from the existing dynamic-top provider algebra, not by trial-and-error selection after observing trajectory outcomes.

Required coverage remains:

- at least 3 hydraulic materials;
- FLUX, HEAD and RUNOFF route families;
- four-level halving ladders;
- exact physical mass accounting;
- TIMEINT16C provider-consistent TG staging unchanged.

Only if that repaired bank qualifies may TIMEINT17 proceed to known-time or endogenous event splitting.

## Production boundary

No production `src/**` change.

No mass-gate change.

No dynamic-event localization is qualified by TIMEINT17A.

`LEGACY_NUMERICS` remains production default.
