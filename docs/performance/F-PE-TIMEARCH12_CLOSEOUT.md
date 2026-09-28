# F-PE-TIMEARCH12 closeout — first AUTO_REFERENCE algorithm application

Date: 2026-09-28

Status: `CLOSED_H0_APPLICATION_NO_GAIN`

TIMEARCH12 tested the first validated cheap classifier as an executed automatic proposal policy behind the redesigned timestep architecture.

The H0-gated controller preserved all 16 validation cases under P-C1 and produced no released-full fallback failures, but achieved only about 6.7% median deterministic work reduction against a frozen 15% gate.

Strict Reference equivalence passed only 5/16 cases.

Therefore no automatic controller is admitted.

## Architectural conclusion

The timestep redesign itself is not rejected.

On the contrary, TIMEARCH01-11 successfully separated configuration, proposal, event scheduling, retry, safety bounds and provenance.

TIMEARCH12 shows that the remaining blocker is algorithmic information quality, not architecture.

## User-facing conclusion

The long-term configuration direction remains:

- ordinary users should not have to tune DTMIN/DTMAX;
- LEGACY_NUMERICS preserves exact old behavior;
- AUTO_REFERENCE remains unavailable until an algorithm is truly qualified;
- DTMAX target role remains optional safety ceiling;
- DTMIN target role remains solver failure floor.

No parser/default behavior changes are authorized yet.
