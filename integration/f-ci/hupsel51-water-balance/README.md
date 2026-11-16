# Closed undrained Hupsel: coupled pond Jacobian

Status: Windows and Ubuntu26.04 full-period, O0/O2 and native restart qualification PASS on the composed runtime source recorded in WINDOWS.json and UBUNTU.json. PR1686 targets integration/f-ci-canonical; canonical admission is not claimed. This is an explicit experimental-input successor, not a replacement RC2 package or a whole-scientific PASS.

## Problem and implementation

The unchanged guard rejects reactive undrained Hupsel day51 at1.000099586478953e-10cm. The original HeadCalc recomputes pond through the original linear PondRunoff equation, but its top-row Jacobian differentiates as if pond were fixed. For a closed saturated profile, that is a poorly conditioned/slow iteration. Original dtmin nonconvergence can continue without solving the candidate balance; strict conservation must not inherit that acceptance.

With lagged conductivity, define c=Ktop/disnod, p=dt*c and r=dt/RSRO when pond>PONDMX, otherwise r=0. Eliminating the original scalar pond-storage/runoff equation gives the top contribution c*(1+r)/(1+p+r), rather than c. Only this derivative changes. Physical residuals, retention curves, top/bottom forcing, runoff, roots, chemistry, tolerances and all checkpoints remain under their existing owners.

Activation is limited to explicit experimental SWMACRO0/SWSNOW0/SWDRA0/SWBOTB6/SWKIMPL0 projects and the actual ponded linear RSROEXP1 branch with RSRO>=0.001. The atmosphere/head, nonlinear-runoff, macro and other-boundary branches retain their original tangent. This eligibility is not a qualification claim for every untested option combination. The three registered release source images are unchanged.

## Windows execution and exact continuation

The original Hupsel inputs are copied with only the declared synthetic changes: SWDRA0, SWSP1, SWDC1 and DECPOT0.001/day in both layers. Every original date, weather record, crop, remaining parameter and numerical policy stays fixed. This is a hypothetical reactive-solute test, not a field calibration.

- Generated donor/kernel O2: full1096 accepted days; exact own50â†’52 and530â†’532.
- Generated donor/kernel O0: full1096 accepted days; exact own50â†’52 and530â†’532. The immutable original provider remains O2.
- Every physical journal field and printed continuation record is exact. The entire native result.end and auxiliary macro.bin endpoint payloads are byte-exact. Accepted origins remain unchanged.
- The actual Fortran tangent matches a complex-step derivative of the original scalar PondRunoff equation in36 cases per optimization. Maximum relative arithmetic error is2.77e-15; the fixed-pond Jacobian's relative error reaches40. This diagnostic threshold is not a physical balance tolerance.
- Grassgrowth1827, registered Hupsel1096 and SaltFarm1461 complete with exact native own windows. All physical daily fields are byte-for-value equal to the retained RC2 results; their6/12/12 generated original units are also byte-identical. No frozen package files change.

O2 maximum daily independent water error: 2.3109292257573e-13cm; kernel water: 2.3225865675158e-13cm; solute: 1.1316295123187e-13mg/cmÂ². The guards remain1e-10cm and1e-10mg/cmÂ². Sum of daily water residues: 3.1970948512292e-12cm, reported separately from the daily limit. Day51 now has an independent residual of1.0200174038743626e-14cm.

The full O2 model/controller observation is 4.614s; O0 is 5.173s. Build time is separate. These are single observations, not accuracy-matched or statistical performance qualification. All final model checks have a60s wall cap.

## Targeted original comparison

Unmodified original SWAP4.3.1 uses byte-identical executed input. Its earlier60s-capped run retains336 complete days and is reused; it is not relabeled a full reference PASS. Original day51 printed BALDEV is5.873903714537e-7cm. Full common-field comparisons and the large remaining groundwater/storage differences remain explicit in WINDOWS.json. No scientific acceptance boundary is changed to accept them.

A separate diagnostic executes the original program with only the same analytic pond tangent added, retaining original time control and loose convergence behavior. It completes1096 days in2.743s. This distinguishes the missing coupled derivative from SWAP5 daily-host overhead, but is explicitly a corrected numerical control, not pristine4.3.1 or an independently qualified scientific reference. Its mass behavior and remaining differences are recorded, not hidden.

Whole scientific equivalence, original oxygen criteria and independently validated heat/energy limits retain their existing status. Exact native thermal restart is not an independent complete physical energy-balance proof.

## Reproduction and evidence

Use the ordinary source-only provider preparation, then:

```powershell
python -B tools/solute/check_closed_pond_jacobian.py --reference-work C:\SWAP5-RC2\provider --output C:\SWAP5-testing\fresh-component
python -B tools/solute/check_hupsel51_repair.py --reference-work C:\SWAP5-RC2\provider --output C:\SWAP5-testing\fresh-O2 --model-cap 60
python -B tools/solute/check_hupsel51_repair.py --suite O0 --reference-work C:\SWAP5-RC2\provider --output C:\SWAP5-testing\fresh-O0 --model-cap 60
python -B tools/solute/check_hupsel51_repair.py --suite named --reference-work C:\SWAP5-RC2\provider --output C:\SWAP5-testing\fresh-named --model-cap 60
```

Put the same qualified GNU toolchain on PATH. Use fresh output directories. WINDOWS_RAW.json binds the compact WINDOWS_RAW.zip containing actual inputs, emitted code, executable identities, full journals/CSVs, native checkpoints and reference outputs. Source/object/compiler/writer hashes remain in BUILD.json. No checkpoint is rebound to another source. The focused Ubuntu workflow creates a fresh original provider on that platform.

The rejected receipt-only approaches are preserved by their commits and local raw trials. They are absent from production source. The temporary CSV test offset defect was fixed by accounting for both the header and initial-state record; failed harness verdicts were not used to claim physical model failures or successes. Current qualification reruns use the corrected test and the composed source.

## Terminal CI adjudication

The source-bound Ubuntu26.04 run [43844795787](https://github.com/abhedwig-cell/SWAP5/actions/runs/43844795787) passed every step: actual tangent O0/O2, full undrained1096 at both profiles, exact own native continuations and all three complete named cases. UBUNTU_RAW.zip preserves the exact uploaded artifact, verified against GitHub's SHA256 digest. The head source is6e2cd26f873f9a935af92816a2f1d947df9293c7; its tested PR-merge tree isff58bbb4955e5d34b1a505df2e07dfdcfb992863. Final evidence-only changes do not alter the recorded runtime dependency surface.

General F-CI43844795754 and MC-SOL column43844795879 remain red at frozen source-authority checks. CI_ADJUDICATION.json reproduces both exact first failing predicates on canonical parent3fb625da73031885624987d42ad922cb184c96e5 and the repair source: `application source differs from tested head` and `unreviewed delta`. Both guards are byte-identical across those refs and already fail on the parent, before reaching any new model test. They are not weakened or falsely reported as global CI PASS. Existing root-oxygen and the other completed affected contracts pass separately.

## Current CI selection for PR1686

The frozen F-CI and surface-age guards remain byte unchanged. Their first
source predicates also fail on canonical3fb625da7, as retained in
CI_ADJUDICATION.json. They are historical authorities, not evidence of a
new physical regression. The current workflow uses a narrowly bounded
PR1686 successor: exact runtime6e2cd26f, sealed proof4ee0e08b, unchanged
1e-10 water/solute limits, all full periods and native own-restart windows.
Only three literal current-workflow forwarding insertions are permitted; the
old bodies, predicates and proof capsules are not repinned or rewritten.
Unknown source changes or altered sealed proofs are refused. F-CI still runs
the six current physical contracts; MC-SOL still builds and executes its
actual column/file/restart tests at both optimizations before preservation.
This selection is not whole-science admission and does not repair or hide
the original failed science comparisons. The former red runs remain visible.
