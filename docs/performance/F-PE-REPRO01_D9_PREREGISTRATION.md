# F-PE-REPRO01 D9 — inactive-root qbot-materialization falsification

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

D8 localized the deterministic scratch dependency to one array:

- ROOT_SINK poison: 0/40 PASS;
- THETA/K/CAPACITY/DKDH poison: 40/40 PASS each.

Source inspection found that prescribed-head bottom-flux materialization executes:

`qrosum = sum(richards%provider_root_sink(1:n))`

unconditionally.

For root-inactive requests, `request%evaluation%root_sink` is not associated and the provider scratch is not authoritative.

## Hypothesis

The exact mode-5 route has a read-before-write defect in qbot materialization:

- inactive root extraction leaves `provider_root_sink` scratch undefined;
- mode-5 qbot materialization nevertheless sums it;
- process-dependent scratch contents can therefore contaminate the transaction and produce status 6.

## Test-only falsification

Use the D8 ROOT_SINK poison fixture.

Patch only the copied diagnostic legacy-binding source so qrosum is:

- the sum of `provider_root_sink` when a root-sink provider is associated;
- exactly zero otherwise.

Do not modify repository `src/**`.

Run:

- ZERO control: 100 processes;
- ROOT_SINK poison with original materialization: 100 processes;
- ROOT_SINK poison with conditional inactive-root materialization: 100 processes.

## Decision

The hypothesis is supported only if:

- ZERO passes;
- original ROOT_SINK poison reproduces failure;
- conditional inactive-root materialization restores deterministic success and the clean physical signature.

If supported, REPRO01 has localized a concrete ownership defect and may hand off to a separate production repair workunit.
