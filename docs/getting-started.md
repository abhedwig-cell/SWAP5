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