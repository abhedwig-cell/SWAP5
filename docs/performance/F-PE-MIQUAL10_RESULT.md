# F-PE-MIQUAL10 result — serialized manager zero-waste candidate A

Date: 2026-10-01

Status:

`MIQUAL10_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`

Qualification authority:

- workflow run: `36827610701`;
- job: `110256713373`;
- workflow conclusion: SUCCESS.

Canonical authority at final interpretation:

`integration/f-ci-canonical@243f43cccd817c1bb175f14faa64efd574d6d3ca`

The canonical delta since MIQUAL10 start is PPA-WU05A9 macropore top-input work. It does not alter the moving-interface adapter/manager physics and is outside the MIQUAL10 no-macropore eligibility envelope.

## Candidate A

Removed two classes of per-manager-call heap allocation:

1. temporary saturated-state logical vector in tail detection;
2. temporary tail pressure/water-content reconstruction arrays.

Tail reconstruction scratch is now adapter-owned persistent storage, reallocated only on shape change. Saturated-tail detection now uses allocation-free scalar scanning.

No physics, eligibility, tolerance, fallback or publication contract changed.

## Preservation

The full MIQUAL06 serialized seam gate passes after the change.

Verified again:

- default route remains full;
- explicit manager route remains reduced;
- n=16 full state -> n=13 reduced solve;
- full-shape publication;
- typed full bypass;
- Z43F fallback/rollback/no-leak smoke preserved.

## Performance remeasurement

The unchanged MIQUAL09 paired 40,000-interval benchmark was rerun.

Baseline MIQUAL09:

- median wall ratio: 1.05538;
- geometric-mean wall ratio: 1.05594;
- median CPU ratio: 1.05532;
- deterministic work ratio: 0.8125.

Candidate A:

- median wall ratio: 1.04677;
- geometric-mean wall ratio: 1.04743;
- median CPU ratio: 1.04669;
- deterministic work ratio: 0.8125.

Thus candidate A recovers approximately 0.86 percentage point of wall overhead and approximately 0.86 percentage point of CPU overhead.

The manager remains about 4.7% slower than LEGACY on this equilibrium serialized benchmark.

## Interpretation

The eliminated heap churn was a real contributor, but not the dominant one.

Candidate A removes a measurable part of runtime overhead while preserving exact semantics. It does not recover net speedup.

The next zero-waste targets remain:

- repeated zero source/sink scans;
- repeated copying of known-zero source/sink arrays into reduced scratch;
- repeated source/sink provider rebinding;
- remaining reduced-request/candidate copy overhead.

## Classification

`MIQUAL10_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`

## Consequence

Open a separate candidate B workunit. Do not fold additional optimizations into MIQUAL10 after exposure.

## Production boundary

No default change.

`LEGACY_NUMERICS` remains production default.
