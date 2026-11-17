# Proposed unified local wetting numerical policy

**Functional selected scope tested; scientific equivalence NOT_QUALIFIED;
not canonically admitted.** This package proposes one explicit policy for
above-ground irrigation and rain, rather than changing registered defaults.
Target base: `f0e5e39ea3d166755e394700a5a8765700eab875`.

## Implementation and contract

Select `original-adaptive-local-wetting-v1` explicitly using
`--experimental-time-step-policy`. The original TimeControl bounds actual net
rain plus active gross irrigation supply to 0.02 cm per proposed step and
retains duration/2048 during subdaily irrigation. It samples fresh rain after
Meteo3 and does not seed a new day from yesterday's rain. Original DTMAX,
DTMIN, event ordering and rejected-step reduction remain in force.

The same policy bounds positive accepted theta change to 0.002 per cell,
including internal redistribution. Exceedance uses the original `fldecdt`
rollback before Integral3; inability to resolve at DTMIN refuses execution.
This is an explicit numerical resolution setting, not a change to existing
mass, nonlinear or scientific acceptance tolerances, and not a demonstrated
general truncation-error estimator. No calendar or fixture-specific switch,
new saved history, hidden instance state or restart format is introduced.
Metadata binds the policy, settings and generated source. Missing, foreign,
corrupt and cross-policy restarts are refused. Frost/snow and active macropores
are outside this experimental policy. Existing defaults remain unchanged.

## Actual completed evidence

The two explicit Hupsel-derived surface/runon/hysteresis variants exercise
water and water plus solute, short irrigation and the 50.2 mm storm. They are
test variants, not new unmodified historical project acceptances.

Windows GNU 16.2 and Ubuntu 26.04 each completed O0/O2 for both variants:
**8 full 1096-day trajectories, 8768 committed day records**. Each full profile
has eight exact own cold-start windows: 2→4, 4→6, 199→201, 211→213,
213→215, 365→367, 530→532 and 1094→1096. All **64 full-period windows**
preserve physical records, CSV and native payloads exactly, with unchanged
saved origin. Short 215-day profiles precede the full runs. Independent
instance, refusal, discard/replay/recovery, accepted surface transactions and
forged native/metadata controls are retained in FINISH and raw observations.

Unchanged daily water guard: 1e-10 cm; solute: 1e-10 mg/cm². Maximum Windows
water residual is 1.469e-13 cm, solute 1.505e-12 mg/cm²; Ubuntu water
1.652e-13 cm, solute 1.569e-12 mg/cm². Each full profile records 341
rejected-step budget retries. No acceptance threshold was enlarged.

Hosted full source is `53db42ec5fdb015093592e00d3cd896ea649e390`, run
[44065892623](https://github.com/abhedwig-cell/SWAP5/actions/runs/44065892623),
terminal SUCCESS, artifact 14319519833, SHA256
`1e223f761ce4574b84bcbd1c103a3ce1c8d9fecd077996b156e4e087304b6f2c`.
RESULT/FINISH, generated Fortran, BUILD identities, actual inputs and raw
records bind each platform separately. This is selected qualification, not
a substitute for an unexecuted broad F-CI admission campaign.

Canonical independently added scheduled subsurface irrigation. Merge
`c02580924fe15364659eae1d2e68b650a33f7fef` reconciles that inactive branch.
`COMPOSITION_RESULT.json` proves current Windows emitted source, compiler and
physical dependency/input closure identical to the full-run builds, then
freshly verifies all four 215-day prefixes and 12 additional exact native
windows. No old executable or checkpoint was relabelled with a new identity.
Later commits change test/evidence files only. Ubuntu full evidence is bound
to its recorded source, not misreported as a later binary rebuild.

## Cost and unchanged original comparison

Full Windows O0/O2 trajectories take approximately 9–13 s; Ubuntu 4–6 s.
The selected runners enforce 30 s per full model and 20 s per literal original
reference. Windows original SWAP 4.3.1 takes 2.805 s (water) and 4.128 s
(solute), compared with selected SWAP5 O2 9.171 s and 9.606 s. These are
different execution/output architectures, not equal-cost solver benchmarks.
Paired prior pulse-policy O2 ratios are 1.065/0.952 on Windows and
1.391/1.378 on Ubuntu. They include output/checkpoint IO, whose cadence is
not identical between policies; no portable algorithm speed guarantee follows.

Literal original B0 full runs use the **actual executed worker input files**,
including output/end settings, with hashes checked before and after. All 1097
CSV rows are compared. Maximum GWL differences are **2.678132 cm on Windows
and 2.782673 cm on Ubuntu**, near saturation around day 364. Windows maximum
water-stock difference is 0.034312 cm; solute stock 0.010655 mg/cm². Original
failed comparisons remain failures. The selected policy gives Windows signed
GWL differences −0.097562 cm on day 5 and −0.162823 cm on day 215. It does
not establish full scientific equivalence or solve every earlier discrepancy.

The original-only matched-policy diagnostic still differs by up to 2.050366 cm.
Late original refinement changes day-364 GWL from nominal +0.011926 cm to
−3.435385/−3.807774 cm at DTMAX .004/.0004, with original day 0–362 exact.
These distinguish temporal/reference sensitivity but do **not** independently
qualify a replacement reference. They cannot erase the failed B0 comparison.
After two controller approaches, do not add another empirically tuned limiter.
`SUPPLY_ONLY_PREIMAGE.*` preserves the first approach and its failed comparison.

## Concrete open acceptance conditions

1. Scientific review must disposition the remaining saturation/GWL differences
   under the existing criteria, or establish an independently qualified reference.
   The present evidence does not support scientific PASS or default promotion.
2. Supported-heat qualification without observer interference remains open.
   The existing original read-only observer's completed 1096-day diagnostic
   satisfies the unchanged 1e-9 J/cm² conduction guard (cell 1.052e-12,
   global step 2.662e-12), but separately linking it perturbs physical results
   from day 585, even with the full run's checkpoint mode. Both attempts are
   preserved; no third observer repair or equality relaxation is claimed.
   Whole physical energy remains incomplete because required energy fluxes
   are absent; no zero advection or other invented energy is inserted.

The draft PR is the bounded deliverable. Neither open condition invalidates
the separately bound exact water/solute native tests, and neither is silently
converted into a qualified heat/scientific result.

## Reproduction and preservation

Use a prepared, validated original provider (`C:\SWAP5-RC2\provider` on this
Windows machine), Python and gfortran in PATH. In a fresh output directory:

```text
python -B tests/local_wetting/component.py --reference-work PROVIDER --output COMPONENT
python -B tests/local_wetting/run.py --reference-work PROVIDER --output OUT --phase short
python -B tests/local_wetting/run.py --reference-work PROVIDER --output OUT --phase full
python -B tests/local_wetting/finish.py --reference-work PROVIDER --output OUT
python -B tests/local_wetting/matched_reference.py --reference-work PROVIDER --output OUT
python -B tests/local_wetting/saturation_reference.py --reference-work PROVIDER --output OUT
python -B tests/local_wetting/compose.py --reference-work PROVIDER --prior OUT --output COMPOSED
```

Exact executed compile/link/start commands are in individual JSON reports and
BUILD files. The optional `heat.py` reproduction intentionally refuses
qualification on observer-induced trajectory change. It requires a fresh OUT
without existing heat2 directories. It is not a passing production heat gate.
Current docs source check and the focused prior-policy verifier and Hupsel
successor tests pass; these are preservation support, not new science coverage.

`FILES.json` maps original platform-relative paths to SHA256 assets in
`RAW-*.zip`; extract by that mapping. `SEAL.json` hashes archives/index and the
downloaded hosted artifact. Sources, inputs, daily records, CSV, original
comparisons, checkpoint capsules, controls and failed heat observations are
preserved. Compiler products/executables are omitted; BUILD retains their
identities and commands. The prior-controller archive remains separately sealed.

Coverage gain: the single explicit rain/irrigation policy executes both selected
full process combinations. Reliability: exact native/transaction/water/solute
contracts are tested, with heat and science limits above. Development return:
small shared policy, bounded seconds-long models, one refinement after the
first scientific failure; no broad repeat campaign. Next work is disposition
of these concrete open conditions, not rollout to unrelated configurations.
