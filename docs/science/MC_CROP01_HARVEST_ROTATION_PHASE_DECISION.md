# MC-CROP01 harvest/rotation phase decision boundary

Status: investigated, proposed shared-contract decision; NOT production
implementation or qualification. Canonical baseline
`7315be4f532c791fe008f76d0d4fc9855705a87e`; PR1209 growth completion is admitted.

## Authenticated source and retained invariants

Reuse `SWAP431_B111_AUTHORITY.tar.gz.b64` and exact source identities in
`MC_CROP01_ROOTED_WEATHER_PRODUCTION_STATUS.json:next_lifecycle_dependencies`.
Historical swap.f90 lines491/511/514/521/535 order growth3, harvest4,
integral/output, reset; the next morning orders TimeControl2, Meteo2,
croprotation2. Wofost task4 checks abs(t1900-cropend-1.d0)<0.1d0 and, for
annual sw_harv>0, DVS>=dvsend. Reset occurs after end-status output, not
before that observation. No source archive recovery is required.

The existing inactive WOFOST owner forbids allocated biomass/evolution
continuation. Preserve it by retaining immutable harvest end-status inside
the existing transactional crop owner while resetting its active owner.
Do not create an output/crop-state shadow owner or weaken validation.

## Actual shared phase gap

PR1209 commits current growth over positive [day,day+1]. At the following
morning, crop and accepted hydrology already have time day+1. A new season
must initialize after its authentic morning weather and before its own
hydrology, independently of acceptance of that day's end. Current kernel
advance_interval rejects t1<=t0 (mod_kernel_transactions.f90 line700).
Its candidate origin and committed revisions are opaque physical authority.
Reinitializing/wrapping the carrier to reset its time/revision, replaying an
already consumed weather window, or using a fabricated zero-duration interval
does not resolve this gap. Deferring initialization until that same day's
hydrological acceptance violates the historical daystart requirement.

The bootstrap additionally refuses lifecycle%harvested at daystart and when
binding rooted weather forcing. Calendar receipt binding only publishes
derived calendar/window retirement after a matching physical crop receipt.
The physical-calendar restart validator intentionally refuses fallow and
direct switches. Calendar select_at or caller crop numbers cannot authorize
the missing physical reset/start transition.

## Routed decision and dependent implementation

Owner: existing central RT/HY/F-KT admission with MC-CROP01/F-WOF38 and
calendar/restart owners. Route under workstream-execution-protocol shared
contract boundary; no independent alteration of kernel semantics.

Decide the source-bound morning initialization publication contract on an
already accepted previous-day carrier: either an existing admissible
boundary transaction/receipt composition, or an explicitly qualified phase
schedule retaining a real positive accepted window for morning publication.
It must cover adjacent crops as well as intervening fallow; no synthetic
crop-growth events or caller-only weather provenance. Define how biological
events, physical receipts, crop identity/parameters and independent soil
time remain distinguishable and exactly-once across both phases.

Then implement one coherent block: source harvest candidate/end-status,
owned reset, zero canopy/extraction in actual fallow hydrology, new-season
task2/task3/emergence through existing owners, derived calendar binding and
joint partial/pending/harvested/fallow/start restart. Qualify two authentic
crop periods plus adjacent switch, calendar and maturity harvest, final-day
flush, output-before-reset, positive/zero/positive actual extraction,
rejected transitions/rollback/retry/duplicates, mass, O0/O2, owner/full F-CI
and complete affected highest frost closure. No fullcap/count promotion
until that physical trajectory and remaining historical profiles pass.
