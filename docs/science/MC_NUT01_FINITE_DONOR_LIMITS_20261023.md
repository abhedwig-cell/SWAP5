# Finite-donor regular coefficient limits

Qualified numerical extension candidate of MC-NUT01's admitted finite-donor fallow route.
Baseline: `d6f52d935c0bee6039051fe4e4a7b810df507822`. The existing
HIST-COMPLETE record owns recovery; no full migration or admission is implied.

The admitted SWAP-020 equation is retained, including nonnegative production,
linear NH4 sorption, concentration-dependent outflow and reaction loss, and
bounded prescribed top extraction after exhaustion. There is no new competing
sink allocation. Active crops, immobilisation and automatic surface binding
remain outside this change.

Previously nonzero h or h1 below 1e-8, or a small nonzero h-h1, were rejected.
These are regular limits of `(s+h*t) dC/dt = -h1*C + P-E`, where
`s=theta0+rho*K`. The extension evaluates the same equation by a convergent
power series after scaling time to [0,1]. It is selected for those previously rejected coefficients and for nonzero
coefficients with max(abs(h*dt/s),abs(h1*dt/s)) at most 1e-5, where the
old quotients demonstrably lose precision. Both scaled magnitudes must be at
most 1/8 for any new series evaluation. Sixty-four terms give a rapidly convergent series in this bounded domain.
No small coefficient is rounded away by this new route. Existing roundoff-only
h1 cancellation remains unchanged. The diagnostic solution class is 6.

The homogeneous coefficients satisfy
`a[n]=-(y+(n-1)*x)*a[n-1]/n`, a[0]=1. The forcing coefficients start at
d[0]=0,d[1]=1 and obey the same recurrence thereafter. Summing these series gives
the endpoint; dividing each term by n+1 gives the concentration time integral.
The existing independent exhaustion-time bisection and actual/unmet extraction
books use these coefficients unchanged. The original 84-case matrix and default positive transport procedure retain
their calculations. Previously accepted near-limit values may intentionally
change: the preimage returned a concentration average about 1.11e-6 instead of
2.25e-10 for a depleted, unsorbed donor with h=0,h1=1e-7. This is numerical
cancellation, not a new physical allocation rule. Independent ODE and mass
books must qualify the corrected values.

Affected invariants:3,7,13,21,23,25,26,30. No interface, persistent state,
restart schema, solver tolerance, hydraulic code or reference archive changes.

Selected validation: fresh GNU13 O0/O2 direct production driver, independent
high-accuracy ODE and event-time oracle, near-limit sorption/source/stock matrix,
original 84-case byte equality, default-route byte equality, and mineral
owner balance/restart checks. Follow with the existing HIST physical owner if
the affected consumer preservation is selected. Broad F-CI, highest low-air and
RossFast are not selected by a single analytical branch extension. Canonical
admission requires separately reconciled source/evidence ownership; no stored
predecessor evidence may be relabelled as newly compiled evidence.


Local result:516 production O0/O2 cases pass the independent ODE/event oracle,
including461 previously rejected cases and39 corrected previously accepted limit
cases. Maximum field error is9.992007221626409e-16; maximum mass residual is
1.3877787807814457e-17kgN/m2. The original84-case matrix and default-route output
remain byte-exact. Twelve mineral-owner intervals per optimization pass opaque
restart, invalid-input rollback and independent mass closure.

Fresh affected HIST O0/O2 passes with56 separate-process continuations. Existing
finite-donor coupled qualification passes four runs and eight independent-process
restarts against the unchanged corrected reference. HIST compilation227.603s,
link0.668s,native13.651s,restart34.921s; other gates retain their own receipts.
The initial native attempt exhausted the default stack and returned -11. Exact
successful compilation receipts were reused with verified source/object hashes;
the failed attempt was retained and all original assertions completed with64MiB
stack. No failed event counts as PASS.

Evidence and local claims are recorded in
`integration/mc-nut01/MC_NUT01_REGULAR_LIMITS_LOCAL_20261023.json` and its capsule.
This is locally tested code awaiting source/evidence admission reconciliation.
The existing163 historical-output corruption controls are not claimed as newly
executed. Automatic approval review initially rejected branch publication. The user then
explicitly authorized publishing this change as a draft PR. Canonical admission
is still pending. Current canonical21871ca changes HeadCalc through PERF01;
the earlier native tests do not qualify that new composition. Active competing sinks remain explicitly excluded.


## Current canonical composition qualification

PR1391 is now qualified against canonical93c46252, including its admitted
HeadCalc repair. Two changed HeadCalc O0/O2 compilations were fresh;652 unchanged
provider compilation receipts were reused only after exact source,flags and
object/module checks. All78 HIST native/trace/restart processes ran freshly,
including56 separate-process continuations. Complete original HIST results
remain exact. Existing finite-donor joint qualification adds four fresh coupled
runs and eight fresh continuations; all physical endpoints and journals equal
the earlier qualified result. Fresh HeadCalc compilation3.457s,link0.807s,
HIST native14.503s,restart36.362s; inherited compilation is not summed as fresh.

The18 predecessor corruption assertions stay unchanged and pass through the
new bounded source owner. Fifteen new source/raw controls give33 current controls.
The original163 output controls were also re-executed on exact original188f
source, with their own baseline and result retained in the new capsule. This
is not a claim that163 old native runs were repeated on the new source.
Current output/PERF/general authority and FSI35 registry entrypoints pass.
No numerical assertion or physical threshold was weakened.

Additional SOL accuracy replay exposed an existing absolute-command-path
assumption. With explicit recorded-command anchoring, every original scientific
assessment assertion passes and all live source/raw observations are exact.
The wrapper's final bitwise summary equality still fails:20 derived fields differ
by at most3.553e-15. Both failures remain recorded, not PASS. The previously
accepted SOL evidence is inherited for its unchanged source and observations;
no new SOL accuracy claim follows and no SOL runner was modified.

The current receipt is
`integration/mc-nut01/MC_NUT01_REGULAR_LIMITS_QUALIFICATION_20261023.json`.
The finite-donor/source/current-composition capsule is indexed at
`integration/audits/evidence/mc-nut01-regular-limits-composition-20261023/INDEX.json`.
Canonical admission and actual-merge verification remain separate from this
qualification. Full MC-NUT01,active competing sinks,immobilisation and automatic
snow/persistent-surface binding remain open; all master dispositions stay fixed.


### Latest seasonal admission reconciliation

Canonicalf729f0b/PR1392 added the481-day seasonal native caller while PR1391
was being finalized. Its shared SRC is exact to93c46252. Every recorded input
of both completed current NUT native closures remains byte-exact, so these
numerical runs are inherited without repetition. The NUT source hook now sits
on the newest seasonal owner, preserving all30 existing assertions;15 new
NUT corruption controls give45 combined controls. The SAT/native/history/
calendar owners retain canonical PR1392 bytes. All current owner entrypoints
and the FSI35 registry are rechecked on the composed candidate. Earlier33-control
and original163-control receipts keep their recorded scopes.
