# F-PE-TIMEARCH09 preregistration — user DTMIN/DTMAX semantics

Date: 2026-09-28

Status: `PREREGISTERED_CONFIGURATION_ARCHITECTURE`

Canonical authority:

`integration/f-ci-canonical@71b15a81a77c7e301fd6221bce990d85cd24b43f`

## Purpose

Decide whether DTMIN and DTMAX should remain ordinary required user inputs in modern SWAP5.

This workunit does not change numerical execution.

It classifies the semantic role each bound should have in the target timestep architecture.

## Existing evidence

### DTMAX

TIMEARCH03:

- 186 accepted steps;
- 90 accepted proposals hit the global DTMAX ceiling;
- DTMAX hit fraction 48.4%;
- shadow controller preferred dt above DTMAX on 41.9% of accepted steps.

By regime, DTMAX is most active in DRY and TRANSITION cases.

Hupsel:

- DTMAX = 0.04 d;
- 1096 days;
- 32518 timestep records;
- about 29.67 steps/day;
- DTMAX alone imposes at least 25 steps/day even before nonlinear difficulty or events.

Therefore current DTMAX is a normal operating selector, not merely a safety ceiling.

### DTMIN

BOFEK/TIMEARCH03:

- 188 attempted intervals;
- only 2 solver retries;
- no evidence that DTMIN is a common accepted-step selector on the 20-case bank.

Hupsel:

- DTMIN = 1e-6 d;
- DTMAX = 0.04 d;
- ratio = 1:40000.

SHORTSTEP/TEMPORAL work:

- reducing step duration can worsen nonlinear convergence in difficult Reference cases;
- therefore smaller dt is not monotonically equivalent to safer or more accurate execution.

Legacy TimeControl also uses DTMIN as:

- solver-retry floor;
- terminal/floor flag;
- initialization constraint through DTMIN <= 0.1*DTMAX.

## Candidate future semantics

### DTMAX options

A. required user timestep-policy input;

B. optional expert safety ceiling, with normal dt selected automatically;

C. remove entirely, including expert override.

### DTMIN options

A. required user timestep-policy input;

B. optional expert numerical-failure floor;

C. internal solver-profile floor with no ordinary user input, plus optional advanced override.

## Decision criteria

A bound should remain ordinary user input only if:

1. users can select it from physical/model requirements rather than solver internals;
2. it represents a stable scientific meaning across regimes;
3. it is not primarily compensating for limitations of the current controller;
4. removing it from ordinary input would make model behavior less auditable or less safe.

Backward compatibility is a migration constraint, not by itself a reason to preserve the input as a permanent normal-user concept.

## Production boundary

No parser/default/timestep behavior changes in TIMEARCH09.
