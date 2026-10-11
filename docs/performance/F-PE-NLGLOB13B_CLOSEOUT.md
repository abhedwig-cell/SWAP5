# F-PE-NLGLOB13B closeout — bounded second-level failing-half subdivision

Date: 2026-09-29

Final status:

`CLOSED_TG_NEARSAT_SUBDIV4_DOMAIN_PERSISTS`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@5c498c9df933f900fd00869b72106584f10f6622`

Qualification authority:

- run `36555701610`;
- job `109364205596`;
- conclusion: SUCCESS.

## Closure

NLGLOB13B closes the bounded `h/4` subdivision candidate negatively.

All seven O05/TG near-saturation target trajectories still fail accepted-state retention admissibility at quarter-step scale.

No target case fails for endpoint, route, ponding, nonfinite or mass reasons.

Smooth second-order authority and physical mass remain preserved.

## Closed route

Do not add `h/8` inside NLGLOB13B.

The next question is not another subdivision depth but the scaling law of the accepted-state overshoot with temporal resolution.

## Direct successor

Open:

`F-PE-NLGLOB13C — near-saturation accepted-state overshoot scaling`.

P0 must remain observational.

For the seven target trajectories, at the first failing nominal interval record the prospective accepted TG state for:

- the full failing interval;
- the corresponding failing `h/2` interval;
- the corresponding failing `h/4` interval.

Record at least:

- maximum `theta_TG - theta_s`;
- normalized overshoot relative to `theta_s-theta_r`;
- node identity;
- accepted pre-subinterval distance to saturation;
- temporal scale.

No `h/8` solve or state acceptance is authorized in NLGLOB13C.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB13B

BASELINE: `5c498c9df933f900fd00869b72106584f10f6622`

BRANCH: `research/f-pe-nlglob13b-quarter-subdivision`

STATUS: closed negative

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `CLOSED_TG_NEARSAT_SUBDIV4_DOMAIN_PERSISTS`

NEXT SAFE STEP: preregister NLGLOB13C overshoot scaling attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
