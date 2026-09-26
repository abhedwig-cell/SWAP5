# F-PE-TEMPORAL02 P2 — completing-policy runtime and solve-effort comparison

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Trigger

P0 identified 5e-4 cm as the first tested common completing budget and 1e-3 cm as the first tested all-direct-accept budget.

P1 showed that 5e-4 remains very close to the 1e-3 full-step reference over the current 12-point matrix.

## Purpose

Quantify the practical runtime and retry-work difference between the two common completing candidates.

## Arms

- 5e-4 cm;
- 1e-3 cm.

Use all six difficult origins at +/-0.001 cm.

## Timing protocol

For each point/arm:

- initialize once;
- warm up five same-origin trials;
- discard each warm-up candidate;
- run 50 measured same-origin trials from the captured origin;
- discard every measured candidate;
- time only the participant trial call, excluding process startup, initialization, Python import and build cost;
- require every trial to succeed;
- report median and robust spread.

Also record deterministic q for each arm.

## Interpretation

This phase measures practical cost only.

It does not turn either budget into a physically qualified production policy.

If 1e-3 is materially faster than 5e-4 while retaining the same short-window response/state envelope, it becomes the preferred candidate for later oracle qualification.

If runtime difference is negligible, prefer the stricter candidate for subsequent qualification.

No production `src/**` change is allowed.
