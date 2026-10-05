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

The exact B1.11 `solute.f90` bytes have now been recovered and verified; see the recovery record above. The earlier public SWAP source-family files remain non-identical and are no longer needed as the equation authority.

| Term | Exact B1.11 solute rule | SWAP5 contract consequence |
|---|---|---|
| `qdra(level,node) > 0` | Removes solute from the node at local dissolved `CML`; source loops each level separately. | Preserve every signed level rate and debit its own local donor concentration. |
| `qdra(level,node) < 0` | Adds solute from `Cdrain`, not from receiving-node `CML`. | Require explicit external `Cdrain` forcing/state and restart identity. Never infer it from matrix concentration. |
| `qssdi(node)` | No salt term occurs in the solute source's mass update. Surface irrigation and precipitation have explicit `nird*cirr` and `nraidt*cpre` terms. | Reconstructed source-consistent route must keep qssdi zero-solute or reject it. No nonzero qssdi salt may be inferred. |
| Bottom seepage | Default `swbotbc=0` sets `cseep=cdrain`; selectors 1/2 take separate fixed or time-varying `cseep`. | Treat bottom solute forcing as its own declared boundary. Do not conflate it with the drainage receipt. |
| Dynamic aquifer | With `swbr=1`, `cdraini` initializes an evolving aquifer concentration; otherwise `cdrain` is prescribed. | First restricted implementation should make externally forced Cdrain explicit; dynamic aquifer storage is a separate scope. |

The source and byte identities are recorded at `archive/swap431-wofost81-qualified-donor` commit `f8301c6e5c8b0eb6df86a2ae0e21b5bf0e476736`. Archive SHA-256 is `965a4908d028ff6a509ddc3d4efcf2e6bce736a7f59a6fc052c8fa2fdd66459b`; extracted `solute.f90` SHA-256 `2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`, 51,508 bytes. This exactly matches the pinned B1.11 manifest member. The numbered chunks and manifest provide a reproducible source route.

The exact source also applies root uptake as `tscf*qrot*CML`; its full transport includes dispersion, sorption, decomposition and internal solute substeps. Those parts remain outside the current advective prototype and require separate implementation and evidence.

Consequently, the next typed drainage receipt must retain each signed `qdra` level, book positive-flow removal against node `CML`, and book negative-flow addition against explicit `Cdrain`. Keep qssdi explicitly zero-solute or fail-closed. This source audit does not implement any typed receipt or FMR salt candidate.

## Next action

Keep PPA-WU05-E salinity disabled on the live FMR macro route. The transport
candidate is ready only for a bounded process-level envelope. Next add typed
accepted top/returned-surface and rapid-drainage salt receipts; retain
fail-closed behavior for covered-top and geometry-return routes until their
donor and receiver mapping is explicit. Then bind per-domain macro salt mass
atomically with the physical candidate and qualify commit/discard/retry/restart
before any salinity response or Jarvis composition. PPA-WU05-F remains the
separately registered frost root-stress unit.


## Exact B1.11 solute source recovered (2026-10-05)

The pinned B1.11 member is no longer missing. It was recovered from the isolated historical source archive on `archive/swap431-wofost81-qualified-donor` at `f8301c6e5c8b0eb6df86a2ae0e21b5bf0e476736`. The archive README identifies the donor as recovered and byte-verified. Concatenating encoded parts 001–049 and decoding reproduced `SWAP_WOFOST81_SOURCE.zip` at 545,332 bytes, SHA-256 `965a4908d028ff6a509ddc3d4efcf2e6bce736a7f59a6fc052c8fa2fdd66459b`. The extracted `solute.f90` is 51,508 bytes, SHA-256 `2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`, Git blob SHA-1 `2fc77cc8d127d76e07a03369c1dac766157084b9`; it matches the pinned B1.11 member byte-for-byte.

Source contract from that exact member:

- The solute loop applies every `qdra(level,node)` independently. Positive flow removes mass using local dissolved `CML`; negative flow adds/removes signed mass using `Cdrain`. It books the signed result to the drainage mass ledger. Opposing drainage levels cannot be aggregated before selecting their donor concentrations.
- `Cdrain` is a prescribed boundary concentration unless `swbr=1`, in which case `cdraini` initializes the dynamic aquifer concentration and the aquifer balance evolves it. Bottom seepage is selected independently: default `swbotbc=0` follows `Cdrain`, while other selector values provide fixed or time-varying `cseep`.
- The source salt balance has no `qssdi` term. Surface irrigation and precipitation do have explicit `nird*cirr` and `nraidt*cpre` inputs. For a source-consistent restricted SWAP5 envelope, qssdi must be explicitly zero-solute or rejected; no concentration can be inferred from water forcing.
- Root salt uptake is `tscf*qrot*CML`. The exact source also includes dispersion, sorption, decomposition, internal solute substeps and optional aquifer breakthrough; these remain outside the current advective prototype unless separately implemented and tested.

This removes the exact-source identity blocker. It does not qualify a SWAP5 receipt, Cdrain forcing/restart owner, FMR salt candidate, or Jarvis integration. Keep those routes fail-closed until the contracts and transaction evidence exist.

Reconstruction record: `reference/historical/swap431-wofost81/README.md`, `SOURCE_MANIFEST.tsv`, `reconstruct_source.py`, and `encoded/SWAP_WOFOST81_SOURCE.zip.b64.part001..part049` on the donor archive branch.
