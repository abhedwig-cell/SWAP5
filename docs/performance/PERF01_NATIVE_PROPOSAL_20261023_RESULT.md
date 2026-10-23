# Native crop step proposals with atomic fallback

23 October 2026. Current qualification/admission state is owned by
`benchmarks/performance/PERF01_NATIVE_PROPOSAL_20261023_STATUS.json`.
The [compatibility contract](../science/PERF01_NATIVE_STEP_PROPOSAL.md)
extends only the optional native simple-crop/ETref zero-tracer application.

## Result

The existing proposal runtime is reused unchanged. `run_project.py` now accepts
`--retain-step-proposal`; omission preserves the old default. The corresponding
namelist field remains false by default. Seasonal bottom forcing, positive tracer, Picard conductivity,
continuous conductivity and implicit transport remain excluded from this
optional application combination. General chemistry is not promoted.

Three serial O2 repetitions per mode and rainfall sequence give these observed
medians for the same97-day constructed original-input site at tolerance0.001:

| Rainfall | Native OFF s | Native ON s | Complete project OFF s | Complete project ON s |
| --- | ---: | ---: | ---: | ---: |
|1x|1.041|0.581|1.341|0.804|
|4x|1.001|0.721|1.237|0.894|

The complete route is about40%/28% faster in this sample. Native-only time falls
about44%/28%. Failed optional attempts and their full ordinary retry are included
in those timings. Compilation is excluded. These are sample observations under
unchanged hard gates, not equal global error, portable throughput or parity with
original4.3.1. This path remains substantially slower than the original program.

Keeping proposals alone failed at day83 under1x and day7 under4x. The supported
option therefore retries a proposal-caused water rejection once for the complete
same day with the incumbent policy. Real fallback days are83 for1x and7,74,92
for4x, identically at O0/O2. A failed retry propagates; a chemical or commit
rejection is never used to select this retry. The flag is restored for subsequent
days, and no persistent cursor or restart schema is added. Logs expose failed
work before retry. Original solver-limited proposal fallback remains unchanged.

## Physical and state evidence

All default-OFF budget, state, endpoint and restart bytes are exact to the
previous admitted application. Proposal runs are deterministic and O0/O2
physical outputs are byte-identical. A fresh-process day48 restart gives exact
final state, endpoint, restart bytes and all remaining49 budget rows. Full
project preparation/publication yields the same physical bytes as direct native
execution in every measured case.

Against default OFF, maximum daily runoff difference is zero at1x and below
8e-12mm at4x. Storage differences are below9e-12mm; transpiration and total
evaporation agree to floating-point rounding. There is a4x seasonal shift of
about0.0002053mm from soil evaporation to pond evaporation. Individual partition
components are therefore not called byte-equivalent. Final head differences are
about0.00111/0.00071cm; no complete daily head-equivalence claim is made.
Hard water gates remain unchanged; the capsule verifier also independently
reconstructs gross daily water from original rainfall/bottom flux and current
storage, runoff, evaporation and uptake.

Four real fallback days at both optimization levels give eight complete
before/after rejected joint generations with exact bytes. Two forced double
water failures additionally demonstrate that the fallback cannot silently finish
or alter committed state. Actual ordinary exfiltration rejection still propagates
with proposal ON. Six native unsupported-positive-tracer/numerical combinations
reject before budget publication. The source/raw owner and24 corruption controls
pass, while every predecessor assertion body remains intact behind explicit
successor dispatch. Historical predecessor science retains its original epoch;
fresh optional/default application work is recorded separately.

No shared solver/runtime/provider, tolerance, reference source or default changes.
No highest-low-air, RossFast expansion, new1e-6 trial or unrelated full F-CI run.
The manifest-bound capsule retains40 completed native/front-end executions,
six selected native input rejections, the actual failed pilots, forced fallback
failures, chemical rejection and all generated rollback probes. Whole SOL/NUT
and general native production qualification remain open.

The concurrently admitted seasonal caller is preserved. Its original8-day
constant/seasonal and481-day cross-year runners are selected again at O0/O2
on the combined application, including day365 fresh-process continuation and
independent gross water. This combination does not activate proposals for
seasonal bottom inputs. The original source/raw seasonal assertions remain
intact behind the same explicit successor mechanism.

Concurrent PR1393 native-grid observations are also preserved by a fresh
41-cell two-day default-OFF run, with exact profile/state/endpoint/budget and
all six original grid evidence controls. Historical82/164-cell observations
and censoring keep their original epoch. An accidentally uncapped365-window
probe was interrupted, retained explicitly as NOT PASS, and replaced by this
exact two-day execution; no result is inferred from the interrupted work.
