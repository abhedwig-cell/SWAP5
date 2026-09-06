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

The GNU runner is capability-limited verification infrastructure and is not declared globally equivalent to the packaged Intel executable.

## Current B1.9 corrected reference

`B1.9` is the current corrected-reference oracle:

```text
B1.9 = B1.8 + SWAP-012
```

SWAP-012 targets `MOD_MvG_functions.f90`, unchanged by B1.1-B1.8, so its ordered B1.8 preimage equals canonical B0. The exact stored patch is isolated from the historical SWAP-011 `dhconduc` changes.

Admission bookkeeping:

```bash
python tools/vq/b1_9_admission_gate.py
```

The stored actual-source roundtrip evidence is bound to exact patch/preimage/corrected-target identities by:

```bash
python reference/swap-4.3.1/patches/SWAP-012/tests/run_inverse_evidence_gate.py
```

Exact source reconstruction from canonical B0:

```bash
python tools/vq/b1_9_reconstruct.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --output-dir /tmp/B1.9/SWAP
```

Expected source identity:

```text
members          63
source bytes      1,863,300
manifest SHA-256  5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
```

SWAP-012 qualification is based on the broader D2 22,240-point inverse study plus a separately executed 600-point actual-source strict GNU Fortran gate. B0 fails 513/600 isolated points at `1e-6` decade; the corrected source fails 0/600 with maximum error `1.17e-10` decade. Model 4 remains the analytical control.

## Expected differences

`docs/verification/expected-differences.json` defines the admitted B0 -> B1.9 difference envelopes. Any unregistered difference remains a qualification failure.

## B2 reference-entrypoint admission

Before a numerical B1.9 -> B2 comparison can run, the candidate checkout must pass:

```bash
python tools/vq/b2_reference_gate.py \
  --repo-root /path/to/SWAP5-checkout \
  --candidate tools/vq/cases/b2-reference-candidate.json
```

The fail-closed gate still requires an exact B2 commit, integrated callable reference-mode entrypoint, explicit reference numerical policy, canonical result contract, generic `[t0,t1]`, committed state and forcing inputs, separate numerical configuration, unrounded mass accounting and transaction diagnostics.

The current candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`. B1.9 changes corrected legacy inverse behaviour only; it does not create the missing production B2 seam.

## Unrounded mass accounting

The future B2 normalization contract remains under `docs/verification/mass-accounting-contract.md` and `tools/vq/contracts/mass-accounting-record.schema.json`. Hard mass conservation may not be weakened by execution policy.

## Unit tests

```bash
python -m unittest \
  tools.vq.test_reference_identity \
  tools.vq.test_balance \
  tools.vq.test_b0_source_runner \
  tools.vq.test_b1_snapshot_identity \
  tools.vq.test_b1_reconstruct \
  tools.vq.test_b2_reference_gate
```

Every future B1/B2 adapter must record exact source/artifact identity, case identity, interval, runner capability and qualification scope.
