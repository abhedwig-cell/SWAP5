# F-GC37 — Coupled predictor-corrector host contract

## Status

**DESIGN / IMPLEMENTATION AUTHORITY NOT YET QUALIFIED**

F-GC37 defines the smallest host-side orchestration that composes the already-qualified SWAP5 tangent path with a transaction-capable groundwater backend.

The purpose is not to build a new application runtime. It is to encode one coupling-window algorithm with explicit accepted-origin semantics, bounded outer iteration, fail-closed candidate handling and atomic final publication.

F-GC37 deliberately does not assume that a live MODFLOW6/xmipy kernel can rollback in place. A concrete groundwater backend must prove that every trial is generated from the same accepted groundwater origin.

## 1. Reused authority

F-GC37 reuses, without changing:

- F-GC30 per-tile predictor/tangent semantics;
- F-GC31 N:1 affine cell response;
- F-GC33 MODFLOW6 HCOF/RHS transform;
- F-GC34 typed package publication;
- F-GC35 XMI package lifecycle guard;
- F-GC36 live MODFLOW6 package consumption;
- existing SWAP5 transaction principle that predictor and corrector trials originate from one immutable accepted SWAP checkpoint;
- existing prepare/commit/abort publication pattern from Groundwater Coupling v1.

The existing `mod_groundwater_predictor_corrector_window` and MultiSWAP transaction modules remain authority for transaction meaning. F-GC37 does not replace them with a second commit model.

## 2. Missing backend capability discovered

The live MODFLOW6 XMI surface exposes forward lifecycle calls:

```text
prepare_time_step
prepare_solve
solve
finalize_solve
finalize_time_step
```

but no native checkpoint/rollback/restore operation equivalent to the SWAP5 transaction contract.

Therefore F-GC37 MUST NOT implement:

```text
solve candidate A
mutate same live kernel
solve candidate B
pretend B started from the accepted origin
```

unless the concrete groundwater backend separately proves origin restoration.

## 3. Required participant contracts

### 3.1 SWAP participant

The host sees a transaction-capable SWAP participant with these semantics:

```text
capture_origin() -> swap_origin

build_predictor_response(swap_origin)
    -> immutable predictor response / fixed slope u

corrector_trial_from_origin(swap_origin, prescribed_head)
    -> swap_candidate
       q_u_at_prescribed_head
       accepted-window exchange candidate

discard_swap_candidate(candidate)

prepare_swap_candidate(candidate) -> prepared_swap
commit_prepared_swap(prepared_swap)
abort_prepared_swap(prepared_swap)
```

Every corrector trial MUST start from `swap_origin`.

### 3.2 Groundwater participant

The host sees a transaction-capable groundwater participant:

```text
capture_origin() -> groundwater_origin

trial_from_origin(groundwater_origin, affine_cell_response)
    -> groundwater_candidate
       solved_head
       realized_boundary_flux

discard_groundwater_candidate(candidate)

prepare_groundwater_candidate(candidate) -> prepared_groundwater
commit_prepared_groundwater(prepared_groundwater)
abort_prepared_groundwater(prepared_groundwater)
```

Every groundwater trial MUST start from `groundwater_origin`.

A live MODFLOW6 implementation may realize this through process/kernel reconstruction, explicit state restoration, restart materialization or another qualified method. F-GC37 does not choose one.

## 4. Coupling-window algorithm

At accepted time `T_n`:

1. capture one immutable SWAP origin;
2. capture one immutable groundwater origin;
3. build the F-GC30/F-GC31 predictor response once;
4. freeze the qualified tangent slope `s = dq_u/dH` for this coupling window;
5. initialize the affine reference with predictor `H_ref, q_ref`.

Then iterate for `k = 1..max_outer_iterations`:

### Groundwater trial

From the same accepted groundwater origin:

```text
q_lin,k(H) = q_ref,k + s * (H - H_ref,k)
```

Run a groundwater candidate and obtain:

```text
H_gw,k
q_gw,k = q_lin,k(H_gw,k)
```

### SWAP corrector

From the same accepted SWAP origin, prescribe `H_gw,k` and obtain:

```text
q_swap,k
candidate whole-window exchange
```

### Coupling residual

Define:

```text
r_q,k = q_swap,k - q_gw,k
```

Convergence is based on a governed absolute flux tolerance:

```text
abs(r_q,k) <= q_tolerance
```

The first F-GC37 contract does not add relaxation, secant slope updates or adaptive `u).

### If not converged

Discard both candidates and update only the affine reference:

```text
H_ref,k+1 = H_gw,k
q_ref,k+1 = q_swap,k
s_k+1     = s
```

Then retry from the same two accepted origins.

### If converged

Do not run another scientific trial.

Prepare:

1. the converged SWAP candidate;
2. the converged groundwater candidate;
3. the accepted exchange publication/ledger participant if present.

Only after all preparation succeeds may irreversible commits occur.

## 5. Candidate ownership rules

At most one SWAP candidate and one groundwater candidate may be live at a time.

For every non-converged iteration:

```text
groundwater candidate -> discard
SWAP candidate        -> discard
```

before the next iteration begins.

On any failure before prepare:

```text
discard all live candidates
no accepted origin advances
no mass publication occurs
```

On prepare failure:

```text
abort any already-prepared participant
no participant may be committed
```

The host must record the exact failure stage.

## 6. Commit-order boundary

Existing SWAP5 governance already treats final coupled publication as a prepared multi-participant transaction.

F-GC37 therefore does not invent a recoverable rollback after the first irreversible commit.

Its contract is:

1. all reversible validation and preparation first;
2. explicit publication preflight;
3. irreversible commit sequence only after preflight;
4. exactly one accepted exchange publication.

The concrete final commit ordering remains governed by the existing transaction/publication authority and must not be silently changed in this host.

## 7. Qualification envelope

The first F-GC37 owner qualification uses deterministic participant doubles, not live MODFLOW rollback.

It must prove:

### Q1 — same accepted origins

Every groundwater trial receives exactly the same groundwater-origin identity.

Every SWAP corrector trial receives exactly the same SWAP-origin identity.

### Q2 — fixed tangent

The predictor slope is constructed once and is byte/logically unchanged through all outer iterations.

Only `H_ref` and `q_ref` may change.

### Q3 — residual iteration

A deterministic nonlinear SWAP corrector fixture requires more than one outer iteration and converges to a known fixed point.

### Q4 — non-converged candidate disposal

Each rejected iteration discards both candidates before the next trial.

### Q5 — bounded failure

If the residual remains outside tolerance at `max_outer_iterations`, the host returns NOT_CONVERGED, requests a smaller coupling window and commits nothing.

### Q6 — prepare fail-closed

Failure of the second participant's prepare aborts the first prepared participant and commits nothing.

### Q7 — exactly-once final commit intent

On success, exactly one SWAP candidate and one groundwater candidate reach prepare/commit. Earlier candidates are discarded and never committed.

### Q8 — no live-MODFLOW rollback claim

Static qualification must show the F-GC37 production host has no direct `xmipy`, XMI pointer or MODFLOW execution calls. A live transaction backend is a separate dependency.

## 8. Explicit exclusions

F-GC37 does not:

- implement a live MODFLOW accepted-origin restoration mechanism;
- alter F-GC30/F-GC31/F-GC33 science;
- alter F-GC34/F-GC35/F-GC36 package semantics;
- introduce slope relaxation or dynamic tangent updates;
- change SWAP transaction ownership;
- couple Ribasim;
- implement irrigation;
- expand active-drainage derivative coverage;
- admit itself to canonical.

## 9. Next bounded step

After this orchestration contract is qualified, the next workunit must qualify one concrete live MODFLOW6 transactional-origin backend against this interface.

Only after that backend proves same-origin candidate generation may F-GC37 be exercised end-to-end with live MODFLOW6 and real SWAP5 trials.
