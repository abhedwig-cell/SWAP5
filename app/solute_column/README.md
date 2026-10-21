# File-driven Reference solute column

This opt-in application runs the production Reference water/pond/matrix route
from a text input, with unrounded accounting and independent-process restart.
Schema1 retains four cells (0.5, 0.5, 1 and 1 cm). Schema2 supplies a grid of
2 through 256 cells with `nodes` and `cell_thickness_cm`. It supports linear sorption,
prescribed roots, one signed drainage level, a signed prescribed bottom flux,
rain, irrigation, runon, pond mixing, runoff and nonexporting pond evaporation.
Roots here are prescribed extraction, not a live crop model. This is not yet a
general historical `.swp` reader or field-scale/seasonal qualification.

From the repository root, with GNU Fortran and Python installed:

```bash
FC=gfortran-13 python tools/solute/build_column.py --optimization O2 --output /tmp/swap5-solute-build
python tools/solute/run_column.py --exe /tmp/swap5-solute-build/swap5_solute_column --input examples/solute_column/positive_pond.nml --output /tmp/solute-full
python tools/solute/run_column.py --exe /tmp/swap5-solute-build/swap5_solute_column --input examples/solute_column/positive_pond.nml --output /tmp/solute-first --stop-after 1
python tools/solute/run_column.py --exe /tmp/swap5-solute-build/swap5_solute_column --input examples/solute_column/positive_pond.nml --output /tmp/solute-resumed --restart /tmp/solute-first
```

Each output directory must be new. `budget.csv` contains per-window water and
solute inventories, external inputs/outputs, residuals and accepted gross water
fluxes. `state.csv` contains node heads, water contents and dissolved/sorbed
solute. `endpoint.csv` adds pond water/mass and whole-column inventories.
`restart.bin` and the manifest are one published generation. Restart requires
the identical input file and executable; a new scenario needs a new initial
run. The complete input is retained as `input.nml`. Numerical receipts refer to
accepted hydraulic substeps, including their source provenance.

Time is days since zero, all lengths are cm, rates cm/day, concentration mg/cm3
and solute inventories mg/cm2. Bulk density is g/cm3 and the linear sorption
coefficient `kf` is cm3/g. Drain and bottom water fluxes use the production
conventions: positive drain flux extracts water; positive bottom flux enters the
column. Potential evaporation is a positive demand. `ends_day` is strictly
increasing. The two required input groups are `column` (schema=1 or schema=2) and `surface`.
Undeclared physics keywords are rejected. See the example and the
[application contract](../../docs/science/MC_SOL01_COLUMN_INPUT_CONTRACT.md).

Local qualification:

```bash
FC=gfortran-13 python tools/solute/build_column.py --optimization O0 --output /tmp/swap5-solute-O0
python tests/nut-sol/test_column_input.py --build-O0 /tmp/swap5-solute-O0 --build-O2 /tmp/swap5-solute-build --output /tmp/swap5-solute-evidence
```

For schema2, supply all cell thicknesses, for example
`nodes=8, cell_thickness_cm=4*0.25,4*0.5`. Concentration, root and drainage arrays
are indexed by cell. Omitted entries default to zero; nonzero entries beyond
`nodes` are rejected. Material parameters and initial pressure remain uniform.
See `examples/solute_column/deep_grid.nml` for a 32-cell, 138-cm input.

Grid qualification exercises 2, 8, 32 and 256 cells with actual Reference fluxes,
budgets and fresh-process restart. The dry 138-cm case at initial head -75 cm
rejects 0.001-day windows under the unchanged strict Reference numerical policy;
0.00001-day windows complete. The wetter -10-cm deep example uses 0.001-day
windows. Failure publishes no generation. This is a reproducible numerical
domain limit, not seasonal or arbitrary-grid convergence qualification.

The complete schema2 qualification has 86 process observations in 123.44 s of
launcher/native/validation time on the qualification host. Cold GNU13.3
compile/link took 19.89/0.077 s at O0 and 64.71/0.103 s at O2. These short
scenarios do not measure seasonal throughput; physics-only time is UNKNOWN.

The original schema1 GNU13.3 provider closure is 178 source files. Cold compilation/link
took approximately 21 s at O0 and 67 s at O2 in the qualification session; the 26
process checks took about 7.3 s including launcher/validation overhead. These
measurements describe a small column on that host, not production throughput.

The standalone link context is deliberately outside `src`: this build alone
allocates its immutable legacy symbol layout from the input grid. Except the historical arithmetic
conductivity mean, old physics/numerical entries abort if called. All active
hydraulic/transport calculations use existing production providers. Other
application builds retain their own legacy module definitions.

## Explicit numeric heat and nonlinear soil sorption

`examples/solute_column/nonlinear_thermal_pond.nml` enables `dynamic_temperature`,
`freundlich_exponent` (0.5..2), `reference_concentration` (mg/cm3),
`decay_rate_day` (1/day), `gamma_temperature` (1/C), node `initial_temperature_c`
and per-window `surface_temperature_c`. The surface temperatures prescribe the
soil heat boundary; the bottom heat flux is zero. Pond solute stays dissolved.
There is no additional pond thermal reservoir. `temperature.csv` is included in
the complete-generation manifest. S5PT0001 binds water, heat and pond/soil chemical
inventory and parameters; the original heat-off joint format remains unchanged.

There are at most 2048 explicit reporting/coupling windows. Existing files retain
linear sorption, zero decay and disabled heat by default. The optional retained
step proposal is rejected with dynamic heat until that composition is qualified.
See [the qualification contract](../../docs/science/MC_SOL01_THERMAL_POND_CONTRACT.md)
for splitting refinement and the limits of the prescribed 30/365-day experiments.
The application remains opt-in and does not replace the historical SWP reader.

The opt-in `swp_water_bootstrap=.true.` additionally imports native SWP grid,
layered default MvG parameters and unsaturated HTB initial pressure heads. Use
schema2 with nodes=0 and no explicit grid/hydraulic overrides, plus `--swp`.
See [the bounded water contract](../../docs/science/MC_SOL01_SWP_WATER_CONTRACT.md)
and examples/solute_column/swp_water.nml with layered_water.swp. Surface, bottom,
root, drainage, meteo and crop forcing remain explicit. This is not a complete
historical default-SWP application and is not yet canonically admitted.
