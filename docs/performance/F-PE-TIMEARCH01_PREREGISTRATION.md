# F-PE-TIMEARCH01 preregistration — timestep architecture audit and redesign

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_ARCHITECTURE_DECISION`

Canonical authority:

`integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`

## Trigger

BOFEK01/02, BOFEK-PRACTICAL, STATESTEP, EMBEDSTEP and DYNERR01 show that substantial performance headroom exists in timestep selection, but repeated tuning inside the current `DTMIN/DTMAX + iteration-count + event-clamp` architecture does not produce a robust production policy.

This workunit therefore does not tune another timestep parameter.

It asks whether the timestep architecture itself should be redesigned.

## Scope

Audit the current canonical timestep/control stack end to end:

1. legacy `TimeControl`;
2. internal Richards retry;
3. event alignment;
4. day/output/meteo/irrigation/runon constraints;
5. transaction retry;
6. temporal acceptance/certificate policy;
7. coupling-window boundaries;
8. process-specific timestep reductions.

No production source modification in TIMEARCH01.

## Questions

1. Which current timestep controls are true numerical integration policy?
2. Which are hard event boundaries that must be preserved exactly?
3. Which are solver-failure recovery?
4. Which exist only because of legacy day-oriented control flow?
5. Which controls overlap or duplicate transaction/temporal mechanisms added in SWAP5?
6. Should `DTMIN` and `DTMAX` remain user-facing scientific inputs, become optional safety bounds, or disappear from normal user configuration?
7. What minimal modern timestep-controller contract would preserve all canonical physical and transaction invariants?

## Decision rules

A redesign is justified if all are true:

- current authority demonstrably mixes at least three independently owned concerns in mutable `dt` state;
- the concerns can be separated without changing physical equations;
- canonical event boundaries can be represented independently from numerical step proposal;
- solver retry can be represented independently from accepted-step growth;
- transaction and temporal acceptance contracts remain intact;
- the target architecture can emulate current Reference behavior as one policy profile.

If these conditions fail, close without redesign recommendation.

## Production boundary

TIMEARCH01 is architecture-only.

Possible outcomes:

- `QUALIFIED_TIMESTEP_ARCHITECTURE_REDESIGN`;
- `CLOSED_KEEP_CURRENT_TIMECONTROL_ARCHITECTURE`;
- `BLOCKED_<reason>`.
