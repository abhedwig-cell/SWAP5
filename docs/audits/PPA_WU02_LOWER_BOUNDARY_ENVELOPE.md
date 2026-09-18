# PPA-WU02 — Source-bound lower-boundary application envelope inventory

Date: 2026-09-18

Status: **SOURCE INVENTORY / SEMANTIC TRACE COMPLETE; PRESCRIBED-QBOT APPLICATION SLICE PREREGISTERED**

Canonical reconciliation basis: `integration/f-ci-canonical@12beef3e91f90f88b101c13af72cd216bccc63e3`.

## Authority boundary

The exact corrected SWAP 4.3.1 authority is B1.11:

- source members: 63;
- source bytes: 1,886,519;
- source manifest SHA-256: `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`;
- exact B0 distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- nested source archive SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The decisive lower-boundary members are source-identity pinned in the B1.11 replay evidence. `boundbottom.f90`, `headcalc.f90`, `calcgwl.f90`, `soilwater.f90`, `fluxes.f90`, `integral.f90` and `variables.f90` are byte-identical to B0. Their hashes are respectively:

- `boundbottom.f90`: `5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`;
- `headcalc.f90`: `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`;
- `calcgwl.f90`: `d7649f02bf6cd629cc7eceb1c761a6c38d6f0adf0d0c072c7aaab3af4562f5eb`;
- `soilwater.f90`: `027cfefc3ba7a010a256db1e43bd6e9c9facc4bf6edb4984578ddf1ef48acac8`;
- `fluxes.f90`: `b28b163520bc2ed873d98d4e0308d7b02a33577ee81b12a7f4bc1bc4cf746550`;
- `integral.f90`: `bd37ebe5014f14ab2ff961a336cfa284266102d510617feef1c00f6616c64174`;
- `variables.f90`: `327a064ca74f6c4bebc327a38de367824c7fe535baa1a8611879f9a6a479c856`.

B1.11 `readswap.f90` is `e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c`. Its only admitted B1 mutation is SWAP-013, a PDI HA/H0 validation insertion around the soil-physics parser. It does not touch the lower-boundary parser block. Consequently the B0 lower-boundary grammar is preserved in B1.11.

For readable source tracing, the official SWAP source repository was used only as a lineage cross-check for the unchanged legacy blocks. It is not substituted for the exact B1.11 identity above. Existing SWAP5 source-bound qualifications, especially F-SI27, independently reconstruct the exact pinned B1.10/B1.11 `headcalc.f90` hash and verify its lower-boundary arithmetic.

## Native sign, units and publication boundary

Legacy/native `qbot` is in cm d-1. Positive `qbot` enters the simulated soil profile through the lower boundary; negative `qbot` leaves it. F-SI27 and F-SI16 independently freeze this convention.

The public groundwater coupling convention is different: `q_swap` is positive outward from SWAP. The admitted conversion is

`q_swap_m_s = -qbot_cm_day * 0.01 / 86400`.

The accepted transaction carries whole-window bottom exchange. Trial `qbot` is not authoritative publication until the outer transaction accepts and commits. Rejected or rolled-back attempts must not enter committed transfer totals.

## Source-bound selector catalogue

### SWBOTB=1 — prescribed groundwater level

Parser authority: a dated `GWLEVEL` table. Runtime authority interpolates `gwlinp` at the current time. This is not merely a prescribed lower pressure head.

When the prescribed water table lies inside the modeled profile, HeadCalc changes the effective saturated-domain treatment, derives the lower flux by the profile balance and reconstructs saturated-zone heads. When the water table lies below the profile, it maps the groundwater level to a lower-face pressure head and follows the head-boundary branch. The state includes `gwlinp`, `gwl`, `fllowgwl`, hydraulic state and the moving saturated-domain location.

**SWAP5:** legacy physics is preserved in the B1.10 compatibility port, but there is no admitted typed production contract for this hybrid water-table boundary. Groundwater Coupling v1 is not equivalent: it supplies an explicit coupling-plane head to the admitted mode-5 route and has separate datum, ledger and publication semantics.

Classification: **PRESERVED_BUT_NOT_TYPED / NOT_NORMAL_APPLICATION_MIGRATED**.

### SWBOTB=2 — prescribed regional/native bottom flux

Two legacy forcing forms exist:

1. `SW2=1`: annual cosine forcing using `SINAVE`, `SINAMP`, `SINMAX`;
2. `SW2=2`: dated `QBOT2` table.

At each interval the forcing resolves to native `qbot`. In the Richards residual, the lower equation receives `-qbot`; bottom head is not an active control. A special continuation exists: if the bottom node becomes oven-dry (`h < -1e7 cm`), legacy state switches internally to `SWBOTB=-2` and free drainage.

**SWAP5:** the physics and typed boundary contract are production-admitted. F-SI27 qualifies explicit `bottom_mode=2` / `bottom_flux`; F-SI38 adds the temporal-certificate operator; F-MR44R qualifies the serialized runtime; F-VQ75 independently qualifies it; F-CI62/F-CI62P canonically admit and reconcile the production postimage. Current PPA-WU01 nevertheless admits only normal bootstrap modes 5 and 7, so nonzero prescribed qbot is not yet reachable through the generic production application bootstrap.

Classification before the WU02 application slice: **PHYSICS_AND_RUNTIME_CANONICAL / NORMAL_APPLICATION_ADAPTER_MISSING**.

The legacy sine/table forcing generator and its oven-dry `-2` transition remain a separate future adapter slice. WU02 does not silently equate an already-resolved typed qbot with the complete legacy SWBOTB=2 parser semantics.

### SWBOTB=3 — regional deep-aquifer Cauchy relation

Inputs include `SHAPE`, `HDRAIN`, `RIMLAY`, `SWBOTB3IMPL`, `SWBOTB3RESVERT`, a sinusoidal or tabulated deep-aquifer head, and optionally an additive dated bottom flux.

The explicit route computes a groundwater-level-dependent profile resistance and `qbot=(deepgw-gwlmean)/(rimlay+cvalprof)`. The implicit route instead embeds the Cauchy relation directly in the terminal residual and Jacobian, optionally including the lower half-cell hydraulic resistance. This is a state-dependent Robin/Cauchy boundary, not a fixed qbot and not an external groundwater predictor/corrector contract.

**SWAP5:** preserved legacy implementation exists, but no typed production contract or application route for the full relation is admitted.

Classification: **PRESERVED_BUT_NOT_TYPED / NOT_MIGRATED**.

### SWBOTB=4 — q(gwl) lower-boundary relation

Two forms exist:

1. exponential `qbot = COFQHA * exp(COFQHB*abs(gwl))`, with optional `COFQHC`;
2. tabulated q versus `abs(gwl)`.

The flux is therefore computed from evolving groundwater-level state. It is not equivalent to a caller-prescribed qbot at interval entry.

**SWAP5:** no typed production relation owner or normal application adapter is admitted.

Classification: **PRESERVED_BUT_NOT_TYPED / NOT_MIGRATED**.

### SWBOTB=5 — prescribed lower-face pressure head

Parser authority is a dated `HBOT5` pressure-head table in cm. The runtime interpolates `hbot`, evaluates lower-face conductivity at that prescribed head and applies the Dirichlet lower-face gradient. The solver produces authoritative qbot as an output.

**SWAP5:** F-SI16 qualifies the exact prescribed-head boundary, F-MR11 and F-VQ26 qualify the restricted serialized mode-5 runtime, and the later F-GC line canonically composes mode 5 into groundwater coupling. PPA-WU01 admits an all-mode-5 groundwater application-owner profile. It does not admit an ordinary standalone mode-5 bootstrap, and no legacy HBOT5 date-table application adapter is claimed.

Classification: **RESTRICTED_PRODUCTION via groundwater application profile; legacy date-table adapter not migrated**.

### SWBOTB=6 — zero bottom flux

Exact legacy meaning: `qbot = +0.0 cm d-1`.

**SWAP5:** F-APP02/F-VQ102/F-CI95 canonically bind selector 6 to typed `bottom_mode=2`, `bottom_flux=+0.0`. M1-C3 additionally exercises this exact mapping through the bounded legacy-file Hupsel typed adapter.

Classification: **RESTRICTED_PRODUCTION / CANONICAL LEGACY-TO-TYPED BINDING**.

### SWBOTB=7 — free drainage

Exact legacy meaning: `qbot = -K_bottom`, with terminal conductivity evaluated from current lower-node hydraulic state. The lower Jacobian includes the corresponding conductivity derivative contribution. This is not fixed zero flux.

**SWAP5:** F-SI13 admits explicit free-drainage modes 7 and internal -2. The serialized Reference runtime and PPA-WU01 canonically admit bottom_mode=7 as the standalone normal typed production bootstrap profile.

Classification: **RESTRICTED_PRODUCTION / NORMAL TYPED APPLICATION REACHABLE**.

### SWBOTB=8 — lysimeter / suction-plate free outflow

Parser input is optional `HPLATE`, default 0 cm. HeadCalc uses a switching condition: while the terminal state does not permit outflow, qbot is zero; once the threshold is exceeded it activates a prescribed-head branch to `hplate`. The branch state (`flboth`) participates in the iterative lower-boundary treatment and Jacobian.

This is not semantically the same as SWBOTB=6 and cannot be admitted by mapping it to constant qbot=0.

**SWAP5:** legacy physics is preserved but no typed switching-boundary contract, transactional continuation state or normal application adapter is admitted.

Classification: **PRESERVED_BUT_NOT_TYPED / NOT_MIGRATED**.

## Non-selectable lower-boundary states

`SWBOTB=-2` is an internal free-drainage fallback used by legacy SWBOTB=2 after the oven-dry guard. F-SI13 admits typed -2 free-drainage physics, but -2 is not an input selector because `readswap` accepts only 1..8.

`SWBOTB=9` appears in historical HeadCalc internals, but the B1.11 application parser admits only 1..8. It is therefore **INTENTIONALLY_EXCLUDED_FROM_THE_LEGACY_APPLICATION_SELECTOR_CATALOGUE**, not an unresolved normal application mode.

## Transactional implications

Modes 2, 5 and 7 already live on admitted transactional paths in bounded SWAP5 profiles. Mode 6 inherits mode-2 transaction semantics through the exact qbot=0 binding.

Modes 1, 3, 4 and 8 require more than selector translation. Their semantics depend on evolving hydraulic state or switching continuation. Any future migration must make candidate/accepted state ownership explicit and must not mutate committed application state before acceptance.

The groundwater coupling ledger is a separate interface owner. It must not be reused as an implementation shortcut for legacy SWBOTB=1, 3 or 4 unless a future source-bound scientific mapping explicitly establishes equivalence.

## Dependency-aware migration slices

1. **PPA-WU02A: normal typed prescribed-qbot application profile.** Admit all-bottom_mode=2 in the existing production bootstrap, using already-resolved typed qbot forcing and the already-canonical F-CI62 postimage. No legacy sine/table parser, no new physics, no new state.
2. **SWBOTB=2 legacy forcing adapter.** Later bind the annual cosine and date-table forcing to interval-local typed qbot and explicitly preserve the oven-dry -2 transition. This needs a forcing/state-owner decision and is not folded into WU02A.
3. **SWBOTB=5 ordinary prescribed-head application adapter.** Separate the already-qualified mode-5 physics from the currently groundwater-owned PPA profile and qualify an ordinary typed/date-driven application owner without changing F-GC semantics.
4. **SWBOTB=1 hybrid groundwater-level boundary.** Requires an explicit typed hybrid-domain/state contract; do not alias to F-GC head coupling.
5. **SWBOTB=3 Cauchy boundary.** Migrate explicit and implicit variants only after freezing state, resistance and Jacobian contracts.
6. **SWBOTB=4 state-dependent q(gwl).** Requires an explicit committed hydraulic-view dependency and rollback-safe evaluation.
7. **SWBOTB=8 lysimeter switching boundary.** Requires explicit switching continuation state and transactional rollback/restart semantics.

## WU02A admission decision

WU02A is directly implementable under existing authority. The science is already fixed and canonically admitted at the solver/runtime layer. The missing capability is only normal application reachability from the existing Fortran/FMR production owner.

The bounded implementation may therefore widen the production bootstrap from the existing homogeneous mode-7 standalone profile to also accept a homogeneous mode-2 standalone profile. It must not widen mixed-mode ownership, parser semantics, groundwater ownership, process families, tolerances or solver policy.
