# F-GC37 — Live MODFLOW6 outer-iteration host

## Status

**OWNER-QUALIFIED LIVE MODFLOW6 OUTER-ITERATION HOST**

F-GC37 adds the smallest live host layer needed after F-GC36. It does not yet claim a complete coupled SWAP5-MODFLOW6 transaction.

The bounded target is:

- one initialized MODFLOW6 6.8.0 kernel;
- one already-qualified F-GC35 API-package view;
- F-GC34 publication before the first solve;
- repeated F-GC34 republication between MODFLOW outer iterations;
- one externally supplied response provider;
- convergence on both MODFLOW's solve result and a coupling-head criterion;
- explicit separation between a converged MODFLOW candidate and irreversible timestep finalization.

## 1. Why this host is separate from the older groundwater exchange-service abstraction

The admitted SWAP groundwater exchange-service contract assumes a participant that can:

- capture a checkpoint;
- create candidates from that checkpoint;
- discard candidates;
- prepare one candidate;
- commit or abort the prepared candidate.

MODFLOW6 6.8.0 XMI exposes a different lifecycle:

```text
prepare_time_step
prepare_solve
solve
solve
...
finalize_solve
finalize_time_step
```

The XMI source exposes no timestep checkpoint, rollback or restore operation.

Therefore F-GC37 must not pretend that live MODFLOW6 implements
`groundwater_preparable_exchange_service_t`.

Instead, the MODFLOW kernel remains live in one prepared nonlinear solve while
external response terms are updated between calls to `solve`.

## 2. Scientific ownership

F-GC37 owns no SWAP coupling science.

The response provider supplied to the host owns generation of the next
MODFLOW-facing terms. Future SWAP binding must reuse:

```text
F-GC30 predictor/corrector response
 -> F-GC31 N:1 cell response
 -> F-GC33 HCOF/RHS
 -> F-GC34 package publication
```

F-GC37 only controls when those already-defined terms are published relative to
the MODFLOW solve lifecycle.

The F-GC37 smoke provider is deliberately synthetic. It exists only to prove
that changing terms between live MODFLOW outer iterations are consumed.

## 3. Host lifecycle

```text
MODFLOW already initialized
F-GC35 addresses already acquired

solve_candidate:
    prepare_time_step(0)
    F-GC35 refresh_after_prepare_time_step

    acquire live model head view

    response_provider(H0)
    F-GC34 publish initial terms through F-GC35
    F-GC35 close_before_prepare_solve

    prepare_solve(solution_id)

    repeat:
        solve(solution_id)
        read new live head

        if MODFLOW converged AND coupling head delta <= tolerance:
            finalize_solve(solution_id)
            return PREPARED_CANDIDATE

        response_provider(Hnew)
        republish F-GC34 terms into the same current-generation XMI views

    bounded failure:
        DO NOT finalize_time_step
        mark kernel as requiring reinitialization

commit_candidate:
    only from PREPARED_CANDIDATE
    finalize_time_step()
```

## 4. Repeated publication contract

F-GC35 itself remains unchanged.

A new F-GC37 outer-iteration publisher may reuse the live F-GC35 package view
after `close_before_prepare_solve`, but only when all of these remain true:

- adapter generation is unchanged;
- package view generation equals the generation captured at solve start;
- F-GC35 recorded a successful initial F-GC34 publication for that generation;
- the same F-GC34 publisher is used;
- no XMI address or pointer reacquisition is invented inside the solve loop.

The new publisher may write only:

- NODELIST
- HCOF
- RHS
- NBOUND

through the existing F-GC34 call.

## 5. Coupling convergence in F-GC37

The generic host uses a narrow numerical criterion:

```text
MODFLOW solve reports converged
AND
max(abs(H_k - H_(k-1))) over configured monitored nodes <= tolerance
```

This is not yet the final SWAP5-MODFLOW scientific convergence contract.
A later SWAP binding may add interface-residual criteria while retaining this
host lifecycle.

## 6. Live qualification case

Use the same 1 x 3 MODFLOW model as F-GC36:

```text
CHD(1) = 1.0 m
API_SWAP at cell 2
CHD(3) = 0.0 m
K = 1 m/day
```

The smoke provider represents a nonlinear target flux

```text
Q*(H) = 0.06 - 0.1 H + 0.5 (H - 0.5)^2
```

but deliberately keeps the coupling slope fixed:

```text
dQ/dH used by the published linear term = -0.1
```

At every host iteration it updates only the reference source so that the
published line passes through `(H_ref, Q*(H_ref))`.

This mimics the F-GC30 quasi-Newton design principle that a response coefficient
may remain fixed within the coupling window while the flux/source is corrected.

For the three-cell system the nonlinear coupled root satisfies:

```text
2 H = 1 + Q*(H)

0.5 H^2 - 2.6 H + 1.185 = 0
```

The physically relevant root near the initial state is approximately 0.50477 m.

Qualification requires more than one F-GC34 publication and equality of the
final MODFLOW head to the analytic root within tolerance.

## 7. Candidate versus commit

A successful `solve_candidate` is not a coupled scientific commit.

It proves only that MODFLOW has a converged, finalized-solve candidate.

`commit_candidate` then calls `finalize_time_step` for the smoke case.

F-GC37 does not claim atomicity with a SWAP commit because MODFLOW XMI exposes
no qualified rollback if a second kernel fails after MODFLOW publication.

That decision surface remains explicitly open.

## 8. Qualification gates

### Q1
Official MODFLOW6 6.8.0 shared library and F-GC34 bridge remain pinned exactly as
in F-GC36.

### Q2
Initial package publication uses F-GC35 + the real F-GC34 bridge.

### Q3
Repeated outer-iteration publications use the same F-GC34 bridge and the same
qualified F-GC35 generation.

### Q4
At least two successful publications occur and the published RHS changes.

### Q5
MODFLOW solve calls occur under exactly one `prepare_solve` /
`finalize_solve` pair.

### Q6
The nonlinear coupled head closes to the analytic root.

### Q7
`finalize_time_step` is not called by `solve_candidate`; it is called only by
explicit `commit_candidate`.

### Q8
Nonconvergence or publication failure cannot call `finalize_time_step` and
marks the host unusable without kernel reinitialization.

## 9. Explicit exclusions

F-GC37 does not:

- bind a real SWAP trial provider;
- commit SWAP state;
- claim atomic SWAP-MODFLOW publication;
- implement MODFLOW rollback;
- alter F-GC30 through F-GC36 science;
- couple Ribasim;
- add irrigation;
- expand active-drainage tangent coverage;
- admit anything to canonical.

## 10. Next bounded step

If F-GC37 qualifies, the next workunit may bind a real non-committing SWAP
candidate/response provider to this host. That workunit must preserve one
accepted SWAP origin across all MODFLOW outer iterations and must address the
remaining cross-kernel publication/abort boundary explicitly.


## 11. Qualification result

Qualified branch head before checkpoint metadata:

```text
0c0aa3cebebe387b36853f32beb990000f3a48bc
```

Owner qualification workflow:

```text
run 35289635676
job 105429464324
conclusion success
```

The successful live nonlinear case executed:

```text
F-GC34 publication count = 5
MODFLOW solve count       = 5
final head                = 0.5047673159062819 m
analytic head             = 0.5047673160243038 m
```

All five publications occurred within one prepared MODFLOW solve and one
unchanged F-GC35 XMI generation.

The explicit candidate/commit boundary also passed: `solve_candidate`
performed `finalize_solve` but did not call `finalize_time_step`;
`commit_candidate` then finalized exactly one timestep.

A second live case deliberately bounded the host to one solve iteration. That
case returned nonconvergence, performed neither `finalize_solve` nor
`finalize_time_step`, rejected a subsequent commit request and marked the
host as requiring full kernel reinitialization.

Canonical reconciliation at qualification:

```text
integration/f-ci-canonical
d517088cdc1cd82904b37648d6556dc79d57a641
```

The canonical movement after the initial F-GC37 reconcile contained only
PUB-ME D6 workflow, publication documentation and publication tests. No
F-GC30 through F-GC37 production dependency source changed.

### Qualification boundary

F-GC37 proves the live MODFLOW host lifecycle and iterative package
republication. It still does not prove that a real SWAP5 candidate provider can
be invoked from the same accepted SWAP origin for every MODFLOW outer
iteration. That remains the next bounded workunit.
