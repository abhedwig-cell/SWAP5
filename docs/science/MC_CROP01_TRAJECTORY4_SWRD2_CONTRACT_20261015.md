# Daily persistent SWRD2 successor

Status: bounded current science and shared owners qualified; full preservation
and canonical admission pending. This is not complete SWRD2/density coverage.
Baseline `451e35ccd1797aa96fb4354dabc465cceff18635`, production tree
`b8ac1c1c12096bc40478a58c5c8ac36ba687e3e0`. PR1241 remains closed.

## Source and scope

Authenticated B1.11 `MOD_cropdevelopment.f90` SHA256
`aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210`,
initialize_rootextension and update_rootextension, own RDI/RDM/RRI, separate
actual/potential depth, optional accepted IQROT_DAY/IPTRA_DAY scaling and
strict IALPWET_DAY < AERATECRIT suppression. Reuse the existing production
rate owner; do not duplicate these formulas in runtime.

First executable slice is SWDMI2RD=0/1 with static density and existing
empirical oxygen. The complete requested route also includes SWDMI2RD=2
drought/supply. That branch is NOT admitted by this first slice. Its source
requires WROOT_NODE from a real density owner, not an invented share of WRT.
The source initializes/updates that array only with SWRDC=1, SW_DROUGHT>1 or
SW_OXYGEN=2, while SWDMI2RD=2 is independently selectable. Resolve the source
domain and owning density composition before enabling it; existing component
tests do not prove its daily production binding. Never silently substitute
static biomass for the adaptive state.

## State and publication decision

Attach one optional existing crop_root_depth_rate_state_t to the existing
F-WOF38 committed crop transaction. No application-owned depth cache or
second crop owner. Allocate only for explicit SWRD2. Carry its two depths in
clone and serialization-neutral persistence; restore validates finite,
nonnegative actual <= potential and configured bounds on execution. Modes1/3
retain absent depth state. Existing native weather disk-codec limitation remains.

Initialize RDI at emergence, zero before emergence. On an accepted daily crop
candidate use the same accepted water/oxygen aggregates and that candidate's
actual/potential gross allocation. Evaluate depth before publishing biomass,
shadow, depth and event receipt together. Failed/rejected/stale/repeated events
cannot advance depth. Both current-day and lagged completion obey the same
owner. Potential depth is never scaled by actual water/oxygen stress.

Immutable application configuration and crop parameters must agree on SWRD2
controls. Hydrology reads committed actual depth through the existing static
profile materializer and real Richards sink; tentative depth is never used.
No new mass, water revision, solver policy or biomass formula.

Affected invariants:3/4/7/9/13/21/23/29/30. Shared crop transaction API changes
are explicit optional arguments with default-absent semantics. Root extension
parameters require strictly positive negligible-transpiration threshold for
water scaling, preventing the existing unconstrained zero/zero parameter edge.

## Verification selection

Before expensive work persist source and work-unit status. Start with the
existing small root-rate, oxygen and supply fail-closed production contracts
at O0/O2; add state/persistence/nonmutation and accepted-event tests. Measure
actual provider closure, compile/link/native/validation separately where
available. Then short real Richards daily current/lagged, root-depth feedback,
potential independence, oxygen/water discrimination, retry/rollback and opaque
joint restart. No component PASS becomes daily admission.

Select affected owner preservation and one stable-candidate local full moving
F-CI only after science and source reconciliation. Current costs are UNKNOWN;
historical trajectory3 full cost2676s is context, not this route's measurement.
Highest low-air NOT_SELECTED_POLICY. No Actions dispatch. No coverage promotion
until the bounded executable scope is qualified and actually merged.
