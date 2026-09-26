# F-PE-PROFILE06 P2 — difficult directional-stack measurement

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Frozen case set

P1 selected six cases using the preregistered exact-work rule:

- B01 wet, h0 = -10 cm;
- B01 mid, h0 = -75 cm;
- B12 wet, h0 = -10 cm;
- O05 wet, h0 = -10 cm;
- O14 wet, h0 = -10 cm;
- O14 mid, h0 = -75 cm.

P1 evidence:

- exact nonlinear work spans 116 to 250 iterations per 20-step sequence;
- A2C reduces nonlinear work by about 28 to 34% in these selected cases;
- median direct-solve runtime gain is material in every selected case;
- state/flux/cumulative-exchange deviations remain inside the existing A2C envelope.

## Purpose

Test whether A1 tangent reuse and A2C solve-effort reduction are complementary when the accepted-direction route is exercised on genuinely difficult hydraulic states.

## Route

Use the real FGC44 transaction participant:

- prescribed-head bottom mode 5;
- accepted-direction response tangent requested;
- same-origin repeated corrector trials;
- production A1 cache implementation;
- production A2C flag.

No synthetic tangent-only shortcut is allowed.

## Arms

For every frozen case measure:

1. exact;
2. A1 only;
3. A2C only;
4. A1 + A2C.

A1 policy remains:

- head displacement limit 0.005 m;
- max age 8;
- same-origin lineage/revision/window rules unchanged.

A2C remains the qualified `1e-8` convergence quartet.

## Timing

Use at least five replicated timing measurements per arm/case.

Within each timing measurement execute enough same-origin corrector trials that wall-clock time is well above timer noise.

Record:

- ns/trial;
- fresh tangent count;
- reused tangent count;
- response exchange checksum;
- tangent checksum;
- failures.

## Validity

For all arms:

- every trial must be valid;
- q checksum must match exact at the same requested heads;
- same-head tangent checksum must match exact for the cache-valid requests;
- no candidate-only transaction failure.

## Interpretation

Report direct measured ratios only.

For each selected case:

- A1/exact;
- A2C/exact;
- stack/exact;
- stack/A1;
- stack/A2C.

The result demonstrates complementarity only if stack is faster than both A1 and A2C in at least four of the six cases using median replicated timing.

Otherwise the remaining optimization target should be chosen from the measured dominant arm/cost, not from arithmetic combination of prior speedups.
