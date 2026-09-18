# F-GC49B1 — Production FMR groundwater participant registry

## Purpose

F-GC49B1 creates the production SWAP-side participant registry needed by the generic application service. It replaces qualification-specific global participant wiring with opaque integer handles over externally owned FMR application contexts.

It is entirely Fortran. It does not yet expose a C ABI or Python client.

## Ownership model

The registry does not own or copy committed SWAP state, FMR backends, parameters, forcing, application columns/templates, numerical configuration, forcing materializers or interface ledgers.

At bind time it records Fortran pointer associations to application-owned TARGET objects. The application must keep those targets alive and stable for the lifetime of the registry binding.

The registry itself owns only coupling-local state:

- the admitted `fmr_groundwater_swap_participant_t` checkpoint/candidate provenance;
- the latest corrector trial value;
- the prepared-ledger token;
- current coupling window/datum/predictor lineage;
- opaque monotonically increasing handle identity and lifecycle flags.

The raw FMR `kernel_executor_t` is never exposed to the registry. SWAP commit remains delegated through the admitted F-GC43 participant and the backend-owned commit operation.

## Predictor service

`mod_fmr_groundwater_predictor_service` factors the real F-GC30 predictor path out of the old qualification bridge.

It requires an explicitly supplied accepted interface state. It therefore does not invent or collapse accepted groundwater provenance. The supplied accepted SWAP lower-face head must match the lower-face head reconstructed from the committed FMR state and predictor qbot. The supplied accepted SWAP flux must match that predictor qbot under the canonical sign/unit conversion.

The service then:

1. captures a real kernel checkpoint from the committed state;
2. runs the predictor trial through the production serialized FMR backend;
3. materializes the accepted-trajectory analytic tangent through F-GC30;
4. captures committed predictor-origin provenance through F-GC30;
5. assembles the typed predictor response through the F-GC30 candidate assembler;
6. always discards the noncommitting predictor candidate before return.

No predictor candidate can be committed by this service.

## Registry binding

`fmr_groundwater_participant_registry_t` is initialized with a fixed capacity. `bind_context` validates:

- positive tile, SWAP-lineage and ledger identities;
- external committed state is ready and owns the declared SWAP lineage;
- application column lineage/template agrees with the binding;
- predictor and corrector backends are distinct objects;
- tile id, SWAP lineage and ledger id are globally unique inside the registry;
- the external ledger is quiescent and bound to the declared logical ledger identity.

A successful bind returns a monotonically increasing opaque `int64` handle. Unbinding invalidates that handle; reusing a registry slot never resurrects an old handle.

## Window lifecycle

`begin_window` builds one predictor response and then captures the corrector origin from the same still-unmodified committed SWAP state. It stores only window-local provenance after both operations succeed.

`corrector_trial` delegates to the admitted F-GC43 real FMR participant. Every non-final corrector therefore starts from the participant's immutable accepted checkpoint.

`discard_candidate` rolls back only the live candidate and leaves committed SWAP state unchanged.

## Ledger lifecycle

`prepare_ledger(handle, area_fraction)` requires a valid final corrector and SWAP publication readiness. The whole-window physical exchange is weighted by the topology area fraction before being staged in the participant's external logical ledger.

The ledger lineage uses the stored predictor coupling/groundwater provenance and candidate revision `swap_origin_revision + 1`.

Prepared-ledger readiness is exposed separately from SWAP candidate readiness so the generic application service can complete all preflights before MODFLOW timestep publication.

## Publication and abort

`commit_swap` is allowed only when both the SWAP candidate and prepared ledger are ready. It delegates the actual committed-state mutation to the admitted F-GC43 participant/backend path.

`commit_ledger` is allowed only after SWAP commit and closes the participant window.

`abort_prepublication` discards a live SWAP candidate and aborts/discards any ledger trial before clearing the registry window. It is explicitly rejected after SWAP publication has begun.

This registry does not claim rollback after an irreversible publication point.

## Qualification boundary

The owner qualification uses two real FMR committed states and independent predictor/corrector backends. It proves:

- real F-GC30 predictor responses through the new production service;
- unique opaque handles and duplicate-ownership rejection;
- repeated correctors from one accepted origin;
- prepublication abort followed by clean re-begin;
- all participant/ledger preflights before SWAP commit;
- external committed state advances only through kernel-owned commit;
- area-weighted ledger publication;
- stale handles fail closed.

Independent F-VQ122 verifies that the registry contains no raw kernel/XMI ownership, reuses F-GC30 and F-GC43 chains, keeps committed state externally owned, and retains noncommitting predictor rollback and post-publication guards.

## Next boundary

F-GC49B1 deliberately stops before the language boundary. The next bounded substage is F-GC49B2: a narrow C ABI / Python client over this admitted handle registry. That ABI must expose only handles and scalar/typed value records, never raw Fortran pointers or kernel state.