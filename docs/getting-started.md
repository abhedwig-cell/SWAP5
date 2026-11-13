# Getting started: standalone no-macro SWAP5

**RELEASE READY for the named standalone no-macro scope.** PR1663's actual
canonical source postimage is verified in the versioned release record. This is
not whole scientific equivalence or an official tagged/public GitHub release.

## Supported release boundary

The standalone user route supports exactly these registered original profiles:

| Model selector | Original input | Complete period | Grid |
| --- | --- | ---: | ---: |
| `HYBRID_GRASSGROWTH_WATER` | `2.grassgrowth` | 1827 days | 113 nodes |
| `HYBRID_HUPSEL_WATER` | `1.hupselbrook` | 1096 days | 34 nodes |
| `HYBRID_SALTFARM_WATER` | `4.salinitystress-04dS` | 1461 days | 195 nodes |

These use one generic SWAP5 daily controller and private original Fortran workers.
They are complete selected applications, with exact day restart; arbitrary edited
SWP files and unregistered option combinations are refused. Active macropores,
including original Andelst, are outside this release. No input switch is silently
changed. Preserved native/research applications and the legacy Andelst archive
preparation remain separate development routes, not prerequisites or aliases.

For development beyond these registered profiles, see the separately qualified
[experimental original no-macro input and option coverage](science/NOMACRO_FUNCTIONAL_COVERAGE.md).
It retains explicit experimental selection and does not expand this release's
production or scientific-equivalence claims.

## Install and obtain the source

Obtain the source with Git (or use an existing checkout at the admitted commit):

```bash
git clone --single-branch --branch integration/f-ci-canonical https://github.com/abhedwig-cell/SWAP5.git
cd SWAP5
git rev-parse HEAD
```

Keep the printed commit with your results. The versioned release decision and
Windows/Ubuntu evidence are in `integration/f-ci/USERRELEASE01_20261112.json`.
Python 3.12 or later,
GNU Fortran and GCC major 15 or 16, and GNU binutils (`ar`) must be on PATH. Fortran
and C must target the same platform. The model launcher uses only Python's standard
library; no downloaded research capsule or previous executable is required.

On Windows, use Python and the matching MSYS2 UCRT64 GNU compiler/binutils packages.
In PowerShell add the installed UCRT64 `bin` directory to PATH, for example:

```powershell
$env:PATH = "C:\msys64\ucrt64\bin;" + $env:PATH
python --version
gfortran --version
gcc --version
ar --version
```

On Ubuntu 26.04 install Python and the default GNU toolchain, then optionally make
`python` available through an isolated environment:

```bash
sudo apt-get install python3 python3-venv gfortran gcc binutils
python3 -m venv .venv
. .venv/bin/activate
python --version
gfortran --version
gcc --version
ar --version
```

Run all commands below at the repository root. Paths are examples relative to that
root; every preparation, build and result directory must be new. Builds and saved
states are platform/compiler/source bound, not cross-platform binaries.

## Prepare original sources once; no model is executed

```bash
python -B tools/solute/run_water.py --no-macro-release --prepare-sources --reference-work ./original-provider
```

This verifies the repository-bundled original `SWAP.ZIP` and `TTUTIL.ZIP`, compiles
their original objects and library, and stages the three registered inputs.
Grassgrowth and Hupsel retain the original project bytes. SaltFarm is materialized
from the original workbook/template **before** input preflight, with its 581 saline
irrigation events and no changed physical switch. Equivalence to the historical R
preprocessor's output bytes is not claimed. The original archive hashes are:

- SWAP: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.
- TTUTIL: `ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`.

`original-provider/PREPARED.json` binds archive, compiler, preparation source,
selected source, object, module, library and actual input hashes. The preparation
executes zero original models, including zero Andelst/macropore runs. No whole
distribution ZIP, personal temporary directory or GitHub artifact is needed.
Keep the provider and build together with results; modifying inputs or objects
invalidates reuse. A compiler change requires a new provider and build.

## Build and run complete periods

```bash
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_GRASSGROWTH_WATER --reference-work ./original-provider --build-only --kernel-opt O2 --output ./grass-build
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_GRASSGROWTH_WATER --reference-work ./original-provider --build-bundle ./grass-build --output ./grass-full
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_HUPSEL_WATER --reference-work ./original-provider --build-only --kernel-opt O2 --output ./hupsel-build
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_HUPSEL_WATER --reference-work ./original-provider --build-bundle ./hupsel-build --output ./hupsel-full
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_SALTFARM_WATER --reference-work ./original-provider --build-only --kernel-opt O2 --output ./saltfarm-build
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_SALTFARM_WATER --reference-work ./original-provider --build-bundle ./saltfarm-build --output ./saltfarm-full
```

Without `--days` these run all 1827, 1096 and 1461 days. `--build-only` compiles
without simulation. The original process worker remains O2; `--kernel-opt O0`
selects the checked SWAP5 controller build. A model/controller call defaults to a
60-second wall cap, excluding compilation. `--timeout-seconds` explicitly selects
a positive cap up to 300 seconds. Cap exhaustion retains accepted journals and
reports `MODEL_WALL_CAP_REACHED`, never successful completion. Build commands in
original source preparation each have a 60-second cap. No process or tolerance
is removed to meet a time limit.

## Save and resume an accepted day

This short example exercises exactly the same state and executable owners as a
complete run. Use the corresponding model selector and build for Hupsel/SaltFarm.

```bash
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_GRASSGROWTH_WATER --reference-work ./original-provider --build-bundle ./grass-build --output ./grass-prefix --days 4 --checkpoint-at 2
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_GRASSGROWTH_WATER --reference-work ./original-provider --build-bundle ./grass-build --output ./grass-resumed --days 4 --restart ./grass-prefix/accepted-column-1-day-2.zip --restart-day 2 --checkpoint-at 4
```

The first run saves day 2 **after acceptance**, then continues through day 4.
The fresh process resumes the saved state through days 3 and 4. Reuse the same
build; do not recompile between these commands. The ZIP binds both original
native state and complete auxiliary state to the exact project, original inputs,
source and numerical build. Wrong day, source/build/input, incomplete or corrupt
payloads refuse; the accepted origin is never overwritten. Add `--checkpoint-at N`
to any complete run to save its accepted day N. There is no four-day prototype
limit: `--days` is an absolute day within the selected original period.

## Read outputs and units

- `BUILD.json`: project, exact production sources, original object/library and
  compiler identities, actual input hashes, executable hashes and checkpoint binding.
- `RESULT.json`: requested and committed days, first refusal, maximum accepted
  water residual in cm, source/input hashes and controller/model elapsed seconds.
  Success requires no refusal and the requested number of daily records.
- `daily.jsonl`: one accepted/refused day record. Stocks, daily water fluxes,
  pressure head, groundwater and drainage are in cm (daily amounts, not rates).
  `bottom_outward_cm` is positive outward. `independent_residual_cm` and
  `kernel_residual_cm` retain the existing `1e-10 cm` guard. Hupsel/SaltFarm also
  report solute stocks/ledger/residual in mg/cm2 with `1e-10 mg/cm2` guard and
  uptake terms in cm. Day and revision identify the accepted transaction.
- `original/result_output.csv` and original output files: original process output;
  their headers label fields and units, including soil temperature in degrees C.
- `accepted-column-1-day-N.zip`: durable native + auxiliary day state and binding;
  it is a restart package, not an editable input file.
- Worker/kernel stdout and stderr remain beside results for diagnosis.

`stock_end_cm` / `stock_start_cm` order is soil water, pond, snow, canopy
interception, then two inactive macropore slots (both zero). `external_flux_cm`
retains the original amount order: liquid rain, snow rain, snowfall, irrigation,
run-on, lateral inflow, bottom inflow, interception evaporation, runoff, root
uptake, pond evaporation, soil evaporation, sublimation, drainage, inactive
macropore drainage (zero), bottom outflow. The first seven enter; the final nine
leave. Solute ledger order is end stock, change, rain, irrigation, bottom input,
drainage loss, decay loss, root loss, reported residual. Consult original CSV
headers before interpreting any extra original process-specific output.

The additional qualified numerical heat ledger is currently **research-only**.
The supported user launcher does not promise an exported heat-budget CSV. Its
qualified research observer covers sensible storage and conductive flux, not full
physical energy: advective water-carried heat, latent/gas and full surface energy
are not supplied or fabricated. Temperature output is not a full energy balance.

## External boundaries and scientific limits

Original forcing is the default. The existing serial daily coupling API keeps
explicit prepare/discard/accept, rollback and independent worker ownership. The
[Grass prescribed-groundwater contract](science/HYBRID_GRASS_DAILY_GROUNDWATER.md)
and [surface-irrigation contract](science/HYBRID_HUPSEL_DAILY_IRRIGATION.md) describe
accepted caller inputs, units and restrictions. The shared no-macro irrigation
mode accepts registered Hupsel/SaltFarm surface events; the older Hupsel-only mode
stays restricted. Existing MODFLOW exchange conventions are unchanged. There is
no new general CLI for arbitrary forcing and no caller thermal feedback contract.

Functional readiness does not establish whole scientific equivalence. Preserve
original Grassgrowth oxygen FAIL results (including the native thermal-profile
day 188 criterion), underresolved Hupsel day 584 reference families, failed
zero-advection comparisons and SaltFarm preprocessor limits. Read the
[functional scope](science/SWAP5_FUNCTIONAL_CLOSURE.md) and
[scientific disposition](science/FULL_TRAJECTORY_SCIENTIFIC_DISPOSITION.md).
Active macropores, arbitrary edited SWP projects, new process combinations,
thread-safe legacy globals and full physical energy are outside this release.

## Reproduce user acceptance or build documentation

```bash
python -B tools/solute/check_userrelease.py --output ./user-acceptance
python -m pip install -r requirements-docs.txt
python tools/docs/check_docs.py
mkdocs build --strict
```

The acceptance runner invokes the public commands in separate processes from a
new source provider, builds all three projects at O0/O2, checks exact physical and
native own restarts, executes the complete selected O2 periods and tests invalid
source/toolchain/input/build/output and active-macro refusals. It does not execute
Andelst or load a research provider. Existing full O0, seasonal restart, heat,
rollback, independent-instance and external-input qualification remains separately
source-bound; this packaging change does not change the production Fortran/host.
