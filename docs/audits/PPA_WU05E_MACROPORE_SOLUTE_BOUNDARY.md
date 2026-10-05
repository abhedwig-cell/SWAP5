# PPA-WU05-E macropore solute boundary

**Status:** proposed implementation contract; source audit only. This is not a
qualification or an admission record.

**Baseline:** PPA-WU05-E work branch; source-level prototype pending a pinned
qualification manifest. The worktree changes are not canonically admitted.

## Finding

The accepted FMR water observation is not a source-complete salt-transfer
interface for the admitted macro-enabled water route. The macropore process
computes matrix exchange by domain and node (`qexc_to_matrix_rate`, shaped
`[num_domains,num_nodes]`). Its sign convention is explicit: positive exchange
is macropore-to-matrix; negative exchange is matrix-to-macropore. The multi-
domain receipt uses the same sign in `internal_exchange_to_matrix_cm`.

Earlier accepted traces stored only `macropore_result%exchange_rate_node`, the
sum over macropore domains. The work branch now preserves exchange by domain,
paired macro water start/end volumes, and reconstructed vertical faces in each
accepted substep. The trace still does not own per-domain dissolved salt mass
or typed receipts for all route boundaries. Multiplying the summed water
exchange by matrix concentration would invent a solute transfer and debit the
wrong donor.

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

## Restricted coupled transport candidate

`src/process/mod_solute_mobile_macro_salt_transport.f90` adds profile
initialization, a read-only concentration view, and a stateless single-substep
candidate over one matrix mobile domain and the traced macro domains. Matrix
water is passed as volumetric content and multiplied by node thickness to
obtain cm water per ground area; macro water is already in cm per ground area.
Salt mass is mg/cm2 and concentration is always derived from matching mass and
water volume. Initialization maps a declared matrix/domain concentration
profile to separate matrix and per-domain inventories. Vertical flow, signed
exchange, root TSCF removal, and explicit top/bottom concentration inputs for
matrix and macro boundaries are booked in one separate salt ledger. All donors
use the synchronized committed start state. A mismatch in water continuity,
aggregate donor water overdraw, invalid or negative candidate inventory, or
positive inventory paired with zero end water rejects the full candidate.

The ordered-trace entry point applies contiguous accepted substeps in time
order, verifies matrix and macro water-state continuity between them, and uses
each completed candidate as the following substep's donor state. It aggregates
external, root, and signed internal exchange receipts. Any later invalid step
discards the entire candidate and all accumulated receipts.

The O0/O2 manufactured oracle covers matrix and domain profile initialization,
rederived concentration identity and dry-state rejection, nonzero vertical
macro advection,
opposite-sign internal exchange, unequal node concentrations, explicit matrix
top input and bottom output, a root TSCF receipt, total-salt closure, bad water
closure, nonfinite flow rejection, ordered reversal from the updated candidate,
and late-substep rollback with no partial candidate or receipt. This is
process-kernel evidence only:
the new kernel is not called by FMR, its arguments are not yet a typed accepted
salt-boundary receipt set, and it does not add committed macro salt mass or
restart state. Its boundary concentration inputs do not qualify FMR surface
partition, returned water, covered-top transfer, rapid drainage, or geometry
return routes.

## Source-bound facts

| Fact | Source |
| --- | --- |
| Domain exchange rates have `[domain,node]` shape and are summed to node exchange for the matrix provider. | `src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90`; `src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90` |
| Positive exchange transfers water from macropore to matrix; negative exchange transfers matrix water to macropore. | `src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90`, `compose_macropore_candidate` |
| The committed macropore continuation owns per-domain/node water volume, but no solute mass. | `src/runtime/mod_macropore_continuation_state.f90` |
| The opt-in accepted FMR trace preserves domain/node exchange, its node sum, paired per-domain start/end water volumes, and reconstructed vertical face rates; it validates per-node storage/exchange/face continuity. Macro top and rapid outflow remain rejected, and typed salt boundary receipts are absent. | `src/runtime/mod_fmr_serialized_reference_backend.f90`, `append_accepted_water_flux_substep` and accepted trace validation |
| E1 salt candidate consumes matrix face fluxes and a single mobile mass per node; unowned source/sink closure rejects. | `src/process/mod_solute_mobile_salt_state.f90`; `tests/fpm/test_ppa_wu05a7_real_richards_runtime.f90` |
| Macropore vertical faces are reconstructed by domain from top inflow, accepted storage change, matrix exchange, and rapid outflow; accepted trace validation enforces their nodewise continuity. | `src/process/macropore/mod_ppa_wu05a6_vertical_flux_reconstruction.f90`; `src/runtime/mod_macropore_single_column_runtime.f90`, `prepare_vertical_request`; `src/runtime/mod_fmr_serialized_reference_backend.f90` |
| The standard storage route requires fixed geometry; a separate multi-domain candidate path can return displaced water to matrix. Covered-top transfer adds water to the macropore candidate and removes it from the matrix source above the top node. | `src/process/macropore/mod_macropore_standard_storage.f90`; `src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90`; `src/runtime/mod_macropore_single_column_runtime.f90` |

## Required contract before macro-route salt advancement

The next implementation slice under PPA-WU05-E must establish all of the
following before binding a salt consumer to this route:

1. The opt-in water trace now preserves accepted, ordered macropore exchange
   **per domain and node**, verifies its node sum, and carries paired domain
   water start/end volumes for that substep. A7 requires a nonzero exchange and
   nonzero macro water change, then verifies replay identity.
2. Define the macro salt state and its sole mass owner. For a restricted
   dissolved-only envelope, it must be explicit whether this is a distinct
   per-domain/node mass array paired atomically with the existing macro water
   continuation, or another accepted composite physical-state owner. A
   concentration view is derived from matching salt mass and liquid volume;
   no independent stale concentration state is authoritative.
3. The accepted attempt trace now carries the reconstructed per-domain vertical
   face rates and checks their local water-storage/exchange identity. Ordered
   internal macro advection is therefore observable in the restricted route.
   Add typed top and rapid-drainage solute receipts before those external
   routes can participate in a salt candidate. These terms are required to move
   dissolved mass as the macro storage profile is canonicalized bottom-up. A
   zero or net-only trace cannot substitute for the ordered donor fluxes.
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
   receipts separately attributable while committing or discarding the whole
   physical candidate atomically. Clone, restart-layout identity, restore,
   retry and fresh-process replay must preserve both mass owners.

The exchange-only and coupled transport kernels verify closed internal
matrix-plus-multiple-domain transfer. The coupled oracle also verifies
vertical macro advection and explicit matrix boundary/root receipts. A live FMR
case must still prove independent water and salt closure under commit, discard,
retry and restart before Jarvis integration is attempted.

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

## Matrix-source salt authority: qssdi and qdra

The current FMR matrix-water source/sink trace includes subsurface drip
irrigation (`qssdi`) and level-resolved lateral drainage (`qdra`). The local
B1.10/B1.11-compatible water-source implementation establishes their water
semantics, but does not establish a salt concentration for either route:

| Term | Water meaning and sign | Salt authority in current route |
|---|---|---|
| `qssdi(node)` | Subsurface drip irrigation into a matrix node; the source is added to Richards. Integrals are accumulated as `qssdi * dt`. | No concentration accompanies the FMR forcing/trace. The salt mass input cannot be inferred from water volume. |
| `qdra(level,node) > 0` | Soil-to-drain extraction at a specific level and node; accumulated as drainage outflow. | The corroborative SWAP source-family solute routine uses local `CML` for positive `qdra`; current FMR trace has no paired dissolved-mass receipt. |
| `qdra(level,node) < 0` | Drain-to-soil infiltration at a specific level and node; accumulated separately as drainage inflow. | The corroborative source-family routine uses separate `Cdrain`, not receiving-node `CML`. Current FMR forcing has no such salt state. |

The signs and node/level semantics are source-backed by
`src/legacy/b1_10_port/headcalc.f90` (adds `qdra` to sink and binds `qssdi` as
source), `src/legacy/b1_10_fci11_port/integral_part05.inc` (nodewise
`qssdi * dt`), `src/legacy/b1_10_fci11_port/integral_part06.inc` (positive and
negative drainage accounting), and the FMR trace construction in
`src/runtime/mod_fmr_serialized_reference_backend.f90`. These are water-source
semantics, not proof of B1.11 solute implementation details.

The retrieved `SWAP-model/SWAP@c22bd832ddf3e53e330a552f5e31e74f183362d1`
`src/solute/solute.f90` is not byte-identical to the B1.11 manifest member
(18,271 versus 51,508 bytes). In that corroborative routine, levelwise positive
`qdra` exports salt at local `CML`, negative `qdra` imports at `Cdrain`, and no
`qssdi` term appears in the displayed mass update (surface `nird*cirr` is
present). Therefore do not silently equate `qssdi` with surface irrigation,
assume its salt is zero, or copy this source-family omission as B1.11 truth.
The exact B1.11 `solute.f90` is still needed to decide whether subsurface-drip
salt is omitted, separately parameterized, or accounted elsewhere. `Cdrain`
also requires an identified water/solute owner and restart lifecycle before
negative drainage can be enabled in SWAP5.

Consequently, a future typed receipt must preserve each signed `qdra` level
flux rather than only its Richards sum, book positive `qdra` removal against
the matrix-node donor concentration, and source negative `qdra` only from an
explicit `Cdrain`-equivalent state if the applicable B1.11 semantics confirm
it. `qssdi` salt handling is unresolved until the exact B1.11 source semantics
and input contract are recovered. All routes must reject absent, non-finite,
or physically invalid donor data; do not silently substitute receiving-node
`CML` or assume zero salt. No typed receipt or FMR salt candidate is
implemented by this audit. Exact B1.11 solute source bytes are not materialized
here, so this is a SWAP5 blocker contract, not a claim of historical solute
equivalence.

## Next action

Keep PPA-WU05-E salinity disabled on the live FMR macro route. The transport
candidate is ready only for a bounded process-level envelope. Next add typed
accepted top/returned-surface and rapid-drainage salt receipts; retain
fail-closed behavior for covered-top and geometry-return routes until their
donor and receiver mapping is explicit. Then bind per-domain macro salt mass
atomically with the physical candidate and qualify commit/discard/retry/restart
before any salinity response or Jarvis composition. PPA-WU05-F remains the
separately registered frost root-stress unit.
