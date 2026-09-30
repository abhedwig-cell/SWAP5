# F-PE-ELASTIC57 — non-monotone mode-7 certificate controller robustness preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC56 — QUALIFIED_LOCALIZED_BINF_NONMONOTONICITY_WITH_GLOBAL_ENVELOPE_PRESERVED`

Parent branch head:
`research/f-pe-elastic56-monotonicity-attribution@39237db54f0a8ee6d0bb9548fdf367828df0f975`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Frozen global research envelope:
`H_INF <= 0.17320259355765216 * Binf`.

## Question

Can the existing model-certificate retry semantics remain safe and bounded when
the mode-7 defect indicator is locally non-monotone with dt?

ELASTIC57 does not modify `mod_transaction_reference`.
It simulates the existing `TX_TEMPORAL_MODEL_CERTIFICATE` retry contract over
the qualified ELASTIC55/56 direct-solve bank.

## Controller semantics

For a requested interval and a fixed research head-error budget `H_budget`:

1. start at retry index 0;
2. if the full solve fails, retry at the next frozen dt;
3. if the research mode-7 indicator is unavailable/nonfinite, retry;
4. if the independent full-trial hard mass ledger exceeds `1e-12 cm`, retry;
5. compute the conservative predicted error
   `H_bound = alpha_global * Binf`;
6. accept when `H_bound <= H_budget`;
7. otherwise retry at `dt *= 0.5`;
8. after retry index 8, fail closed as exhausted.

No step assumes that Binf must decrease after one halving.
No retry reversal or dt growth is permitted.

This mirrors the monotonic-free acceptance semantics already present in
`TX_TEMPORAL_MODEL_CERTIFICATE`.

## Frozen target sequences

The 15 violating eligible ELASTIC56 sequences are frozen explicitly:

1. 11060 / OFF / h0=2 / delta=+0.035
2. 10260 / OFF / h0=2 / delta=+0.035
3. 10260 / FIXED_1E6 / h0=2 / delta=+0.035
4. 10260 / OFF / h0=2 / delta=+0.05
5. 10260 / FIXED_1E6 / h0=2 / delta=+0.05
6. 10260 / OFF / h0=10 / delta=+0.035
7. 8016 / OFF / h0=2 / delta=+0.035
8. 8016 / OFF / h0=2 / delta=+0.05
9. 8016 / OFF / h0=10 / delta=+0.035
10. 8016 / OFF / h0=10 / delta=+0.05
11. 3030 / OFF / h0=2 / delta=+0.035
12. 3030 / OFF / h0=2 / delta=+0.05
13. 3030 / FIXED_1E6 / h0=2 / delta=+0.05
14. 3030 / OFF / h0=10 / delta=+0.035
15. 3030 / OFF / h0=10 / delta=+0.05

## Matched monotone controls

For each target sequence use the same:
- profile;
- regime;
- initial head;
- perturbation magnitude;

but reverse the perturbation sign.

Thus each positive-forcing target has one negative-forcing matched control.

Total sequences:
`15 target + 15 control = 30`.

## Frozen dt ladder

`[0.015625, 0.0078125, 0.00390625, 0.001953125,
0.0009765625, 0.00048828125, 0.000244140625,
0.0001220703125, 0.00006103515625] day`.

Maximum retries:
`8`.

## Research budget sweep

No production temporal tolerance is selected.

Evaluate the following head-error budgets in cm:

`[0.05, 0.10, 0.25, 0.50, 1.0, 2.0, 5.0, 10.0]`.

The same budgets are applied to all target/control sequences and all regimes.

## Mass gate

For every full-converged candidate reconstruct an independent full-trial ledger:

`storage_end - storage_start - (total_in - total_out)`.

The controller may accept only when the ledger residual is finite and
`abs(residual) <= 1e-12 cm`.

This is a research hard gate. It does not replace the canonical transaction
mass ledger.

## Safety oracle

Where the controller-accepted retry point also has a converged full+half1+half2
trajectory, require:

`H_INF <= H_budget`.

Any paired accepted point violating the requested budget falsifies the
controller candidate.

Accepted points without a paired trajectory are classified
`UNVERIFIED_ACCEPT` and may not be used as direct safety proof.

## Paired efficiency oracle

For each sequence/budget with at least one paired point satisfying
`H_INF <= H_budget`, identify the earliest such retry as the paired oracle.

Compare:
- controller accepted retry;
- paired-oracle retry.

Record extra refinement when the conservative certificate accepts later.

## Hypotheses

H1. The monotonic-free controller terminates in at most nine attempts for every
sequence/budget and never oscillates.

H2. There are zero paired unsafe accepts.

H3. Local Binf increases can cause extra refinement or exhaustion, but not an
unsafe paired acceptance.

H4. The violating target sequences remain controllable over at least part of
the preregistered budget sweep.

H5. Opposite-sign controls require no more pathological retry behavior than
targets at the same budget.

## Gates

A1. Exactly the 15 frozen target sequences and 15 matched controls execute.

A2. O0/O2 physical/indicator outputs agree.

A3. Full-trial ledger mass is finite and hard-gated for every accepted
candidate.

A4. Frozen alpha is exact and never refit.

A5. Every controller outcome is ACCEPTED or EXHAUSTED within 9 attempts.

A6. Zero paired unsafe accepts.

A7. No `src/**` production changes.

## Decision

ELASTIC57 may qualify:
- a robust research controller candidate;
- a conservative-but-inefficient candidate;
- or a falsified controller route.

It may not authorize:
- production temporal policy replacement;
- a production head budget;
- production mode-7 indicator admission;
- relaxation of mass or solver gates.
