# F-ROM-LARE RS1 state-sufficiency reconciliation

## Status

**RESEARCH BRANCH — STATE FIRST, CLOSURE SECOND**

Branch: `work/f-rom-lare-rs1`

Canonical start authority:

`integration/f-ci-canonical@9bb73821bb78a04c759b763746b50a3f777cd416`

No production physics, solver, timestep, retry, tolerance, or coupling semantics are changed by this work.

## Why this work exists

A reduced hydrological model is not subject to the same equivalence claim as an alternative numerical solver.

An alternative numerical solver such as RossFast targets essentially the same Richards solution and is therefore judged under strict numerical and hydrological equivalence.

A deliberately reduced model may instead be useful when it preserves the hydrological information required for a declared application while accepting bounded departures elsewhere.

The RS1 question is therefore:

> Which conservative vertical state information must be retained for each declared hydrological purpose before any LARE propagation closure is introduced?

This is intentionally a state-sufficiency study before a LARE solver study.

## Retrospective pilot screen

Two already-qualified historical ROM state libraries were recovered from their exact GitHub Actions artifacts:

- B01, 768 accepted states, 16 cells of 10 cm;
- B14, 768 accepted states, 16 cells of 10 cm.

For every contiguous fixed partition of the 16-cell column, the reduced coordinate is the vector of mean water contents in the partition layers. With fixed layer thickness this is information-equivalent to the conservative layer-storage state

`W_i = integral(theta dz)`.

A collision is retained only when the full theta profile is distinguishable above the material-specific frozen Reference floor while the candidate partition is not.

The exhaustive replay is implemented in:

- `tests/rom/analyze_lare_rs1_partition_ladder.py`
- `tests/rom/validate_lare_rs1_partition_screen.py`
- `.github/workflows/f-rom-lare-rs1-partition-screen.yml`

The persisted summary is:

- `integration/f-rom/LARE_RS1_PARTITION_SCREEN_RESULT.json`

Workflow run `35443794334` reproduced the screen from the historical artifacts and passed.

## Pilot result

For B01, the minimum zero-collision partition has three layers:

`0-140 | 140-150 | 150-160 cm`

For B14 no three-layer partition is zero-collision. Exactly two four-layer partitions are zero-collision:

- `0-10 | 10-130 | 130-150 | 150-160 cm`
- `0-10 | 10-140 | 140-150 | 150-160 cm`

Only the second is also zero-collision for B01.

Therefore the minimum cross-material pilot partition is:

`0-10 | 10-140 | 140-150 | 150-160 cm`

This is a four-dimensional storage state.

The result must not be interpreted as evidence that four layers are sufficient for SWAP or for LARE dynamics. The minimum separation margins are small, and a 1% relaxation of the candidate-distance threshold already creates near-collisions in both materials.

The pilot libraries are also short, near-equilibrium hydraulic perturbation libraries. They do not contain seasonal drying, crop extraction, large wetting fronts, long capillary support, or realistic groundwater excursions.

## Physical interpretation

The pilot result supports an **active-zone resolution hypothesis**, not a universal bottom-refinement rule.

B01 state distinguishability is concentrated near the lower part of its 160 cm pilot column.

B14 additionally requires information from the uppermost 10 cm.

That pattern is physically plausible because top forcing and lower-boundary forcing create different channels of dynamically relevant vertical structure.

However, the location of the active zone is application dependent.

### Hupsel is a counterexample to blind bottom refinement

The authoritative Hupsel case has:

- a 200 cm soil profile;
- B2 material from 0-30 cm;
- O2 material from 30-200 cm;
- subsurface drains at 80 cm;
- initial hydrostatic equilibrium at approximately 75 cm groundwater depth;
- an impermeable lower layer represented by a zero-flux bottom boundary;
- realistic forcing from 2002 through 2004.

Therefore the physical lower boundary at 200 cm is not the main groundwater-exchange outlet in Hupsel. Drainage and the moving phreatic zone around the drain system are hydrologically active.

The B01/B14 pilot result cannot be transferred by simply refining 180-200 cm in Hupsel.

## Frozen Hupsel candidate family

Before exposing a new daily Hupsel profile library, the following LARE-eligible fixed grids are frozen in:

`integration/f-rom/LARE_RS1_HUPSEL_CANDIDATES.json`

- H4: `0, 10, 30, 80, 200 cm`
- H6: `0, 10, 30, 60, 80, 100, 200 cm`
- H8: `0, 10, 20, 30, 60, 80, 100, 150, 200 cm`
- H10: `0, 5, 10, 20, 30, 50, 70, 80, 100, 150, 200 cm`

The 30 cm soil-material boundary is always preserved. The 80 cm drainage depth is explicit. Additional resolution is concentrated at the surface and around the drainage/freatic active zone.

Equal-depth U4 and U8 partitions are retained as information-only controls; they cross the material boundary and are not eligible for the first LARE dynamics comparison.

## Observation-only Hupsel profile route

The SWAP `outvap` output route already writes, per compartment:

- water content;
- pressure head;
- hydraulic conductivity;
- drainage;
- root extraction;
- vertical water flux;
- compartment top and bottom.

The historical Hupsel input also already enables `SWVAP=1`, but its normal output schedule is monthly.

RS1 therefore changes output scheduling only:

- `SWMONTH=0`;
- `PERIOD=1`;
- `SWRES=0`;
- `SWODAT=0`;
- retain `SWVAP=1`;
- retain the already-qualified GNU execution adjustment `SWCSV=0`.

The preparation tool is:

`tests/rom/prepare_lare_rs1_hupsel_daily_output.py`

Its post-run hard identity gate remains the exact M1-C3 whole-Hupsel scientific result:

- normalized `result.bal` SHA-256 `a9cc9b18a404726dfbce22d8372df279b9d3bdf1bc76c8c38f33c8080430d0e7`;
- normalized `result.blc` SHA-256 `1bd2631d91cb21e72a5949f54524d0cb55ed0bb059a88fc4a4def8507693b77c`.

If either changes, the observation run is rejected.

The conservative VAP projector is:

`tests/rom/build_lare_rs1_hupsel_profile_library.py`

For each candidate fixed layer it computes exact overlap-weighted storage from the full-order compartments and requires

`sum_i W_i = W_full`

within `1e-10 cm`.

No profile reconstruction is used in RS1.

## Purpose-dependent acceptance

Numerical non-injectivity is no longer by itself a reduced-model failure.

For a candidate projection `P`, if

`P(x_a) ~= P(x_b)`

but the full states differ, the pair is frozen and receives identical future forcing.

The reduced state fails only if a declared purpose output differs beyond its independently preregistered hydrological envelope.

Relevant purpose outputs include:

### Groundwater / recharge

- cumulative bottom exchange;
- instantaneous bottom flux;
- flux sign;
- drainage/capillary reversal timing;
- groundwater level where prognostic;
- long-horizon bias.

### Crop / ET

- root-zone storage;
- actual transpiration;
- soil evaporation;
- drought-stress duration and onset;
- cumulative ET.

### Event response

- infiltration and drainage timing;
- fast storage redistribution;
- extreme wet and dry states;
- regime-transition timing.

Mass conservation remains a hard structural requirement, not an application-dependent tolerance.

## Relation to the old B14 no-go

The old frozen B14 coordinate `Z8+G8` had 351 formal state collisions and therefore correctly failed the old material-transfer state-separation gate.

However, the separately frozen future-probe subset produced no formal predictive storage ambiguity and only numerical-scale exchange differences.

That does not prove the 351 collisions are harmless. It does prove that full-state non-injectivity and application-relevant predictive ambiguity are different questions.

RS1 is designed to test the latter directly.

## Next gates

1. Close the observation-tool qualification.
2. Generate the exact daily Hupsel profile library without changing the qualified Hupsel scientific result.
3. Screen the frozen H4/H6/H8/H10 candidates and equal-depth controls on state collisions.
4. Freeze collision pairs before inspecting future response.
5. Adjudicate them under crop/application purpose envelopes.
6. Independently build the longer RS1-GW reversal library because Hupsel has a zero-flux physical bottom boundary and is not a bottom-recharge authority.
7. Only after a state representation survives its declared purpose gate compare published LARE, equilibrium-subtracted LARE, and coarse Richards on the same fixed partition.

No LARE propagation dynamics are authorized by this checkpoint.
