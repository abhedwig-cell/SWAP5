# F-MQ18 — F-SI04 real HeadCalc focused admission

F-MQ18 is qualification-only and changes no production source.

## Exact basis

- F-MQ17 parent: `cd63058f19623b71c6a904ad85b9b14ebe1a990c`
- F-SI04 qualification head: `c76f794b93522bea3a80a6880bc95ef5671cb914`
- F-SI04 tested postimage: `0cfbefc271447b4b53eeee50c1dfbb2acaf020df`
- F-SI04 qualification blob: `fdfc028191a347fc2bdcec2d136788c4f9a84177`
- F-SI04 gate blob: `b8bbe5d6c2eb86bda995d77ec44e813ffbe84d85`
- canonical B1.10 HeadCalc blob: `225b9f2cc1ecff01414b5691799103b92bc068c5`
- F-SI04 workflow run: `34122972659` (`success`)

## Admitted evidence

F-SI04 executed the exact canonical B1.10 HeadCalc on a focused 4-node matrix-flow/free-drainage fixture. Both the original path and a generated workspace-redirected path execute at O0 and O2. Their outputs are byte-identical, O0/O2 outputs are identical, workspace scratch poison/reset is exercised, ABA repeat replay is identical, solver route/iteration counts match, and the focused unrounded HeadCalc equation residual is zero within machine precision.

This is the first F-MQ dependency that executes real canonical HeadCalc equations rather than only a testdouble/common-interface layer.

## Why the 35-row real coverage remains zero

The F-MQ01 matrix defines stricter row-level minimums. F-SI04 does not yet satisfy them:

- P06 needs 8 columns / 8 workers and cross-column committed-state isolation.
- P11 is a real-SWAP interval replay from committed state with a hard mass gate; F-SI04 is a focused HeadCalc fixture, not a complete SWAP interval.
- P16 requires full committed SWAP water accounting; F-SI04 qualifies only the focused HeadCalc equation residual.
- P19 needs at least 2 logical columns / 2 workers and identical committed physical state/diagnostics across poison patterns.
- P03/P18 require real multi-worker/multi-column execution; F-SI04 explicitly leaves parallel real HeadCalc unqualified.

Therefore F-MQ18 records stronger focused real-solver prerequisites for P06, P11, P16 and P19 without promoting any complete matrix row.

## Hard holds

Production workspace-aware HeadCalc is not yet committed; full reference Richards reentrancy, parallel real HeadCalc, full unrounded SWAP mass balance, production reference admission and production MultiSWAP admission remain open. F-SI05 and later F-MR/F-VQ evidence are required before those claims can change.
