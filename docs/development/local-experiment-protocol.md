# Local experiment protocol

Status: repository working protocol

## Purpose

SWAP5 uses GitHub Actions as an independent qualification and admission mechanism. It is not the default execution engine for broad exploratory campaigns.

This protocol separates the fast research loop from the evidence loop:

```text
pin exact ref
  -> build once where possible
  -> local/scratch campaign
  -> falsify and narrow candidates
  -> persist compact evidence in Git
  -> independent qualification/admission in GitHub Actions when required
```

The objective is lower queue pressure without weakening reproducibility or qualification.

## What belongs in the local loop

Use local or isolated scratch execution by default for:

- parameter sweeps such as DTMIN, DTMAX, tolerances and elastic-storage coefficients;
- BOFEK or soil-family campaign matrices;
- performance profiling and repeated timing;
- exploratory solver and time-integration settings;
- hydraulic lookup and surrogate characterization;
- falsification campaigns with many expected negative trials;
- repeated runs that use one unchanged executable with varying input.

A campaign may contain hundreds or thousands of trials without creating one commit, push or Actions job per trial.

## What still belongs in GitHub Actions

Use Actions when remote execution is part of the declared evidence contract, especially for:

- independent reproduction of the selected candidate;
- compiler, platform or configuration portability;
- regression gates;
- admission to canonical;
- a work-unit-specific gate that explicitly names GitHub Actions as authority.

A green exploratory local run does not become qualified merely because it is persisted. A green unrelated Actions run also does not qualify a work unit.

## Minimum provenance for a campaign

A promoted campaign must record, where applicable:

- exact Git commit used for source and executable;
- whether the executable was rebuilt or reused;
- campaign configuration or parameter matrix;
- command template;
- host/runtime/compiler notes when they affect interpretation;
- per-trial return code and wall time;
- relevant physical or numerical diagnostics;
- explicit negative or failed trials that affect the conclusion;
- identification of the candidate, if any, promoted to qualification.

Raw scratch directories do not need to be committed. Prefer compact machine-readable summaries and a human-readable result note.

## Build-once rule

If trials differ only through runtime input or configuration, do not rebuild SWAP for every trial. Pin the executable to the exact source commit and reuse it across the campaign. Rebuild when source, compiler options, linked libraries or another executable dependency changes.

## Parallel work

Local campaigns do not grant authority over moving branches. Before promoting a result or writing repository evidence:

1. refetch canonical;
2. refetch the work branch;
3. reconcile relevant dependency-surface changes;
4. rerun affected trials if the pinned postimage no longer represents the intended candidate.

## Generic harness

`tools/experiments/run_campaign.py` provides a small, model-agnostic local runner. It reads a JSON campaign definition, creates one isolated working directory per case, exposes case parameters as environment variables, executes the configured command, and writes JSONL plus CSV summaries.

It intentionally does not decide scientific acceptance. Work-unit-specific collectors may augment its output with water balance, convergence, time-step, Newton-iteration or other diagnostics.

Example:

```json
{
  "name": "elastic-storage-screen",
  "workdir_template": "examples/Hupsel",
  "command": ["./swap"],
  "matrix": {
    "SS": ["0", "1e-7", "1e-6", "1e-5"],
    "DTMAX": ["0.25", "0.5", "1.0"]
  }
}
```

The runner exposes each parameter as `SWAP5_PARAM_<NAME>`. A work-unit wrapper can use those variables to patch input files before execution.
