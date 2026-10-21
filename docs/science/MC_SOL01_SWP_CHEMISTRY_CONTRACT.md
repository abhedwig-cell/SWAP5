# MC-SOL01 original SWP chemistry adapter

Implementation checkpoint; not qualified or canonically admitted.

The optional --swp route uses the archived original read_solute_CDE and original TTUTIL. Only its two global-context USE bindings change. The original AFGEN_2 and RDADORTB are retained. This imports chemistry and initial concentration into the existing production column. Explicit typed hydrology, forcing and numeric heat configuration remain required; this is not the complete historical default SWP application.

The original ISUBLAY/ISOILLAY/HSUBLAY/NCOMP table must match every explicit water-owner cell thickness. No interpolation of grid or hydrology is allowed. Chemical vectors follow original soil-layer indices. Internal-face dispersivity uses layer(i), as in original solute.f90 lines 321-326. Initial concentration follows original absolute-depth interpolation. Original BDENS in mg/cm3 is divided by 1000 and KF in cm3/mg multiplied by 1000, preserving their sorption product in the typed g/cm3 convention.

The admitted exponent domain remains 0.5 through 2. Aquifer, macropore, snow, analytic heat, time-varying bottom concentration, loose historical restart and unsupported crop branches fail before physical owners exist. SWHEA must agree with the explicit numeric heat owner. No new process equations or state owners are introduced.

Every SWP generation retains the exact input bytes and hash. A restart must supply the same SWP and executable. Existing no-SWP generations retain their original file inventory. Original TTUTIL is linked as a static archive; generated source, archived authority, compiler flags and all linked providers are recorded in the completed build.

Affected architecture invariants: 2, 3, 7, 9, 13, 21, 23, 25, 27, 29. Validation must include native original grammar, layered units and interpolation, invalid inputs, real production balances, fresh-process restart, and existing no-SWP preservation.
