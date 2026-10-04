# PPA-WU05-E macropore solute boundary

**Status:** proposed implementation contract; source audit only. This is not a
qualification or an admission record.

**Baseline:** PPA-WU05-E branch at `dc8be5e5b` (worktree changes are not yet
included in that commit).

## Finding

The accepted FMR water observation is not a source-complete salt-transfer
interface for the admitted macro-enabled water route. The macropore process
computes matrix exchange by domain and node (`qexc_to_matrix_rate`, shaped
`[num_domains,num_nodes]`). Its sign convention is explicit: positive exchange
is macropore-to-matrix; negative exchange is matrix-to-macropore. The multi-
domain receipt uses the same sign in `internal_exchange_to_matrix_cm`.

The FMR accepted-substep trace currently stores only
`macropore_result%exchange_rate_node`, which is the sum over macropore domains.
That sum closes the water source term for the matrix Richards solve, but loses
which macropore domain supplied or received the water. E1's mobile salt state
owns only matrix/mobile salt mass. It has neither per-domain dissolved salt
mass nor a donor concentration for matrix/macropore exchange. Multiplying the
summed water exchange by the matrix concentration would therefore invent a
solute transfer for macropore outflow and fail to remove the correct donor
mass for macropore inflow.

This is an ownership/interface gap, not a salinity-response defect. A test-only
transfer oracle now exists in `tests/physics/ppa_wu05e_mobile_macropore_exchange_oracle.f90`,
with O0/O2 checks for both signs, unequal domain concentrations, zero flow,
within-sequence reversal, salt closure, dry donors, and water overdraw. It uses
start-of-substep donor concentration and returns no candidate when the donor is
unavailable. This tests the exchange arithmetic only; it does not supply the
missing production state or trace. The fail-closed `SOLUTE_WATER_CLOSURE`
outcome remains correct. Jarvis must remain a
read-only consumer of the concentration derived from the accepted/trial salt
state.

## Source-bound facts

| Fact | Source |
| --- | --- |
| Domain exchange rates have `[domain,node]` shape and are summed to node exchange for the matrix provider. | `src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90`; `src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90` |
| Positive exchange transfers water from macropore to matrix; negative exchange transfers matrix water to macropore. | `src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90`, `compose_macropore_candidate` |
| The committed macropore continuation owns per-domain/node water volume, but no solute mass. | `src/runtime/mod_macropore_continuation_state.f90` |
| The opt-in accepted FMR trace preserves domain/node exchange, its node sum, and paired per-domain start/end water volumes; macro top and rapid outflow remain rejected, and salt boundary receipts are absent. | `src/runtime/mod_fmr_serialized_reference_backend.f90`, `append_accepted_water_flux_substep` and accepted trace validation |
| E1 salt candidate consumes matrix face fluxes and a single mobile mass per node; unowned source/sink closure rejects. | `src/process/mod_solute_mobile_salt_state.f90`; `tests/fpm/test_ppa_wu05a7_real_richards_runtime.f90` |

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
3. Transfer salt with the signed accepted water exchange and the donor-domain
   concentration. Apply the equal-and-opposite amount to matrix and macro
   ledgers. Reject unavailable donor mass, dry donor state, invalid mapping,
   or mismatched time coverage; do not clip or infer a concentration.
4. Account for the macro top partition, geometry returns, covering-layer
   transfer, and rapid external outflow explicitly. Routes without a typed
   boundary concentration or donor state stay disabled and fail closed.
5. Keep matrix salt mass, macro-domain salt mass, water mass and external salt
   receipts separately attributable while committing or discarding the whole
   physical candidate atomically. Clone, restart-layout identity, restore,
   retry and fresh-process replay must preserve both mass owners.

The implemented test-only oracle verifies a closed matrix-plus-multiple-domain exchange: positive and
negative water exchange, unequal donor concentrations, zero exchange, reversal
within ordered accepted substeps, and invalid/dry/insufficient donor cases.
Each case must prove equal-and-opposite internal salt transfer and unchanged
column salt inventory absent external salt flux. A live FMR case must then
prove independent water and salt closure under commit, discard, retry and
restart before any Jarvis integration is attempted.

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

Keep PPA-WU05-E salinity disabled on the live FMR macro route. First make a
source-bound trace/state contract for per-domain accepted exchange and paired
macro salt mass, then implement that state and transfer owner with isolated
oracles. Only after a source-complete accepted trace exists should E1 transport
be reconsidered for a live coupled receipt. PPA-WU05-F remains the separately
registered frost root-stress unit.
