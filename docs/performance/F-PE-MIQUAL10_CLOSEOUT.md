# F-PE-MIQUAL10 closeout — serialized manager zero-waste candidate A

Date: 2026-10-01

Final status:

`MIQUAL10_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`

Candidate A is semantically clean and measurably faster than the original adapter, but still slower than LEGACY.

Baseline manager penalty:

about +5.5%.

After candidate A:

about +4.7%.

The improvement is reproducible in both wall and CPU ratios, so the removed heap allocation was real overhead.

Direct successor:

`F-PE-MIQUAL11 — zero-source/sink invariant runtime optimization`.

Candidate B should move zero-source/sink eligibility work out of the repeated manager solve path and avoid copying known-zero arrays on every full/half/half solve.

All manager physics and MIQUAL09 benchmark inputs remain frozen.

Production default remains `LEGACY_NUMERICS`.
