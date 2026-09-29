# F-PE-TIMEINT11 closeout — two-stage stiff embedded integrator feasibility

Date: 2026-09-29

Final status:

`CLOSED_TRBDF2_DEFAULT_COST_TOO_HIGH`

## Decision

Do not implement TR-BDF2/ESDIRK as the primary smooth-regime SWAP5 integrator.

The optimistic lower-bound work cost is already approximately twice that of the qualified fully implicit BDF2 path.

## Current preferred modernization path

The research evidence now favors:

- fully implicit variable-step BDF2 for smooth accepted trajectories;
- accepted adjacent step ratio bounded to 0.5..2.0;
- first-order restart/bootstrap where history is invalid;
- explicit history invalidation at hard events and regime transitions;
- no legacy NUMBIT-based growth law as the long-term accuracy controller.

The unresolved problem is not the smooth integrator.

It is robust treatment of real SWAP discontinuities and dynamic-top regime transitions.

## Required successor

`F-PE-TIMEINT12 — dynamic-top BDF2 with explicit first-order transition fallback`.

TIMEINT12 should:

1. move the qualified BDF2 mechanism from fixed-flux to the BOFEK00 corrected dynamic-top route;
2. use BDF2 only while accepted boundary regime/history is smooth;
3. detect an accepted dynamic-top regime change;
4. re-evaluate that interval with fully implicit first-order BE from the same origin;
5. commit the BE transition step;
6. invalidate BDF2 history;
7. rebuild BDF2 after one accepted first-order bootstrap step;
8. compare against current Reference on wet/ponding trajectories and smooth dry controls.

This isolates the next architecture question: can higher-order integration coexist cleanly with SWAP's piecewise surface-boundary physics?

## Production boundary

No production source change.

LEGACY_NUMERICS remains default.
