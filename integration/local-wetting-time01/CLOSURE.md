# PR1701 follow-up: repaired heat reproducibility and bounded GWL diagnosis

## Current decision

The heat-observation blocker is **repaired and tested** on Windows/Ubuntu O0/O2.
The 2.8 cm nominal groundwater comparison is **causally explained as temporal
and history sensitivity**, but the original failed criterion is **not converted
to PASS**. The opt-in policy is not a demonstrated groundwater-error estimator.
PR1701 remains draft: an independently accurate, mass-qualified reference is
still required for scientific acceptance. No original tolerance was enlarged.

## Actual defect and repair

Poisoning only unfilled original lookup entries, then running the real model,
refuses on day562 at clock37817.027744980369, H=−19509.494434557197 cm:
interpolation row429 reads **K_table(430,1), which was never initialized**.
The original dry interval can also read row431 outside the populated table.
Extra heat-accounting allocations exposed this pre-existing undefined state;
removing or relinking the heat calculation did not reliably cure it. Those
failed attempts, including the otherwise unchanged binary repeat, are retained.

`micro_lookup_state.py` now completes the original trapezoidal integral at its
declared −20000 cm lower limit using the same `watcon`/`hconduc` functions.
It initializes the real conductivity endpoints and handles the final partial
logarithmic interval with its actual coordinate. Unused allocation tails have
defined values. Neither constitutive parameters nor original nonlinear,
conservation or scientific thresholds change.

The native lookup header advances to version2 and saves/restores all431 used
M and K rows instead of430/429. The metadata policy becomes
`original-complete-dry-end-micro-top-oxygen-v4`. Old bundles/checkpoints are
explicitly refused; they cannot be rebound to this correction. The correction
uses the existing explicit-state owner; no new generic state framework or
instance-global physical cache is added.

The O0/O2 contract driver calls the actual initialized private lookup at the
exact wilt boundary, final partial interval, logarithmic grid boundary and
the witnessed failing pressure, plus the original below-wilt zero branch.
It checks finite, nonnegative, ordered values and an unchanged586-day physical
prefix. Both profiles pass. This is real initialized-model execution, not a
copied formula. The first215-day probe had not reached the microscopic crop
and correctly did not establish this contract; that failed selection is retained.

## Complete verification and costs

Corrected selected water/solute variants complete Windows/Ubuntu O0/O2:
8×1096 days, 8768 committed records,64 exact own cold restart windows. These
are fresh affected trajectories; the previous v3 results are not relabelled.
Unchanged1e-10 water/solute guards pass. Windows maximum water residual is
1.405e-13 cm and solute1.505e-12 mg/cm². Windows full runs take8.97–11.39 s;
Ubuntu4.54–5.98 s. Every full model remains below its30 s bound.

The **same original heat observer that exposed the problem** now leaves every
physical daily record exactly unchanged in all8 complete profiles. It passes
the existing1e-9 J/cm² numerical conduction budget: maximum global step
residual2.345e-12 Windows and2.936e-12 Ubuntu. No workaround that hides the
old failure is selected. Passive/link-wrapper alternatives remain diagnostic
failed attempts. Missing mass-carried physical energy is still unknown; whole
physical energy completeness remains false.

Ubuntu run[44080859947](https://github.com/abhedwig-cell/SWAP5/actions/runs/44080859947)
at c3a0a7e17 passes all full/native/reference/transaction steps but terminates
FAILURE because the new heat runner used a Windows-only kernel executable name.
The source-independent path correction uses the existing executable resolver.
Run[44081632203](https://github.com/abhedwig-cell/SWAP5/actions/runs/44081632203)
at999474ea3 recovers that exact artifact, validates matching provider/bundles,
and completes all four heat profiles with SUCCESS. Successful full runs are
not repeated for this test-path correction. Original failed platform output is
preserved under a distinct name. Artifact SHA256 values are in ASSESSMENT/SEAL.

Windows short builds began before source persistence; their actual generated
source and micro-owner SHA match the persisted physical snapshot at c3a0a7e17.
BUILD identities are authoritative; the earlier RESULT start-commit field is
not rewritten. Full/heat/reference commands and per-platform binaries retain
their own exact identities. Later changes are verification/documentation only.

## Groundwater: distinguishing results and remaining boundary

The dry lookup defect first occurs on562, whereas maximum groundwater difference
is on364. Repairing it therefore does **not** claim to remove that earlier
2.678132 cm Windows /2.782673 cm Ubuntu nominal-B0 difference.

Only the final three days are refined; the first362 days remain exact within
each execution family. Original-only day364 GWL changes from nominal+0.011926
cm to−3.833672,−3.837333 and−3.843162 cm at caps1e-4,2.5e-5 and6.25e-6 day.
Those model runs take3.25,4.98 and14.88 s. The last reference's BALDEV is
−1.515e-7 cm, outside the unchanged1e-10 mass criterion: it is not a qualified
replacement oracle. Refining SWAP5's same three-day interval gives−3.589151 /
−3.601118 cm at1e-4 /2.5e-5 day, with its strict balances retained.

To distinguish different prehistory from physics, an additional bounded test
transfers the actual saved day362 binary state into original431 and compares
the same final three days. `SWINITYPE=2` explicitly selects binary reading.
The wholly past fixed-irrigation table is explicitly disabled in this separate
diagnostic because the original reader refuses it; both actual three-day
irrigation histories are zero. This is **not literal executed-input equality**
and does not replace the full literal-input B0 comparisons. Initial water and
pond stocks agree exactly; the initially recomputed GWL differs0.001341 cm.

With that shared saved state, day364 GWL differences are **0.006547 cm** at
1e-4 day and **−0.000069638363 cm** at2.5e-5 day. The latter original and
SWAP5 outputs are−3.601048403241 /−3.601118041604 cm. The committed recipe
reproduces these latter values. This supports time/history sensitivity as the
cause of the2.8 cm endpoint discrepancy, rather than a new2.8 cm constitutive
error. It does not certify all transferred legacy history or universal accuracy.

The original common-state BALDEV values still reach−8.435e-7 cm. Thus this
strong causal result remains **NOT_QUALIFIED** under the existing mass/science
criteria. No finer empirical production limiter, date-specific production cap,
relaxed guard, or tuned match to nominal B0 is introduced. Further model
parameter tuning is unjustified until an independently mass-qualified temporal
reference exists. That is the concrete remaining scientific acceptance blocker.

## Evidence and reproduction

`closure/ASSESSMENT.json`, `VERIFIED.json`, platform RESULT/FINISH/HEAT,
OLD_STATE_REFUSAL and the content-addressed RAW archives retain all successful,
failed and censored observations. `closure/FILES.json` maps raw paths to assets;
SEAL hashes the archives/index and recovered hosted artifact. Full binaries and
compiler products are omitted; their SHA/compile/link commands are retained.

Use a validated original provider, fresh output directories and gfortran in PATH:

```text
python -B tests/local_wetting/run.py --reference-work PROVIDER --output OUT --phase short
python -B tests/local_wetting/run.py --reference-work PROVIDER --output OUT --phase full
python -B tests/local_wetting/heat.py --reference-work PROVIDER --output OUT
python -B tests/local_wetting/finish.py --reference-work PROVIDER --output OUT
python -B tests/local_wetting/lookup_endpoints.py --reference-work PROVIDER --prior OUT --output ENDPOINTS
python -B tests/local_wetting/candidate_saturation.py --reference-work PROVIDER --prior OUT --output CANDIDATE_REFINE
python -B tests/local_wetting/saturation_reference.py --reference-work PROVIDER --prior OUT --output REFERENCE_REFINE --caps 0.0001 0.000025 0.00000625
python -B tests/local_wetting/common_saturation.py --prior OUT --candidate-build CANDIDATE_REFINE/dt000025-build --reference-exe REFERENCE_REFINE/late-reference-2p5e-05-build/original_late_refinement.exe --output COMMON --no-current-irrigation
python -B tests/local_wetting/verify_evidence.py integration/local-wetting-time01/closure
```

Coverage: both selected full process combinations retained. Reliability: the
undefined dry endpoint and incomplete saved lookup domain are repaired,64 own
windows and8 nonperturbing complete heat observations pass. Development return:
one small shared-owner repair after a discriminating poisoned-read witness;
seconds-long causal trials, successful platform runs reused. Whole science and
unrelated canonical admission are not promoted. Current canonical's independent
subsurface-solute work is outside this tested physical snapshot; no merge or
canonical postimage qualification is claimed by this draft PR.
