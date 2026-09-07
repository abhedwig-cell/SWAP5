# F-MQ14 — F-SI02 common solver admission

Status target: qualification-only downstream admission.

F-MQ14 starts from qualified F-MQ13 head `871f4062caf490fc244db5c61693dc9a7c620f83` and consumes only exact qualified F-SI02 evidence at `da1d5da0d909c5ce55efa17507b805bffd6b82f9`.

## What is newly admissible

F-SI02 materializes and qualifies a compileable common soil-water solver contract plus a worker-owned reference-Richards workspace. The common layer has explicit request/result/workspace types, separate candidate physical state, unrounded flux/mass-residual fields, diagnostics, reserved interface-sensitivity shape, explicit workspace reset/poison operations and a payload-size query. F-SI02 independently qualified O0/O2 compilation, base-state clone independence, scratch poisoning/reset, 1/2/4/8-thread workspace isolation and separation of warm-start data from physical state.

For F-MQ this closes common-layer prerequisites for P03/P05/P06/P16/P18/P19 and adds a useful PFX01 memory-introspection prerequisite. It does not by itself satisfy those rows at real-physics or production-MultiSWAP level.

## What remains fail-closed

F-SI02 explicitly does not qualify the B1.10 reference-Richards binding, full solver reentrancy, repeated full-solver identity, full solver order/worker/poison identity, unrounded physical water-balance identity, solver route/iteration identity, interface tangent production behavior or the parallel MultiSWAP backend.

The observed F-VQ09 head is only a checkpoint for the real temporal harness asset contract and is not consumed by F-MQ14 as qualification evidence.

Therefore the F-MQ matrix counts remain:

- synthetic executable: 27/35;
- real physics executable: 0/35;
- production runtime qualified: 0/35.

No SWAP production source is modified on the F-MQ14 branch.
