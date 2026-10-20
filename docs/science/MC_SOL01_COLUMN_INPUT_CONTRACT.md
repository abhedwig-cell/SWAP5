# MC-SOL01 file-driven Reference column

Status: proposed application adapter, based on canonical `d443dced3313e2602fdea4cbd1a6cb566f53fb0e`.

The executable `swap5_solute_column` reads a versioned Fortran namelist, constructs
the existing physical parameters and committed owners, and calls
`run_pond_joint_interval`. The kernel does not read files. Scientific authority is
the admitted matrix/pond route, including PR1304; see `MC_SOL01_FINAL_CLOSURE.md`.
This is an explicit opt-in application, not a replacement for the historical SWP
reader or an automatic default activation in other applications.

The initial qualification domain is one serialized four-node column with cell
thicknesses 0.5, 0.5, 1, 1 cm, uniform Mualem-van Genuchten parameters, prescribed
root extraction and one drainage level, signed prescribed lower-face flux,
linear Freundlich sorption, constant chemical parameters, and piecewise constant
gross surface supply. File inputs specify pressure, initial soil concentration,
pond water/mass, rainfall/irrigation/runon concentrations, evaporation, runoff
threshold/resistance and reporting windows. No equation is duplicated in the
application. Temperature-dependent decay is inactive in this first route.

Positive pond/runon/runoff and infiltration must be observed from actual accepted
Reference trace records. Evaporation removes water without dissolved solute.
The chemical owner consumes the accepted trace once. Each successful reporting
window emits unrounded water and solute budgets and node state. A rejected joint
interval publishes neither owner. Application failure returns a nonzero exit.

Restart uses the existing same-platform S5MJ0002 codec, binding both committed
owners. The input configuration must retain its declared positive parameter IDs;
the chemical vector is validated by the existing reader. A separate application
manifest must bind the complete input bytes so changing hydraulic parameters or
future forcing cannot silently reuse an old restart under the same IDs. Fresh
process continuation starts only at an exact input window boundary. The caller
can stop after a window and resume into a separate output directory. Existing
outputs are never overwritten. This adapter does not claim crash-safe checkpoint
publication until its manifest and binary are published as one generation.

The standalone link context supplies the legacy symbol layout still imported by
the typed Reference bridge. It retains the already qualified four-node geometry.
The arithmetic face mean (SWKMEAN=1) is the literal already-admitted
`0.5*(kup+klow)` branch of historical `SWAP/functions.f90` (SHA256
`b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527`). Other
legacy physics/numerical entries abort if reached; calculations use the explicit
production providers and solvers. It is
compiled only by the explicit standalone build tool. It must not replace a full
legacy application's module providers.

Affected invariants: 1, 2, 3, 7, 9, 13, 21, 25, 26 and 29. Existing shared
production interfaces, state ownership and equations are unchanged. Qualification
requires GNU O0/O2 real file-driven runs, independently recomputed output budgets,
positive accepted fluxes, separate-process restart identity, invalid input and
restart identity rejection. Full F-CI and unrelated solver research are selected
only if owning change-impact evidence requires them.
