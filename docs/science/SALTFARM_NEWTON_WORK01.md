# SaltFarm Newton work: explicit conditional polishing

Proposed, not RC3: the registered SaltFarm numerical policy selects
`strict-water-half-interior-polish-v1`. Other projects retain
`strict-water-always-polish-v1`. Physical equations, original convergence,
maximum iterations, step limits and all acceptance tolerances are unchanged.
The build identity and checkpoint binding distinguish these policies.

The first original-converged Newton iterate must still pass the existing
strict cumulative water guard. An additional original Newton iterate is
retained when the residual exceeds half that guard. Inside that conservative
interior, padding is omitted. The factor one half is an explicit numerical
safety margin, not an independent error bound or a new scientific acceptance
threshold. Every completed day still passes the unchanged independent
`1e-10 cm` guard; there is no automatic fallback or acceptance of refused days.
This policy requires qualification of each application domain before selection.

The read-only 365-day RC3 trace reproduced all physical records and the native
day109 checkpoint exactly. Of35048 Newton iterations,9251 failed original
convergence,6743 failed strict mass convergence,9527 were padding and9527
were accepted. No original or mass rejection followed padding in this sample.
Nevertheless unconditional removal is unsafe: the short365-day probe passed,
but its continued trajectory refused day454 with independent residual
`1.0002533176733941e-10 cm`, while the projected guard was just inside its limit.
That failure is retained; no tolerance is widened. One conservative interior
candidate was selected instead of tuning a succession of margins.

The current candidate must pass fresh current-source O0/O2 full SaltFarm1461,
balances, exact own native/CSV/day restart, rollback and isolation, plus a
separate original431 comparison. RC3 and historical scientific dispositions
remain immutable. Current result and recovery authority:
`integration/f-ci/saltfarm-newton-work01/`.

## Completed Windows qualification

At code1841beb68, GNU16.2.0 on the owner's Windows laptop, both generated
donor routines and the SWAP5 kernel were compiled at O0 and O2. The immutable
original provider remains O2. Both complete1461day trajectories pass and are
exactly equal to each other. Each has exact physical records, printed CSV and
native `result.end`/`macro.bin` at109→111,365→367,453→455,1460→1461 and
109→1461. Original checkpoints remain unchanged. Actual external proposals
at453→454 pass discard/replay, separate-instance/native equality and foreign
numerical-policy refusal at both optimization levels.

| Measured work | Always polish | Interior policy |
| --- | ---: | ---: |
| Full Newton iterations |138089|110477|
| Full HeadCalc calls |38065|38065|
| First365 original-nonconverged iterations |9251|9251|
| First365 strict-mass rejected iterations |6743|6824|
| First365 forced extra iterations |9527|2679|

The full run saves27612iterations (19.996%). The short trajectory saves6848
padding iterations but requires81additional mass iterations: the remaining
mass work is retained, not bypassed. The2679padding iterations are a deliberately
retained safety margin; this experiment does not prove every one is physically
necessary. The actual current always-polish control reproduces RC3 physical
records exactly, and only generated `headcalc.f90` differs between current
control/candidate build sources.

Maximum daily water residual rises from2.960e-12 to5.107e-11cm, remaining below
the unchanged1e-10cm limit. Candidate cumulative signed daily residual is
2.0295e-8cm over1461days; maximum solute residual is7.656e-12mg/cm2, below
the unchanged1e-10mg/cm2 limit. These are actual independently checked ledgers,
not a claim of complete physical energy closure.

Sequential full-period ABBA timings were17.885/16.398/15.977/15.036seconds
(control/candidate/candidate/control). The mean wall reduction is1.66%; donor
CPU reduction is about2.3%. Large drift prevents a material or portable speed
claim. No new original431 run was needed: its verified identical-executed-input
reference was reused. Candidate versus current control maximum GWL change is
1.98668e-7cm; versus original431 the maximum is0.018153260320cm (control:
0.018153260030cm). The complete column comparison is sealed in `raw.zip`.
These descriptive differences establish no new scientific threshold. Existing
oxygen failures, underqualified references and whole-science NOT_QUALIFIED
remain visible. At this Windows checkpoint Ubuntu was not yet qualified; the completed
follow-up is below. Portable speedup remains unqualified.

## Reproduce without rebinding

Use the existing verified original provider or prepare one with the public
no-macro preparation command. From repository root, with GNU tools on PATH:

```powershell
python -B tools/solute/run_water.py --model HYBRID_SALTFARM_WATER --reference-work C:\SWAP5-testing\rc3-local01\provider --build-only --kernel-opt O2 --donor-opt O2 --no-macro-release --output C:\SWAP5-testing\newton-O2
python -B tests/saltfarm_newton/qualify.py --reference C:\SWAP5-testing\rc3-local01\provider --bundle C:\SWAP5-testing\newton-O2 --output C:\SWAP5-testing\newton-O2-accept
python -B tests/saltfarm_newton/verify_successor.py
```

Use new output directories; select both O0 flags for the O0 qualification.
The verifier reruns no models and recomputes full balances, trajectory lengths,
own restart/native/CSV equality, optimization equality, iteration totals and
original431 differences from actual sealed records. Full stdout remains in the
local recovery directory; versioned evidence retains daily records, native
checkpoints, CSV, counts, build/source identities and relevant diagnostic stdout.
This is a reviewable current-source numerical-policy proposal, not an update
of the fixed RC3 archive or its accepted scientific scope.

## Ubuntu and current-canonical composition

Production355559313 incorporates canonicalf2fc11124 without changing the
qualified SaltFarm mathematics. Fresh Windows O0/O2 runs repeat all1461days,
five own cold windows and actual external transactions. Their records remain
exactly equal to the preceding Windows candidate. Fresh Ubuntu26.04
run44328844150 compiles both generated donor and kernel O0/O2 from the pinned
original source ZIPs, starts with four-day public probes, and then passes both
full1461day trajectories, all ten own cold windows, native/CSV equality and
discard/replay/independent-instance controls. Ubuntu O0/O2 physical records are
exactly equal; no cross-platform bitwise native claim is made.

Ubuntu maximum water residual5.106084e-11cm and solute7.657819e-12mg/cm2 pass
their unchanged1e-10limits. Full model/controller times were6.053seconds O0
and4.644seconds O2, measured on that hosted runner; these are not paired speed
comparisons with Windows or original431. The original broad checkout was
canceled before any model ran. A sparse source checkout avoids fetching the
unrelated historical archive collection. No model test was duplicated for it.

`PORTABLE.json` binds current Windows records and the byte-exact Ubuntu artifact.
The scoped successor `tests/saltfarm_newton/verify_successor.py` recomputes the
actual full ledgers, cold/native/CSV comparisons and optimization identity.
It retains the literal preceding Snow/calendar owner and validates its schema
on the exact canonical source image, with unchanged archive bytes. This is
inherited canonical evidence, not a newly qualified old source under a new
name. Existing CI failures at the stale source boundary remain in
`CI_PREVIOUS.json`. `test_evidence.py` independently corrupts real daily,
native, source/build/policy and cold records and requires refusal.

The registered old reader/chemistry and F-CI entry points use this successor
only for its bounded new source. Neither historical failed comparisons nor
whole-science qualification are promoted. Fixed RC3 remains unchanged.
