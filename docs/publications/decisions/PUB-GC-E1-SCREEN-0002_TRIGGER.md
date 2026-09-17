# PUB-GC E1 SCREEN-0002 execution-trigger decision

Status: **prospective execution-only deviation, frozen before SCREEN-0002 execution**

Publication owner: `PUB-GC`

Screening manifest: `docs/publications/manifests/PUB-GC-E1-SCREEN-0002.yaml`

Manifest authority: `bc8dca037912de10dbfce33d1ca7a62b34bc7761`

## Context

The frozen SCREEN-0002 manifest names `workflow_dispatch` as the intended GitHub Actions trigger.

The connected GitHub execution surface available in this research session can read workflow state, artifacts and logs and can rerun existing jobs, but it does not expose a workflow-dispatch action for starting a new manual run.

This is an execution-mechanics limitation only. It does not affect the scientific grid, solver configuration, origin policies, observables, selection rule or holdout rule.

## Decision

Before any SCREEN-0002 scientific output exists, permit exactly one temporary push trigger on:

`research/pub-gc-e1-screening`

with the following constraints:

1. the trigger commit may modify only `.github/workflows/pub-gc-e1-screening.yml`;
2. the screening oracle and runner bytes must already be frozen before that trigger commit;
3. the runner remains bound to manifest authority `bc8dca037912de10dbfce33d1ca7a62b34bc7761`, blob `2aef35c16f1b7c87ebd7ff572adeb24e4e830ee4`;
4. the complete 21-row disjoint grid must execute unchanged;
5. no screening row may be added, removed or substituted;
6. the result receipt must record `execution_trigger_deviation: SINGLE_PUSH_FOR_CONNECTOR_LIMITATION`;
7. after the run, restore the workflow to dispatch-only without rerunning SCREEN-0002.

## Non-effect on scientific design

This decision changes only how GitHub Actions starts the frozen executable.

It does not change:

- initial state;
- candidate heads;
- coupling-window durations;
- B1.10 source tree;
- transaction or temporal acceptance semantics;
- same-origin or history-diagnostic policies;
- telemetry;
- eligibility rules;
- stress-class selection;
- primary holdout;
- interpretation or nonclaims.

Therefore the screening remains prospectively controlled with respect to every scientific degree of freedom.

## Failure handling

If the push-triggered run fails because of build, parser, workflow or harness infrastructure, classify that execution as `INVALID_EXECUTION` with no scientific conclusion.

Do not repair the code and reinterpret partial row output from the failed execution as SCREEN-0002 evidence. Any corrected execution must receive a separately recorded execution authority while preserving the frozen scientific grid.
