# F-GC-STRIP01 C2B local continuation

Date: 2026-10-03. Status: reproduced bounded negative; coupled rainfall remains unqualified.

The target remains a working 50-cell, 50 m SWAP-MODFLOW6 strip with a sole left drain, closed right/base, explicit storage ownership, precipitation, closed whole-domain water balance and committed restart/replay. Canonical admission is outside this experiment.

## Source and ownership

Research preimage: `3bce390955d03a3c5920f76b12306d1bc8b2e7d5`. Canonical solver/runtime source: `e3bfcdca00ba89cfeea529cf9b648dcc803483ab`. Each of three local builds compiled 144 `src/` dependencies. Every blob equals the pinned canonical tree. Research changes are limited to fixtures, harnesses and evidence. No production source changed.

The invariants exercised are committed-state preservation on rejection, physical storage in SWAP only for this confined/no-STO configuration, internal interface exchange counted once, and publication ordered MODFLOW then SWAP then interface ledger. Restart is still open.

## Harness repairs

The RAIN01 harness supplied two MODFLOW stress periods but omitted `nper=2`; FloPy wrote `NPER 1`. Native MODFLOW terminated at initialization with `mem_set_value() size mismatch dbl1d, varname=PERLEN`. This reproduces the exit-code-2 failure of Actions run 37112863908 and is not numerical rejection evidence.

The second window must bind a fresh application plan/context to committed revision 1 and `[0.001,0.002]` day. Reusing the published revision-0 context is invalid. The repaired fixture explicitly creates this transition. It is exercised by the fixed-flux sequence; the dynamic variants reject before reaching their transition.

JSON serialization now writes an actual newline instead of a literal backslash followed by n.

## Verified results

| Variant | C2a | C2b | Limit of the observation |
| --- | --- | --- | --- |
| Fixed imposed top flux with temporal history | Published | Rejected at SWAP corrector | A zero-forcing transaction works; rainfall does not qualify under the frozen gates. |
| Dynamic B1.11 Black surface route, model certificate | Rejected before solver | Not reached | Unsupported capability combination, not a nonlinear solver failure. |
| Same dynamic route, external full/half | Rejected before solver | Not reached | Changing the temporal route alone cannot remove the mode-5 exclusion. |

For fixed-flux C2b, all 50 columns retain revision 1 and one committed ledger entry. Physical/history hashes and accepted MODFLOW XOLD are unchanged; no second MODFLOW timestep is finalized. The equilibrium window has zero input, drain and storage change. Each variant was repeated in a fresh process with byte-identical JSON.

An isolated fixed-flux probe from the fresh hydrostatic origin applies 0.1 cm/day surface input and holds interface head at -1 m. Durations from 1e-3 through 1e-7 day all exhaust the existing eight retries without accepted substeps. At 1e-3 day the nine attempts comprise three solver and six temporal rejections. No mass or admission rejection occurs. This probe is not a continuation or timestep-convergence result.

## Direct backend blocker

In `src/runtime/mod_fmr_serialized_reference_backend.f90`, `fmr_serialized_execution_admitted` requires `parameters%bottom_mode /= 5` for both Black and Boesten optional evaporation states. The dynamic rainfall fixture uses Black to route precipitation through the existing B1.11 surface balance and uses mode 5 for groundwater-head coupling. Both dynamic variants therefore return `KERNEL_STATUS_NOT_ADMITTED=101` with one admission rejection, zero numerical attempts and zero completed time for all five probed durations.

There is a second independent interface constraint: Black optional state and Richards temporal-history state are mutually exclusive in `state_matches_numerical_continuation_layout`. Therefore merely deleting the mode-5 exclusion would not establish a valid model-certificate route. The plain external full/half temporal comparison currently requires exact physical identity and is not a general error estimator for forced Richards trajectories. These are shared backend semantics, outside the fixture-only owning surface. They must be resolved and qualified explicitly before declaring rainfall capability.

## Next implementation boundary

The next repair belongs to the serialized backend/surface/temporal capability owner. Establish a supported contract for dynamic precipitation plus mode-5 head coupling, including complete physical/optional state, accepted numerical history, ordinary candidate execution and rollback. Alternatively define an explicitly qualified imposed-infiltration route, with its narrower surface-physics scope stated. Preserve all frozen mass/flux gates and the earlier negatives. Do not use a reference-floor candidate as an accepted transaction.

After that shared capability is qualified, rerun the continuous C2a/C2b sequence, require accepted rainfall and native lateral/drain response, then extend duration and check cumulative mass, Hupsel forcing, committed restart and exact replay. C2a alone is not a working strip benchmark.

Evidence and all three compiled source manifests are in `integration/f-gc/strip01/results/c2b-local-20261003/`. `validation.json` records source binding, native engine hash and exact replay checks.

## Reproduction

Build with `tools/build_f_gc_strip01_research_context.py --root <exact canonical checkout> --profile C1 --build <build> --context-override tests/fgc/strip01/research_context_c2_rain.f90`; overlay only the registered C1 grid stub. Run `tests/fgc/strip01/run_c2_rain_sequence.py --profile C1 --root <canonical checkout> --library <build>/libstrip01_research.so --libmf6 <verified engine>/libmf6.so --output <fresh directory>`. Repeat in another fresh process and compare JSON. For the external full/half control use `research_context_c2_rain_fullhalf.f90`. For the ordinary imposed-flux sequence build `research_context_c2.f90` and run `run_research_sequence_c2.py`.

Prerequisite libraries: NumPy, FloPy 3.9.5, xmipy; native MODFLOW6 6.8.0. Compiler flags and exact dependencies are emitted by the build script.
