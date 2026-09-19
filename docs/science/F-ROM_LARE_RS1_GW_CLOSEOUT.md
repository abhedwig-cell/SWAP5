# F-ROM-LARE RS1 groundwater state-information closeout

## Decision

**PROCEED_TO_LARE_CLOSURE_QUALIFICATION_B01_GW_LAB**

This decision authorizes a bounded reduced-dynamics/closure research experiment.

It does **not** authorize:

- a production ROM;
- replacement of Richards;
- application-level acceptance for groundwater coupling;
- transfer to B14, stratified profiles or Hupsel;
- a universal three-layer LARE grid.

The closeout applies only to the qualified B01 pure-hydraulics groundwater laboratory.

## Authority chain

Canonical start:

`integration/f-ci-canonical@9bb73821bb78a04c759b763746b50a3f777cd416`

Research branch:

`work/f-rom-lare-rs1`

Qualified Stage-A Reference library:

- workflow run `35444243790`;
- artifact `10585316225`;
- 6144 accepted Reference states;
- 98304 node records;
- O0/O2 stdout bit identity;
- maximum absolute step mass residual `4.263256414560601e-14 cm`;
- current Reference reproduction of the historically decisive H02 second bottom-flux reversal at step 57.

Formal response-blind P1:

- exact-fast workflow run `35445455039`;
- independent exact KD-tree cross-check run `35445244523`;
- persisted result `integration/f-rom/LARE_RS1_GW_P1_RESULT.json`;
- selected partitions and all collision-count vectors reconciled exactly between independent implementations.

Formal purpose-dependent P2:

- purpose-split workflow run `35445922440`;
- persisted result `integration/f-rom/LARE_RS1_GW_P2_RESULT.json`;
- GW-D and GW-R evaluated separately;
- absolute `ACCEPT_FOR_PURPOSE` deliberately not adjudicated without external application authority.

Common-cohort P2C:

- workflow run `35446071978`;
- artifact `10584319433`;
- persisted result `integration/f-rom/LARE_RS1_GW_P2C_RESULT.json`;
- one common response-blind cohort of 41 states and 480 cross-history pairs;
- 477 pairs distinguishable above the frozen full-theta diagnostic floor;
- three full-state-near-identical pairs retained as a separate baseline.

## State-complexity result

The formal P1 state representations are:

### D2

`0-150 | 150-160 cm`

At the 1x diagnostic radius: 7988 collisions in the full Stage-A pair population.

D2 remains an aggressive information-loss control.

### D3

`0-140 | 140-150 | 150-160 cm`

At the 1x diagnostic radius: zero collisions in the full Stage-A P1 population.

D3 is the smallest response-blind state representation that is state-separating at the frozen 1x diagnostic radius.

### D4

`0-130 | 130-140 | 140-150 | 150-160 cm`

D4 reduces the 4x collision count from 40951 for D3 to 40942, a difference of nine pairs.

D5 through D10 do not improve the selected P1 collision-count vector beyond D4.

Therefore additional state dimension beyond D4 has no demonstrated state-information value in this laboratory.

## Why candidate-specific P2 was not enough

Formal P2 used eight response-blind nearest adversarial pairs per representation.

That is appropriate for within-representation falsification but not by itself for ranking representations, because the candidate pair sets differ.

For example, U4 had a very small one-day exchange difference on its own nearest eight pairs while simultaneously showing many dynamic reversal failures. A direct statement that U4 was therefore better for GW-R would have mixed pair-selection effects with state-quality effects.

P2C resolved this by evaluating all representations against the same 41-state cohort and the same 480 cross-history pair universe.

## Common-cohort result

### At 1x diagnostic radius

Reduction-induced aliases among the 477 full-state-diagnostic pairs:

| Representation | Dimension | Alias pairs |
| --- | ---: | ---: |
| D2 | 2 | 45 |
| D3 | 3 | 0 |
| D4 | 4 | 0 |
| U4 | 4 | 137 |
| U8 | 8 | 71 |
| B01/B14 pilot R4 | 4 | 0 |
| Z8+G8 information-equivalent | 9 | 0 |

D3 therefore introduces no additional state alias relative to the full-theta diagnostic floor anywhere in this frozen common cohort.

D4 has the same result and provides no demonstrated state-information advantage over D3.

Uniform coarsening retains substantial hidden profile ambiguity even at four and eight prognostic storage states.

### At 2x diagnostic radius

| Representation | Alias pairs | max GW-D cumulative bottom difference | max GW-D terminal bottom-flux difference | GW-D sign mismatches | reversal-sequence mismatches | max 1-day bottom-exchange difference |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| D2 | 64 | 0.240 mm | 5.513 mm d-1 | 12 | 0 | 0.308 mm |
| D3 | 58 | 0.168 mm | 5.513 mm d-1 | 0 | 0 | 0.195 mm |
| D4 | 58 | 0.168 mm | 5.513 mm d-1 | 0 | 0 | 0.195 mm |
| U4 | 201 | 0.403 mm | 19.647 mm d-1 | 56 | 104 | 0.445 mm |
| U8 | 139 | 0.212 mm | 15.064 mm d-1 | 4 | 64 | 0.226 mm |

The 2x comparison is especially informative because every representation has aliases and can be compared without treating absence of aliases as zero hydrological error.

D3 and D4 remain exactly equal on the common-cohort purpose vector.

Both preserve flux direction and reversal sequence much more effectively than uniform U4/U8 within this cohort.

### At 4x diagnostic radius

D2, D3, D4, R4 and Z8+G8 converge to the same 151-pair alias set and the same maximum purpose-response vector.

U4 and U8 still retain larger alias populations and larger dynamic response ambiguity.

This indicates that the response-blind active-zone states differ primarily in how sharply they separate near-neighbour states; once the state neighbourhood is made sufficiently broad, they converge on the same larger-scale ambiguity population.

## Full-state-near-identical baseline

Three common-cohort pairs fall within the frozen full-theta diagnostic floor.

Even those pairs are not predictively identical. Their maximum one-day bottom-exchange response difference is approximately 0.079 mm and their maximum dynamic terminal-flux difference is approximately 2.27 mm d-1.

This is an important interpretation constraint:

**the theta diagnostic floor is a state-search scale, not a hydrological zero-error envelope.**

Consequently, D3 having no reduction-induced aliases at 1x means that it does not add detectable state-information loss beyond that full-theta neighbourhood in this cohort. It does not mean zero future-response uncertainty.

## Scientific disposition of D2, D3 and D4

### D2

Retain as the aggressive compression control.

It is useful because it demonstrates the consequence of dropping one lower active-zone storage state:

- more aliases;
- bottom-flux sign disagreements at 1x and 2x;
- larger common-cohort daily exchange ambiguity.

D2 is not the primary closure candidate.

### D3

**Primary minimum-information closure candidate.**

It is the smallest state that:

- separates the full Stage-A state population at 1x;
- creates no reduction-induced aliases in the P2C cohort through 1x;
- remains cleaner than D2 and uniform controls at 2x;
- retains the historically sensitive lower active zone explicitly.

This is a research-progression result, not application acceptance.

### D4

**Nested closure-resolution control, not a state-information requirement.**

D4 has no demonstrated predictive-state advantage over D3 in P2C.

Its scientific value in the next stage is different: the extra `130-140 cm` layer reduces layer thickness without introducing evidence that another prognostic state is required.

If a LARE closure performs materially better on D4 than D3 while their state-information evidence remains equivalent, the improvement is attributable to closure/discretization resolution rather than missing predictive state information.

This is a particularly clean falsification test.

## Relation to published LARE

He et al. (2021) derived a mass-conservative vertically averaged two-zone form of Richards equation as coupled ODEs and explicitly treated shallow/dynamic groundwater interaction.

He et al. (2022) reported generally good two-layer results but also found degradation with increasing layer thickness and coarser textures; they explicitly cautioned that the original two-layer formulation was not designed for deep soils with a thick vadose zone.

He et al. (2026) generalized the integrated formulation into LARE for stratified multi-layer soil profiles and tested it against analytical solutions, HYDRUS-1D and finite-difference solutions.

Relevant primary sources:

- He, J., Hantush, M. M., Kalin, L., Rezaeianzadeh, M. & Isik, S. (2021). *A two-layer numerical model of soil moisture dynamics: Model development*. Journal of Hydrology 602, 126797. DOI 10.1016/j.jhydrol.2021.126797.
- He, J., Hantush, M. M., Kalin, L. & Isik, S. (2022). *Two-Layer numerical model of soil moisture dynamics: Model assessment and Bayesian uncertainty estimation*. Journal of Hydrology 613, 128327. DOI 10.1016/j.jhydrol.2022.128327.
- He, J., Kalin, L., Hantush, M. M. & Isik, S. (2026). *A Numerical Model for Integrated Form of Richards Equation*. Hydrological Processes 40(1), DOI 10.1002/hyp.70396.

The literature therefore gives no basis for assuming that the extremely thick `0-140 cm` D3 layer will have an accurate LARE flux closure merely because its storage state is information-sufficient.

That question is now the point of the next experiment.

## Next authorized research question

> Given a reduced state that is demonstrably sufficient to retain the relevant Reference-state distinctions in the B01 groundwater laboratory, can a published integrated Richards/LARE flux closure propagate that state without introducing hydrologically consequential closure error?

The next experiment must separate:

1. state-information error;
2. layer-averaged closure error;
3. time-integration error;
4. conventional coarse-Richards discretization error.

## Required next comparators

At minimum:

1. 16 x 10 cm fine Reference Richards;
2. conventional coarse Richards on D3;
3. published LARE on D3;
4. conventional coarse Richards on D4;
5. published LARE on D4;
6. D2 as aggressive negative/information-loss control.

An equilibrium-preserving or equilibrium-subtracted LARE variant may be introduced only as a separately declared repair if the published LARE closure first demonstrates a reproducible hydrostatic-equilibrium defect.

## Remaining blockers outside this closeout

- Hupsel daily profile observation still requires exact-byte SWAP 4.3.1 execution.
- No B14/cross-material closure qualification exists.
- No stratified-profile closure qualification exists.
- No crop/ET/root-uptake reduced dynamics qualification exists.
- No external absolute GW-R/GW-D application tolerance has been established.
- No computational-value claim is authorized until the physical closure survives and is compared at equal state dimension/cost.

## Final RS1-GW status

`STATE_INFORMATION_RESULT = POSITIVE_BOUNDED_B01_GW_LAB`

`PRIMARY_MINIMUM_STATE = D3`

`D4_ROLE = CLOSURE_RESOLUTION_CONTROL`

`D2_ROLE = AGGRESSIVE_INFORMATION_LOSS_CONTROL`

`ABSOLUTE_PURPOSE_ACCEPTANCE = NOT_ADJUDICATED`

`LARE_DYNAMICS = AUTHORIZED_FOR_BOUNDED_RESEARCH_QUALIFICATION`

`PRODUCTION_ROM_AUTHORIZED = FALSE`
