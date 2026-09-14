# EB-R03 status: current-canonical effective forcing selection

Decision: **CLOSED_EMPIRICAL_OBSERVATION_SLICE**

This status closes only EB-R03 inside the continuing `research/swap431-empirical-baseline` capability.

## Evidence identity

- final observation head: `8b43ed0323afa3533f9ca170b6d599eece817e82`
- capability canonical start: `d44b2eb48e7187f8ddc622a5f2329d7a24c24aa0`
- current serialized runtime blob: `1aa2454048d0e480becaee34f596f20f1a7bd66e`
- historical F-MR38 candidate head used only as an oracle boundary: `b2e31bc8993075bc346f80ad7eb9dc4d92ff7ded`
- historical F-MR38 serialized runtime blob: `f06a2eef7b47880e449cf9b201342d7bd1e197e1`
- GitHub Actions run: `34873821318`
- EB-R03 workflow job: `104075955807`
- EB-R02 regression job in the same run: `104075955999`
- EB-R01 regression job in the same run: `104075956011`
- EB-R03 observation SHA-256: `2b73826f696750a3bbbf5cd01ef35481551d60601f382a31677ebd13c1cee2a3`

The current runtime blob is deliberately different from the historical F-MR38 blob. Therefore the historical qualification is not inherited wholesale; it is used only to define the semantic question being replayed against current canonical code.

## Results

All final gates passed:

- current serialized runtime blob identity: PASS
- historical F-MR38 separated from current runtime rather than silently inherited: PASS
- current registry and resolved-forcing seams present: PASS
- `-O0` versus `-O2` observation identity: PASS
- registry handle selects the expected effective forcing: PASS
- A-B-A forcing replay is stateless: PASS
- explicit resolved forcing controls the common executor independently of the retained registry handle: PASS
- invalid forcing handle fails before trial execution: PASS
- EB-R01 and EB-R02 regressions in the same workflow run: PASS

Observed values:

| case | route | handle | effective scale | committed | admission | total mass in | storage change | final revision | active calls |
| --- | --- | ---: | ---: | :---: | --- | ---: | ---: | ---: | ---: |
| registry_a | registry | 1 | 1.0 | yes | ADMITTED | 0.100000000000000006 | 0.100000000000000089 | 1 | 0 |
| registry_b | registry | 2 | 2.5 | yes | ADMITTED | 0.25 | 0.25 | 1 | 0 |
| registry_a_replay | registry | 1 | 1.0 | yes | ADMITTED | 0.100000000000000006 | 0.100000000000000089 | 1 | 0 |
| resolved_b_with_handle_a | resolved | 1 | 2.5 | yes | ADMITTED | 0.25 | 0.25 | 1 | 0 |
| invalid_handle | registry | 3 | n/a | no | ROUTING_REJECTED | 0.0 | 0.0 | 0 | 0 |

## Empirical interpretation

The current serialized registry route resolves `column%forcing_handle` to the corresponding forcing-registry entry before entering the shared physical execution path. Changing only the selected forcing from scale 1.0 to scale 2.5 changes the deliberately observable mass response from 0.1 to 0.25 for the same state, parameters and half-unit interval.

Repeating forcing A after forcing B reproduces the A mass result exactly in the textual observation. Within this seam there is no evidence that a previously selected forcing object is retained as hidden mutable runtime state.

The resolved-forcing entry point is genuinely explicit: with `column%forcing_handle=1` retained as routing metadata but forcing B supplied directly, the common executor produces the B result of 0.25. The registry handle is therefore not silently re-read inside that resolved route.

A forcing handle outside the registry is rejected before the physical trial and produces no state revision or mass transfer.

## Test isolation

EB-R03 executes the real current-canonical `mod_fmr_serialized_multiswap_runtime.f90`. A deterministic probe backend replaces the heavy physical backend only to make selected forcing identity numerically visible. The probe uses

`transfer = transfer_rate * forcing_scale * interval_duration`

with identical state and parameters between cases. This isolates the dispatcher question from Richards-solver response and prevents unrelated nonlinear behaviour from obscuring a routing defect.

## Harness findings during qualification

Two red intermediate runs were harness failures rather than model discrepancies:

1. `mod_soil_water_solver_contract.f90` contains an abstract/default unavailable implementation with intentionally unused interface arguments. Only this support compilation leaves `unused-dummy-argument` as a warning. The current dispatcher, probe backend and observer remain compiled under `-Werror`.
2. The first observer defined a type-bound override through an internal main-program procedure, which is not a valid Fortran binding form. The provider was moved into a small test module. No expected forcing result or production source changed.

Existing support modules with exact REAL comparisons continue to emit visible warnings where required; those warnings are not treated as EB-R03 forcing-selection failures.

## Evidence inheritance

EB-R03 remains reusable while these dependencies and semantics remain unchanged:

- current `src/runtime/mod_fmr_serialized_multiswap_runtime.f90` blob `1aa2454048d0e480becaee34f596f20f1a7bd66e`;
- registry routing through `column%forcing_handle` and `forcing_registry(forcing_index)`;
- resolved execution receiving an explicit `effective_forcing` object;
- the EB-R03 observer and probe backend at final observation head `8b43ed0323afa3533f9ca170b6d599eece817e82`.

A relevant dependency change requires re-observation. Unrelated changes do not invalidate this evidence.

## Hard nonclaims

EB-R03 does not claim:

- that different effective forcing objects produce the expected response under the full B1.10 Richards physics;
- a complete meteorological acquisition, interpolation, interception, snow or irrigation forcing baseline;
- equivalence to running the complete supplied SWAP 4.3.1 binary distribution;
- scientific qualification of the synthetic probe backend;
- any new SWAP5 production capability or admission.

## Next empirical slice

The forcing selection seam is now observed strongly enough to move downstream. Continue on the same capability branch with a soil-water and flux observation using the real B1.10-derived physical runtime. The next slice should expose state/storage change, accepted boundary fluxes and mass closure under a small deterministic physical case while keeping the distinction between qualified B1.10-derived runtime and a complete SWAP 4.3.1 distribution run explicit.
