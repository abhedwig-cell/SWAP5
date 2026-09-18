# F-GC37 - Coupled predictor-corrector host contract

## Status

**OWNER-QUALIFIED CONTRACT, NOT CANONICALLY ADMITTED**

F-GC37 defines the smallest host-side orchestration that composes the qualified SWAP5 tangent path with a transaction-capable groundwater backend.

It does not create a second application runtime. It encodes one coupling-window algorithm with explicit accepted-origin semantics, bounded outer iteration, fail-closed candidate handling and the existing SWAP5 publication order.

F-GC37 deliberately does not assume that a live MODFLOW6/xmipy kernel can rollback in place. A concrete groundwater backend must separately prove that every trial is generated from the same accepted groundwater origin.

## 1. Reused authority

F-GC37 reuses, without changing:

- F-GC30 per-tile predictor/tangent semantics;
- F-GC31 N:1 affine cell response;
- F-GC33 MODFLOW6 HCOF/RHS transform;
- F-GC34 typed package publication;
- F-GC35 XMI package lifecycle guard;
- F-GC36 live MODFLOW6 package consumption;
- the existing SWAP immutable accepted-origin trial semantics;
- the existing Groundwater Coupling v1 prepare/preflight/commit publication pattern.

The existing `mod_groundwater_predictor_corrector_window` and MultiSWAP transaction/publication modules remain authority for transaction meaning.

## 2. Missing backend capability

The live MODFLOW6 XMI surface exposes forward lifecycle calls:

```text
prepare_time_step
prepare_solve
solve
finalize_solve
finalize_time_step
```

but no native checkpoint/rollback/restore operation equivalent to the SWAP5 transaction contract.

Therefore F-GC37 must not implement:

```text
solve candidate A
mutate the same live kernel
solve candidate B
pretend candidate B started from the accepted origin
```

unless a concrete groundwater backend separately proves accepted-origin restoration.

## 3. Participant contracts

### 3.1 SWAP participant

The host requires:

```text
capture_origin() -> swap_origin

build_predictor_response(swap_origin)
    -> affine predictor response with fixed dq_u/dH

corrector_trial_from_origin(swap_origin, prescribed_head)
    -> swap_candidate
       q_u_at_prescribed_head
       accepted-window exchange candidate

discard_candidate(candidate)
publication_preflight(candidate)
commit_candidate(candidate)
```

Every corrector trial must receive the same `swap_origin`.

There is no separate SWAP prepare step. The SWAP candidate remains reversible through publication preflight and is the first irreversible commit, matching existing SWAP5 governance.

### 3.2 Groundwater participant

The host requires:

```text
capture_origin() -> groundwater_origin

trial_from_origin(groundwater_origin, affine_cell_response)
    -> groundwater_candidate
       solved_head
       realized_boundary_flux

discard_candidate(candidate)
prepare_candidate(candidate) -> prepared_groundwater
publication_preflight(prepared_groundwater)
abort_prepared(prepared_groundwater)
commit_prepared(prepared_groundwater)
```

Every groundwater trial must receive the same `groundwater_origin`.

A live MODFLOW6 implementation may realize this through kernel reconstruction, explicit state restoration, restart materialization or another qualified method. F-GC37 does not choose that mechanism.

### 3.3 Accepted-exchange ledger participant

The host preserves the existing staged ledger pattern:

```text
stage(converged_swap_trial)
prepare(staged) -> prepared_ledger
publication_preflight(prepared_ledger)
abort_prepared(prepared_ledger)
commit_prepared(prepared_ledger)
```

## 4. Coupling-window algorithm

At accepted time `T_n`:

1. capture one immutable SWAP origin;
2. capture one immutable groundwater origin;
3. build the predictor response once;
4. freeze `s = dq_u/dH` for the whole coupling window;
5. initialize `H_ref` and `q_ref` from the predictor response.

For outer iterations `k = 1..max_outer_iterations`:

### Groundwater trial

From the same accepted groundwater origin:

```text
q_lin,k(H) = q_ref,k + s * (H - H_ref,k)
```

The groundwater candidate returns:

```text
H_gw,k
q_gw,k
```

### SWAP corrector

From the same accepted SWAP origin, prescribe `H_gw,k` and obtain:

```text
q_swap,k
candidate whole-window exchange
```

### Coupling residual

```text
r_q,k = q_swap,k - q_gw,k
```

Convergence is:

```text
abs(r_q,k) <= q_tolerance
```

F-GC37 does not add relaxation, secant updates or dynamic tangent updates.

### If not converged

Both candidates are discarded before the next iteration.

Only the affine reference changes:

```text
H_ref,k+1 = H_gw,k
q_ref,k+1 = q_swap,k
s_k+1     = s
```

Then the next iteration starts again from the same two accepted origins.

### If converged

No extra scientific trial is performed.

The accepted exchange is staged in the ledger, the groundwater candidate is prepared, the ledger is prepared, and then a complete publication preflight is required.

## 5. Publication order

F-GC37 preserves the existing SWAP5 order:

```text
stage ledger
prepare groundwater
prepare ledger
publication preflight for SWAP + groundwater + ledger
commit SWAP candidate
commit prepared groundwater
commit prepared ledger
```

Failures before the SWAP commit remain recoverable and must clean up all live/prepared participants.

After the first irreversible SWAP commit, a groundwater or ledger commit failure is an ownership/programming invariant violation, not a recoverable coupling path.

## 6. Qualified owner envelope

The deterministic qualification proves:

- all SWAP correctors use exactly one accepted SWAP-origin identity;
- all groundwater trials use exactly one accepted groundwater-origin identity;
- the predictor/tangent is constructed once;
- `dq_u/dH` stays fixed through all outer iterations;
- only `H_ref` and `q_ref` update;
- a nonlinear fixture requires nine outer iterations and converges on flux residual;
- every rejected iteration discards both candidates before the next trial;
- max-iteration exhaustion fails closed and requests a smaller coupling window;
- prepare failure aborts already-prepared state and commits nothing;
- final publication preserves the existing SWAP -> groundwater -> ledger commit sequence;
- exactly one final SWAP, groundwater and ledger state is committed;
- the host has no direct XMI pointer access or MODFLOW execution ownership.

## 7. Evidence boundary

F-GC37 qualifies the orchestration contract only.

It does **not** qualify a live MODFLOW accepted-origin restoration mechanism.

That gap is now explicit: F-GC36 proves a live MODFLOW package can consume SWAP5 tangent terms; F-GC37 proves how multiple candidate solves must be orchestrated; a separate backend must still prove that each live MODFLOW candidate can be regenerated from exactly the same accepted groundwater origin.

## 8. Explicit exclusions

F-GC37 does not:

- implement live MODFLOW origin restoration;
- alter F-GC30/F-GC31/F-GC33 science;
- alter F-GC34/F-GC35/F-GC36 package semantics;
- add slope relaxation or dynamic tangent updates;
- change SWAP transaction ownership;
- couple Ribasim;
- implement irrigation;
- expand active-drainage derivative coverage;
- admit itself to canonical.

## 9. Next bounded step

The next workunit must qualify one concrete MODFLOW6 transactional-origin backend.

Only after that backend proves same-origin candidate generation may this F-GC37 host be exercised end-to-end with live MODFLOW6 and real SWAP5 trials.
