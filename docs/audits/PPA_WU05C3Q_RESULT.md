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
