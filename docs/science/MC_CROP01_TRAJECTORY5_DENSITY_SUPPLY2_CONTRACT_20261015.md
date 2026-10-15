# Daily adaptive root density and SWDMI2RD2

Status: proposed bounded successor, not implemented/qualified/admitted.
Baseline `56aa2ba52fc4980053d712df85660a2facdfb0f4`, src
`fe8a6c1b569e641dccb6b0cc163d3318e7e6d9c0`. Trajectory4/PR1248 stays closed.

## Source and bounded selector domain

B1.11 MOD_cropdevelopment.f90 SHA256
`aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210`
owns initialize/update_rootextension, initialize/update_rootdistribution,
update_wroot_node, update_cumdens and finalize_wroot_node. rootextraction.f90
SHA256 `8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5`
owns QPOTROT/QREDROT and the pre-compensation drought attribution:
ALPDRYNODRTZ = 1 - QREDDRYSUM/PTRA. It is not a mean of layer factors or a
power attribution from compensated uptake. No duplication of uptake equations.

Implement explicit SWRD2/SWRDC1, SWDMI2RD0/1 plus the separate source supply2
composition. Supply2 uses the existing unscaled rate owner, real committed
deepest-node WROOT_NODE, accepted daily drought integral, RRIMIN/EXTENTCRIT and
accepted gross root allocation. Supply2 requires SWRDC1 in this bounded route.
Source permits selector2 independently, but static/advanced-selector WROOT_NODE
initialization outside SWRDC1 is not guessed. Initial depth and emerged WRT must
be positive for this adaptive slice; degenerate zero-profile source divisions
are not silently repaired. Static trajectories remain unchanged by default.

## Ownership and scientific order

One optional adaptive_root_profile_state_t belongs to the existing F-WOF38
committed crop transaction, beside its optional existing depth owner. WOFOST81
remains sole total-biomass owner; layer masses are a spatial distribution view.
At emergence seed from the existing RDCTB materializer at RDI. Before emergence
the optional profile has zero entries. Each accepted day: crop growth/death,
potential depth, actual supply/oxygen depth, adaptive shape update using old
committed layer masses and accepted layer integrals, normalize the resulting
shape onto the new authoritative WRT as finalize_wroot_node does, then publish
owner/shadow/depth/profile/receipt atomically. Reject a nonfinite/negative/empty
shape or invalid geometry before any crop publication. Never invent root mass.

Geometry, seeding fractions and adaptive/supply controls are explicit immutable
parameter data. The seed is the full materialized vector for the configured RDI
and geometry; configuration comparison binds that vector and every geometry and
control entry. No sampled-table equality, mutable application cache or second
crop/biomass authority. Clone/read-only snapshot/serialization-neutral view and
opaque joint continuation carry the optional profile and its configuration.

Optional per-layer potential/reduction integrals extend the existing accepted
window/trial/token/event/receipt chain. Dimensions, nonfinite values, negative
loss, total potential/actual consistency, missing/mixed intervals and exact
receipt identity must fail closed. Integrals enter the window only after the
actual F-KT water commit certificate. Rejected trials cannot contaminate them.
Hydrology reads only the committed adaptive profile through the existing uptake
input contract and unchanged Full Richards process. No synthetic water proof
may qualify this daily physical feedback. Drought/oxygen are the already
qualified uncompensated empirical process within its existing input domain.

Affected invariants:3/4/7/9/10/13/21/22/23/27/29/30. Shared surfaces allowed:
accepted-window lineage/aggregates, crop transaction and production weather
binding, plus a small explicit root-layer data/composition seam. Held fixed:
solver/numerical policy, water mass owners, WOFOST81 growth/N/fixation,
reference sources, existing tolerance/oracle/rollback assertions. Native weather
disk codec, advanced stress/compensation, SWRDC1 with SWRD1/3, constant LRV,
harvest/reset/fallow/rotation and generic input parsing remain separate.

## Selection before execution

First small real production layer-integral and adaptive/supply composition
drivers at O0/O2, with literal independent source oracles, measured providers,
compile/link/native costs, missing/invalid/overflow and nonmutation controls.
Then real crop/lineage transaction and physical daily current/lagged weather,
wet/dry/supply discrimination, node crossing, mass, potential independence,
reject/retry/duplicate, partial/pending/completed opaque continuation.

Select shared-state/restart preservation for concrete changed semantics after
these pass. Inspect compound runners before selection: unchanged RossFast,
hydraulics, irrigation, drainage and other independently qualified components
are NOT_SELECTED_IMPACT unless a changed contract or concrete uncovered failure
requires them. A changed import or new valid sink profile does not qualify as
that reason. No highest long low-air and no Actions dispatch. Full/expensive
admission selection remains pending the stable candidate and live owner policy;
do not reuse trajectory4 full PASS as execution of new profile/carrier source.

One workbranch/PR. Preserve raw failed/censored outcomes and exact source inputs.
No capability promotion until actual bounded admission supports it.
