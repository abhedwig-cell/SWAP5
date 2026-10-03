# F-MIG431-INT12-C preregistration

Date: 2026-10-03

Status: PREREGISTERED, implementation not started
Branch: `work/f-mig431-int12-c-vonhhbraden`
Pinned canonical base: `b0d2cc0ac749e1fa60ba4f5f610d01fc0b3b6ad9`

## Goal

Migrate the bounded SWAP 4.3.1 `SWINTER=1` Von Hoyningen-Hune/Braden interception capability into the current SWAP5 transaction/application route, consuming the already admitted F-MIG431-INT12-P0 source-window runtime seam.

This is PPA-WU04-C. It does not implement SWINTER=2/Gash; that method has a separate nonlinear equation oracle and belongs to PPA-WU04-D / F-MIG431-INT12-D. Do not create a second WU06 record for the same capability.

## Current evidence and gap

The current canonical head is `b0d2cc0ac749e1fa60ba4f5f610d01fc0b3b6ad9`. The current tree contains:

- the frozen PPA-WU04 state/transaction contract and review-only closeout;
- PPA-WU04-A and PPA-WU04-B implementations for SWREDU, not SWINTER=1/2;
- the admitted `mod_interception_source_window_runtime` P0 seam and its qualification;
- no general SWINTER=1 source-window provider/application route that combines full B1.11 inputs, P0 accepted progress/restart, and a bound net-rain receiver.

A restricted SWINTER=1 process already exists in F-APP03: Hupsel with SWETR=0, SWDIVIDE=1, SWMETDETAIL=0, SWRAIN=0 and SWCF=1. Its exact-source qualification covered 384 daily and 14,062 interval records with zero mismatches. The provider is `src/process/mod_pmdirect_swetr0_process.f90`; it is bounded and must be preserved. F-APP04 qualified its root and surface-demand bindings, but its status explicitly records PMdirect `net_rain_cm_per_day` as NOT_BOUND because no exact receiving contract was established. This slice must first determine whether the existing SWINTER=1 calculation and its typed outputs can be reused for the broader PPA-WU04 contract, and how accepted net rain enters the admitted top-boundary path. Do not duplicate the Hupsel formula or claim a general route before that reconciliation.

PPA-WU04 explicitly records general SWINTER=1/2 implementation as not admitted. F-MIG431-INT12-P0 proves why the shared seam is necessary and is already canonically admitted at merge `4d7be05313336e437461f05642affe80bb9bb129`. P0 supplies source-window identity, deterministic aggregate apportionment, accepted progress, rollback and mid-window restart metadata. It contains no method-specific interception equations and must not be changed by this slice.

## Source and equation authority

- Corrected reference snapshot: `reference/swap-4.3.1/snapshots/B1.11.yml`.
- PPA-WU04 contract: `integration/audits/PPA_WU04_STATEFUL_ET_INTERCEPTION_CONTRACT.json`.
- B1.11 source member: `SWAP/MOD_meteo.f90`, SHA-256 `99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`.
- F-PM06 source/call-order trace: `integration/f-pm/F-PM06_ET_MIGRATION_READINESS.md`.
- Independent public source trace: `SWAP-model/SWAP@07d74a82e9ba0465ec81a74e4d82b3dc03d856d9`, `src/atmosphere/interception.f90` and `src/atmosphere/meteoday.f90`.

The independent source trace is corroborating evidence, not a replacement for the B1.11 authority. Before qualification, bind every frozen equation and output convention to the B1.11 member identity and build an independent equation oracle. Preserve legacy units, branch conditions, parameter/time-table semantics, irrigation selection and call order. If this source binding cannot be demonstrated, stop at the source-authority blocker and do not claim qualification.

The source trace identifies the VonHHBraden aggregate relation as follows, subject to exact B1.11 confirmation. The restricted F-APP03 route is an already qualified special case; compare its parameterization and output semantics against this full relation before deciding whether to reuse or generalize it:

- `rpd = 10*grai` when sprinkler irrigation is excluded, otherwise `rpd = 10*(grai+gird)`;
- `cofbb = min(1, 1-exp(-kdif*kdir*lai))`;
- for `cofab > 1e-6`, `aintc = 0.1*cofab*lai*(1 - 1/(1 + rpd*cofbb/(cofab*lai)))`; otherwise `aintc=0`.

The full daily/source-window orchestration also includes the legacy inactive-canopy/zero-input/snow guards, rain-irrigation partitioning, wet-canopy fraction, and demand blending. These are in scope only to the extent needed to reproduce the bounded qualified application route. Do not infer omitted branches from the formula above.

## Frozen ownership and interfaces

- Persistent physical canopy-water state for SWINTER=1: none.
- `aintc`: accepted aggregate for one explicit forcing/source window, never hidden hydraulic or canopy storage.
- P0 owns source-window progress/restart provenance. Do not duplicate this state in the interception process.
- Crop/canopy and interception parameters are read-only inputs for a source window.
- A rejected trial cannot mutate accepted aggregate progress or book interception mass.
- A changed-`dt` retry uses the same frozen source-window aggregate and committed progress.
- Existing accepted top-boundary/application mass owners remain authoritative. Gross and net precipitation cannot both be counted as independent water inputs.
- Keep SWINTER=3 Rutter, SWINTER=2 Gash, meteorological file/calendar parsing, snow-state ownership, solver/timestep policy and groundwater coupling outside this slice.

Before implementation, record the exact typed input/output and transaction binding against the admitted PPA-WU03/PPA-WU01 interfaces. Fail closed for unqualified combinations.

## Qualification gates

Persist exact scope-specific tests and a reproducible runner. Required gates:

1. Exact B1.11 SWINTER=1 aggregate/result oracle, including zero interception, low/no canopy, irrigation selection, and the threshold branch around `cofab=1e-6`.
2. Source-window partition conservation, including unequal subspans and final bitwise aggregate closure.
3. Rejected-trial progress immutability and failed-then-accepted retry equivalence from the same committed checkpoint.
4. Mid-window restart with neither duplicated nor lost remaining aggregate.
5. Exact call-order and output checks for net rain/irrigation, `wfrac`, and wet/dry transpiration demand where those outputs are part of the admitted route.
6. A/B/A replay determinism, invalid-input fail-closed behavior, and O0/O2 output identity.
7. Hard accepted water-mass closure and exactly-once accepted interception accounting.
8. Preservation of PPA-WU01, PPA-WU03, PPA-WU04-A/B, P0 source-window runtime, and SWINTER=3 Rutter.
9. Preservation of the admitted F-APP03 Hupsel vectors and F-APP04 root/surface bindings.
10. No production or test changes beyond the preregistered ownership surface.

Set numerical tolerances per quantity before running qualification. Bookkeeping identities must close tightly; trajectory comparisons must reflect the stated reference/compiler route. Do not relax a threshold to turn a failure green.

## Allowed production delta

Only after exact source binding, reconciliation of the restricted F-APP03 implementation, and a frozen receiving interface review:

- the smallest typed extension or adapter that reuses the restricted F-APP03 provider where its semantics match, or a separate general provider only where the B1.11 comparison demonstrates a real gap;
- narrow forcing/application binding for the qualified route;
- transaction/restart composition needed to consume the existing P0 progress record;
- independent equation, runtime, preservation tests, runner, workflow and persisted evidence.

No P0 seam changes are permitted. Any newly discovered shared-interface requirement must be separately preregistered and admitted before changing shared runtime contracts.

## Admission boundary

Admission may claim only the qualified SWINTER=1 profile. It does not admit SWINTER=2, broad legacy meteorological IO/calendar grammar, arbitrary snowfall/runon combinations, or unrestricted application composition. PPA-WU04-D / F-MIG431-INT12-D remains a separate follow-on slice.

