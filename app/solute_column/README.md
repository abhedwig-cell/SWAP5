# File-driven Reference solute column

This opt-in application runs the production Reference water/pond/matrix route
from a text input, with unrounded accounting and independent-process restart.
It currently has four cells (0.5, 0.5, 1 and 1 cm). It supports linear sorption,
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
increasing. The two required input groups are `column` (schema=1) and `surface`.
Undeclared physics keywords are rejected. See the example and the
[application contract](../../docs/science/MC_SOL01_COLUMN_INPUT_CONTRACT.md).

Local qualification:

```bash
FC=gfortran-13 python tools/solute/build_column.py --optimization O0 --output /tmp/swap5-solute-O0
python tests/nut-sol/test_column_input.py --build-O0 /tmp/swap5-solute-O0 --build-O2 /tmp/swap5-solute-build --output /tmp/swap5-solute-evidence
```

The measured GNU13.3 provider closure is 178 source files. Cold compilation/link
took approximately 21 s at O0 and 67 s at O2 in the qualification session; the 26
process checks took about 7.3 s including launcher/validation overhead. These
measurements describe a small column on that host, not production throughput.

The standalone link context is deliberately outside `src`: this build alone
selects its four-node legacy symbol layout. Except the historical arithmetic
conductivity mean, old physics/numerical entries abort if called. All active
hydraulic/transport calculations use existing production providers. Other
application builds retain their own legacy module definitions.
