# F-DOC08 - RB1 Temporal Acceptance T11 Equation-to-Test Traceability

## Purpose

F-DOC08 closes one bounded documentation maturity gap left explicit by F-DOC07: an explicit T11 relation-to-test graph for `RB1-TIME-REFERENCE`.

This workunit is documentation and traceability only. It does not requalify the temporal science, change production source, change reference data, introduce a tolerance, choose an application `H_budget`, or establish Status A/AA.

The machine-readable authority is `docs/scientific/registries/rb1-time-reference-t11-traceability.json`.

## Frozen upstream

F-DOC08 starts exactly from F-DOC07 `492b984bca282d6ec11dcaa727227b34c0ff3a84`, whose aggregate reconciliation covers all 15 RB1 required capabilities while retaining explicit maturity gaps.

The bounded temporal chain is already qualified upstream:

1. F-VQ34 `df9b1123ba33ece022ce6649e70dcb538e44837f` independently qualified the remediated Richards head-budget temporal certificate. Its tested head is `31e3f85ae83fe8bab9554da5467de0598446c0bd`, with workflow run `34364081068`.
2. F-CI21 `697755068253cfb5a2f838c63894e1609a85ff51` materialized the dependency-closed certificate and replayed F-VQ34 on the materialized postimage while keeping F-VQ33 failed.
3. F-RB01 `aeb74560d801c4ac7314df7b8845fcc5daf8bba6` replays frozen F-CI21 temporal science and separately checks the eight temporal dependency paths against F-CI40 `d81ef430ebaa601469a165dfc5b9866b813b71aa`.
4. F-DOC04 already reconciled this temporal authority into the RB1 capability documentation without inventing an application budget.

F-DOC08 only makes the relation-to-test links explicit and immutable.

## Bounded relations

The qualified normalization is:

`C_h = B_inf / H_budget`

Within the frozen F-VQ34 scope, `H_budget` belongs to explicit numerical configuration, must be supplied, finite and strictly positive, and has no default. Missing or invalid budget values make the certificate unavailable. Required temporal history is also necessary; there is no no-history bootstrap.

The qualified certificate path exercises the `C_h <= 1` acceptance boundary. Certificate rejection preserves committed state. Retry is bounded and rollback is exact within the frozen qualification, but no claim is made that reducing `dt` monotonically reduces `C_h`.

Hard mass rejection precedes the certificate gate. A temporal certificate can therefore never override mass failure.

## Equation-to-test graph

The registry contains eight bounded relation nodes `R01` through `R08` and eight evidence/test nodes `T01` through `T08`.

The scientific core is tied to the frozen twelve-case F-VQ34 matrix:

- cases 1, 2, 10, 11 and 12 exercise valid accept, valid reject and the exact boundary;
- cases 3, 4, 7, 8 and 9 exercise missing, zero, negative, NaN and positive-infinity budget fail-closed behavior;
- case 5 exercises no-history with an otherwise valid budget;
- case 6 exercises bounded retry and exact rollback without a shorter-step monotonicity assumption;
- F-KT09 provides the executable hard-mass-precedence oracle;
- all twelve cases are executed at O0 and O2, for 24 executions with identity required.

F-CI21 then repeats the remediated F-VQ34 policy against the materialized production postimage. Its replay records every relevant F-VQ34 gate as PASS, including direct `B_inf` equivalence, accept/reject/boundary behavior, invalid-budget fail-closed behavior, native diagnostic preservation, no-history behavior, bounded retry/rollback, hard-mass precedence, diagnostics, cost shape, O0/O2 identity and numerical-configuration ownership.

F-RB01 finally replays the frozen F-CI21 temporal authority and verifies that the temporal dependency surface is preserved against F-CI40. The release runner must emit all three temporal PASS markers recorded in the registry.

## Negative evidence remains negative

F-VQ33 remains failed. Its source contradiction concerning native invalid-budget diagnostics is retained as negative provenance and is never counted as positive T11 evidence. The remediated F-VQ34 authority and the F-CI21 postimage replay are the positive evidence.

## What T11 is closed here

F-DOC08 marks complete only the bounded T11 graph for the already-qualified restricted temporal certificate semantics of `RB1-TIME-REFERENCE`.

It does not claim a complete graph for application accuracy. In particular, no value or selection rule for `H_budget` is introduced. The application/runtime provenance that supplies an explicit finite positive `H_budget` remains external, and an application-specific temporal or groundwater-head error budget remains outside this workunit.

## Hard nonclaims

F-DOC08 does not:

- select or recommend any numeric `H_budget`;
- establish a universal temporal tolerance or groundwater-head accuracy target;
- make `B_inf` or `C_h` a general nonlinear true-error upper bound;
- assert shorter-step monotonicity;
- qualify arbitrary restart, forcing/event, topology-discontinuity or coupling-window continuation;
- modify production source, reference data, scientific tolerances, physics, solver policy or performance policy;
- establish Status A or Status AA;
- close T12 application validation;
- close the controlled WR-QA-2024 source gap;
- reopen RB1, F-VQ34, F-CI21, F-DOC04 or F-DOC07.

Surface-evaporation throughput/scaling remains a separate performance workunit and is not part of this traceability claim.

## Architecture reconciliation

The workunit is intended to be architecture-neutral: no runtime behavior changes. The accompanying invariant audit therefore requires all 30 SWAP core architecture invariants to remain PASS with no adverse delta. Mass conservation remains hard and unchanged.

## Qualification rule

F-DOC08 is qualified only if its workflow succeeds on the exact branch head containing final status and closeout. The workflow must mechanically verify the exact upstream blobs and commits, graph completeness, hard nonclaims, bounded changed paths, zero `src` delta, zero `reference` delta, and the 30-invariant no-adverse-delta audit.
