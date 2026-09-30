# F-PE-NLGLOB14Z36 closeout — compact holdout and timing qualification

Date: 2026-09-30

Final status:

`QUALIFIED_Z36_COMPACT_HOLDOUT_READY_FOR_FORTRAN_TIMING`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z36 closes positively.

The frozen four-case heterogeneous holdout passes 4/4 with:

- exact full/reduced physical agreement under the frozen gates;
- O05, O14 and B12 material coverage;
- n=12 and n=13 reduced dimensions;
- zero fallback-required cases;
- mean deterministic work ratio `0.796875`.

The structural work benefit therefore survives beyond the single O05 smoke.

## Timing conclusion

The local Python microbenchmark is slightly slower for the reduced route, with mean reduced/full timing ratio about `1.0185`.

This timing is explicitly non-production and is dominated by Python/reconstruction overhead.

It is not evidence against the manager and should not be optimized further.

Do not open another Python performance workunit.

## Direct successor

Open:

`F-PE-NLGLOB14Z37 — compiled Fortran manager timing qualification`.

The successor should be a focused compiled benchmark using the existing Z34/Z35 manager seam.

Freeze:

- a small fixed case set derived from Z36;
- full and reduced paths in one executable;
- warm-up and measured repetition counts;
- manager/reconstruction overhead included;
- active-dimension and work diagnostics.

Primary question:

does the structural ~20% nonlinear-work reduction become measurable wall-clock benefit in compiled production-shaped execution?

No long trajectory campaign is required for Z37.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z36

BRANCH: `research/f-pe-nlglob14z36-compact-holdout-timing`

RESULT POSTIMAGE BEFORE CLOSEOUT: `6f08848b09b982d28761b7878e764229051e6872`

QUALIFICATION STATUS: `QUALIFIED_Z36_COMPACT_HOLDOUT_READY_FOR_FORTRAN_TIMING`

NEXT SAFE STEP: Z37 compiled Fortran manager timing qualification.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
