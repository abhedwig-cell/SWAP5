# PPA-WU05B16: original SWDIVD1 reference-owner adjudication

## Qualified reference evidence

Full unchanged original B1.11 FrozenBounds and complete DIVDRA execute in independently built O0/O2 processes, with bounds and invalid/zero/overflow traps. All **4536** preregistered controlled cases execute with byte-identical output: single level, SWDRA1/SWDIVD1/SWMACRO0, signed/zero/tiny scalar and bottom rates, normal/low air, blocked/equality/surviving depth, separate-infiltration switch, two spacings and anisotropies. Initial actual DIVDRA materializes the raw nodal proposal before FrozenBounds.

An independent geometric/transmissivity integral checks both original nodal partitions (maximum difference 2.78e-17). This is source-process composition evidence, not a full legacy simulation or production runtime qualification. Reference and production bodies remain unchanged.

## Actual ownership

Positive nodal drainage is a sink; positive bottom flow is upward into the column. In low air, an unblocked non-tiny scalar becomes `raw + qbot`, and original DIVDRA rebuilds its nodal partition using frozen conductivity and `min(gwl,zfrostbot)`. Thus `qbot - drainage` equals `-raw`. Near-zero surviving scalar becomes `qbot`, so its net is zero. A fully blocked scalar and bottom become zero. Normal-air nodes retain their original partition multiplied by frost factors.

This is physical spatial redistribution with a separate bottom owner. The SWDIVD0 reporting-only defect and its correction do not apply by analogy. Source headcalc consumes qdra as a nodal sink; Integral separately accumulates qdrtot and qbot.

## Bounded numerical finding

1296 initial tiny-rate cases retain the original all-zero nodal proposal at the `abs(qdrain) <= 1e-10` early return. That domain remains separately visible and must fail closed for any later nonzero authoritative-scalar production binding.

192 final separate-infiltration cases show a small nodal/level residual, at most **2.43440267944095e-11** cm/day. Original DIVDRA omits a positive unsaturated transmissivity at `KDuns <= 1e-8`, although its denominator still includes that transmissivity. Independent conservative integration predicts the omitted contribution and closes within 2.78e-17. This is a demonstrated bounded numerical omission; no correction has been applied in B16. Under ADR-0005, the next unit must separately preregister and qualify a minimal reference overlay before corrected parity. The original scalar threshold, sign, geometry and FrozenBounds scalar/bottom transformation remain fixed.

## Evidence and limits

[Qualification](../../integration/audits/PPA_WU05B16_REFERENCE_OWNER_QUALIFICATION.json), [status](../../integration/audits/PPA_WU05B16_STATUS.json), and [immutable replay](evidence/PPA_WU05B16_REFERENCE_OWNER_REPLAY.json.gz) bind actual complete outputs, inputs, source bytes and executable hashes. All declared source cases completed. No hard-mass production admission, global frost equivalence, mixed/multilevel drainage or external frost is inferred. Aggregate frost migration remains open.
