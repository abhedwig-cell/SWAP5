# F-PE-EMBEDSTEP01 result — selective full-versus-two-half guard

Date: 2026-09-28

Status: `CLOSED_TRIGGER_AND_OVERHEAD_REJECTED`

Authority:

- canonical base: `integration/f-ci-canonical@7b73f4545f79e3e3575ed21d9c94d3d5a21e3ea9`;
- Actions run: `36417119772`;
- conclusion: SUCCESS.

## Result

All three preregistered embedded envelopes produced the same aggregate result:

- P-C1 pass: 14/16;
- median guard checks: 2 per case;
- median guard rejections: 0;
- median deterministic work change: about -20.8%;
- wet/ponding preservation: FAIL.

The embedded thresholds therefore had no practical selection effect in the tested bank.

## Failure attribution

B12/MOIST failed P-C1 with zero guard checks. The candidate diverged while dt was still at or below the current Reference DTMAX.

B01/POND still entered a nonconvergent path.

Therefore the selective trigger `dt > Reference DTMAX` was too late to preserve the Reference behavior below that threshold, while full+two-half checking added substantial work where it did trigger.

## Decision

Reject this full-versus-two-half guard architecture.

The valid successor must preserve historical Reference-TimeControl behavior whenever dt remains within the current Reference envelope and use state-aware acceleration only to request intervals beyond that envelope.
