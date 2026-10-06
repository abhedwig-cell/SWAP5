# PPA-MICRO07 bounded source stress-factor slice

Status: independently tested source slice, **not** production-wired,
qualified on a PR merge tree, or canonically admitted. Its base is the
MICRO02–06 candidate `3d0e5f2effd9bb4855ec831890ca1335cbaaba42`;
canonical remains `e5eab995ef04fc813dd644025fb0f32e4f5050a1`.

The exact source authority is `rootextraction_micro` in
`reference/swap-4.3.1/b1_11_frost_source/SWAP/rootextraction.f90`, especially
the Feddes wet-head and Maas–Hoffman salt factors and `swAlpTot` construction.
The process-local module `src/process/mod_root_micro_stress_factors.f90`
computes only these bounded factors from explicit current pressure head,
concentration, root count, first-compartment boundary and parameters. It has
no state, I/O or trial-commit authority. Invalid inputs return an unallocated
result. The currently qualified MICRO02–06 runtime still passes all ones to
the nonlinear uptake routine, so this slice changes no executable application
behaviour or admitted water balance.

For `sw_oxygen=1`, a node deeper than `botcom(1)` uses `hlim2l`, otherwise
`hlim2u`. At `hlim1`, the wet factor is zero; at `hlim2`, it remains one.
For `sw_salinity=1`, concentrations above `saltmax` use
`max(0, 1-(cml-saltmax)*saltslope)`. The source combines with multiplication
for `swAlpTot=1` and minimum for mode 2. Mode 3 is implemented only as an
inspectable literal source-oracle behaviour: it multiplies strictly positive
per-node factors and broadcasts the result, including to a node whose own
factor was zero. This is **not** approval of its physical interpretation or
permission to activate it in production. Frost has no executable B1.11
MICRO route because its source guard errors before the later frost loop.
Bartholomeus oxygen mode 2, de Jong van Lier, optimal-root rerun, crop ET
ownership and hydraulic lift are excluded.

`python3 tests/physics/run_ppa_micro07_stress_factors.py` compiles the exact
module and standalone hand-calculated source cases under gfortran O0 and O2,
with bounds and floating-point traps. It checks upper/lower compartment
selection, zero/boundary factors, salt threshold and clipping, all three
literal combinations, unrooted neutrality, invalid selectors and non-finite
fail-closed behaviour. Both optimization outputs must be byte-identical.
This is a local unit oracle only. It does not establish trial recomputation,
single-sink integration, mass closure, restart or moving preservation.

Next admission boundary: choose the physical policy for mode 3 explicitly,
bind factors to the current trial pressure and salt view before one MICRO
sink, qualify changed forcing, rejection and restart on the actual backend,
then repair the B15 moving source-tree pin on that new postimage. None of
these steps is inherited from this isolated test.
