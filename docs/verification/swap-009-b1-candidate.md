# SWAP-009 B1 candidate

SWAP-009 is a high-severity PDI hydraulic implementation bug prepared for, but not yet admitted to, the corrected SWAP 4.3.1 reference.

## Defect

The four PDI conductivity functions pass `abs(h)` to `Kvap_func`. The helper uses the supplied pressure head directly in the Kelvin exponent. Unsaturated pressure head is negative, so the absolute value reverses the exponent sign and can produce relative humidity greater than one.

The minimal correction passes signed `h` unchanged in `K_PDI`, `K_PDI_s`, `K_PDI_2` and `K_PDI_2_s`.

## Why this is a bugfix rather than model development

The Kelvin relation is already implemented in SWAP and expects the physical pressure-head sign. The patch does not introduce a new constitutive equation or parameter. It makes the PDI callers obey the existing relation. The central audit register therefore classifies SWAP-009 as `FIX_TESTED`, certainty very high, severity high.

## Evidence

The existing hydraulic/theory test reports old/corrected vapor-term ratios of approximately 1.16 at `h=-1e5 cm`, 4.26 at `-1e6 cm` and `1.99e6` at `-1e7 cm` near 20 degrees C. The defect therefore becomes large in the very dry range.

The candidate dossier records the canonical B0 target SHA, exact stored patch SHA measured after upload, deterministic corrected-target SHA and a fail-closed byte-safe verifier.

## Admission boundary

Because this correction changes physically active PDI conductivity, it is not being appended to B1 merely from the static audit result. Admission remains pending:

- independent PASS of the repaired B1.5p1 identity gate;
- rerun/recovery of the exact PDI hydraulic testbank on the candidate;
- a representative full PDI production-path regression;
- hard water-balance evidence for that regression.

Until those gates pass, `b1-manifest.yml` remains unchanged and SWAP-009 is only a candidate.
