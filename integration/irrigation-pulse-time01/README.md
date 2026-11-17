# Local temporal resolution for short fixed irrigation pulses

Implemented and qualified for the selected water/chemical Hupsel-derived
runon/scheduled-pond/hysteresis configurations. Baseline canonical is
67ddba2692cc13f89cfc29100836f2d6a4b80eec. The new numerical policy is explicit:
`original-adaptive-irrigation-pulse-v1`. Registered release defaults, input
files, physical equations and existing scientific/mass thresholds are unchanged.
This PR does not claim whole scientific equivalence or change the frozen RC2.

## Behaviour and ownership

The prior source-bound investigation b473d1523 located the2.70681cm groundwater
difference on day5's two-hour24mm irrigation. The improved implicit-pond Newton
derivative accepted a coarse0.04day step which the old derivative rejected.
The old nonlinear failures supplied incidental temporal refinement. The repair
retains the correct derivative and adds explicit local temporal resolution.

During an active above-ground irrigation rate (`gird>0`) with original event
duration strictly between zero and one day, TimeControl caps the proposal at
`max(DTMIN, duration/2048)`. The cap is applied both to its initial case9
proposal and subsequent event limits. Original end-of-pulse, rain, runon,
output/day boundaries and rejection reductions remain in force. It never
increases a proposal or lowers DTMIN. Once the pulse ends, the normal original
adaptive growth resumes. Full-day/absent irrigation is unaffected; no new
subsurface-irrigation temporal claim is made.

2048 intervals resolve the demonstrated two-hour pulse at approximately the
shortest0.00004day diagnostic scale without imposing that scale on every day.
This is a bounded pulse-resolution policy, not a general error estimator or a
proof that2048 intervals suffice for every soil/input. A DTMIN-limited event
can have fewer intervals; its original minimum-step contract remains unchanged.
This scope is explicit experimental fixed irrigation without frost/snow or
active macropores. It introduces no automatic fallback or changed input.

The cap derives entirely from the already owned original rate, event duration
and clock. No persistent variable or new native layout is added. Existing
complete irrigation/native state therefore remains the owner of continuation.
The selected policy, generator, original TimeControl and emitted source hashes
are bound in BUILD.json and checked before use. Missing/foreign policy,
changed resolution and cross-policy checkpoints refuse; no old capsule is rebound.

## Completed verification

- Actual original TimeControl O0/O2 component: initial and subsequent pulse
  steps capped,2048 pulse intervals, original day closure, and large adaptive
  steps restored outside the pulse. Absent/full-day/no-surface-rate controls
  retain their proposals.
- Windows and Ubuntu: eight complete1096-day corrected trajectories,8768 days,
  plus short O0/O2 trials before full execution.48 full native windows are
  exact:2to4,4to6 across irrigation,199to201,365to367,530to532,1094to1096.
  Physical fields, CSV, result.end and macro.bin all match each own continuation;
  origins are unchanged. Equality is per build/profile, not a claim of exact
  Windows/Ubuntu or every O0/O2 forward trajectory.
- Per platform/profile: independent model instances, inconsistent-mass
  refusal without accepted publication, discard/replay, disk recovery and
  actual rehashed native-domain refusals. Additional pulse-day discard/replay
  and next-day disk recovery are exact. Three new metadata corruptions refuse.
- Maximum independent daily water residual across corrected full runs is
  2.8573844679247173e-13cm; maximum solute residual1.5393478456976126e-12mg/cm2.
  Both hard guards remain1e-10. All actual daily records and native payloads
  were independently reconsumed from the sealed raw artifacts.
- Four complete original431 comparisons (two cases per platform) use only
  declared actual worker input bytes, including native output mode2. Literal
  input hashes match before/after execution. No output or swap.ok is copied
  into a reference deck. Every comparison includes1097 records.
- Fresh paired O2 original-policy baselines complete both cases on each
  platform. On Windows their1097 physical CSV records and13/14 generated
  Fortran units are exact to admitted BLOCK_O. Comparing selected and baseline
  emitted sources, only timecontrol.f90 differs. No src/reference physics is
  changed; unaffected existing policy emission is retained.
- Existing ten current-owner negative test methods and documentation source
  checks pass. This focused policy qualification is not a claim that the old
  sealed current-runtime admission consumer admits a new source automatically.
  Historical source/proof guards and failed comparisons are not rewritten.

## Scientific comparison and model cost

On Windows, day5 groundwater difference from original431 changes from
-2.706810392011cm to-0.078500493035cm (about97.1% smaller); spurious day5 runoff
changes from0.190725404235cm to zero. The fully refined five-day diagnostic is
not relabelled as the original input reference: residual post-pulse temporal
effects remain when larger ordinary steps resume.

The complete corrected trajectory still differs from original431 by up to
1.399492693221cm GWL on day215,2002-08-03. Maximum water-stock difference is
about0.03646cm; chemical-stock difference is up to0.009681mg/cm2 across the
tested platforms. These remain diagnostic differences, not a scientific PASS.
Original oxygen, reference and nominal-runon accuracy failures remain visible.
No new scientific acceptance threshold has been introduced or relaxed.

| Paired O2 full1096 model runtime | Prior policy | Local pulse policy | Ratio |
|---|---:|---:|---:|
| Windows water |6.311s|6.122s|0.97|
| Windows chemical |7.028s|8.067s|1.15|
| Ubuntu water |2.342s|3.099s|1.32|
| Ubuntu chemical |2.340s|3.287s|1.40|

These are single paired measurements, including the same checkpoint schedule,
not portable speed guarantees or a repeated benchmark campaign. Every corrected
full run stays below9seconds in these observations and its30second wall cap.
Compile cost is recorded separately. The local accuracy improvement has a
measured overhead, particularly on Ubuntu; no global1000-fold time-step decrease
is used and no process is skipped to reduce cost.

## Sources, hosted continuation and evidence

Windows execution source535607d4c; Ubuntu full execution3b5c682da; Ubuntu
verification completionae2bc4592. Their app/src/reference/tools surfaces are
exact. Run44047914474 completed original component, short/full/native checks
but failed an additional test because it omitted the adapter's required explicit
`adopt_native=True` for a standalone native origin. The refusal was correct;
it was a test error, not a model failure. That run remains FAILED.

Run44048454336 is SUCCESS. It verified the unchanged executed dependency surface,
recovered the immutable prior artifact and completed only the missing reference,
transaction/pulse and paired-cost checks. Full successful trajectories were not
repeated for a test-only correction. ZIP executable permission restoration did
not change bytes; no source/build/native identity was rebound.

QUALIFICATION.json, WINDOWS/UBUNTU.json, WINDOWS_COMPONENT.json, HOSTED.json and
PRESERVATION.json identify actual sources, commands, executable/input hashes,
budgets and scientific disposition. ARCHIVES.json binds the raw ZIPs and every
member. The original hosted artifact SHA256 is
872b2924b6abec7f87bbd4f832c9e27a8e3c5a623e1799531a56b68061977e28.
Raw sources, complete daily logs, native payloads, reference results and
refusals are retained. Executables/objects/modules are omitted from the compact
versioned capsules, with their identities retained in build/test metadata.

## Reproduce

Use a source/compiler-validated original provider and a fresh output directory.
On Windows put C:/msys64/ucrt64/bin on PATH; on Ubuntu use python3.

```powershell
python -B tests/irrigation_pulse/component.py --reference-work C:\SWAP5-RC2\provider --output C:\SWAP5-testing\pulse-component-new
python -B tests/irrigation_pulse/run.py --reference-work C:\SWAP5-RC2\provider --output C:\SWAP5-testing\pulse-new --phase short
python -B tests/irrigation_pulse/run.py --reference-work C:\SWAP5-RC2\provider --output C:\SWAP5-testing\pulse-new --phase full
python -B tests/irrigation_pulse/finish.py --reference-work C:\SWAP5-RC2\provider --output C:\SWAP5-testing\pulse-new
```

For a direct build select the new policy explicitly:

```text
python -B tools/solute/run_water.py --model HYBRID_NOMACRO_WATER --experimental-project INPUT_DIRECTORY --experimental-time-step-policy original-adaptive-irrigation-pulse-v1 --reference-work PROVIDER --build-only --kernel-opt O2 --donor-opt O2 --output NEW_BUILD
```

The focused PR is the delivery boundary requested here. Admission into canonical
and any change of registered release defaults require their own explicit source
preservation/admission selection; this proof does not silently promote either.
