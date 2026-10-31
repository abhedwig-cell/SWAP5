# Grassgrowth: full-period execution and scientific attribution

## Sprint02: independent thermal and trajectory qualification

**VOLLEDIG UITGEVOERD — WETENSCHAPPELIJKE KWALIFICATIE OPEN.**
The complete original 1827-day execution is inherited unchanged. A separately
registered finer numerical configuration now passes all twenty measured
criteria; the original coarse configuration still fails temperature. Neither
result changes the failed predecessor gate or promotes the production model.
This sprint changes no production, application or reference source.

Reconciliation starts from canonical `0c05d6f73c102d8a7e2ec11cc322f4b8f2c4ad50`,
review `3170aa1783872b90f121550803f5bfaaf902b0e8`, and scientific production
postimage `d6514abee5a85367a6b1fa181c011b6f2e9194ed`. The five original inputs,
113 nodes, six-metre profile, five seasons and physical selectors are unchanged.
Issues1458/1386 and PRs1476–1480 were reconciled against the repository receipts;
older issue text does not supersede the sealed full execution. The independent
review's scientific and reproducibility concerns are addressed below. General
architecture work remains outside this bounded sprint. Canonical is untouched;
all new work is on `codex/grassgrowth-sprint02`.

### Identical-state heat comparison

The real original `MOD_SoilTemperature` and current six-provider thermal owner
are called with the same retained temperatures, pressure, geometry, forcing and
water content. Criteria were fixed from the existing FVQ58 independent component
contract before execution: temperature5e-10C, flux5e-10J/cm2/day and
energy5e-9J/cm2. Each O0/O2 build executes96 cases:24 actual checkpoint states
at .04/.02/.01day with frozen water, plus eight adjacent-state water changes
at those three steps. Interpolating daily water changes is an explicit operator
counterfactual; it is not a reconstruction of actual accepted water substeps.

Linux GNU13.3 and Windows GNU16.2 both pass, with identical O0/O2 rows.
Maximum original/current temperature difference is1.066e-14C, flux6.040e-12
J/cm2/day, and independent capacity-stock/boundary discrepancy2.284e-12J/cm2.
The native full-versus-two-half-step defect reaches2.5521e-4C. This isolates
thermal integration sensitivity while finding no thermal formula discrepancy
on the selected states. It does not establish every coupled thermal substep.

### Registered new trajectory observations

Registration was published in commit
`1f63542b6bcbcba0bce5a41e858580134f2a9da8` before the new outputs.
It preserves the old training-derived bounds and their immutable registration
hash. Twelve new profile days64,74,114,128,141,368,733,919,923,1097,1462,1801
are disjoint from the previous profile observations. Together the study covers
26 profile dates,36 native checkpoint dates and all1827 daily scalar outputs.
Original reference runs at DTMAX .00125/.000625/.0003125day complete uncensored
with native exit100 and `swap.ok`, taking198.59/393.89/784.60seconds respectively.
The first two reproduce all pre-existing scalar and nodal reference outputs
exactly. Only the output collector's date list is expanded; original provider
hashes and physical inputs are verified. Original DTMAX is the only changed
numerical input. No checkpoint binding or CRC is replaced.

Twenty-four one-day native forks start from byte-identical sealed coarse/fine
checkpoints with their own unchanged executable and application binding. Every
fork exits0 uncensored and reproduces the corresponding previously stored
budget/crop row exactly. Independently recomputed water stock
`sum(theta*dz)+pond` minus its original checkpoint and net boundary flux closes
to2.310e-14cm; this check does not trust the application's residual column.

The finer native DTMAX .01day configuration passes all twenty unchanged
bounds and all new reference-change decrease criteria. The coarse .04day
configuration fails only temperature in this new assessment:

| Temperature profile criterion | Maximum error C | Frozen limit C | Result |
|---|---:|---:|---|
| Original coarse native configuration | 0.00726587426845 | 0.00277276714718 | FAIL |
| Separately registered fine configuration | 0.00214899440600 | 0.00277276714718 | PASS |

The finer configuration was selected after the earlier coarse failure, but
before these new disjoint outputs. Its successful new test does not convert
the original test into a pass. The old drought decrease failure also remains:
.000176948895 exceeds the preceding .000170241561 at the same day942
(1982-07-30), rather than through an argmax-date switch. Subsequent reference
changes decrease to.000090280965 and.000036682201. This supports a numerical,
non-asymptotic coarse regime without identifying an unobserved branch mechanism.

### Material differences and scope

| Quantity or process | Classification and evidence |
|---|---|
| Potential versus actual transpiration | Demonstrated numerical trajectory sensitivity: potential control agrees before actual canopy feedback; inherited2922 identical-state whole-uptake intervals reproduce the composed demand/reductions. All new fine TPOT/TACT bounds pass. |
| Oxygen and drought | Original/current identical-state stressed owners reproduce within existing source-solver criteria. Accepted-time accumulation differs across adaptive trajectories; wet/dry daily reductions satisfy the transpiration attribution relation. Both new fine bounds pass; old drought gate remains FAIL. |
| Temperature and moisture feedback | Real paired heat kernels agree; timestep-only refinement reduces profile error. Native F-MR39 explicitly preserves water-only temporal acceptance. This is an existing numerical-policy difference, with demonstrated coarse thermal underresolution, not a newly proven formula bug. |
| Biomass, roots, mowing and regrowth | Actual water limitation propagates to assimilation, organ growth, root extension and harvest. Original potential controls, inherited exact mowing/year/regrowth restarts, and new fine organ/root/harvest bounds support numerical attribution within tested scope. No new management/input defect is demonstrated. |
| LAI and cumulative harvest | Explicit reporting phase/counter difference: native LAI is day-start, source LAI day-end; annual source harvest is accumulated before project-total comparison. Unaligned maxima are excluded. |
| Timestep, nonlinear control and process order | Explicit control-policy differences remain; current stricter nonlinear stopping and external full/half water acceptance are unchanged. Original/current identical-state process tests plus refinement support measured numerical attribution, without claiming identical accepted meshes or complete coupled process-order equivalence. |
| Energy and unobserved states | Open scope: conductive thermal capacity/boundary accounting is independently checked. Complete surface energy, enthalpy carried by moving water, and every coupled accepted thermal substep are not qualified by small residuals or sampled profiles. |

No concrete new programming or input error is demonstrated, so there is no
production correction to make merely to force the old gate to pass. Production
promotion would require a separately justified thermal acceptance policy and
its affected-owner qualification, or a prospectively approved explicit coarse
accuracy contract. This sprint neither adjusts tolerances after seeing results
nor silently substitutes the fine configuration for the original one.

### Durable evidence and reproduction

`SPRINT02_EVIDENCE_MANIFEST.json` binds the compact raw capsule, all new source
hashes, original production trees and both immutable predecessor capsules.
It retains inputs, checkpoints, native/reference executables, raw scalar and
profile outputs, build command/flag/compiler reports, native exit statuses,
wall costs, and stdout/stderr. Expanded source/object duplicates are omitted;
their provider hashes resolve to the existing pinned original authorities.
Windows path separators are normalized only for manifest key comparison;
source bytes and recorded hashes are not normalized or replaced.

```bash
python -B tests/dataqual15/sprint02_evidence.py
```

This read-only consumer recomputes raw heat criteria, checkpoint stock/flux,
input/binding identities, output-only collector changes, both reference controls
and every frozen bound/decrease check. A verified capsule is not a scientific
PASS for the original coarse route. Full reruns, when justified, use
`qualify_heat.py` and `qualify_sprint02_holdout.py`; their checked build reports
retain complete commands. The new portable consumer needs no native rerun.
Linux heat run41198744813 and registered-reference run41198100939 are successful;
Windows paired builds take128.77seconds. All declared model runs are uncensored;
there is no unfinished full-period model process. Full original experimental
projects remain2/3 globally and whole scientific qualifications0/3.


The original1827-day Grassgrowth execution is complete and source-bound in
`GRASS_UNION_FULL_MANIFEST.json` and `CANONICAL_FULL_MERGE_RECEIPT.json`.
The follow-up evidence is `STRESS_EVIDENCE_MANIFEST.json` with the portable
verifier `python -B tests/dataqual15/stress_evidence.py`. Its successful evidence
verification preserves a **failed** preregistered scientific resolution test.
Whole-model scientific equivalence and production promotion remain open.
The experimental follow-up is admitted by PR1479 at merge51ee43e; the fetched
whole tree equals the exact qualified tree. Its actual receipt is
`SCIENTIFIC_FOLLOWUP_MERGE_RECEIPT.json`. The two pre-existing legacy solute
source-guard failures are recorded in `LEGACY_SOLUTE_GUARD_RECONCILIATION.json`;
they are not relabelled PASS.

## Identical-state oxygen and whole uptake

The real original and current owners receive identical native accepted states,
root profiles, respiration and potential demand in O0/O2. All2922 accepted
intervals on days25,72,73 and127 are represented, including7661 stressed node
evaluations. Rejected/full sibling trials are retained in the raw observations
and excluded from the accepted receipt integration. The current standalone
oxygen factors reproduce the actual backend factors exactly. O0/O2 outputs
are identical.

| Day | Accepted intervals | Stressed node evaluations | Whole original uptake (cm) | Whole current uptake (cm) |
|---|---:|---:|---:|---:|
| 25 | 558 | 0 | 0.004469345352234 | 0.004469345352234 |
| 72 | 1162 | 946 | 0.005345811715848 | 0.005345811636137 |
| 73 | 1112 | 6715 | 0.010409137597776 | 0.010409137774837 |
| 127 | 90 | 0 | 0.246763458109825 | 0.246763458109825 |

The maximum original/current oxygen-factor difference is6.744e-5, within the
inherited1e-4 SOLVE gate. Replacing only the oxygen owner changes integrated
native uptake by at most1.771e-10cm on these days. The whole original macroscopic Feddes/Bartholomeus
uptake reproduces the original-factor counterfactual within1e-10cm; the whole
current uptake reproduces the accepted native ledger within1e-10cm. These
results exclude a material selected oxygen/uptake-owner discrepancy on the
observed states. They do not test a donor hydraulic/thermal trajectory or every
other uptake option, and the component gate supplies no yield tolerance.

## Controlled numerical trajectories

Three checked native trajectories start independently on day1 with DTMAX caps
0.04,0.02 and0.01day and run through140. They retain all original physical input
bytes and use the existing numerical acceptance policy. Output-only diagnostic
sources have separate source/executable bindings. The coarse budget, crop and
physical checkpoint payload reproduce the qualified original trajectory exactly.
No checkpoint source binding or CRC is rewritten. The original
SWSOLU0 and SWMACRO0 remain selected: solute balance is not_applicable and
macropore flow remains disabled. Macroscopic root uptake is a separate original
Feddes/Bartholomeus option, not a macropore-flow addition. First actual harvest is
2132.071263,2132.061813 and2132.058184kg/ha respectively, a spread of0.01308kg/ha.

The sealed authentic original4.3.1 output-only nodal executable independently
runs all1827days. DTMAX alone changes; the literal0.04 run reproduces all stored
scalar and nodal rows exactly. Annual donor harvest counters are summed before
comparison with the native project counter.

| Original DTMAX (day) | Original project harvest (kg/ha) |
|---:|---:|
| 0.04 (literal reference) | 54049.870947 |
| 0.005 (training) | 54327.618357 |
| 0.0025 (training) | 54344.415200 |
| 0.00125 (held out) | 54352.253369 |
| 0.000625 (held out) | 54355.926976 |

Native original-input harvest is54354.337261kg/ha. Its difference from the
literal donor is+304.466314kg/ha (+0.5633%); versus the finest donor it is
-1.589715kg/ha. Day25's donor-only coarse oxygen reduction vanishes on donor
refinement. Day72 donor reduction approaches the native result. Combined with
the identical-state replay, this is strong attribution to numerical trajectories,
not evidence of an oxygen formula repair or a new physical owner.

## Frozen held-out test: FAIL retained

`STRESS_ATTRIBUTION_PREREGISTRATION.json` was committed before either held-out
run. Quantity-specific envelopes are three times the sup-norm donor change
between0.005 and0.0025 plus declared print/roundoff floors. Independent potential
controls use the floor alone. Both held-out halvings must reduce each reference
change and place native errors inside every frozen envelope. Pressure is
normalized by max(1cm,abs(h)); theta and temperature retain physical units.
Native day-start LAI is compared to donor previous-day end, excluding annual
initializations. This is a conditional numerical-resolution test, not an
observational/ecological error tolerance or full energy qualification.

At0.00125, the drought-reference change is0.000176949cm/day, slightly larger than
the preceding0.000170242cm/day, although the native drought error is within its
frozen0.000510726cm/day envelope. The next halving decreases again. Temperature
fails both held-out tests: maximum native errors0.006918904 and0.007150261C
exceed the unchanged0.002772767C envelope. All other fields meet their frozen
envelopes; the finest holdout fails temperature alone. No limit is enlarged
post hoc and the original failed gate remains false.

The following errors compare the unchanged qualified native trajectory with the
finest donor. Scalar maxima use all1827 daily rows; harvest and nodal quantities
use the retained native checkpoint dates only. Bounds are numerical-resolution
envelopes, not ecological tolerances.

| Quantity | Maximum error | Frozen envelope | Unit | Inside |
|---|---:|---:|---|---|
| WTOT | 0.00210701016 | 0.0102458809 | cm | yes |
| TPOT | 0.000129472514 | 0.00124387249 | cm/day | yes |
| TACT | 0.000334408188 | 0.00432922481 | cm/day | yes |
| TREDWET | 0.000278774757 | 0.00432226472 | cm/day | yes |
| TREDDRY | 0.000238126134 | 0.000510725683 | cm/day | yes |
| WRT | 0.360431117 | 2.62675763 | kg/ha | yes |
| WLV | 1.61497852 | 9.81334274 | kg/ha | yes |
| WST | 0.482345915 | 3.58529754 | kg/ha | yes |
| RD | 0.000143725938 | 0.00575041894 | cm | yes |
| PWRT | 5.1159077e-13 | 1e-06 | kg/ha | yes |
| RDPOT | 0 | 1e-07 | cm | yes |
| DVS | 4.98934227e-13 | 1e-08 | dimensionless | yes |
| TSUM | 4.54747351e-13 | 1e-08 | degree day | yes |
| LAI_DAY_START | 0.00279182593 | 0.0209807138 | m2/m2 | yes |
| HRVDM_PROJECT | 1.58971519 | 50.3905313 | kg/ha | yes |
| PHRVDM_PROJECT | 3.4506229e-09 | 1e-06 | kg/ha | yes |
| NET_FLUX | 0.00241105873 | 0.00825753887 | cm/day | yes |
| PROFILE_head_cm | 0.00264643849 | 0.00829568456 | normalized by max(1cm,abs(h)) | yes |
| PROFILE_water_content | 0.000129076629 | 0.000404914896 | cm3/cm3 | yes |
| PROFILE_temperature_c | 0.00715026139 | 0.00277276715 | C | **no** |

The largest finest-reference temperature error is day1096,node26: native
3.059500807C versus donor3.052350546C. Their water contents differ by only
2.82e-7cm3/cm3. A small heat-accounting residual therefore cannot be used as a
temperature-error bound.

Existing native refinement already reduces the day140 maximum temperature
error versus the finest donor from0.003564388 to0.001744730 and0.000827322C.
Day73 is nonmonotonic (0.000582356,0.000621883,0.000591040C), so a claim of
uniform convergence at every date would be unsupported. A fresh full native
DTMAX0.01 trajectory now completes all1827days in1606.60seconds, with all24
retained full-day checkpoints (including the terminal checkpoint), unchanged
physical inputs and a separate exact source/executable binding. Its maximum
water residual is4.924e-14cm and heat-accounting residual3.038e-12J/cm2.

### Exploratory full native numerical diagnosis

At all14 retained donor profile dates (113nodes each), the refined native
maximum temperature error is0.001614601C, below the **unchanged**0.002772767C
envelope. All20 quantity-specific errors, including daily stress, biomass,
water flux, potential controls and retained harvest/profile values, lie inside
the original frozen envelopes. The full raw per-field result is in
`SCIENTIFIC_DIFFERENCES.json` and independently recomputed by the portable
verifier. Selected maximum nodal temperature errors are:

| Day | Qualified coarse native error (C) | Refined native error (C) |
|---|---:|---:|
| 63 | 0.002094793 | 0.000693603 |
| 140 | 0.003564388 | 0.000827322 |
| 731 | 0.003073244 | 0.000861822 |
| 922 | 0.005014811 | 0.001154408 |
| 1096 | 0.007150261 | 0.001614601 |
| 1461 | 0.004610581 | 0.001015256 |
| 1827 | 0.002435697 | 0.000680586 |

This diagnosis was chosen after the coarse temperature failure. It supports
numerical attribution under pre-existing limits; it does not retroactively pass
the original preregistered test, establish an ecological uncertainty bound or
promote DTMAX0.01 into the production application. The original coarse
qualification remains open and the failed intermediate drought monotonicity
check remains recorded. No physical owner was changed to obtain these results.


Source inspection finds the same average old/new water contents, De Vries
capacity/conductivity, arithmetic face conductivity and implicit thermal matrix
for the selected air-temperature/zero-bottom-flux route. The original advances
heat after water integration. The native route advances heat transactionally
on accepted half steps. The selected native weather/water temporal metric
controls pressure, storage and Darcy exchange, without an independent thermal
error term. This explains why water acceptance and heat conservation alone
cannot certify a temperature envelope. Inspection is not an identical-state
runtime proof of every thermal branch. No physical process defect is confirmed
and no production owner, solver tolerance or physical input is changed.

## Reproduction and preserved scope

Verify the portable raw-data archive without a compiler:

```bash
python -B tests/dataqual15/stress_evidence.py
```

Export the verified study to a new directory, preserving the exact sources,
application bindings, original inputs, CRC checkpoints and native outputs:

```bash
python -B tests/dataqual15/stress_evidence.py --extract /tmp/grass-study
python -B tests/dataqual15/qualify_stress.py --compiler /usr/bin/gfortran-13 --output /tmp/grass-paired --paired-only --observations /tmp/grass-study/observations/coarse/native
```

The second command rebuilds both real original and current owners in O0/O2.
This self-contained reproduction also passes locally with Windows GNU16.2.0,
2922 accepted intervals and identical O0/O2 results. The full application retains
the supported Linux fsync route.
No expired Actions artifact, scratch object or local historical commit is needed.
The old oxygen-only diagnostic source is retained as an explicitly hashed
historical snapshot alongside the later whole-uptake oracle. It is never bound
to the current whole-uptake source hash.

`qualify_donor_timestep.py --profiles` can rerun the full donor study from the
unchanged original capsule. The fixed registration is recomputed from the
training runs before either held-out run is launched. The native thermal
counterfactual is reproducible with `qualify_native_thermal.py --compiler
/usr/bin/gfortran-13 --output /tmp/grass-thermal --donor /tmp/grass-study/donor`.
Its expected cost is2400seconds with a7200second wall cap, justified by the
late day1096 temperature failure that a140-day prefix cannot assess. It starts
on day1 with its own executable/source binding and never resumes an old bound
checkpoint under a new executable.

The original full1827-day execution remains a separate immutable authority.
Variants and refined trajectories do not increase the single migration matrix's
independent-project count: full original executions2/3 globally, whole scientific
qualifications0/3. The source/executable provenance, hard mass/heat accounting
and exact restart claims must not be replaced by the resolution envelope.

## Historical521-day analysis

The following observations describe the earlier521-day receipt. Statements about
unperformed paired/profile diagnostics refer to that historical stage; the
full-period and accepted-state evidence above supersedes those limitations for
its explicitly tested scope.

Experimental comparison of the frozen contiguous original-input day1–521 history with the complete original SWAP4.3.1 scalar reference. This establishes measured differences, not whole-model scientific equivalence. Exact input, output and inspected-source hashes and day-level results are in `SCIENTIFIC_DIFFERENCES.json`.

| Quantity | Largest absolute difference through521 | Day |
|---|---:|---:|
| Water storage | 0.0844245 cm | 189 |
| Daily potential transpiration | 0.00698963 cm | 205 |
| Daily actual transpiration | 0.0113503 cm | 188 |
| Actual root biomass | 12.9860 kg/ha | 205 |
| Actual living leaves | 54.1542 kg/ha | 205 |
| Actual stems | 19.3608 kg/ha | 205 |
| Actual root depth | 0.0500419 cm | 439 |
| Potential root biomass | 5.12e-13 kg/ha | 115 |

The prescribed groundwater at retained checkpoints differs by at most4.73e-8 cm from the original printed output; this is not a full daily groundwater/profile comparison. Full daily soil-moisture and temperature profiles are not available in the retained source outputs.

After the first366-day year, SWAP5's actual harvested dry matter is10742.465086 kg/ha versus10653.182217 kg/ha in the source, a difference of89.282870 kg/ha or0.8381%. Potential harvest is12566.142742 kg/ha in both, within the source's printed precision. By521days the cumulative actual-harvest difference is104.781810 kg/ha; potential export remains within3.46e-9 kg/ha. Source annual harvest counters are summed over completed years before comparing with the native project-total continuation.

The observed entry point is oxygen-limited growth. First actual biomass and root-depth differences above1e-8 occur on day72. That day's actual/potential transpiration ratio is0.994608690 in SWAP5 and0.988890191 in the source; on day73 these are0.937459769 and0.916270251. Through521days, cumulative actual transpiration is0.202562895 cm higher, potential transpiration0.117895695 cm higher, oxygen reduction0.086261170 cm lower, and drought reduction0.001593970 cm higher. These quantities satisfy the transpiration attribution relation to source output precision. The differing actual canopy subsequently feeds back into potential transpiration, assimilation and harvest.

Code inspection finds the same clipped daily actual/potential water ratio in original WOFOST and SWAP5. Both integrate deepest-root oxygen factor times duration for daily root extension. The original calls root extraction before soil water and heat after water-flux integration; SWAP5 evaluates extraction/oxygen from each full, half and retry trial's left hydraulic/thermal state and uses only accepted fluxes in the daily crop update. The inspected node-top root-density and respiration formulas preserve the source arithmetic, constants and mowing-delay branch. This is structural source comparison, not a paired-state runtime proof of the complete oxygen chain.

The causal split between timestep/nonlinear policy, hydraulic/thermal trajectory and oxygen implementation is **not isolated**. The retained canonical SWAP5 acceptance policy differs from original SWAP4.3.1. A controlled paired-state or step-refinement comparison is still needed before attributing all observed differences to numerical discretization. This inspection has not demonstrated a process-order implementation defect. Small heat-accounting residuals do not establish temperature or full energy equivalence.

`crop.csv` requires careful time alignment: its `lai` column is the day-start `crop_view`, whereas its organ biomass, development and root-depth columns are committed day-end values. Comparing its LAI directly with source same-day end-of-day LAI produces a false2.2478 maximum at a mowing boundary. Comparing native day-start LAI with source previous-day LAI, excluding the annual initializations on days1 and367, gives a maximum0.115612 on day206. This is a reporting phase distinction, not evidence of an LAI process error.

A separate output-only donor diagnostic attempt requested113-node H/WC/T profiles. The unchanged donor executable rejected both bracketed and plain H variable requests in its CSV lookup. It produced no success marker or usable profile output and is excluded from successful reference evidence. The qualified scalar-reference folder and its inputs/output were left unchanged. No new model implementation, solver setting or physical input was changed for this comparison.
