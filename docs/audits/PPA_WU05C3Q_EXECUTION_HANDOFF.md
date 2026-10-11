# PPA-WU05-C3Q execution handoff

Status: `RUNNER_READY / EXECUTION_EVIDENCE_PENDING`

## One-command oracle run

From repository root, with the already-pinned exact SWAP 4.3.1 distribution archive available:

```bash
python3 tools/vq/c3q_run_oracle.py \
  --archive /path/to/exact/SWAP_4.3.1.zip \
  --work-dir /tmp/ppa-wu05-c3q
```

The archive is accepted only if existing VQ B0 identity verification passes.

## Outputs

`/tmp/ppa-wu05-c3q/c3q_oracle_result.json`

and

`/tmp/ppa-wu05-c3q/run/2.grassgrowth/c3q_oxygen_trace.csv`

The JSON records:
- B1 reconstruction status;
- source manifest identity;
- original and instrumented oxygenstress hashes;
- instrumentation reversibility;
- executable hash;
- SWAP completion status;
- trace hash and byte count.

## Admission rule

Do not label C3Q PASS merely because this runner completes. Completion establishes the oracle trace.
The next gate is the pure-kernel replay and field-by-field comparison.
