# VQ tools

This directory contains verification and qualification tooling only. It must not contain production SWAP physics or become a hidden production execution path.

## B0 identity and provisional runner

```bash
python tools/vq/reference_identity.py --archive /path/to/SWAP_4.3.1.zip
python tools/vq/b0_source_runner.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --work-dir /tmp/vq-b0 \
  --case 2.grassgrowth
```

The GNU runner is capability-limited verification infrastructure and is not declared globally equivalent to the packaged Intel executable. Rounded legacy BAL/BLC output is never the hard mass oracle.

## Current B1.9 corrected reference

`B1.9 = B1.8 + SWAP-012` is the current qualified corrected-reference oracle.

```text
members          63
source bytes      1,863,300
manifest SHA-256  5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
```

Admission and exact reconstruction:

```bash
python tools/vq/b1_9_admission_gate.py
python reference/swap-4.3.1/patches/SWAP-012/tests/run_inverse_evidence_gate.py
python tools/vq/b1_9_reconstruct.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --output-dir /tmp/B1.9/SWAP
```

SWAP-012 is the qualified isolated `prhead` inverse correction for hydraulic models 3 and 5-12. Historical SWAP-011 `dhconduc` content is excluded from the B1.9 patch.

`docs/verification/expected-differences.json` remains the admitted B0 -> B1.9 difference ledger. Unregistered differences fail qualification.

## B2 reference admission: VQ-1d1..1d3

The B2 gate dynamically reads the current B1 oracle from `b1-manifest.yml` and requires the candidate to match exact snapshot, qualification and source-manifest identity.

```bash
python tools/vq/b2_reference_gate.py \
  --candidate tools/vq/cases/b2-reference-candidate.json \
  --evidence tools/vq/cases/b2-reference-gate-2026-09-06.json \
  --allow-expected-blocked
```

A READY candidate additionally requires:

```text
SWAP5-B2-reference-seam-v1
SWAP5-B2-reference-result-v1
SWAP5-B2-reference-result-record-v1
```

The seam requires explicit parameters/state/forcing/numerical config, generic `[t0,t1]`, rollback-safe transaction semantics, reference full-accuracy policy, unrounded mass accounting and diagnostics, with no hidden kernel file/path/MODFLOW-tile/calendar dependencies.

The canonical result validator independently recomputes:

```text
delta_storage = end_total - start_total
net_external  = sum(external signed_amount)
residual      = delta_storage - net_external
```

No universal production mass tolerance is introduced by VQ-1d.

The real B2 candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`.

## VQ-1e1 transaction and generic-time verifier

The executable verifier harness is:

```bash
python tools/vq/tx_time_harness.py \
  --fixture-suite \
  --evidence tools/vq/cases/vq-1e1-tx-time-harness-2026-09-06.json
```

Named cases:

```text
TX-ROLLBACK-01
TX-COMMIT-01
TX-ACCOUNT-01
TX-RERUN-01
TX-BC-REPLAY-01
TX-WARM-01
TIME-00
TIME-06
TIME-18
TIME-36
TIME-SPLIT
```

The deterministic synthetic adapter qualifies the verifier only. Its result is always separated from production status:

```text
qualification_scope                  VERIFIER_HARNESS_ONLY
b2_physics_status                    NOT_EVALUATED
production_physics_executed          false
production_mass_tolerance_qualified  false
```

## VQ-1e2 production-adapter binding

VQ-1e2 prevents a fixture or wrapper from being relabelled as production qualification. The binding contract is:

```text
SWAP5-VQ-production-adapter-binding-v1
```

Validation and admission:

```bash
python tools/vq/production_adapter_binding.py --binding /path/to/binding.json
python tools/vq/production_adapter_gate.py \
  --candidate tools/vq/cases/b2-production-adapter-candidate.json \
  --evidence tools/vq/cases/vq-1e2-production-adapter-gate-2026-09-06.json \
  --allow-expected-blocked
```

A valid production binding must be non-synthetic, bind the same exact B2 commit/entrypoint/seam/result contract/reference policy, preserve the committed physical start across retries, replay forcing exactly, keep warm-start state numerical-only, expose transaction traces, exclude rejected trials from committed totals and commit an accepted interval exactly once.

The bridge may not change physics, numerical policy, forcing, interval or mass terms and may not introduce hidden kernel file I/O or calendar boundaries.

The current VQ-1e2 state is correctly `BLOCKED_NO_ADMITTED_B2_SEAM`.

## Unrounded mass accounting

The common VQ mass contract remains:

```text
docs/verification/mass-accounting-contract.md
tools/vq/contracts/mass-accounting-record.schema.json
```

Hard mass conservation may not be weakened by reference/normal/relaxed/fallback execution policy.

## Focused unit suite

```bash
python -m unittest \
  tools.vq.test_b1_snapshot_identity \
  tools.vq.test_b2_result_contract \
  tools.vq.test_b2_result_record \
  tools.vq.test_b2_seam_contract \
  tools.vq.test_b2_reference_gate \
  tools.vq.test_tx_time_harness \
  tools.vq.test_production_adapter_binding \
  tools.vq.test_production_adapter_gate
```

Every future B1/B2 or production-adapter qualification must record exact source/artifact identity, case identity, interval, runner capability and qualification scope.
