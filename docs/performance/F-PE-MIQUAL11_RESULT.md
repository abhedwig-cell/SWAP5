# F-PE-MIQUAL11 result — zero-source/sink invariant optimization

Date: 2026-10-01

Status:

`MIQUAL11_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`

Qualification authority:

- workflow run: `36827995982`;
- job: `110257908543`;
- workflow conclusion: SUCCESS.

Canonical authority at final interpretation:

`integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

The canonical delta since MIQUAL10/11 is documentation/status-only PPA-WU05A9 closeout material and does not alter the MIQUAL11 runtime dependency surface.

## Candidate B

Candidate B preserves candidate A and changes only zero-source/sink runtime handling:

- validate zero source/sink once in serialized `prepare_interval`;
- persist an interval-owned zero-source eligibility bit;
- remove repeated zero-array scans from each manager solve;
- initialize reduced zero source/sink scratch only on allocation/shape change;
- do not recopy known-zero arrays for every full/half/half manager call.

No manager physics, reconstruction, tolerances, boundaries, fallback semantics or eligibility envelope changed.

## Preservation

The MIQUAL06 serialized seam gate remains green.

Verified again:

- default route remains full;
- explicit manager route remains reduced;
- n=16 full accepted state -> n=13 reduced solve;
- full-shape publication;
- typed full bypass;
- no fallback/bypass on the benchmark;
- exact physical equivalence.

## Performance remeasurement

The unchanged MIQUAL09 paired 40,000-interval benchmark was rerun.

Baseline MIQUAL09:

- median wall ratio: 1.05538;
- median CPU ratio: 1.05532.

Candidate A / MIQUAL10:

- median wall ratio: 1.04677;
- median CPU ratio: 1.04669.

Candidate B / MIQUAL11:

- median wall ratio: 1.03087;
- geometric-mean wall ratio: 1.03590;
- median CPU ratio: 1.03109;
- deterministic work ratio: 0.8125.

Thus candidate B recovers roughly another 1.6 percentage points of median wall overhead relative to candidate A, and roughly 2.45 percentage points relative to the original MIQUAL09 runtime.

The manager remains approximately 3.1% slower than LEGACY by median wall and CPU time on this equilibrium serialized benchmark.

One pair was favorable to MANAGER, but the preregistered aggregate remains clearly above 1.00. No pair is deleted or substituted.

## Interpretation

Repeated zero-source/sink checking and copying was a meaningful runtime cost.

However it is not the complete explanation for the remaining overhead.

At this point further blind micro-optimization is not justified. Remaining likely costs include:

- repeated reduced-request composition and base-state copying;
- repeated reduced constitutive-provider rebinding across full/half/half durations;
- full candidate rematerialization/copying;
- manager diagnostics/finalization;
- repeated eligibility/tail scanning;
- interaction with transaction full/half/half orchestration.

These contributors must be measured rather than guessed.

## Classification

`MIQUAL11_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`

## Consequence

Open:

`F-PE-MIQUAL12 — serialized manager component-cost attribution`.

MIQUAL12 should instrument the manager adapter path and measure cumulative CPU/wall contribution of:

1. eligibility and tail detection;
2. reduced request preparation;
3. reduced provider preparation/binding;
4. reduced nonlinear solve;
5. tail reconstruction and full rematerialization;
6. manager finalization/publication.

Instrumentation must be diagnostic-only and must preserve MIQUAL06 semantics.

## Production boundary

No default change.

`LEGACY_NUMERICS` remains production default.
