# F-PE-SETUP05 closeout — post-admission large-N setup reprofile

Date: 2026-09-27

Status: `CLOSED_SETUP_FRONTIER`

PR:
`#683 — F-PE-SETUP05: post-admission large-N setup reprofile`

## Decision

SETUP04 removed the meaningful large-N setup bottleneck.

At N=40,000:
- total setup through first warm physical trial: about 1.845 s;
- first physical trial/tangent/discard: about 1.547 s;
- app initialize: about 0.129 s;
- context materialization: about 0.050 s;
- configuration construction: about 0.076 s.

No remaining non-physical setup family clears the preregistered successor threshold.

The setup line is therefore closed as low expected return.

## Reopen rule

Reopen only if:
- production lifecycle begins rebuilding contexts frequently enough that setup re-enters end-to-end wall time materially; or
- a new non-physical setup family owns >=25% and >=0.25 s at representative large N.

## Production boundary

Observation-only.
No production source change.

## Closure

`CLOSED_SETUP_FRONTIER`
