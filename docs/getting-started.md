# Getting started: build, run, input and output

This page gives a practical entry point to the **current repository**, while keeping the distinction between qualified internal/application contracts and a future broad end-user SWAP5 interface explicit.

## First: what the repository currently provides

SWAP5 Status-A is a qualified scientific/runtime baseline and review target. The repository contains production Fortran modules, qualification runners, reference material and documentation. It does **not** currently claim one broad stable public command-line application interface for every historical SWAP input/output mode.

Do not invent a user-facing command from internal qualification scripts. Use the bounded entry points below for the purpose they were admitted for.

## Build the documentation

The documentation itself has a supported local validation route:

```bash
python -m pip install -r requirements-docs.txt
python tools/docs/check_docs.py
mkdocs build --strict
```

This is the same validation discipline used by the repository documentation workflow.

## Exercise the minimal application-host contract

The repository contains an admitted minimal generic soil-water application host in:

```text
src/runtime/mod_fmr_soil_water_application_host.f90
```

Its bounded owner runner is:

```bash
chmod +x tests/runtime/run_fapp01_minimal_soil_water_application_host.sh
tests/runtime/run_fapp01_minimal_soil_water_application_host.sh
```

The runner requires GNU Fortran (`gfortran`). It compiles the host and its contract test under both `-O0` and `-O2`, executes both binaries, requires identical output and reports the resulting SHA-256 plus PASS markers.

This is a **contract exercise**, not a general SWAP5 end-user simulation command.

## What the minimal host selects

F-APP01 establishes one bounded application-level model-selection owner. Its qualified contract includes:

- blank selection resolves to the Reference model;
- Reference can be selected explicitly;
- an alternative must be explicitly selected and registry-bound;
- unsupported selections fail closed;
- an invalid registry fails closed;
- there is no automatic fallback or silent model selection;
- the host owns routing identity, not solver/process science.

The host deliberately does not redefine the legacy SWP grammar or provide a broad stable public API.

## Run the explicit hybrid Andelst application

The development application binds `HYBRID_ANDELST_WATER` to the existing
soil-water application selector. It runs the original Andelst inputs through
one legacy Fortran worker per column and commits each day in the SWAP5 kernel.
This route has its own bounded qualification and is still under development.

With GNU Fortran and GCC on PATH, prepare the reference from the original
SWAP 4.3.1 distribution and use new output directories:

```bash
python -B tools/solute/run_water.py --model HYBRID_ANDELST_WATER \
  --reference-work ./andelst-reference --prepare-archive /path/to/SWAP_4.3.1.zip
python -B tools/solute/run_water.py --model HYBRID_ANDELST_WATER \
  --reference-work ./andelst-reference --output ./andelst-run \
  --checkpoint-at 20 --days 22
python -B tools/solute/run_water.py --model HYBRID_ANDELST_WATER \
  --reference-work ./andelst-reference --output ./andelst-resumed \
  --restart ./andelst-run/accepted-column-1-day-20.zip --restart-day 20 --days 22
```

Omitting `--days` runs through the original final day, 481. A restart ZIP
must match the numerical build and original project inputs. The application
emits daily receipts, the original CSV output and a result JSON with hashes.
The [development evidence](https://github.com/abhedwig-cell/SWAP5/blob/b706a1b6e7216d3b1bc02cdc66817eaceb964644/research/hybrid-water01/README.md)
records the validated windows and scientific comparison separately.

## Run the native Grassgrowth application

The same launcher selects the existing Grassgrowth project owner with
`NATIVE_GRASSGROWTH_WATER`. It uses the original 113-node project and
the retained-step thermal-control profile. Build that profile and run
it in new output directories:

```bash
python -B tools/solute/build_grass_startup.py --output ./grass-build \
  --optimization O2 --policy retained --numerical-profile thermal-control-1e-5C
python -B tools/solute/run_water.py --model NATIVE_GRASSGROWTH_WATER \
  --grass-build ./grass-build --output ./grass-prefix --days 2
python -B tools/solute/run_water.py --model NATIVE_GRASSGROWTH_WATER \
  --grass-build ./grass-build --output ./grass-resumed --days 4 \
  --restart ./grass-prefix/checkpoint.bin
```

The last accepted day is saved in the native checkpoint. The executable,
thermal profile and original input files are checked before model launch.
Omitting `--days` requests the original final day, 1827.

`conductive_budget.csv` sums the sensible storage change and the top and
bottom conductive energy entering the soil over accepted substeps. It
also reports the daily closure residual and the largest absolute
substep residual. This covers the conductive soil calculation. The file
does not include advective heat, gas transport, latent heat or a full
surface energy balance.

## Run the native Hupsel rotation

Select `NATIVE_HUPSEL_ROTATION` with the same launcher. This route uses
the existing 34-node water, solute, heat, crop and irrigation project.
Its prepared inputs come from the pinned pressure-film qualification
archive. The numerical profile uses a 0.01-day maximum time step
and the explicit pressure-film root accuracy selector.

```bash
python -B tests/dataqual15_hupsel/build_and_run.py --output ./hupsel-build \
  --compiler "$(command -v gfortran)" --optimization O2
python -B tools/solute/run_water.py --model NATIVE_HUPSEL_ROTATION \
  --hupsel-build ./hupsel-build --output ./hupsel-prefix --days 2
python -B tools/solute/run_water.py --model NATIVE_HUPSEL_ROTATION \
  --hupsel-build ./hupsel-build --output ./hupsel-resumed --days 4 \
  --restart ./hupsel-prefix/checkpoint.bin
```

Keep `RESULT.json` beside the checkpoint. The launcher verifies that
receipt against the checkpoint, executable and inputs before native
restart validation. Omitting `--days` requests day 1096.

## Bounded generic hybrid Grassgrowth water prototype

The same hybrid host also has explicit `HYBRID_GRASSGROWTH_WATER` for the
original113-node project. Current qualification is limited to days1..4, with
its own exact restart and independent-instance controls. It uses the existing
prepared original distribution. See [explicit hybrid project state](science/HYBRID_GENERIC_WATERHOST.md)
for commands and limits; this does not replace the full native thermal route.

## Input: current truth

There are several different things that can be called “input” in this repository and they should not be conflated.

### 1. Typed/internal application requests

Modern runtime and qualification seams can construct typed requests/state directly for a bounded capability. These are useful for qualification and controlled composition, but they are not automatically a public file format.

### 2. Legacy/reference input

SWAP 4.3.1/reference material remains an important authority for historical file-oriented behaviour. Status-A does not claim that wholesale legacy I/O has been replaced by a new public SWAP5 grammar.

A later application binding can translate a bounded piece of legacy application meaning into typed runtime meaning only where that binding has been explicitly admitted. Such a binding is not authority to redesign the whole legacy grammar.

### 3. Future public interface

A broad stable SWAP5 API/CLI or wholesale input-format modernization remains outside the frozen Status-A denominator unless separately admitted.

## Output: current truth

Qualification runners produce deterministic contract/test output and evidence. Production/runtime capabilities expose admitted state, fluxes, diagnostics or coupling results through their owning contracts.

There is currently no documentation authority here for a new universal SWAP5 output-file format that supersedes all historical SWAP outputs. Do not infer one from test logs or internal diagnostic structures.

For scientific review, output meaning should therefore be traced through the owning process/capability and its balance/evidence contract rather than through a presumed global file schema.

## Where to go next

- To understand what is scientifically admitted, read [Status-A current status](status-a/CURRENT_STATUS.md).
- For the scientific model, read [Scientific model](science/index.md).
- For individual runtime/process capabilities, use [Status-A capability review pages](capabilities/index.md).
- For transaction/retry/commit semantics, read [Numerical formulation](numerics/index.md).
- For exact theory/code/evidence chains, use [Status-A traceability](status-a/TRACEABILITY.md).
- For SWAP 4.3.1 reference context, see [Legacy baseline](legacy/swap-4.3.1-baseline.md).

## Documentation rule

If a build/run/input/output path is missing but can be reconstructed from accepted repository authority, document it. If the authority itself is not yet established, record that as a bounded gap instead of presenting an internal test harness as a supported public interface.
