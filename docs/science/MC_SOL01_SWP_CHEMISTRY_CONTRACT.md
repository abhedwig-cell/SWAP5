# MC-SOL01 original SWP chemistry adapter

Canonically admitted bounded chemistry/grid route through PR1352 and PR1353. Full historical SWP/default orchestration remains outside scope.

The optional --swp route uses the archived original read_solute_CDE and original TTUTIL. Only its two global-context USE bindings change. The original AFGEN_2 and RDADORTB are retained. This imports chemistry and initial concentration into the existing production column. Explicit typed hydrology, forcing and numeric heat configuration remain required; this is not the complete historical default SWP application.

The original ISUBLAY/ISOILLAY/HSUBLAY/NCOMP table must match every explicit water-owner cell thickness. No interpolation of grid or hydrology is allowed. Chemical vectors follow original soil-layer indices. Internal-face dispersivity uses layer(i), as in original solute.f90 lines 321-326. Initial concentration follows original absolute-depth interpolation. Original BDENS in mg/cm3 is divided by 1000 and KF in cm3/mg multiplied by 1000, preserving their sorption product in the typed g/cm3 convention.

The admitted exponent domain remains 0.5 through 2. Aquifer, macropore, snow, analytic heat, time-varying bottom concentration, loose historical restart and unsupported crop branches fail before physical owners exist. SWHEA must agree with the explicit numeric heat owner. No new process equations or state owners are introduced.

Every SWP generation retains the exact input bytes and hash. A restart must supply the same SWP and executable. Existing no-SWP generations retain their original file inventory. Original TTUTIL is linked as a static archive; generated source, archived authority, compiler flags and all linked providers are recorded in the completed build.

Affected architecture invariants: 2, 3, 7, 9, 13, 21, 23, 25, 27, 29. Validation must include native original grammar, layered units and interpolation, invalid inputs, real production balances, fresh-process restart, and existing no-SWP preservation.

Original TTUTIL normalizes file names to lowercase. The launcher stages the exact bytes as input.swp and passes that relative name, so user directory case is preserved. Temporary native input indexes are removed before generation publication. Standard input is closed for batch execution; malformed input cannot wait for an interactive Enter. The original ZC/CML deprecation warning remains a warning. SWSBA is read by the original procedure but does not select historical output formatting in this application.

## Reproducible invocation

Build with tools/solute/build_column.py and run:

    python tools/solute/run_column.py --exe BUILD/swap5_solute_column --input examples/solute_column/positive_pond.nml --swp examples/solute_column/layered_chemistry.swp --output RESULT

Resume with the same executable, --input and --swp plus --restart PREVIOUS_RESULT.
The example imports two original soil layers with density 1300/1500 mg/cm3,
KF 0.0002/0.0004 cm3/mg and exponent 0.5. The explicit water/heat inputs remain
authoritative for hydrology and forcing.

Canonical reconciliation includes PERF01 PR1351 trace lifetime management at
c8b35ac3e9f2a2cf2400033d0225aea8198469ea. Both affected runtime providers are
rebuilt for the current application. Original thermal-pond, finite-donor and
trace-scope scientific owners are verified on their exact fixed commits.
The thermal workflow retains its complete original physical test body; the
input-only route inherits that proof only when the complete src tree matches
the reconciled baseline, while current O0/O2 file and annual runs remain selected.

## Canonical admission

PR1352 admits the original chemical reader at d7b891759a8c378ba0367e1a1a112c684712199f. PR1353 reconciles the already qualified transaction successor with the original F-SI35 native guard at bcf7a497d131d858b61e9ebbb7ec6dbc23fa6c8b. Both actual source trees retain 035a4085b0f43d484ca39884a3e59dad641a63f0. All 19 feature PR workflows, all 17 reconciliation PR workflows and the selected actual final canonical workflows pass. Eleven source/evidence rejection controls pass. The original immutable F-SI35 O0/O2 replay remains intact. Four master capability facets are updated, with 239 other rows and all 243 dispositions unchanged. No complete historical migration or general seasonal accuracy is claimed.
