# MC-SOL01 file-driven Reference column

## Optional numerical proposal successor, 21 October 2026

The [PERF01 proposal contract](../performance/SWAP5-PERF01_PROPOSAL_CONTRACT.md)
adds the optional logical `retain_accepted_step_proposal` to `&column`, default
false for both schemas. It changes numerical execution only and leaves physical
parameters, tolerances, hard budgets and restart schema intact. The
[qualification result](../performance/SWAP5-PERF01_PROPOSAL_RESULT.md) specifies
the bounded Reference cases, unchanged default-OFF files, one-day error/cost
comparison and excluded long dry infiltration failure. General activation is
not implied. Actual admission is through its owning PERF01 status and PR.

## Canonical schema2 grid successor, 20 October 2026

PR1332 admits this bounded successor at
`fc6f52e0e6d1f5ade79e01efbb0af4e665d13bb1`, qualified head
`2c7112f500791b756358f5b95b23734d45890231`. All16 qualified-head workflows
succeed, including actual O0/O2 file-column/restart qualification39470971724.

This work extends only the application geometry adapter. Schema1 retains its
four cells and its existing numerical endpoint. Schema2 adds `nodes` and
`cell_thickness_cm` to `column`: 2 through 256 cells, each finite and between
0.0001 and 10000 cm, with total depth at most 1000000 cm. All active thicknesses
must be supplied. Cell centres are negative depths; face distances are half the
adjacent thickness sum. Initial concentration, prescribed root extraction and
signed drainage arrays have one entry per cell; omitted entries remain zero,
and nonzero entries beyond the active grid are rejected. Initial pressure and
hydraulic/chemical parameters remain uniform. Schema1 rejects grid overrides.

The standalone legacy symbol context is allocated once from this geometry,
before constructing the production owners. It is not committed physical state,
cannot change within a run, and is not a second hydraulic or chemical owner.
The existing typed Reference solver, pond transport, transaction and restart
implementations remain unchanged. Restart continues to require identical input
and executable bytes, including the grid. No kernel file input is introduced.

Admission requires local GNU O0/O2 real calculations on the original four-cell
case, a nonuniform refinement and a deeper profile, independently recomputed
water/solute inventories, accepted gross fluxes, multiple substeps, exact fresh
process restart, invalid geometry rejection and original endpoint preservation.
This is not spatial-convergence, seasonal, arbitrary-stratigraphy or live-crop
qualification. Existing surface-age/NUT source-bound evidence must remain valid.
Full moving F-CI, RossFast and highest low-air are not selected for this adapter.

The 32-cell 138-cm case at uniform initial head -75 cm rejects 0.001-day
reporting windows after repeated solver retries with the existing strict
Reference policy. There is no published generation or mass-balance acceptance.
The same dry profile completes at 0.00001-day windows; the wetter -10-cm profile
completes at 0.001-day windows. These are separate qualified regimes. No
tolerance is relaxed and no universal solver convergence claim is made.

Status: canonically admitted bounded application through PR1329 at
`21cc80984a864b48d4344b9671d6ccd2ae5882ad`, based on
`d443dced3313e2602fdea4cbd1a6cb566f53fb0e`.

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
outputs are never overwritten. The Python file adapter stages, validates and
fsyncs all files, then publishes the directory with one same-filesystem rename
and fsyncs its parent directory. A generation binds the unchanged input bytes,
executable bytes and all seven output files. Qualification kills the launcher
immediately before and after publication: the old generation remains unchanged,
and the new directory is either absent or contains the complete matching endpoint.
This is serialized same-platform POSIX process-crash qualification, not a test of
hardware power loss or concurrent writers.

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

## Local qualification, 20 October 2026

The actual file-driven GNU13.3 O0/O2 builds use 178 providers and no test source.
Each uninterrupted run accepts 270 and 264 substeps in its two input windows.
Positive runon/runoff/infiltration/evaporation are read from accepted Reference
receipts. Independent gross water and whole-solute accounting, endpoint
inventories and native residual checks pass. Maximum native water residual is
1.17e-16 cm and maximum solute residual 8.58e-16 mg/cm2. O0/O2 budgets, state
tables and restart bytes are identical. The separate-process restart endpoint
has SHA256 `42d92009baeb4e7a90ef2e2ebbd22c79df69cb05bc7cf0e01e7cea39bf192e4f`.

The 26 process observations cover uninterrupted/split/fresh continuation,
existing-output rejection, wrong schema, negative concentration, nonfinite
forcing, backward time, unsupported physics keyword, changed hydraulic-input
identity, corrupted restart generation and termination on both sides of the
publication rename. Rejected trials within the joint production route retain
their existing admitted rollback authority; no new state owner is introduced.
Source checkpoint `7217e33287e09385f2f6abbcb321198ae452348e` is equivalent to the
compiled application/runner postimages. The archive and exact local execution
lineage are recorded in the existing trajectory3 `column_input_20261020` entry.

All fifteen workflows on the final qualified head `19f973e4` are terminal SUCCESS,
including actual hosted O0/O2 application run39463805790. The actual merge tree
equals that qualified tree. Postmerge application run39464479365 also passes the
real native suite and existing age/source/evidence qualification. Master receipt
`371e92f2` adds only two bounded application receipts; all243 dispositions remain
unchanged.

After concurrent NUT PR1330 (`d118bcf1`), all178 actual application providers still
match the executed O0/O2 SHA256 inventory. Current joint source/evidence
qualification passes; its predecessor helper now handles ordinary full checkouts
as well as the existing sparse route. Only that staging condition changes. No
scientific assertion, application provider or physical equation changes.
