# PPA-WU05-C3Q — first executed oracle/parity result

Date: 2026-10-01

Status: `QUALIFIED_NUMERICAL_POLICY_RESULT / FULL_REFERENCE_ADMISSION_PENDING`

## Exact source input

The already retained Library copy of `SWAP_4.3.1.zip` was materialized locally and passed the canonical VQ identities:

- distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- nested `SWAP.ZIP` SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`
- B0 `oxygenstress.f90` was transformed with the admitted SWAP-007 replacement and reproduced corrected oxygen identity `8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87`.

Later B1.11 patches do not modify `oxygenstress.f90`; current B1.11 VQ identity/admission also passed on PR #962.

## Executed oracle run

Compiler: GNU Fortran 14.2.0.

Case: official `2.grassgrowth`, five-year case.

Result:
- process return code: 100;
- `Swap normal completion!`;
- `swap.ok` present;
- `swap.err` empty.

The first unbounded diagnostic implementation exposed a tooling defect: Fortran `NEWUNIT` may return a negative unit, so testing `unit < 0` reopened the trace on every call and exhausted file descriptors. This was corrected to an explicit logical open flag.

The full per-call trace was then deliberately bounded to:
- the first 500 evaluations;
- all later physical evaluations with `rwu_factor < 0.999999`;
- no unbounded saturated-route logging.

Final trace:
- 72,382 CSV lines including header;
- trace SHA-256 `bb0f58072c49456ffe9817cc0c10f7d042a0a9393e42f67db1abd678322dad18`;
- diagnostic executable SHA-256 `05b7eb40bc0447d171dfcea285fdd40214eb2d85ed5710b53491489b0c1ad50f`.

## Independent bounded-solver replay

The exact source equations for MICRO and MACRO were independently replayed from the captured physical inputs. The candidate policy used:
- the same MICRO algebra;
- bounded monotone bisection for the inner MACRO zero-depth equation;
- endpoint/no-stress checks plus bounded bisection for the outer respiration balance.

Across 72,381 physical trace rows:

| quantity | maximum absolute difference | p99 absolute difference | mean absolute difference |
| --- | ---: | ---: | ---: |
| respiration factor | 2.5651e-5 | 2.1979e-5 | 1.1875e-6 |
| final RWU factor | 1.5605e-4 | 9.1546e-6 | 2.6479e-7 |
| c_macro | 7.0431e-7 | 9.7327e-9 | 1.2116e-9 |

The respiration-factor envelope is consistent with the legacy ZBREND stopping rule: `accuracy=1e-4` produces a half-tolerance positional floor of approximately `5e-5`. The bounded candidate was solved more tightly.

The stored legacy `c_min_micro` after ZBREND is not a valid parity oracle for the returned respiration factor: ZBREND leaves the module global at its last residual evaluation, which need not equal a fresh MICRO evaluation at the returned root. C3Q will therefore not use that stale global as a formula-equivalence gate.

## Interpretation

1. The inner MACRO Newton/restart policy can be replaced by the bounded monotone solve without a material physical-response change over this large real-call sample.
2. The outer root policy can likewise be replaced by a bounded solve; observed response differences are smaller than the legacy solver's own declared positional tolerance.
3. The largest RWU-factor difference is an amplification of a small respiration-factor difference when `max_resp_factor` is close to 1, not evidence of a different oxygen balance.
4. The current result qualifies the numerical-policy replacement on the official grass response envelope. It does not yet qualify the independent water-film replacement or production wiring.

## Next gate

- compile and execute the persisted pure Fortran kernel gates;
- add fresh MICRO-at-returned-root diagnostics for exact formula parity;
- qualify the reference water-film policy;
- then create the production composition candidate.


## Post-result implementation hardening

The persisted candidate was reviewed against strict GNU warning semantics before production wiring.

Corrections made:
- the inner bounded zero-depth routine is now `pure`, matching its use from the pure MACRO evaluator;
- the outer residual callback interface is no longer incorrectly constrained to `pure`, allowing explicit fail-closed propagation of invalid physical evaluation;
- unused bisection endpoint assignments were removed;
- real equality checks in the scalar gate were removed;
- a composed-kernel smoke gate and a non-owning root-sink composition gate were added.

A separate `mod_bartholomeus_root_uptake_composition` now expresses the intended ownership boundary:
the existing root process supplies the base sink, oxygen supplies only factors in [0,1], and composition
returns one final sink vector. It performs no mass booking and owns no accepted state.

Production wiring remains disabled until the strict compiled gate and refreshed return-root diagnostics pass.


## Qualification update — current B1.11 and persisted kernel gates

Current corrected-reference authority is B1.11.

On this branch, persisted workflow `VQ reference qualification` run `36912933046` completed
successfully and re-established B1.11 as `QUALIFIED_NUMERICAL_BEHAVIOURAL`, including source
manifest SHA-256 `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

Persisted C3Q workflow run `36912932999`, kernel job `110539797272`, completed successfully with:

```text
PPA_WU05C3Q_KERNEL_SMOKE=PASS
PPA_WU05C3R_MACRO_ZERO_DEPTH_CHECKS=27
PPA_WU05C3R_MACRO_ZERO_DEPTH=PASS
PPA_WU05C3R_SCALAR_BRACKET=PASS
PPA_WU05C3Q_ROOT_COMPOSITION=PASS
```

The current B1.11 oxygenstress source retains the admitted SWAP-007 postimage
`8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87`;
later B1 corrections do not modify `oxygenstress.f90`.

Source-bound local replay of that exact corrected oxygen source on 1000 real five-year grassgrowth
evaluations, including 500 oxygen-limited rows, gave:

- MICRO max absolute difference: `4.43e-17`;
- MACRO bounded-solver max absolute difference: `5.86e-09 kg/m3`;
- respiration-factor max absolute difference: `2.48e-05`;
- RWU-factor max absolute difference: `1.22e-05`;
- all sampled respiration/RWU differences remained inside legacy `SOLVE accuracy = 1e-4`.

Qualified architecture findings:
- no Bartholomeus continuation state across accepted timesteps;
- vertical `C_top(node+1)=C_macro(node)` is ordered profile-call scratch;
- six derived arrays are immutable-after-construction and require a complete construction/share key;
- legacy c_macro/c_min_micro globals can be last-residual solver scratch and are not physical state;
- water ownership remains with the existing root sink;
- inner MACRO Newton/restart is replaceable by the proven bounded monotone solve.

### Updated decision

`C3Q = PASS / QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE`

Scope is analytical-MvG Bartholomeus `SWOXYGEN=2 / SWOXYGENTYPE=1` with bounded inner/outer
solves and ordered profile composition.

Still outside this admission result:
- SWSOPHY=1 tabular water-film path;
- WFT300/practical lookup mode;
- changed scientific parameters or formulation.

Next gate: production wiring plus non-oxygen preservation and full oxygen end-to-end regression.


## Production composition qualification update

Production composition gate `PPA WU05 C3P oxygen composition` was repaired without changing
production physics. The initial failures were qualification-harness dependency/warning-policy
issues: first the hydraulic contract module was omitted from compile order, then an existing
solver-contract unused-dummy warning was incorrectly promoted to an error by the narrow harness.

After correcting only the harness, persisted run `36918960435` completed successfully:

```text
PPA_WU05C3P_ROOT_OXYGEN_COMPOSITION=PASS
```

This qualifies the existing root-water-uptake composition boundary for applying bounded
per-rooted-node oxygen factors while preserving root-sink ownership.

C3Q/C3P now jointly establish:
- source-bound Bartholomeus response parity;
- pure bounded oxygen response kernel;
- ordered profile oxygen composition contract;
- root-water-uptake modifier composition;
- no new water-mass owner.

Remaining admission work is end-to-end production wiring/configuration and preservation regression,
not redesign of the physical kernel.


## C3P production-composition gate

The first production-composition workflow failure was diagnosed as test-harness dependency ordering,
not an oxygen/composition defect: `mod_process_hydraulic_view` was compiled before its existing
`mod_soil_water_solver_contract` dependency. The runner was repaired without changing production
physics. A pre-existing unused-dummy warning in the broad solver contract is scoped out only for
this focused composition harness; oxygen/composition sources remain under `-Wall -Wextra -Werror`.

Persisted rerun:
- workflow: `PPA WU05 C3P oxygen composition`
- run: `36919068192`
- job: `110560257874`
- result: SUCCESS
- observed gate: `PPA_WU05C3P_ROOT_OXYGEN_COMPOSITION=PASS`

This qualifies the production ownership seam tested here:
the existing drought/root-water-uptake process owns and computes the base root extraction sink;
the oxygen composition layer applies a bounded [0,1] modifier only to rooted nodes and recomputes
the resulting uptake total. Oxygen does not book water independently.

C3P focused composition status: `PASS`.
