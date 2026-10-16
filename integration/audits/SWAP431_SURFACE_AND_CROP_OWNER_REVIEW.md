# Surface input and crop owner reconciliation

Baseline: `78acf56f931763d2e1d4924b3dea0742f231d2e8`.
This review makes bounded migration decisions, not new runtime admissions.

## Macropore surface transfer

B1.11 `headcalc.f90:98` forms matrix surface supply as
`(net rain + net irrigation + melt)*(1-ArMpSs) + runon - evaporation`.
Runon is therefore not a second direct precipitation partition into macropores.
`boundtop.f90:150..165` derives the potential lateral transfer from ponding:
`RsRoMp=(h0max+(nraidt+nird+melt)*ArMpSs*dt)/KsMpSs`, with a PndmxMp threshold,
the coupled `p2Mp` denominator and an available-water cap. The transfer is an
interval amount despite the historical variable comment describing a rate.
`macrorate.f90:1397..1408` returns capacity-rejected input through QMpLatSs;
`boundtop.f90:209..231` debits its accepted value from the same surface balance.

A9 admits a separately owned, already resolved lateral input rate. Its current
`mod_fmr_macropore_top_input` partitions that supplied amount; it has no PndmxMp,
KsMpSs or surface-water donor state. Its limiter and returned-surface receipt
already exist. The missing capability is the coupled pond-derived request and
surface debit/return binding, not the partition or capacity limiter.

Decision: **MIGRATE** SW431-MACRO-POND under MC-MACROSUR01. Preserve one surface
store and one accepted transfer receipt, with rejected-trial isolation. Start
with no external runon; qualify dry/threshold/wet/capacity-rejected cases.
Then **MIGRATE** SW431-MACRO-RUNON as the composition of the separately registered
runon carrier with that donor. It depends on both SW431-RUNON and
SW431-MACRO-POND. Never add the same runon amount to matrix and macro channels.
A9's explicit exclusion of independent direct pond/runon sources is preserved.

## Prescribed surface-water level and rapid drainage

`surfacewater.f90:503..599` selects primary/secondary water level, resolves the
active drain basis and assigns `ZDraBas=drainl(NumLevRapDra)` for the selected open
drain. SWSEC=1 exits before the internal-store falling-dry limiter. Initialization
at 1160..1171 alone is not the whole time-varying capability.

The current factory sets `rate_template%rapid%drain_level_cm` once. The standard
adapter copies the template, updates macropore water level, volume below drain
and storage, but never replaces the drain-level forcing. The backend interval
forcing has no prescribed rapid-drain basis carrier. An immutable configuration
change/reinitialization is not an accepted interval forcing protocol.

Decision: **MIGRATE** SW431-MACRO-SW-EXTERNAL. Add a bounded immutable interval
basis from the source open-channel level resolver; recompute the existing
volume-under-drain term using that basis. Keep the existing static rapid route.
Qualify moving level, clamp/activation seams, changed-forcing retry, restart and
exactly one rapid outflow receipt. Internal surface-store feedback is separate.

## Irrigation components and missing composition

`mod_irrigation_process` already owns fixed-event index, active-event interval,
origin and depth/rate handling. Its fixed event supports sprinkler, surface and
SSDI labels. Do not schedule a second implementation of these fields.
F-APP07 qualifies a fixed surface event and TCS1/DCS2 scheduled sprinkling.
Its explicit exclusion of ISUAS!=0 remains relevant.

The application binding has a fixed sprinkler/surface identity route, and a
separate scheduled-TCS1-to-Rutter route that always marks irrigation intercepted.
It has no fixed-sprinkler-to-Rutter binding or scheduled surface bypass. Identity
is appropriate only in the declared nonintercepting envelope; it is not evidence
that a canopy sprinkler loss may be skipped.

Decision: **MIGRATE** SW431-IRR-FIXED-SPRINK by reusing the fixed process, adding
the intercepted sprinkler composition and qualifying event lifecycle with that
water owner. **MIGRATE** SW431-IRR-SCHED-SURF first for the admitted TCS1/DCS2
decision rule with an explicit nonintercepted application route. Other timing
and depth selectors remain separate work items. Test the same gross event under
sprinkler and surface labels, canopy storage, partial intervals, rejected retry
and restored event progress. Do not infer admission solely from accepted enums.

## Crop response and season ownership

CO2 response is not just the location of a file. B1.11
`MOD_cropdevelopment.f90:889..909` selects one year's concentration and evaluates
CO2AMAXTB, CO2EFFTB and CO2TRATB consistently. SWATMOFIL=0/1 only changes storage
of that input. Current classic and WOFOST81 assimilation consume already resolved
factors. F-WOF43A evaluates the transpiration factor, but does not bind the three
response factors to one production forcing revision. There is no source-table
resolver for CO2AMAXTB/CO2EFFTB in current production source.

Decision: **MIGRATE** SW431-CROP-CO2 as a typed three-response resolver and shared
crop/ET forcing binding. Calendar/file selection can stay outside the physics
owner; caller supplies the source year's concentration. Preserve factor=1 for
disabled response and inactive-crop dependency minimality. Qualify nonconstant
tables, endpoints, year changes, invalid forcing and consistent crop/ET use.

`croprotation` in the same source (181..354) switches crop configuration, resets
preparation/sowing/emergence flags and initializes development/root extraction
when the next crop emerges. Current F-WOF39 lifecycle code retires a consumed
accepted *daily* event. It neither selects a next crop nor resets a seasonal crop
owner. Treating that event lifecycle as crop rotation was not justified.

Decision: **MIGRATE** SW431-CROP-ROTATION as accepted season transitions over a
typed schedule. No old crop-file parser is required. Preserve soil state across
harvest/fallow/next emergence, reset only the intended crop state, and bind the
next crop parameters exactly once. Start with prescribed emergence; automatic
sowing/germination remains SW431-CROP-SOW. Test two different crops separated by
fallow, boundary replay, rejected transition and restart on either side.

## Ordinary capped drain infiltration

B1.11 `drainage.f90:185..194` applies SWLIMINF to the ordinary DRAMET3 negative
head difference before division by INFRES and directional suppression. The
existing EXTENDED provider has related cap algebra, but the retained literal
DRAMET3 probe already disproves unrestricted dispatcher equivalence at its
independent activation seam. Decision: **MIGRATE** SW431-DRAIN-INF-LIMIT as a
small selector slice of the native DRAMET3 resolver, after SW431-DRAIN-DRAMET3.
Do not duplicate or replace EXTENDED. Qualify cap-active/inactive, equality,
dry channel, SWALLO and signed spatial binding separately.

All these decisions preserve existing admitted code. Hash-bound evidence lists
the actual production and exact B1.11 members inspected. None changes a numerical
tolerance or turns a component qualification into a canonical admission.

## Existing code that still needs a bounded runtime qualification

Four entries have a different next action. Their implementation is present;
the missing deliverable is source-bound runtime qualification/admission:

| Capability | Reuse | Required controlling gate |
|---|---|---|
| SW431-MACRO-SEP1 | Ernst component and standard Reference adapter; 48-case literal comparison | Active positive-K full/partial seepage face in actual Richards/macropore runtime, water/donor bounds, retry and restart |
| SW431-MACRO-SEP2 | Youngs component and same adapter/comparison | Same owner gates with independently active Youngs geometry, not the inherited SWSEP0 fixture |
| SW431-CROP-ANNUAL | Classic AMAXTB prepare/finalize/leaf owner and F-WOF38 transaction | Literal B1.11 classic daily and seasonal source trajectories with actual water stress, carbon/organ/leaf closure and accepted-event/restart ownership |
| SW431-CROP-WOF-OTHER | Common IDSL1 daylength finalizer | The preceding classic annual gate extended across DLC/DLO and anthesis; persistent IDSL2 vernalisation remains separate |

Decision for each: **MIGRATE by qualification of the existing production route**,
with a repair only if the declared source comparison finds a discrepancy. This
is an executable next step, not a claim that the evaluator is absent. F-CI89
explicitly admits WOFOST81 and preserves the older F-WOF38/39 contract; neither
that preservation nor the different WOFOST81 donor admits every B1.11 classic
annual option. The classic gate excludes separately listed root-depth resolvers,
Soil-N, soybean, grass, automatic emergence and companion potential RELMF.
MC-MACRO01 owns the two seepage gates. MC-CROP01 owns the annual gate followed
by its IDSL1 extension. A passing probe remains qualification until its owning
admission is recorded.

## Solute and snow branch check

The complete executable snow update was re-read. SWSUBLIM, warm-soil immediate
melt, temperature/rain melt, 7% liquid retention, drainage and proportional
deficit correction are represented in `mod_snow_process`. In particular the
source contains `lm=333580` and continued `slw`; the earlier blanket statement
that B1.11 contains no latent-heat term was too broad. SW431-ICE now explicitly
means *soil* phase change. The existing daily Snow admission is unchanged.

The solute update distinguishes mobile advection/diffusion/dispersion and TSCF
root removal, pond inventory, linear/nonlinear equilibrium sorption,
temperature/moisture/depth decay, aquifer breakthrough and water-age production.
Existing ledger IDs cover those equations. The decay source sets its temperature
factor to zero when SWHEA=0; a future migration must adjudicate that exact branch
instead of silently assuming unit temperature response. Water age produces
`0.5*(theta+thetm1)` per time and requires its own stored age amount, not just a
conservative tracer label. Its pond history is also physical continued state.

The SWBR aquifer block has a reproduced source defect. `bdenskfsatporos` is
allocated with numnod elements at source line193. After the compartment loop,
the aquifer block (462..469) indexes that array with the completed-loop index
`i=numnod+1`. The unchanged extracted aquifer block fails bounds checking in
all eight probes: one/three nodes, positive/negative qdrtot, O0/O2.
Evidence: `evidence/SWAP431_AQUIFER_BOUNDS_PROBE.json`; replay:
`python tools/audits/probe_swap431_aquifer_bounds.py --output /tmp/aquifer.json`.

This is a bounded allocation/index witness, not a full executable source replay.
MC-SOL01 must first establish an explicit aquifer storage/coefficient contract
under the reference-defect policy, including units of accumulated isqdra versus
rate qdrtot and the substep balance. Changing the index to a guessed soil node
is not a qualified repair. The intended aquifer capability stays ACTIVE_MIGRATION;
neither a family rejection nor an untested corrected equation is declared.

## Active seepage runtime smoke

`probe_swap431_seepage_runtime.py` builds the unchanged real production module
closure and a recorded derivative of the A8 four-node trial fixture. It changes
the physical fixture to a partially saturated matrix with a lower macropore
water level, positive horizontal conductivity and zero other exchange sources.
It retains the A8 mass, candidate isolation, commit and revision assertions.
The exact fixture replacements and every compiled dependency hash are recorded.

The first mode7/free-drainage fixture did not keep the seepage face active:
the predictor produced negative matrix heads before exchange evaluation.
The solver and commit completed, but the independent positive-exchange assertion
failed. Initial and diagnostic attribution records are retained; these failures
are not proof of a missing seepage evaluator or a failed Richards solve.

The closed-bottom mode2 fixture keeps the source branch active. All six runs
pass, with identical O0/O2 stdout for each case:

| Variant | Initial macro water (cm) | Accepted macro water (cm) | Reported column mass residual (cm) |
|---|---:|---:|---:|
| Youngs K=0 control | 0.02 | 0.02 | 0 |
| Ernst K=0.1 | 0.02 | 0.020036413738389627 | 0 |
| Youngs K=0.1 | 0.02 | 0.020140224810362411 | 0 |

This establishes actual positive-branch execution through the existing
Reference/macropore transaction, rather than merely a callable component.
It does not qualify full-top-cell geometry, capacity exhaustion, changed-forcing
retry, fresh-process restart or a coupled literal-source trajectory. MC-MACRO01
retains exactly those gates. Neither entry is promoted to ADMITTED by this smoke.
Evidence: `evidence/SWAP431_SEEPAGE_RUNTIME_PROBE.json`, with the two unsuccessful
fixture records under `..._INITIAL_PROBE.json` and `..._ATTRIBUTION_PROBE.json`.
