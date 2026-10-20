# MC-NUT01 final closure review

Updated20 October2026 against canonical `d443dced3313e2602fdea4cbd1a6cb566f53fb0e`. The19October review and its immutable evidence remain historical receipts.

## Decision and claim boundary

**Full historical MC-NUT01 closure remains open. The independent positive historical gross atmospheric N route is canonically admitted through PR1330.** This is the requested final closure review, not a declaration that the completion criteria all passed. No capability is promoted merely because its development branch has been merged.

The existing work-unit authority is `integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json`. The master remains the single capability register on PR1072, branch `work/swap431-master-coverage-20261006`, reviewed at `d77939e08b841fc0456d76a883450f4f15a9c099`. It is not a file on current canonical. Review receipt `962cd60ad7b170432d363d821e6c4f223b6dfd08` corrects the nine bounded production-reachability records on that same master branch, leaves all234 other rows equal and preserves every disposition/count. It claims no new whole-master qualification. Its nine MC-NUT01 rows are all ACTIVE_MIGRATION. The matrix below is a report derived from those exact rows, not a second registry.

The original atmospheric information deficit is resolved in the new positive historical gross-forcing route by an explicit independent N carrier. Original management_soil lines400..402 constructs gross atmospheric water input separately from evaporation. The admitted aggregate Soil-N owner receives one signed net surface-water carrier. Equal net water can correspond to different gross N inputs. The historical counterexample remains documented in [the original-source witness](MC_NUT01_HIST_GROSS_NET_BLOCKER_20261018.md). The programme owner selected original gross loading/order/aggregate ponding on20October. [The qualified successor](MC_NUT01_HISTORICAL_GROSS_TOP_CONTRACT_20261020.md) supplies that aggregate independently of accepted net soil water. Negative aggregate and automatic original atmospheric-producer/ponded application binding remain unqualified; a corrected surface-N store is not introduced.

Additional incomplete historical envelope: unrestricted TTUTIL constructs, fractional timestamps and extended diagnostics; no complete original-model multiyear comparison. These are recorded separately from the gross-carrier blocker. Material definition labels and bounded experimental humus are already admitted and must not remain listed as missing.

## Historical authority and corrections

The immutable archive is `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`. Original input interpretation additionally uses `SWAP431_TTUTIL_AUTHORITY.zip.b64`, decoded SHA256 `ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`. The caller-clock archive is `SWAP431_HUMUS_CLOCK_AUTHORITY.tar.xz.b64`, decoded SHA256 `eb2c33d8a93cd46ea175f964d768bc4bcbef04a5b9ff1f0f88cc5882632c3959`.

| Capability | Original archive member | SHA256 |
| --- | --- | --- |
| SW431-NUT-ORGANIC | `SWAP/wofost_soil_orgmatn.f90` | `85146e95249b41ed9b5202b507cb1647784592a313e36e75010da9bbf9a733f6` |
| SW431-NUT-MINERAL | `SWAP/wofost_soil_watern.f90` | `b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722` |
| SW431-NUT-AMEND | `SWAP/wofost_soil_amendments.f90` | `157caa9b6feafcd16f9505099874f0a8f56bc81618667d5acdafc17e40735df9` |
| SW431-NUT-RESIDUE | `SWAP/wofost_soil_cropresidues.f90` | `1f5d61e97d4a5d1dae7be604f0ed67ce5a780471d7db35236dbb0dc27d1ff8e9` |
| SW431-NUT-CROP | `SWAP/management_soil.f90` | `0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b` |
| SW431-NUT-NITRIF | `SWAP/wofost_soil_rateconstants.f90` | `0d869c9acbf290b731c2e7344a0a9df7413eba4da44dcd48d124da994f4adcc6` |
| SW431-NUT-DENIT | `SWAP/wofost_soil_rateconstants.f90` | `0d869c9acbf290b731c2e7344a0a9df7413eba4da44dcd48d124da994f4adcc6` |
| SW431-NUT-TRANSPORT | `SWAP/wofost_soil_watern.f90` | `b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722` |
| SW431-NUT-NFIX | `SWAP/wofostnut.f90` | `071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2` |

Authority is historical SWAP4.3.1 as pinned in these archives, with explicitly registered corrected-reference decisions. It is not unrestricted literal B0 equivalence. In particular:

* MC-NUT01-R1 corrects the duplicated Bio term in the organic mineralisation coefficient. The defect witness and one-line transform remain immutable.
* Retained-stock follows its admitted corrected B1.12 contract, while growth ownership remains the admitted WOFOST81 path. This is not proof of the complete original crop trajectory.
* The original seepage reader mistakenly assigns the nitrate-seepage field to the lateral field. The independent B0/B1 reader witness distinguishes the defect from the one-target correction; distinct current boundary parameters are preserved.
* A rejected residue fraction up to eight spacings below its lower boundary is projected only with an exactly booked NH4 compensation. No external N is manufactured, and larger deviations remain rejected.
* Original TimeControl advances before SoilManagement. The humus experiment therefore tests the interval endpoint against its start date, with the original strict daily rate threshold above 1e-6.

See [native rotation](MC_NUT01_HIST_NATIVE_ROTATION_20261018.md), [atmospheric qualification](MC_NUT01_HIST_ATMOSPHERIC_N_QUALIFICATION_20261018.md), [humus qualification](MC_NUT01_HIST_HUMUS_QUALIFICATION_20261018.md) and [material labels](MC_NUT01_NATIVE_MATERIAL_LABELS_20261018.md) for their exact bounded authorities.

## Capability matrix

Every row below retains the master disposition. ADMITTED in the facet column refers only to its versioned bounded admission. None is a whole-row ADMITTED claim. For all nine rows, native coupled restart, daily atomic failure and actual water/crop composition are covered only within the respective owning profiles. No QUALIFICATION_ONLY, SUPERSEDED or NOT_APPLICABLE row is invented to remove a remaining historical requirement.

| Master capability | Master status | Facet status | Meaning | Historical member | Current owner/interface | Input/configuration | Numerical and historical evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SW431-NUT-ORGANIC | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | Eight FOM pools, biomass/humus, mineralisation and immobilisation | `SWAP/wofost_soil_orgmatn.f90` | `src/process/mod_b111_soil_n_reactive_owner.f90` | Initial FOM/Bio/Hum and N/C fractions; reference/environment rates; optional dated humus rate | Literal original orgmatn/rateconstants with registered R1 correction; source endpoints; 730-day humus/rotation |
| SW431-NUT-MINERAL | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | Owned NH4/NO3, sorption and finite supply | `SWAP/wofost_soil_watern.f90` | `src/process/mod_b111_soil_n_mineral_owner.f90` | Initial NH4/NO3, density/depth, sorption, boundary concentrations | Original analytical watern; low/ample/exhausted-supply drivers; atmospheric/rotation endpoints |
| SW431-NUT-AMEND | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | Fertiliser/manure, volatilisation and dated repeated events | `SWAP/wofost_soil_amendments.f90` | `src/crop/mod_crop_soil_n_calendar_day.f90` | Native SNM materials, iMat positions, dates, kg/ha dosage and volatilisation | Original amendments and independent TTUTIL; same-date/fallow/year transitions |
| SW431-NUT-RESIDUE | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | Returned, retained and pending residues; harvest export | `SWAP/wofost_soil_cropresidues.f90` | `src/crop/mod_crop_soil_n_senescence_day.f90` | Corrected B1.12 return/retention policy and source residue ages | Retained/thermal/empty/TCS6 old bytes; two harvests; conservative eight-spacing edge correction |
| SW431-NUT-CROP | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | Source-selected crop demand, uptake and daily ownership | `SWAP/management_soil.f90` | `src/crop/mod_crop_soil_n_day.f90` | SWCROPSNM=1 with admitted classical crop selection, source parameters and active crop state | B1.11 vegetative and bounded reproductive request/apply; actual Richards/WOFOST81; finite N and fallow |
| SW431-NUT-NITRIF | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | NH4 oxidation as an internal N transfer | `SWAP/wofost_soil_rateconstants.f90` | `src/process/mod_b111_soil_n_daily_exchange.f90` | RateConNitr_ref and temperature/moisture environment | Original analytical NH4/NO3 exchange plus full original chemistry |
| SW431-NUT-DENIT | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | Nitrate gaseous loss with moisture/temperature/respiration | `SWAP/wofost_soil_rateconstants.f90` | `src/process/mod_b111_soil_n_reactive_owner.f90` | RateConDenitr_ref, WFPS thresholds and dissimilation response | Original rateconstants and chemistry; external gaseous loss in daily/whole budget |
| SW431-NUT-TRANSPORT | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | Analytical concentration, uptake and signed boundary exchange | `SWAP/wofost_soil_watern.f90` | `src/process/mod_b111_soil_n_transport.f90` | Accepted full-column daily water carrier, root uptake, bottom/lateral concentrations | Original watern plus actual Reference water; bounded top infiltration; gross/net counterexample limits full scope |
| SW431-NUT-NFIX | ACTIVE_MIGRATION | ADMITTED bounded facet; full envelope open | Biological fixation booked as crop input | `SWAP/wofostnut.f90` | `src/crop/mod_b111_nfixation_policy.f90` | Explicit admitted source fixation policy; actual crop demand/supply | Vegetative/reproductive source witnesses, whole-system budgets and native continuation |

Whole-envelope blockers attach principally to NUT-TRANSPORT, NUT-MINERAL and NUT-CROP through the atmospheric carrier, and to native input/application reachability where unsupported syntax is required. Organic, amendment, residue, nitrification, denitrification and fixation processes do exist and execute in admitted compositions. An old complete-absence statement cannot override those later admissions. The remaining envelope for each master row requires its own owner review before promotion.

Aquifer functionality is outside this work unit. RossFast remains limited to previously approved use. Surface-water age is not a dissolved NH4/NO3 inventory and cannot close the N carrier gap. No phosphorus or other new biogeochemical model is inferred from the generic word nutrients.

## Stores, equations and accounting

The authoritative Soil-N hierarchy owns eight FOM organic-matter pools, microbial biomass, humus, NH4 and NO3. Organic N is derived from the organic stores, their immutable N fractions and column depth. Crop N belongs to the crop owner; retained and pending residues remain inside the joint inventory until incorporation/export. Crop quantities in kg/ha convert to kg/m2 by 1e-4. Organic density is kg/m3 and depth is m; accepted hydraulic storage/flux diagnostics use cm, with explicit conversion to the chemical m/day carrier.

For total element accounting define:

`N_total = N_organic_soil + NH4 + NO3 + N_crop + N_retained + N_pending`.

`R_N = N_initial + N_external_input - N_external_output - N_final`.

Internal mineralisation, immobilisation, nitrification, soil-to-crop uptake, translocation and residue incorporation cancel in this total. They must never appear as unexplained net production or destruction of total N. Compartment budgets retain them with opposite signs. In particular, nitrification debits NH4 and credits NO3; denitrification is a genuine external gaseous loss.

The original analytical transport/exchange uses water storage, sorption capacity, outflow, boundary concentrations and finite crop request. Organic first-order turnover is temperature/moisture adjusted, with source respiration modifying denitrification. The exact source equations and reference transformation remain in the pinned original routines and production providers listed above; they are not replaced by a new approximate reaction model in this report.

| Route | Source | Store/transfer | External sink or internal destination |
| --- | --- | --- | --- |
| Initial conditions | Native named FOM/Bio/Hum/NH4/NO3 | Initial authoritative soil stocks | Neither a subsequent input nor a reset at crop transition |
| Mineral/organic amendments | Dated material, dosage and fractions | Organic pools and NH4/NO3 | Volatilisation booked separately; gross input counted once |
| Atmospheric/bottom/lateral dissolved input | Accepted bounded carrier times source concentration | NH4/NO3 | Qualified top infiltration only; general gross atmosphere open |
| Organic turnover | Existing organic N | Mineral pool or other organic pool | Internal; denitrification separately external |
| Crop uptake | Soil NH4/NO3 | Crop organs | Internal to whole system; exact soil debit equals crop receipt |
| Fixation | External atmospheric N | Crop N | External input exactly once |
| Death/harvest | Crop N | Retained/pending returned material | Export is external; returned/incorporated fraction internal |
| Drainage/lower outflow | Soil solution | Boundary receipt | External N output; no invented balancing water |
| Successor establishment | Explicit initial successor inventory | New crop | Explicit external seed N, not an unbooked replacement |
| Retry/restart | Previous committed state | Complete serialized owners and cumulative ledgers | No repeated source event or flux publication |

The source-full calendar owns event progress. It does not reapply an event both through native input and through the coupled day. Chemical fallow advances soil/calendar state without fabricating crop uptake. Crop demand uses the accepted active crop and its source policy, development/biomass state, actual water uptake and available soil N. Harvest, death and successor transitions use the existing retained/pending owners.

### Tolerances

The production pool transfer applies `abs(residual) <= 1e-12 * scale`, where `scale=max(1,abs(N_before),abs(N_after),external_input,external_output)`, in kg/m2. The floor means this is an absolute 1e-12 kg/m2 gate for the sub-unit inventories shown here, not a purely relative threshold. The integrated daily whole-N driver uses 1e-12 kg/m2 and the 730-day cumulative driver 1e-10 kg/m2. The accepted water closure is 1e-10 cm. None was relaxed.

These double-precision gates allow arithmetic accumulation while constraining physical loss: the cumulative N allowance equals 1e-6 kg/ha. Observed residuals are far smaller. Relative residuals below are reporting diagnostics defined as `abs(R_N)/(N_initial+N_external_input)`; they are not alternative acceptance gates.

## Executed model results versus fixtures

The actual coupled driver is `tests/nut-crop/test_b112_retained_joint.f90`, run through `run_hist_complete.py`. It compiles 323 production providers at O0/O2, executes Reference Richards water and actual WOFOST81/Soil-N daily transactions, and retains five endpoint families: default, source124 and three 730-day rotations. Temperature, radiation/daylength and groundwater exchange are controlled synthetic forcing. This is a complete coupled contract calculation, not a calibrated field prediction or a complete SWAP4.3.1 multiyear replay.

The rotations grow a first crop for120 days, harvest with returned/retained residues, advance chemical fallow, establish a successor on day365, harvest again on day500, and continue chemistry to730. Six events include simultaneous dates, fallow amendments and year boundaries. Lateral flux is zero in these long scenarios; lateral/drain transport assertions belong to the separate bounded physical drivers, not to a falsely claimed nonzero longrun drainage case.

| 730-day profile | Initial N | External input | External output | Final N | Absolute residual kg/m2 | Relative residual | Internal uptake kg/m2 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Original zero-top rotation | 0.6656915305925469 | 0.09708924930446881 | 0.012370661578694379 | 0.7504101183183204 | 9.957312752106873e-16 | 1.3054e-15 | 0.007091920030277561 |
| Atmospheric | 0.66569153059254693 | 0.013678071059048533 | 0.0077548447218841101 | 0.67161475692971284 | 1.5178830414797062e-15 | 2.2343e-15 | 0.006862902053561642 |
| Atmospheric plus experimental humus | 0.66569153059254693 | 0.013678065024113333 | 0.007819175844226128 | 0.67155041977243912 | 5.03417e-15 | 7.4101e-15 | 0.006862910133890103 |

Values and original signed residuals are recorded in the source-bound archives/status. Recombining rounded displayed columns can differ by final floating-point rounding. Separate raw NH4/NO3/FOM/Bio/Hum observations and native states remain in those archives; these aggregate budgets do not establish unqualified process combinations.

Humus whole-system maximum daily N residual is 2.50127e-15 kg/m2. Atmospheric maximum is 1.6548815150939063e-15 kg/m2. Cumulative water storage goes from10.377346899380083 to10.377421237280426 cm, with signed top input0.00006194825028434364 cm, bottom input28.164960854763596 cm, outflow0.4650182252684006 cm, root extraction27.699930239845116 cm and residual1.7763568394002505e-14 cm. Water content spans0.3313437794793025 to0.4039759894671573; head spans-91.01662183697339 to-22.17468522605584 cm.

For the humus profile the explicit N routes are: gross amendments0.009642, volatilisation0.0004965, top dissolved input4.650389582411417e-5, bottom dissolved input8.449488256429077e-4, lateral input0, other soil output0.002325934383678155, fixation0.00274461230264632, harvest export0.004996741460547970 and successor seed0.0004 kg/m2. Internal uptake is excluded from external output.

The numerical trajectory has14025 accepted substeps,60584 temporal rejection/retries, zero solver rejections, minimum accepted step3.814697265625e-6 day and maximum normalized temporal indicator0.9999596991660622. This is observed controlled-case evidence, not a general runtime claim. The original imposed drying stress with bottom flux-0.1 still fails on day67; it is retained as failed evidence.

Independent process fixtures include original analytical chemistry/transport, finite low/ample/exhausted crop supply, TTUTIL interpretation, input rejection and the gross/net counterexample. They complement rather than replace the real coupled calculations. No complete historical multiyear regression result exists to report.

## Rollback and restart

The latest label-qualified production round preserves exact O0/O2 observables and all five original endpoints. Six fresh-process restart splits, after days1,120,121,365,366,500, for each of three730-day profiles and two optimizations give36 complete transition continuations. Every resumed endpoint is byte-identical to the uninterrupted endpoint, including private stocks and cumulative source/sink/crop ledgers, not just final total N.

Serialized states before/after rejected days120 and366 match exactly, followed by an accepted retry. Atmospheric/humus runs also reject incompatible clean-only top identities. Separate owner tests cover rejected water and chemistry paths, invalid identities/configuration and corrupted/truncated native payloads. Persistent joint restart uses the existing codec and immutable parameter vector; absent new optional parameters preserve old bytes. No new owner or schema was added by this review.

## Admission lineage and integrated evidence

| PR | Bounded contribution | Canonical merge / evidence |
| --- | --- | --- |
| 1253 | Vegetative source request binding | Existing retained workstream authority and preservation |
| 1277 | Corrected B1.12 retained stock | c60185dbda371c66e4b8f18b4d8c8c068bca00ff |
| 1290,1291 | Source-full and source calendar | Existing canonical workstream records; no reimplementation |
| 1301 |31-day actual coupled source run |15aaf51769a578d63fc67f2c61b03b06fd8f99fa; run39079887061 |
| 1313 | Native input and730-day rotation |8bf52bf23277d193039ea5162e7100b6889bc7c0; runs39149147667,39149147864,39149147694,39149147687 |
| 1314 | Bounded atmospheric N |01a053f93f9c6548278df503a4cfea5424c84fce; runs39154014408,39154015051,39154014477 |
| 1316 | Humus clock and conservative residue edge |829bfabade71a3e3156914275d2b3fdc65c29112; runs39159565340,39159565393,39159565482 |
| 1319 | Historical positional material labels |03daf601446ba1bdc56c6d436fb09fbc904ea66b; local execution6f151ccf7ecd40010de0b14c896a72371cf5ce83 |
| 1321 | Later current-source preservation reconciliation |6153b5407dcb22a1f800b5359c39c3c12e9b8959; automatic runs39168835957,39168836087,39168835956,39168835969,39168835955 |

The last row is later integrated governance/preservation evidence, not a fresh full N model qualification. A green automatic canonical selection job is not a full F-CI96 numerical run. Historical N/retained/thermal/TCS6 and literal source qualifications remain bound to their recorded dependencies. Full moving F-CI and new RossFast/highest-low-air campaigns are not selected by this documentation-only review.

Latest physical O0/O2 label round costs: compile393.446 s, link0.806 s, main native185.891 s, fresh restarts157.118 s. Humus original round also freshly ran retained/thermal/empty and all54 TCS6 native trajectories. The archives retain failed/cancelled attempts and the default-stack SIGSEGV diagnosis; only the unchanged executable with unlimited stack is counted successful.

## Review executed on 19 October 2026

Current canonical was resolved through the GitHub connector. PR1301 and PR1319 merge status were read directly. A local clone at exactly the same canonical SHA was available and read without altering its source. The23-commit delta from PR1319 to reviewed canonical contains no production or reference changes; shared evidence-dispatch changes are the later registered CI preservation layer.

Fresh checks completed in this review:

* SHA256 verification of physical humus, retained humus, latest material-label and gross/net-witness decoded capsules.
* Original management and watern source identities, including the exact separate evaporation/gross-water assignments.
* All18 incumbent historical evidence-corruption controls.
* All9 registered material-label corruption controls, including current source/driver inputs, original native outputs, checked compile inventory, missing restarts and rollback-byte corruption.

Documentation source checks and strict MkDocs build pass (18.68 seconds). Raw control outputs, the failed full-wrapper traceback, archive identity checks and documentation logs are retained in `integration/audits/evidence/MC_NUT01_FINAL_REVIEW_20261019.tar.xz.b64`, decoded SHA256 `a6e9b0f0276538f0545b48dcd7f21c88b56466a0841b3401bf3f9b01a9b2c7c1`.

These checks revalidate archived executed evidence; they do not rerun Fortran. The full current source/admission wrapper could not run locally because its required ancestor `b27a646928c73d334fd11f54b74b7f12cc0064a4` is absent from the shallow local history. That attempt is FAILED/INCOMPLETE, never PASS. The direct git network route also failed authentication. GNU Fortran is unavailable on PATH and the workspace filesystem is full; no new O0/O2 compilation or model execution is claimed. The archived admitted O0/O2 calculations above remain historical results with checked inputs, not new local runs.

## Remaining blockers and next admissible action

1. **Scientific gross atmospheric N carrier.** The original source uses gross precipitation/snow/irrigation/interception/runon/runoff with evaporation separate, and explicitly questions ponding. At4 mm rain plus4 mm evaporation, the original diagnostic inputs0.8 kg N/ha while a zero net carrier inputs zero. The owner selected the original gross route. The positive independent source carrier now passes original analytical/full chemistry and actual730-day Reference/WOFOST81/Soil-N O0/O2,48 fresh-process transition continuations and atomic hydraulic/chemical rollback. The remaining limit is negative aggregate and automatic original atmospheric-producer/ponded application binding; it is no longer an undecided B0/B1 reference choice. Passing gross rain as net water violates water closure. Invented drainage and treating age as N are rejected alternatives.
2. **Historical input envelope.** Fractional timestamps and general TTUTIL constructs remain unsupported. Bounded native arrays/tables, material positions, daily dates and humus options are admitted. Required versus intentionally excluded grammar must be decided against actual historical inputs; no arbitrary universal parser is authorized here.
3. **Extended diagnostics and complete original-model regression.** These are not evidence of missing N process formulas, but the complete historical claim remains unproven. Extended output must not be silently marked NOT_APPLICABLE. No fabricated complete SWAP4.3.1 multiyear comparison is supplied.

The existing master dispositions remain unchanged. The old total-absence text is stale and must point to the bounded admissions. This report records a concrete blocked full closure while preserving all independently admitted functionality; it does not transfer the atmospheric scientific choice to MC-SOL01 pond-age work.

## Reproduction

Use the exact archived input hashes and the existing work-unit selection record. Existing commands and environment:

```bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export PYTHONDONTWRITEBYTECODE=1
python tests/nut-crop/verify_hist_native_successor.py --self-test
python tests/nut-crop/verify_hist_native_successor.py
```

For fresh numerical qualification use the admitted GNU Fortran13 toolchain; generate the reproductive literal with `tests/nut-crop/run_reproductive_process.py` and `REPRODUCTIVE_PROCESS_RESULT_DIR`, then run `tests/nut-crop/run_hist_complete.py` with fresh `N_HIST_RESULT_DIR` and `REPRODUCTIVE_LITERAL_FILE`. The native and original-reader runners use `N_NATIVE_RESULT_DIR` and `TTUTIL_RESULT_DIR`; follow the exact source-bound reproduction instructions in the native-rotation document. The gross/net witness uses `N_CARRIER_GAP_RESULT_DIR` with `integration/audits/run_nut_hist_carrier_gap.py`.

A full source-history checkout, all named immutable capsules, adequate storage and the recorded compiler/flags are prerequisites. Source hashes alone do not replace native output, and a fixture PASS cannot authorize full model equivalence.

The definitive reviewed science commit is `e122ff8f682584620717e97ab24ce07933dd0923`. Any later documentation merge is an administrative review receipt, not a new scientific admission or full MC-NUT01 closure.

## Canonical review admission receipt

Review PR1322 merged at `4719ed47b0ed8a35830a206b0bf00014aae84f7c`. The merged diff contains only this document, current-status/traceability navigation, the existing work-unit record and the additive final-review evidence capsule. Exact-ref postmerge retrieval confirms the blocked whole-HIST flags and the source-bound evidence receipt. Final document source checks and strict MkDocs build passed again in20.74 seconds. No hosted workflows were created for this documentation review merge; no new integrated numerical PASS is inferred. The original reviewed scientific commit remains `e122ff8f682584620717e97ab24ce07933dd0923`. Full MC-NUT01 remains scientifically blocked as stated above.

## Historical gross top successor,20 October2026

The programme owner selected option1, preservation of original gross atmospheric
loading and original aggregate ponding convention. The new optional forcing in
the existing seven NUT owner/runtime modules solves the demonstrated equal-rain/
evaporation information deficit within the explicit nonnegative aggregate domain.
Existing accepted soil-water traces remain sole water authority.

Fresh GNU13.3 O0/O2 passes all18 direct mineral and9 original full-chemistry cases,
the new730-day gross rotation and all old default/source124/three730-day cases.
All10 old endpoints remain exact, all48 transition continuations match, rejected
actual water and N trials preserve complete serialized state, and the retained/
thermal/empty/54TCS6 native preservation suite passes.

New whole N budget kg/m2: initial0.66569153059254693 +input0.019448273121288662
-output0.0080723769466728382 -final0.67706742676716480 =
-1.9931972738973514e-15; relative2.90918329820151e-15.
Maximum daily N residual1.8432074324546384e-15kg/m2; water-step maximum
4.986462631695332e-15cm. The new endpoint is
`f43aff865026e2f26337c7c87c1c8f5446346492539de2dcaf709304ee2b33af`.
Gross top input alone is58.4kg N/ha over730days, booked once.

Exact source, toolchain, costs, inputs, raw native/restart/rollback payloads,
remaining limits and reproduction are in
[the successor contract and receipt](MC_NUT01_HISTORICAL_GROSS_TOP_CONTRACT_20261020.md)
and `historical_gross_top_successor` in the existing status record.
No whole-master disposition or unrestricted historical claim follows.

## Actual canonical admission and remaining negative-source boundary

PR1330 merged at `d118bcf1cacf7462cf62c27141cf306d7a4a52fb`, qualified head
`071c8214ca957d39505262f2321a45f165581080`, complete reviewed/merged tree
`661da011d0c276ea878707149feff7e5cb0dabdd`, production tree
`a60ac1d96c98f3ecc7c414fc412884271a54b227`.
The current owning qualifier passes again on the actual merge. Concurrent
PR1329's opt-in solute-column tree at21cc8098 is preserved in full. The strict
predecessor pointer is therefore21cc8098, with unchanged nutrient science;
original d443dced remains the initial implementation baseline.
Master PR1072 receipt `ccdcccb9ab787d81a03864a7e5477e3be99f8298` adds this bounded
admission to the nine existing NUT rows;234 other rows and all dispositions
are preserved. No full-HIST promotion.

Final source/evidence, corruption-control, postmerge and docs receipts are in
`integration/audits/evidence/MC_NUT01_HISTORICAL_GROSS_TOP_CONTROLS_20261020.tar.xz.b64`,
decoded SHA256
`91c0c4ad03549aa4f612556304d3e69da3f21c1091a54511c31a890e4112009c`.

The additional diagnostic compiles unmodified original watern at O0/O2 and
reproduces the same outputs. It passes a negative top aggregate-0.004m/day
and c_top0.005kg N/m3 at constant0.3water fraction in a0.3m column:

| Initial N kg/m2 | Specified top N transfer kg/m2 | Original final N kg/m2 | N residual kg/m2 |
| --- | --- | --- | --- |
| 0.002 | -0.00002 | 0.00198 | 0 |
| 0.00000001 | -0.00002 | 0.00000000000009 | -0.00001999000009 |

The second original solution clips concentration to1e-12kg/m3 without making
the specified external extraction consistent with the available inventory.
The residual is approximately0.1999kg N/ha, rather than roundoff.
This is a conditional source-routine counterexample, not proof that the full
historical hydrology actually produces that forcing. Its full caller reachability
remains unqualified. Literal reproduction of that depleted result conflicts with
the hard element balance. No unbooked clipping, manufactured N or corrected
surface store is introduced; negative aggregate remains fail-closed.
The diagnostic source, full original routine, compiler commands, native outputs
and result are retained in the control capsule. It is not a new production PASS.
