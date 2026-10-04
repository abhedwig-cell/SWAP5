# PPA-WU05-E macropore solute boundary

**Status:** proposed implementation contract; source audit only. This is not a
qualification or an admission record.

**Baseline:** PPA-WU05-E PR branch postimage at `e0472bb2e913ffe4b42916006a000024bc03e9a3`; this audit records the local prototype that follows it.

## Finding

The accepted FMR water observation is not a source-complete salt-transfer
interface for the admitted macro-enabled water route. The macropore process
computes matrix exchange by domain and node (`qexc_to_matrix_rate`, shaped
`[num_domains,num_nodes]`). Its sign convention is explicit: positive exchange
is macropore-to-matrix; negative exchange is matrix-to-macropore. The multi-
domain receipt uses the same sign in `internal_exchange_to_matrix_cm`.

The opt-in FMR accepted-substep trace now preserves the signed exchange rate
per domain and node, its node sum, matching macro-water start/end volumes, and
the reconstructed per-domain vertical face rates. The A7 O0/O2 transaction
gate checks nonzero domain exchange, nonzero macro-water change, nonzero
vertical flux, source-sum identity, volume validity, Richards closure, and
exact retry/replay plus fresh-process restart trace identity. Producer and
consumer checks also enforce per-domain storage/exchange/face continuity on
every accepted substep. These are
attempt-local water diagnostics only. E1 remains matrix-only, but the FMR
physical salt component now has an optional `macro_mass_mg_cm2(domain,node)`
payload under the distinct `FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE`
identity. Clone and Restart v3 round-trip tests preserve that payload with the
matching macro-water state. It is only storage scaffolding: FMR rejects active
salt trials, no live process initializes or advances this macro mass, and typed
solute boundary receipts remain absent. Multiplying matrix concentration by
aggregate exchange would invent donor mass.

This is an ownership/interface gap, not a salinity-response defect. A bounded,
stateless exchange operator now lives in
`src/process/mod_solute_macropore_exchange.f90`; O0/O2 tests exercise both
signs, unequal domain concentrations, zero flow, within-sequence reversal,
salt closure, dry donors, aggregate matrix donor-water limits, and water
overdraw. It uses start-of-substep donor concentration and returns no candidate
when the donor is unavailable. The source kernel computes only internal
matrix/macropore exchange. It does not own continuation state, transport
scheduling, boundaries, or a live FMR route. The fail-closed
`SOLUTE_WATER_CLOSURE` outcome remains correct. Jarvis must remain a read-only
consumer of concentration derived from an accepted/trial salt state.

## Source-bound facts

| Fact | Source |
| --- | --- |
| Domain exchange rates have `[domain,node]` shape and are summed to node exchange for the matrix provider. | `src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90`; `src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90` |
| Positive exchange transfers water from macropore to matrix; negative exchange transfers matrix water to macropore. | `src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90`, `compose_macropore_candidate` |
| The committed macropore continuation owns per-domain/node water volume. A separate optional FMR salt component can carry per-domain/node macro mass under a distinct solute layout; it is validated and clone/restart-preserved but not advanced by live FMR. | `src/runtime/mod_macropore_continuation_state.f90`; `src/runtime/mod_fmr_serialized_reference_backend.f90`; `src/runtime/mod_fmr_restart_state_contract.f90`; A7 O0/O2 tests |
| The opt-in accepted FMR trace preserves domain/node exchange, its node sum, paired per-domain start/end water volumes, and ordered per-domain vertical face rates. It rejects nonzero top input/return, covering transfer, and rapid outflow; typed boundary salt receipts are absent. | `src/runtime/mod_fmr_serialized_reference_backend.f90`, `append_accepted_water_flux_substep` and accepted trace validation |
| E1 salt candidate consumes matrix face fluxes and a single mobile mass per node; unowned source/sink closure rejects. | `src/process/mod_solute_mobile_salt_state.f90`; `tests/fpm/test_ppa_wu05a7_real_richards_runtime.f90` |
| Macropore vertical faces are reconstructed by domain from top inflow, accepted storage change, matrix exchange, and rapid outflow; the opt-in FMR water trace now carries those rates for supported zero-boundary substeps. | `src/process/macropore/mod_ppa_wu05a6_vertical_flux_reconstruction.f90`; `src/runtime/mod_macropore_single_column_runtime.f90`, `prepare_vertical_request`; `src/runtime/mod_fmr_serialized_reference_backend.f90` |
| The standard storage route requires fixed geometry; a separate multi-domain candidate path can return displaced water to matrix. Covered-top transfer adds water to the macropore candidate and removes it from the matrix source above the top node. | `src/process/macropore/mod_macropore_standard_storage.f90`; `src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90`; `src/runtime/mod_macropore_single_column_runtime.f90` |

## Required contract before macro-route salt advancement

The next implementation slice under PPA-WU05-E must establish all of the
following before binding a salt consumer to this route:

1. The opt-in water trace now preserves accepted, ordered macropore exchange
   **per domain and node**, verifies its node sum, and carries paired domain
   water start/end volumes and ordered domain vertical face rates for that
   substep. A7 requires nonzero exchange, macro-water change and vertical flux,
   then verifies per-domain storage/exchange/face continuity, retry/replay and
   restart identity.
2. Complete the macro salt state owner. A distinct per-domain/node mass array
   and solute layout now exist and are paired with macro water by the FMR physical
   carrier and Restart v3. The next work is to define profile initialization,
   derive concentration only from synchronized mass and liquid volume, and stage
   mass changes in the same candidate as accepted water exchange. No production
   trial currently performs those operations.
3. Add typed solute receipts for top input/returned surface water, covered-top
   transfer, geometry return and rapid drainage. The water trace now carries
   ordered domain vertical faces for the supported zero-boundary route, but
   candidate advancement must continue to reject boundary configurations until
   their donor/receiver salt ownership is explicit.
4. Transfer salt with signed accepted matrix exchange and the donor-domain
   concentration. Apply the equal-and-opposite amount to matrix and macro
   ledgers. Reject unavailable donor mass, dry donor state, invalid mapping,
   or mismatched time coverage; do not clip or infer a concentration.
5. Account for macro top partition/returned surface water, geometry returns,
   and covered-top transfer explicitly. These terms need typed donor and
   receiver routing; geometry return is not active in the fixed-geometry
   standard candidate scope. Routes without typed salt receipts stay disabled
   and fail closed.
6. Keep matrix salt mass, macro-domain salt mass, water mass and external salt
   receipts separately attributable while committing or discarding one physical
   candidate atomically. Clone and Restart v3 layout identity/restore scaffolding
   now preserve both arrays; production advancement, rejection rollback, retry
   and fresh-process replay still need an accepted coupled route.

The implemented stateless source kernel verifies a closed matrix-plus-multiple-domain exchange: positive and
negative water exchange, unequal donor concentrations, zero exchange, reversal
within ordered accepted substeps, and invalid/dry/insufficient donor cases.
Each case must prove equal-and-opposite internal salt transfer and unchanged
column salt inventory absent external salt flux. A live FMR case must then
prove independent water and salt closure under commit, discard, retry and
restart before any Jarvis integration is attempted. The storage-only layout and
Restart v3 test do not satisfy that criterion.

The standalone O0/O2 runner is `tests/physics/run_ppa_wu05e_mobile_macropore_salt_exchange.sh`. Passing this oracle does not change the active-route rejection or establish accepted-substep macro salt transport.

## Scope and evidence limits

This contract is derived from current SWAP5 source ownership and exchange
semantics. It does not claim that the same multi-domain solute layout or
exchange discretization is byte-equivalent to B1.11; the exact B1.11 solute
member remains unavailable in this execution surface. It does not qualify
macropore solute transport, boundary solute forcing, dispersion, salinity
stress, Jarvis combinations, or production behavior. The base-layout FMR
temporal-identity gate is a separate TX/FMR policy dependency and is not
changed by this slice.

## Next action

Keep PPA-WU05-E salinity disabled on the live FMR macro route. The stateless
exchange kernel and FMR trace now provide the internal exchange and ordered
vertical water terms for the tested restricted route. The next implementation
slice must define paired per-domain macro salt mass and typed boundary-salt
receipts, then bind matrix and macro mass to one candidate/clone/restart owner.
Qualify commit, discard, retry, replay and independent closure before enabling
a live consumer. PPA-WU05-F remains the separately registered frost unit.
