# F-GC-STRIP01 C2E: proposed native-registry Dummy-SWAP A/B

**Status:** `PROPOSED_FOR_DESIGN_REVIEW_NOT_AUTHORIZED`  
**Baseline:** C2D closeout at `72d54b276639ecd6dac1213ce8b3e400fac38d25`  
**Contract:** `integration/f-gc/strip01/F-GC-STRIP01_C2E_NATIVE_DUMMY_PREREGISTRATION.json`

## Why this is next

C2D established that its analytic Dummy-SWAP publishes the target recharge and produces a spatial MODFLOW response, drainage and closed mass through the F-GC49C service, F-GC34 publisher and MODFLOW6. C2B records the real-SWAP/Richards failure. The remaining uncertainty is whether the dynamic dummy can use the native F-GC49D registry/context while keeping the same transactional and publication path.

The current registry stores concrete `fmr_groundwater_swap_participant_t` and `fmr_serialized_reference_backend_t` values. The participant owns candidate/origin checks and delegates commit to the backend. Substituting only a flux after the Richards trial would sever the response from its candidate state. A second registry or the existing Python service would repeat C2D rather than close the same-registry gap.

## Proposed seam

Add a reviewed, explicitly test-only participant-provider construction path at the leaf participant boundary. Keep the F-GC49D C API, application context, registry lifecycle/identity, 50 index-preserving handles, coupling iteration, native package publisher and MODFLOW solve/publication in the path. Production constructors continue to create only the existing real-SWAP participant. The test factory must not be addressable through the production entrypoint or hidden global configuration.

The provider contract owns a self-consistent origin, candidate response and candidate storage. It must support origin capture; trial at the prescribed head; complete candidate discard; publication preflight against participant identity, origin revision and exact window; and exactly-once commit. The trial flux and tangent come from the same analytic state transition. The registry continues to decide whether and when the candidate is accepted and published.

The test dummy inherits C2D's storage partition and forcing: Dummy-SWAP owns recharge and top-system storage, MODFLOW owns the disjoint research aquifer capacitance and the single drain representation, and interface exchange remains an internal transfer. This ownership is confined to the research experiment and does not extend the production fixed-interface contract.

## Qualification order

1. Repeat the matched-head four-window hydrostatic zero control through all 50 native registry participants.
2. Inject a deterministic prepublication rejection and prove no participant, ledger or MODFLOW state advances; retry from the same origin.
3. Run C2D's 120-window recharge/recession profile at near-zero and finite resistance, recording subsystem convergence, coupling residual and physical mass residual separately.
4. Run matched real-SWAP and dummy cases through the same native harness, compare first failure and response, and replay each case in fresh processes.

Passing establishes same-registry coupling support for this analytic response and makes the C2B comparison much sharper. It still does not qualify field physics, Hupsel, production aquifer storage/drain ownership or a production Dummy-SWAP backend. If an additive seam cannot preserve real-SWAP defaults and transaction guarantees, retain C2D as the bounded service-level reference and stop this extension.

## Review boundary

This is a proposed contract, not an accepted interface decision or implementation authorization. The open review item is whether the native registry can dispatch through an explicit test-only provider while preserving its current identity, candidate and commit guarantees without changing the production ABI or default behavior. No source/runtime changes are included in this proposal.
