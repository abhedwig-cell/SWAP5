> Current-canonical reconciliation: this F-GC39 contract is rematerialized with zero production-code delta after F-GC34, F-GC35, F-GC36 and F-GC38 were canonically closed. Predictor/corrector ownership remains below iMOD Coupler; only contract/evidence authority is being refreshed.

# F-GC39 — Prepared-solve internal SWAP5–MODFLOW coupling service contract

## Status

**CURRENT-CANONICAL REQUALIFICATION — prepared-solve internal coupling-service contract**

F-GC39 reconciles the F-GC37 internal coupling-service contract with the live MODFLOW6 lifecycle qualified by F-GC38.

The ownership boundary remains unchanged:

```text
iMOD Coupler
    |
    | coarse model orchestration only
    v
internal SWAP5-MODFLOW coupling service
    |
    +--> SWAP5 transactional participant
    |
    +--> MODFLOW6 prepared-solve backend (F-GC38)
```

Predictor/corrector strategy remains below iMOD Coupler.

## 1. Why F-GC37 needs semantic reconciliation

F-GC37 correctly established:

- one immutable accepted SWAP origin;
- predictor/tangent construction once per coupling window;
- SWAP corrector trials from that same origin;
- flux-residual coupling convergence;
- bounded fail-closed iteration;
- predictor/corrector ownership below iMOD Coupler.

Its groundwater test double, however, modeled every outer iteration as a separately rollback-able groundwater candidate from one accepted groundwater origin.

F-GC38 proved that this is not the native MODFLOW6 XMI model.

The qualified MODFLOW6 model is:

```text
prepare_time_step
prepare_solve        # once
  XOLD <- accepted previous-time head
  |
  +-- solve iteration 1 -> X(1)
  +-- update API terms
  +-- solve iteration 2 -> X(2)
  +-- update API terms
  +-- ...
finalize_solve       # once after coupled convergence
```

`XOLD` remains fixed; `X` is the evolving nonlinear iterate.

Therefore F-GC39 supersedes only F-GC37's *groundwater per-iteration candidate/discard abstraction*. It preserves the SWAP-side transaction semantics and ownership boundary.

## 2. Tangent authority

F-GC39 does not implement derivative coverage rules.

It consumes an already-authoritative affine SWAP response from the admitted tangent/cell-response authority.

Current canonical at reconciliation:

```text
integration/f-ci-canonical
15883938da5777f90f097c8f6938458840ccb75a
```

The complete lower MODFLOW integration stack is now closed canonical:

- F-GC40 — MultiSWAP MODFLOW6 cell response;
- F-GC33 — linear HCOF/RHS response backend;
- F-GC34 — typed API binding;
- F-GC35 — XMI package adapter;
- F-GC36 — live MODFLOW6 bridge;
- F-GC38 — prepared-solve iterative backend.

Canonical also includes active-drainage directional coverage in the predictor tangent adapter when the accepted trajectory reports complete source/sink directional coverage.

The internal coupling service must consume that authority; it may not recreate or weaken it.

## 3. SWAP participant

The service requires:

```text
capture_origin() -> swap_origin

build_predictor_response(swap_origin)
    -> authoritative affine response

corrector_trial_from_origin(swap_origin, groundwater_head)
    -> swap_candidate
       q_swap

discard_candidate(swap_candidate)
```

Every corrector trial is computed from the exact same immutable `swap_origin`.

The initial affine slope is fixed for the first F-GC39 contract.

## 4. MODFLOW prepared-solve participant

The service requires:

```text
open_window() -> prepared-solve session

solve_iteration(affine_response)
    -> current groundwater head X
       realized affine boundary q_gw
       modflow_converged

finalize_converged_solve()
invalidate_abandoned_solve()
```

The backend contract is the F-GC38 lifecycle:

- one `prepare_solve`;
- fixed `XOLD`;
- repeated F-GC34 publication and `solve`;
- explicit `MXITER` guard;
- one `finalize_solve`;
- no `finalize_time_step`.

There is **no groundwater discard between coupling iterations**.

## 5. Coupling iteration

Let the predictor response be:

```text
q(H) = q_ref + s * (H - H_ref)
```

where `s` is frozen for the coupling window.

For coupling iteration `k`:

1. publish the current affine response to MODFLOW;
2. execute exactly one MODFLOW nonlinear solve iteration;
3. obtain current groundwater head `H_k` and realized affine boundary flux `q_gw,k`;
4. run one SWAP corrector from the immutable SWAP origin under `H_k`;
5. obtain `q_swap,k`;
6. compute:

```text
r_q,k = q_swap,k - q_gw,k
```

Coupled convergence requires **both**:

```text
abs(r_q,k) <= q_tolerance
AND
modflow_converged == true
```

A MODFLOW convergence flag alone is insufficient if SWAP changes the boundary response.

A small coupling residual alone is insufficient if the groundwater nonlinear system has not converged.

## 6. Non-converged iteration

If the coupled convergence condition is false:

- discard the current SWAP corrector candidate;
- do **not** rollback or discard MODFLOW `X`;
- update only the affine reference:

```text
H_ref <- H_k
q_ref <- q_swap,k
s     <- unchanged
```

and execute the next external nonlinear iteration in the same MODFLOW prepared solve.

## 7. Converged iteration

When both conditions are true:

- retain the final SWAP candidate;
- call `finalize_solve` exactly once;
- return a **converged coupled-window candidate** to the later publication layer.

F-GC39 deliberately stops before `finalize_time_step` and before irreversible SWAP publication.

This keeps solver convergence separate from accepted timestep publication.

## 8. Failure

Failure before coupled convergence includes:

- backend solve failure;
- MODFLOW `MXITER` exhaustion;
- invalid/non-finite groundwater iterate;
- invalid SWAP corrector;
- coupling outer-iteration budget exhaustion.

On failure:

- discard any live SWAP corrector candidate;
- invalidate the MODFLOW prepared-solve session;
- do not call `finalize_solve` as if the window were accepted;
- do not commit SWAP;
- do not finalize the MODFLOW timestep;
- return `RETRY_SMALLER_WINDOW` where policy permits.

A concrete smaller-window reconstruction route remains outside F-GC39.

## 9. Qualification envelope

The owner qualification uses deterministic doubles and proves:

### Q1 — service ownership

No iMOD Coupler, XMI pointer, MODFLOW package, or timestep-finalization logic exists in the coupling-service harness.

### Q2 — same SWAP origin

All predictor/corrector calls use one immutable SWAP origin.

### Q3 — one groundwater session

The groundwater prepared solve is opened exactly once.

No per-iteration groundwater capture/discard/rollback exists.

### Q4 — conjunctive convergence

A fixture where flux residual is acceptable before MODFLOW convergence must continue.

A fixture where MODFLOW is converged before flux residual is acceptable must also continue.

Only the iteration satisfying both may close the solve.

### Q5 — SWAP-only rejection

Every non-converged SWAP candidate is discarded before the next iteration.

The groundwater nonlinear iterate remains continuous.

### Q6 — fixed tangent

The predictor slope is built once and remains unchanged.

### Q7 — finalization

Successful convergence retains exactly one final SWAP candidate and finalizes the prepared MODFLOW solve exactly once.

No timestep finalization occurs.

### Q8 — bounded fail-closed

Coupling iteration exhaustion or backend iteration-limit failure invalidates the prepared solve, discards the live SWAP candidate and returns retry without publication.

## 10. Evidence boundary

F-GC39 qualifies the **coupled nonlinear iteration contract**.

It does not qualify:

- whole-window restart after an abandoned MODFLOW prepared solve;
- final multi-participant timestep publication;
- live real-SWAP plus MODFLOW end-to-end execution;
- N:1 multi-cell production scaling;
- Ribasim or irrigation.

Those remain later bounded capabilities.


## 11. Qualified evidence

Green owner qualification:

```text
run 35291803801
job 105436039695
head 26e145dddcae78931124b2d6c9b72b41e28da253
conclusion success
```

The executable contract evidence demonstrates:

- one prepared groundwater session per coupling window;
- one immutable SWAP origin for predictor and all correctors;
- one fixed affine tangent slope for the first contract;
- conjunctive convergence: MODFLOW convergence **and** interface-flux convergence;
- a flux-converged but MODFLOW-unconverged iterate is rejected;
- a MODFLOW-converged but flux-unconverged iterate is rejected;
- only non-final SWAP candidates are discarded;
- no groundwater capture/discard/rollback exists per outer iteration;
- successful convergence finalizes the groundwater solve exactly once and retains the final SWAP candidate;
- coupling-budget exhaustion invalidates the prepared solve and requests retry;
- a groundwater backend iteration-limit failure invalidates the prepared solve before a SWAP corrector is attempted;
- no iMOD Coupler, direct XMI pointer, MODFLOW solve, or timestep-finalization operation exists in the service harness.

The initial qualification attempt failed only because a raw text check for `solve(` also matched the legitimate service method name `finalize_converged_solve()`. The static ownership gate was changed to syntax-aware call inspection; service semantics were unchanged.

## 12. Supersession statement

For future composition, F-GC39 is authoritative over F-GC37 specifically for groundwater outer-iteration semantics.

F-GC37 remains valid evidence for:

- internal-service ownership below iMOD Coupler;
- immutable SWAP-origin semantics;
- transactional SWAP correctors;
- bounded coupling iteration.

The following F-GC37 concept is superseded:

```text
groundwater candidate from accepted origin
discard groundwater candidate
repeat
```

The qualified replacement is:

```text
one prepared MODFLOW solve
fixed accepted XOLD
evolving X
republish response + solve
republish response + solve
...
```

Whole-window abandonment/retry and final timestep publication remain separate capabilities.

## 13. Next bounded step

The next scientific/software boundary is no longer predictor/corrector placement or MODFLOW nonlinear iteration.

It is the **whole-window acceptance and retry boundary**:

- how a converged F-GC39 window is atomically published across SWAP, MODFLOW timestep state and exchange ledger;
- what exact reconstruction path is used if the whole coupled window must be retried at a smaller timestep after an abandoned prepared solve.

Those concerns should be qualified separately without moving any predictor/corrector logic into iMOD Coupler.
