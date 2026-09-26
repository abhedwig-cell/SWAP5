# F-PE-REPAIR01 — inactive-root qbot scratch ownership repair

Date: 2026-09-26

Status: `PREREGISTERED_REPAIR`

Parent:
`F-PE-REPRO01`

## Defect

REPRO01 localized a process-dependent exact mode-5 failure to a read-before-write of Reference worker scratch.

The prescribed-head bottom-flux materializer currently executes:

`qrosum = sum(richards%provider_root_sink(1:n))`

unconditionally.

When `request%evaluation%root_sink` is not associated:

- root extraction is inactive;
- `provider_root_sink` is not authoritative;
- the scratch vector is not required to have been written;
- process memory contents can contaminate reconstructed qbot.

D9 demonstrated the causal chain:

- clean original: 100/100 PASS;
- original + ROOT_SINK poison: 0/100 PASS;
- conditional inactive-root qrosum + same poison: 100/100 PASS.

## Repair

Modify only the mode-5 qbot materializer ownership rule:

- if `request%evaluation%root_sink` is associated, preserve the existing sum over `provider_root_sink`;
- otherwise set `qrosum = 0.0_real64`.

Do not zero the whole workspace.

Do not change solver tolerances, temporal policy, retry policy or physics.

Do not change root-active semantics.

## Required regression

Add a deterministic regression that:

1. uses mode 5 with root extraction inactive;
2. poisons `provider_root_sink` before the solve/materialization seam;
3. proves the repaired result is identical to a clean workspace;
4. retains the exact accepted solver/transaction outcome.

Also preserve an active-root test showing that a bound root-sink provider still contributes to qbot.

## Requalification

After the production repair:

- exact first-corrector repeated processes;
- fixed-build exact live FGC44 repeatability;
- live SWAP + MODFLOW6 exact route;
- A1 coupled control;
- A2C coupled reproducibility;
- application-shaped A2C mass/accounting;
- existing canonical/reference gates.

## Admission rule

REPAIR01 closes only if:

- poisoned inactive-root regression is deterministic;
- root-active semantics are preserved;
- exact live coupled repeatability no longer exhibits status 6 in the qualification sample;
- no new mass/accounting or endpoint drift appears.

The repair must remain minimal and ownership-correct.
