# F-WOF04 — Crop owner resolution and minimal host contract

Baseline: `integration/f-ci-canonical` at `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`.

Status: `OWNER_RESOLVED_MINIMAL_CROP_HOST_IMPLEMENTATION_ADMITTED`.

## Owner

The normative SWAP5 owner for WOFOST crop development and plant physical state is **Crop, ET and root-uptake physics**.

This follows the target component map and the legacy-to-target migration map, which explicitly maps `wofost.f90` to Crop/ET physics behind a common plant/crop contract and `wofostnut.f90` to optional crop/nutrient physics.

## Minimal admitted production seam

F-WOF04 may create `src/crop` and add one pure, file-independent WOFOST73 biomass-reallocation subcomponent. This is the smallest independently qualified 7.3 physics seam established by F-WOF01 through F-WOF03B.

The seam must:

- separate immutable parameters, committed state, interval inputs, flux results and diagnostics;
- receive committed reallocation bookkeeping state read-only and return candidate state separately;
- capture fixed leaf/stem reallocatable caps only in candidate state when activation first occurs;
- expose leaf and stem biomass transfer out, storage-organ transfer in, conversion loss and a dry-matter residual;
- explicitly reject non-one-day duration until a separate scientific derivation qualifies arbitrary crop-process cadence;
- remain a crop subcomponent, not a second SWAP kernel and not a replacement for the future common crop contract;
- require no persistent state for runtime templates where reallocation can never become active.

## Explicit non-scope

F-WOF04 does not admit:

- broad WOFOST 7.3 porting;
- WOFOST 8.1 crop-N physics;
- removal of legacy SWAP-N;
- PCSE water balance or SNOMIN;
- irrigation or snow changes;
- soil-water solver changes;
- calendar-day assumptions in the SWAP kernel.

## Time contract

The public process shape remains `[t0,t1]`. For this source-bound seam, `t1 - t0 = 1 day` is an explicit **crop-process admission**, not a fundamental kernel timestep.

## Transaction contract

A rejected trial must not persist:

- activation;
- activation-time leaf/stem caps;
- cumulative reallocated biomass.

Repeated trials from the same committed crop state must therefore be deterministic and physically identical.

## Qualification basis

The production implementation must reproduce the pinned PCSE 6.0.13 WOFOST73 reallocation formula and the F-WOF02/F-WOF03B golden vectors exactly for the admitted domain. It must also preserve an exact zero dry-matter residual for the explicit transfer accounting.

## Architecture invariants

Primary invariants: 1, 2, 3, 4, 7, 8, 9, 16, 21, 23, 25, 27 and 30.
