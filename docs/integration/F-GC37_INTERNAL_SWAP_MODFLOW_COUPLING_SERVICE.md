# F-GC37 — Internal SWAP5–MODFLOW coupling service contract

## Status

**OWNER-QUALIFIED SERVICE CONTRACT, NOT CANONICALLY ADMITTED**

F-GC37 defines the predictor/corrector and transaction semantics of the **internal SWAP5–MODFLOW coupling service**.

This service sits **below iMOD Coupler**.

iMOD Coupler is not the owner of:

- SWAP predictor construction;
- tangent construction or reuse;
- corrector iterations;
- coupling residuals;
- retry/smaller-window decisions;
- candidate discard;
- accepted-origin semantics;
- coupled publication ordering.

Those are scientific coupling semantics and remain behind the SWAP5–MODFLOW service boundary.

## 1. Architectural ownership

The required layering is:

```text
iMOD Coupler
    |
    | coarse model orchestration only
    | run one coupled window / receive outcome
    v
internal SWAP5-MODFLOW coupling service
    |
    | owns predictor/corrector, tangent, convergence,
    | accepted origins, candidates, retry and publication
    |
    +--------------------+
    |                    |
    v                    v
SWAP5 transaction     MODFLOW6 transactional
runtime               groundwater backend
```

The service may later be exposed through a narrow API, but its internal algorithm must not leak upward into iMOD Coupler.

A suitable coarse external contract is conceptually:

```text
run_coupled_window(...)
    -> ACCEPTED
    -> RETRY_SMALLER_WINDOW
    -> FAILED
```

iMOD Coupler should not invoke `predictor()`, `corrector()`, `discard_candidate()` or individual outer iterations.

## 2. Qualification-harness correction

The original F-GC37 qualification logic was temporarily placed under:

```text
src/adapter/coupled_predictor_corrector_host.py
```

That placement incorrectly suggested that the Python host/adapter layer was the intended production owner.

The logic itself remains useful as executable contract evidence, but it is now reclassified and moved to:

```text
tests/fgc/support/fgc37_internal_coupling_service_harness.py
```

This Python module is **qualification support only**.

It does not prescribe:

- production language;
- production module location;
- iMOD Coupler ownership;
- a new application runtime.

The eventual production service should be materialized next to the existing SWAP5 transaction/runtime authority, not in the iMOD Coupler.

## 3. Reused authority

The internal service reuses, without redefining:

- F-GC30 per-tile predictor/tangent semantics;
- F-GC31-style N:1 affine cell-response semantics where applicable;
- F-GC33 MODFLOW6 HCOF/RHS transformation;
- F-GC34 typed package publication;
- F-GC35 XMI lifecycle guard;
- F-GC36 live MODFLOW6 package consumption;
- existing SWAP immutable accepted-origin trial semantics;
- existing groundwater prepare/preflight/commit semantics;
- existing MultiSWAP publication ordering.

The exact live capability identifiers may move as concurrent canonical work is admitted; the scientific ownership boundary here is independent of numbering.

## 4. Coupling-window semantics

At accepted time `T_n` the service:

1. captures one immutable SWAP origin;
2. obtains one immutable groundwater origin from the groundwater backend;
3. builds the SWAP predictor/tangent once;
4. freezes `s = dq_u/dH` for the coupling window;
5. initializes the affine reference `H_ref, q_ref`.

For outer iteration `k`:

```text
q_lin,k(H) = q_ref,k + s * (H - H_ref,k)
```

The groundwater backend generates a candidate from the same accepted groundwater origin and returns:

```text
H_gw,k
q_gw,k
```

SWAP then generates a corrector candidate from the same accepted SWAP origin under `H_gw,k` and returns:

```text
q_swap,k
accepted-window exchange candidate
```

Residual:

```text
r_q,k = q_swap,k - q_gw,k
```

Convergence:

```text
abs(r_q,k) <= q_tolerance
```

If not converged, both candidates are discarded before retry and only:

```text
H_ref,k+1 = H_gw,k
q_ref,k+1 = q_swap,k
```

are updated. The tangent remains fixed for this first contract.

## 5. Publication ownership

F-GC37 preserves existing SWAP5 publication governance:

```text
stage accepted-exchange ledger
prepare groundwater
prepare ledger
publication preflight
commit SWAP
commit groundwater
commit ledger
```

There is no new parallel transaction architecture.

## 6. Groundwater-backend boundary

The service requires a groundwater participant with true:

```text
trial_from_origin(accepted_groundwater_origin, response)
```

semantics.

The live MODFLOW6/XMI surface demonstrated so far has forward lifecycle operations but no native rollback operation equivalent to the SWAP transaction contract.

Therefore the **next problem is below the coupling service**, not above it:

```text
internal SWAP5-MODFLOW coupling service
                |
                v
MODFLOW6 transactional-origin backend
```

That backend must prove that repeated MODFLOW candidates originate from the same accepted groundwater state.

iMOD Coupler does not solve or own this problem.

## 7. Qualified evidence retained

The earlier executable qualification remains scientifically valid and is retained as test-only evidence. It proves:

- same accepted SWAP origin across correctors;
- same accepted groundwater origin across groundwater trials;
- predictor/tangent built once;
- fixed tangent through the window;
- multi-iteration flux-residual convergence;
- rejected candidate disposal;
- bounded non-convergence;
- prepare-failure cleanup;
- existing publication order;
- exactly-once final publication intent.

Reclassifying the Python implementation as a harness changes ownership, not these results.

## 8. Current canonical reconciliation

Current canonical during this ownership correction is:

```text
integration/f-ci-canonical
7b864853ca22baa73141b2dec9ed2f3915ef520d
```

Since the previous F-GC37 reconciliation, canonical has admitted additional active-drainage/directional work, including changes to the MODFLOW6 predictor-tangent adapter.

Those changes expand/adjust underlying tangent capability but do not alter this service-ownership decision:

**predictor/corrector semantics remain inside the SWAP5–MODFLOW coupling service and outside iMOD Coupler.**

The production service should reconcile against the then-current admitted tangent authority when it is materialized.

## 9. Explicit exclusions

F-GC37 does not:

- place predictor/corrector logic in iMOD Coupler;
- establish Python as the production coupling language;
- implement live MODFLOW accepted-origin restoration;
- create a production MODFLOW solve driver;
- couple Ribasim;
- implement irrigation;
- create a second SWAP transaction lifecycle;
- silently absorb concurrent tangent/drainage work;
- admit itself to canonical.

## 10. Next bounded step

The next workunit should qualify a **MODFLOW6 transactional-origin backend below this service**.

Only after that backend is qualified should the internal SWAP5–MODFLOW service be materialized against real SWAP5 and live MODFLOW6 participants.

iMOD Coupler integration comes later and should consume only the coarse coupled-window service surface.
