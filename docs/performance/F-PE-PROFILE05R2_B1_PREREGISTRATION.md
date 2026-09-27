# F-PE-PROFILE05R2 B1 — repeated four-arm coupled timing

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Trigger

The first five repaired-postimage four-arm live SWAP + MODFLOW6 replicas all passed endpoint/robustness gates.

However, the coupled loop is only about 0.4–0.6 ms and the stack timing was not directionally consistent:

- 2/5 stack replicas faster than exact;
- 3/5 slower than exact;
- median stack speedup about -1.98%;
- mean stack speedup about +0.74%.

This is insufficient resolution for a practical-stack speedup claim.

## Purpose

Increase timing resolution without changing model code, numerical controls or workload meaning.

## Protocol

Compile exact and A2C binaries once.

Run 15 fresh coupled processes for each of four arms:

- exact;
- A1;
- A2C;
- A1 + A2C.

Use a rotating arm order per cycle to reduce systematic order bias.

Each process uses the unchanged FGC44 live SWAP + MODFLOW6 workload.

A1 configuration:

- same-origin tangent cache ON;
- head displacement limit 0.005 m;
- max age 8.

A2C:

- production opt-in ON;
- production A2C tolerance authority unchanged.

## Required validity

Every one of the 60 runs must:

- complete;
- preserve coupled iteration count;
- preserve final MODFLOW head versus exact to the existing representation;
- preserve final SWAP exchange;
- preserve interface ledger.

Any candidate-only failure invalidates the timing result and reopens robustness.

## Timing statistics

Primary authority is the paired per-cycle stack/exact ratio.

Report:

- all 15 paired stack/exact ratios;
- median and mean stack speedup;
- minimum and maximum stack speedup;
- number of speed-positive cycles.

Also report paired:

- A1/exact;
- A2C/exact;
- stack/A1;
- stack/A2C.

The result may support a speedup claim only if the stack is speed-positive in at least 12/15 cycles and the median stack speedup is positive.

Otherwise conclude that this short live coupled fixture cannot resolve a general stack speedup, even if local/application-shaped gains remain real.
