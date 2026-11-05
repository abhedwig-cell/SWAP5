# Explicit Hupsel pressure and film numerical policy

Status: qualified Windows production candidate; cold POSIX admission pending.
The recovery and exact source scopes are
`integration/dataqual15_hupsel/ROOT_ACCURACY_PRODUCTION_RECOVERY_20261105.json`
and `ROOT_ACCURACY_PRODUCTION_SCOPE_20261105.json` in the same directory.

## Interface and numerical behavior

`SWAP5_ROOT_ACCURACY = 1` is an optional numerical SWP declaration for the
original Hupsel crop rotation. Missing or zero retains the original policy;
unknown values refuse before advancing. Physical root, oxygen, crop, soil,
weather, management and drainage values remain unchanged. The selected SWP
contains the byte-exact original prefix plus this explicit numerical declaration.
Its exact bytes are already bound by S5HR0004; switching numerical declarations
refuses the existing stream. No schema, physics parameter or persistent state
is added. Cross-version or cross-optimization restart portability is unqualified.

The serialized worker owns immutable per-instance numerical configuration and
resets it on initialization. Its guard refuses unsupported macropore, thermal,
snow/frost and alternative-solver combinations. MICRO requires configured
pressure-bracket accuracy before stopping its search; its separate final flux
certificate,500-iteration cap, demand cap and physical parameters stay unchanged.
The independent film kernel requires two consecutive successful relative1e-5
refinements within the existing24 levels, rejects nonfinite inputs and refuses
exhaustion. The existing mode1 and public optional-argument defaults retain their
old algorithms exactly. New provider mode3 selects the numerical refinement.

## Actual qualification

Checked Windows GNU Fortran16.2 O0 and O2 each rebuild all236 providers and
complete the original-initialized1096-day trajectory. Each has ten exact own
restart windows: both sides of four wet cuts,365-to367 and1095-to1096. Complete
restart bytes and every water/crop suffix row agree. Dormant crop suffixes must
be exactly empty when the uninterrupted trajectory has no corresponding rows.
Maximum independent water defect is4.443667656062189e-14cm; maximum solute defect
is9.6270422189626e-12mg/cm2. Cumulative closure and all typed stock/canopy checks
retain their original limits.

Each build passes37 real owner decoder controls,11 application corruption/input/
nonfinite refusals,6 actual public writer nonfinite refusals preserving prior
files, and2 numerical-profile input/unknown-selector refusals. Component builds
at O0/O2 compare64 original rooted film states against the frozen old and
refined algorithms, pressure searches against the registered precise predicate,
and actual nonfinite/cap failures. Default outputs are exact to the frozen
algorithms; the refined route preserves the separate final flux certificate.
Current shared-runtime and registered thermal preservation are separately
checked. The unrelated canonical joint crop/soil-N CRC owner is absent from
this actual236-provider closure; all provider source hashes remain exact after
#1564/#1565 reconciliation. An unnecessary duplicate prefix was stopped, with
its cause and elapsed/CPU retained. It is not a second full completion.

The same37 immutable original comparisons yield36 passes. Day584 oxygen error
is0.00024467966173205916cm against the unchanged5.371840000016327e-7cm bound.
This failure remains explicit; no physical calibration or tolerance change is
made to follow the underqualified original trajectory. Whole-scientific
admission stays false. Across Grassgrowth, Hupsel and Andelst the counts remain
2/3 complete original trajectories and0/3 whole-scientifically qualified.
