# F-CI05 B1.10 Physical Adapter Preimage

## Decision

F-CI05 qualifies the exact B1.10 physical adapter preimage and the legacy seams that a canonical adapter must replace or isolate. It does **not** admit a physical adapter yet.

This distinction is intentional. Importing the A23BU Hupsel adapter wholesale would reintroduce B1.6 assumptions and would claim transaction semantics that the exact B1.10 source does not expose cleanly.

## Exact source identity

The available SWAP 4.3.1 distribution was inspected at its nested source archive:

`SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`

The nested archive SHA-256 is exactly:

`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`

This is the source-archive identity pinned by B1.10. The archive contains 63 Fortran source files.

The B1.10 patch chain changes macropore, crop development, meteo, oxygen stress, tridag, hydraulic constitutive code, readswap, inverse hydraulic functions and tillage. It does not modify the six physical seam files pinned by `F-CI05_B1_10_PHYSICAL_SEAM.json`. Therefore those seam files are byte-identical between the exact B0 source archive and B1.10.

## What exact B1.10 already exposes

`swap.f90` already has tasks 1, 2, 3, 11 and 21. Task 21 can replace `tstart/tend`, reset run switches and reinitialize soil-water state variables. This is useful and means a future port does not need to invent a new physical restart concept.

However that is not sufficient for a canonical transactional backend.

## Blocking legacy properties

### Module-global state

The exact source still contains extensive `SAVE`/module-global state. `variables.f90` is a global state container and `headcalc.f90` itself contains persistent solver variables. A canonical column checkpoint cannot therefore be defined merely by cloning a small external object.

### Trial output side effects

The dynamic SWAP task calls output routines from inside the physical time loop. A rejected transaction could therefore create irreversible reporting/file side effects unless output is isolated or suppressed outside accepted commit handling.

### Forcing ownership

The normal `iCaller /= 2` dynamic path obtains forcing through legacy meteo state/file machinery. The DLL exchange path can inject weather, but its timing contract explicitly rejects `TEND != TSTART` and is therefore a single-day exchange API, not the generic canonical `[t0,t1]` seam.

### Numerical scratch

HeadCalc contains saved Newton/solver work variables. F-CI03 already established the target architecture in which that scratch is worker-owned. The exact B1.10 source does not yet implement that ownership.

## Required controlled source port

The next source-changing unit may modify B1.10 only through a new, exact B1.10-bound port. The minimum required changes are:

1. expose an explicit physical continuation state that can be captured/restored without copying numerical scratch;
2. move or project HeadCalc scratch/history to worker-owned context;
3. isolate trial reporting/output so rejected trials have no externally visible side effects;
4. provide a forcing seam separate from persistent state and independent of file parsing inside the kernel path;
5. preserve B1.10 physics and all corrected-reference fixes;
6. retain generic real-valued interval semantics at the canonical API even where legacy calendar events must be projected internally;
7. expose accepted unrounded mass totals needed by the canonical result contract;
8. qualify irrigation/crop/process continuation explicitly rather than assuming that module globals are harmless.

## Fail-closed rule

Until those capabilities exist in materialized source and focused qualification passes, the canonical status remains:

`B1_10_PHYSICAL_ADAPTER_BLOCKED_PENDING_CONTROLLED_SOURCE_PORT`

A compileable adapter that still relies on hidden global continuation or trial output leakage is not admissible.

## Invariant check

This decision protects invariants 2, 3, 4, 5, 7, 8, 9, 13, 16, 23, 26, 29 and 30. It also avoids falsely declaring generic physical time complete merely because task 21 accepts two real arguments.
