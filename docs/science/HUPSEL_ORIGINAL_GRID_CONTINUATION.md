# Original oxygen grid and nonlinear input controls

This bounded work unit extends the PR1526 original accepted-chronology evidence.
It qualifies actual original-source input variations and their published data;
it does not qualify a replacement oracle or a physical SWAP5 correction.

Four fresh original trajectories start from initialization and end on day584.
The original executable and six physical input files are bound to the sealed
parent. Only the registered DTMAX and prefix TEND change in the legacy cases.
The stronger-criteria cases additionally use the five original convergence
inputs already exercised in the parent's strict-balance control. Original
SWKIMPL0, root physics, iteration/retry limits and production settings remain
unchanged. No checkpoint or synthesized continuation is used.

| DTMAX (day) | Original criteria oxygen on584 (cm) | Stronger criteria oxygen on584 (cm) |
|---|---:|---:|
|0.000078125|0.003387737174|0.003387732492|
|0.0000390625|0.003362952709|0.003362967866|

The previous original0.00015625 prefix reports0.003453844588cm. The next two
legacy grid changes are6.6107414e-5 and2.4784465e-5cm. The stronger-criteria
grid change is2.4764626e-5cm. Both finest-grid changes remain about46 times
the unchanged5.371840000016327e-7cm oxygen limit. On these grids the largest
oxygen response to the stronger input criteria is1.5157e-8cm. The original
adaptive sequence can respond to the criteria, so these are coupled input
responses, not an isolated causal term or a rigorous error estimate.

All four complete585 daily records and19890 primitive profile rows per run.
Independent positive-sum stock reconstruction agrees with the original
12-decimal WTOT publication within5.116e-13cm. Its check uses the publication
rounding and floating-point summation certificate, not a relaxed model mass
tolerance. Forty corruptions/admission attempts are rejected, including
resealed physical-input changes, altered source identity, truncated output,
poisoned primitive stocks, foreign seeds and false completion/promotion.
Two further controls reject re-pinning the immutable parent archive or
transferring production admission to this diagnostic parent.

The original reported BALDEV remains separate from that publication check.
Its maximum absolute daily values are6.44349e-5 and1.3984133e-4cm for the
legacy cases and6.44948e-5 and1.4010263e-4cm for the stronger cases. Stricter
criteria reduce cumulative reported error but do not establish an exact mass
or oxygen reference. The raw balances, logs and original warnings are retained.

Measured execution times are280.64/494.88s and307.65/556.99s for legacy and
stronger cases respectively. The selection and expected costs were registered
before execution. Unchanged native/oxygen component qualifications are reused;
this input-only research does not relabel them as freshly executed.

The portable qualifier checks the complete source/input/output identities,
primitive stock publication, paired responses and all40 refusals. No
extrapolated value replaces the oracle, no frozen predecessor gate changes,
and whole scientific/production admission remain false. The next reference
accuracy decision must account for both temporal response and the original
reported balance; more grid-only work is not an automatic production fix.

Owning recovery: `integration/dataqual15_hupsel/ORIGINAL_CHRONOLOGY_RECOVERY_20261104.json`.
Evidence: `integration/dataqual15_hupsel/ORIGINAL_OXYGEN_GRID_EVIDENCE_20261104.json`.
