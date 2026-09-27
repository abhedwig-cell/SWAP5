# F-PE-BASE01 P2 preregistration — temporal-indicator demand specialization

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_CANDIDATE`

Parent:
`F-PE-BASE01 P1B`

## Trigger

P1B measures temporal-indicator / temporal-certificate evaluation at:

- `112,698 ns` aggregate;
- `22.3632%` of q/state serialized-backend runtime.

This is the only isolated P1/P1B work family that clears the frozen 20% aggregate-backend gate.

## Candidate

Replace the two full constitutive evaluations inside the Reference temporal indicator with demand-specialized evaluations of only the quantities the indicator actually consumes.

Current base-state call computes:

- water content;
- conductivity;
- capacity;
- dK/dh.

The temporal operator uses only base conductivity.

Current candidate-state call computes the same full tuple.

The temporal operator uses:

- candidate capacity;
- candidate water content for provider/state consistency checking.

P2 candidate therefore requests only:

- base: conductivity;
- candidate: water content + capacity.

No constitutive formula is changed.

## Required semantic identity

Against the current implementation on the frozen 12-group q-only live population, the candidate must preserve:

- current right derivative;
- temporal indicator availability/status/route;
- head_inf_bound;
- raw/defect/bounded norms where observable;
- min mass weight where observable;
- q at every replay head;
- transaction attempts/retries;
- accepted substeps;
- temporal rejection count;
- nonlinear iteration count;
- solver rejection count.

Floating differences must be zero where the same scalar functions and evaluation order make bit identity possible. Otherwise differences must be bounded at roundoff and must not alter any discrete acceptance decision.

## Performance authority

Use paired/interleaved replay on the frozen LIVE01 q-only head sequences.

Report at minimum:

- temporal-indicator wall-clock current versus specialized;
- total serialized-backend wall-clock current versus specialized;
- total q/state trial wall-clock current versus specialized.

Primary advancement gate:

1. semantic/trajectory identity passes;
2. temporal-indicator runtime improves by >=15% aggregate;
3. serialized-backend runtime improves by >=3% aggregate.

The backend gate prevents admission of a micro-optimization that does not survive composition.

## Scope

Research-only in BASE01.

No production `src/**` change is admitted here.

The candidate must be implemented in generated/test copies only.

No change to:

- c=0.65;
- floor=1e-5 cm;
- temporal acceptance mathematics;
- BALTOL02;
- retry scale;
- nonlinear tolerances;
- tangent mathematics;
- MODFLOW behavior;
- constitutive equations or parameters.

## Decision outcomes

P2 closes with exactly one of:

- `QUALIFIED_SUCCESSOR_TEMPORAL_INDICATOR_DEMAND_SPECIALIZATION`;
- `REJECT_NO_COMPOSED_RUNTIME_GAIN`;
- `REJECT_SEMANTIC_DRIFT`;
- a real measurement blocker.
