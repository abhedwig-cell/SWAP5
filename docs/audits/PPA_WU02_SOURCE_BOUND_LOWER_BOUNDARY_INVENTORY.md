# PPA-WU02 Source-bound lower-boundary application envelope inventory

## Status

**SOURCE INVENTORY AND SEMANTIC TRACE COMPLETE; TWO BOUNDED LOW-SCIENCE-RISK ADMISSIONS PREREGISTERED**

Canonical reconciliation base: `integration/f-ci-canonical@12beef3e91f90f88b101c13af72cd216bccc63e3`.

This workunit separates four questions that were previously easy to conflate:

1. does SWAP 4.3.1 B1.11 define the physics?
2. does SWAP5 have a typed boundary contract and executable physics for it?
3. can a normal production application owner reach it?
4. is it part of the separate groundwater-coupling contract?

A generic `bottom_flux` or `bottom_head` field is not evidence for all four.

## Exact reference authority

The controlling corrected-reference snapshot is B1.11:

- source members: 63;
- source bytes: 1,886,519;
- source manifest SHA-256: `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`;
- `SWAP/boundbottom.f90`: SHA-256 `5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`;
- `SWAP/readswap.f90`: SHA-256 `e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c`;
- `SWAP/headcalc.f90`: SHA-256 `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

No B1 correction targets `boundbottom.f90`. SWAP-013 is the only B1 correction targeting `readswap.f90`, and its exact patch changes only PDI hydraulic-parameter validation around the soil-parameter block. It does not touch the lower-boundary parser block. SWAP-011 leaves `headcalc.f90` byte-identical. The lower-boundary catalogue can therefore be source-bound to the frozen B1.11 identities without inheriting later SWAP development semantics.

The public SWAP source lineage was used only as corroboration of the unchanged lower-boundary block. Its current files are not byte-identical to B1.11 and are not substituted for the frozen reference.

## Conventions

The legacy native hydraulic bottom flux `qbot` is in cm/day. Positive `qbot` is inflow through the lower boundary into the SWAP soil column. Downward free drainage is therefore negative and is represented by `qbot=-K_bottom`.

This is not the public groundwater-coupling sign. The admitted coupling contract uses outward-from-SWAP `q_swap` in m/s and translates explicitly:

`q_swap = -qbot * 0.01 / 86400`.

Legacy `hbot` is pressure head in cm at the lower face. Groundwater Coupling v1 exposes hydraulic head in metres and requires a datum. A legacy pressure-head boundary must not be relabelled as a groundwater hydraulic-head contract.

## Selector matrix

| Legacy selector | Exact B1.11 meaning | Inputs and time dependence | Solver/state semantics | SWAP5 mapping before WU02 admission | Classification before WU02 admission | Migration disposition |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | prescribed groundwater level | time table `date1/gwlevel` -> `gwltab` | `gwlinp` is interpolated each step. If groundwater lies inside the profile, the saturated part and `qbot` are reconstructed inside HeadCalc. If below the profile, a lower-face pressure head is derived. | legacy HeadCalc semantics preserved; no admitted typed mode-1 application route | **F_NOT_MIGRATED** | dedicated groundwater-level boundary contract. Do not alias to F-GC mode 5. |
| 2 | prescribed regional bottom flux | `sw2=1`: annual cosine using `sinave/sinamp/sinmax`; `sw2=2`: time table `date2/qbot2` | ordinary Neumann `qbot`. If bottom `h < -1e7`, legacy mutates the selector to internal `-2` and uses free drainage `qbot=-K_bottom`. | typed bottom_mode=2 physics is canonical through F-CI62/F-CI62P. No normal PPA-WU01 bootstrap route before WU02. No legacy SWBOTB=2 forcing adapter. | **C_CORE_ADMITTED_APPLICATION_GAP** | WU02-A admits explicit typed nonzero qbot only. Legacy sine/table ingestion and oven-dry transition remain separate. |
| 3 | Cauchy exchange with deep aquifer | `shape,hdrain,rimlay,SwBotb3ResVert,sw3`; aquifer head sinusoid or table; optional `sw4` extra q table | `qbot=(deepgw-gwlmean)/(rimlay+cvalprof)` for explicit route. `swbotb3Impl=1` makes lower exchange head-dependent inside residual/Jacobian. | no typed production contract for this Cauchy family | **F_NOT_MIGRATED** | scientific/transaction migration slice. Must separate accepted groundwater state from candidate head dependence. |
| 4 | empirical/table flux as function of groundwater level | `swqhbot=1`: `cofqha*exp(cofqhb*abs(gwl))` plus optional `cofqhc`; `swqhbot=2`: q(h) table | state-dependent flux forcing from current groundwater state | no typed state-aware q(h) lower-boundary provider | **F_NOT_MIGRATED** | outer state-aware boundary provider, then mode-2 solver composition. Needs candidate/retry authority. |
| 5 | prescribed pressure head at lower face | time table `date5/hbot5` | Dirichlet/Darcy lower face. Face conductivity is evaluated at prescribed `hbot`; Jacobian carries face stiffness. | typed bottom_mode=5 exists and is production-admitted only in restricted groundwater participant/application composition. PPA-WU01 standalone mode-5 trajectory was not admitted. | **C_RESTRICTED_GROUNDWATER_ONLY / LEGACY_APP_GAP** | separate standalone prescribed-head application qualification. Do not infer equivalence from F-GC coupling. |
| 6 | zero lower flux | no additional lower-boundary data | exact `qbot=+0.0`; ordinary Neumann flux | F-APP02/F-VQ102/F-CI95 maps 6 -> typed mode 2, exact +0.0. M1-C3 uses it in the restricted legacy-file typed route. | **C_RESTRICTED_PRODUCTION** | closed. Preserve exactly. |
| 7 | free drainage | no additional lower-boundary data | `qbot=-K_bottom`; Jacobian includes the conductivity derivative contribution | typed bottom_mode=7 is admitted and is the PPA-WU01 standalone profile. No explicit legacy selector-7 binding yet. | **C_TYPED_PRODUCTION / SELECTOR_ADAPTER_GAP** | WU02-B is a direct low-science-risk selector binding. |
| 8 | lysimeter/free-outflow plate boundary | optional `hplate`, default 0 cm | BoundBottom starts with zero q. During HeadCalc the solve switches to a pressure-head plate when the bottom-node state exceeds the plate threshold; otherwise q remains zero. `flboth` is solve-local continuation. | no typed hybrid plate-switching boundary | **F_NOT_MIGRATED** | dedicated state-dependent hybrid boundary contract with retry/rollback qualification. |

### Internal `swbotb=-2`

`-2` is not accepted by the legacy input parser. It is an internal continuation state reached only from selector 2 under the oven-dry guard. Its physical equation is free drainage `qbot=-K_bottom`. The serialized Reference backend can execute typed `bottom_mode=-2`, but SWAP5 has no admitted application contract for the legacy selector mutation itself. It is therefore **preserved typed physics, not a normal application selector**.

### Selector 9

The SWAP5 legacy HeadCalc port contains an internal mode-9 branch used by later development/adaptation work, but the B1.11 legacy parser admits only selectors 1 through 8. Mode 9 is intentionally excluded from the B1.11 application catalogue.

## Semantic trace by concern

### Parser versus kernel ownership

The legacy parser owns dates, tables and selector-specific coefficients. These are application semantics. PPA-WU02 does not put `date1`, `qbotab`, `hbotab`, file units or parser ordering into the typed solver contract.

The typed solver boundary remains numerical/physical: mode plus resolved flux/head. Time interpolation belongs outside that contract.

### Groundwater semantics

Selectors 1, 3 and 4 refer to groundwater state, but they are not automatically Groundwater Coupling v1. F-GC has its own hydraulic-head datum, outward flux convention, whole-window interface ledger and predictor/corrector publication rules. Legacy groundwater-level, Cauchy and q(gwl) semantics require separate source-bound mappings.

Selector 5 is also not automatically an F-GC application. The physical Dirichlet face is shared, but the application ownership differs: a legacy prescribed pressure-head table is not a coupled groundwater service.

### Transaction semantics

Legacy code mutates global state directly. SWAP5 cannot carry those mutations literally across rejected trials.

The two modes with the largest continuation risk are:

- selector 2: the oven-dry switch from 2 to internal -2 must be candidate-safe and cannot leak from a rejected attempt;
- selector 8: the `flboth` plate/zero-flux switch is solve-local state and must replay identically after rollback/retry.

Selectors 3 and 4 also depend on groundwater state and therefore need explicit accepted/candidate ownership before migration.

### Mass balance and publication

For any admitted mode, only accepted lower-boundary exchange may enter canonical mass accounting. A candidate flux or candidate coupled exchange is not accepted history. Existing FMR and F-GC ledgers remain the owners; PPA-WU02 introduces no second ledger.

## Current SWAP5 lower-boundary capability layers

### Physics capability

The serialized Reference backend currently admits typed bottom modes `2`, `5`, `7` and internal `-2` in its bounded profile.

### Typed boundary contract

The solver contract exposes `bottom_mode`, `bottom_flux` and `bottom_head`. Those fields are necessary but not sufficient evidence of application admission.

### Normal production application owner

Before WU02, PPA-WU01 admits only homogeneous all-mode-7 standalone applications and homogeneous all-mode-5 groundwater-owner applications. Mode 2 is deliberately absent from its profile validator despite already-admitted core physics.

### Legacy application adapter

The unique legacy selector binding owner currently maps only SWBOTB=6 to typed mode 2, qbot=+0.0. Other selectors fail closed.

## Dependency-aware migration slices

1. **PPA-WU02-A, explicit typed nonzero prescribed qbot application admission.** No physics change. Extend the existing PPA-WU01 production owner so a homogeneous all-mode-2 profile can run standalone. Preserve all-mode-5 and all-mode-7 behavior and reject mixed lower-boundary profiles.
2. **PPA-WU02-B, SWBOTB=7 selector binding.** Extend the existing unique legacy lower-boundary binding owner with exactly 7 -> typed mode 7. Preserve selector 6 bit-exactly and keep every other selector fail-closed.
3. **SWBOTB=5 standalone prescribed-head application.** Requires a dedicated successful standalone transactional qualification first. Existing groundwater admission is not enough.
4. **SWBOTB=2 legacy forcing composition.** Add sine/table time-source adapter only after the mode-2 application owner is admitted. Treat the oven-dry 2 -> -2 transition as separate transactional continuation.
5. **SWBOTB=4 q(gwl).** Introduce a candidate-safe state-aware forcing provider, not a parser-aware kernel contract.
6. **SWBOTB=1 groundwater-level boundary.** Reconstruct the saturated-zone semantics as its own boundary family. Do not collapse it into a fixed bottom head.
7. **SWBOTB=3 Cauchy/deep-aquifer.** Separate explicit and implicit variants and qualify the Jacobian/state dependencies.
8. **SWBOTB=8 lysimeter.** Preserve plate-switch state and rollback/retry behavior explicitly.

## WU02-A admission basis

The old audit statement that nonzero prescribed qbot is only qualification-only is obsolete on the live canonical line.

F-CI62/F-CI62P canonically admitted the F-SI38 plus F-MR44R production postimage. F-VQ75 independently qualified positive prescribed qbot, hard mass closure, O0/O2 identity and fail-closed nearby modes. Therefore WU02-A changes only normal application reachability.

The bounded target is explicit typed forcing. It does not claim legacy `SWBOTB=2` grammar or time-series ownership.

## WU02-B admission basis

B1.11 defines selector 7 as free drainage `qbot=-K_bottom`. The current serialized runtime and PPA-WU01 already admit the corresponding typed mode 7. The missing layer is only the explicit legacy selector image. No new physics or application owner is required.

## Nonclaims

PPA-WU02 does not claim complete SWBOTB migration, legacy-file grammar completion, new groundwater architecture, a new solver, a new predictor/corrector method, new tolerances, or ROM functionality.
