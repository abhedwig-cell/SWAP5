# VQ-1e2 production-adapter binding gate

**Workstream:** VQ  
**Slice:** VQ-1e2  
**Current corrected-reference oracle:** `B1.9`  
**Production code changed:** no

## Purpose

VQ-1e1 qualified the transaction/generic-time verifier itself with a deterministic synthetic fixture. VQ-1e2 defines the next fail-closed boundary: how that verifier may be bound to a **real integrated B2 reference implementation** without turning a fixture, wrapper or translation layer into an alternative physics path.

VQ-1e2 does **not** execute SWAP5 physics. It only admits a production bridge for later VQ execution.

## Required chain

A production TX/TIME run is admitted only after this complete chain is true:

```text
current qualified B1 oracle
  -> admitted B2 reference candidate
  -> SWAP5-B2-reference-seam-v1
  -> SWAP5-B2-reference-result-v1
  -> SWAP5-VQ-production-adapter-binding-v1
  -> VQ-QualificationAdapter-v1
```

The current B2 target is still blocked, so the real VQ-1e2 state is also blocked.

## Files

```text
tools/vq/contracts/production-adapter-binding.schema.json
tools/vq/production_adapter_binding.py
tools/vq/production_adapter_gate.py
tools/vq/cases/b2-production-adapter-candidate.json
tools/vq/cases/vq-1e2-production-adapter-gate-2026-09-06.json
```

## Binding identity

A valid binding must identify one exact 40-character implementation commit and bind the VQ bridge to exactly the same:

- B2 entrypoint path;
- B2 reference-seam path;
- B2 semantic result-contract path;
- `reference` numerical policy.

A commit or path mismatch fails admission even when all files individually exist.

## Production-only requirement

The binding declaration requires:

```text
production_target = true
synthetic_fixture = false
qualification_adapter_protocol = VQ-QualificationAdapter-v1
```

The VQ-1e1 `SyntheticTransactionalAdapter` can therefore never satisfy VQ-1e2 production admission.

## Transaction/time mapping

The bridge must explicitly preserve the semantics already exercised by VQ-1e1:

```text
generic interval forwarded exactly
committed state remains physical trial start
forcing replayed exactly on retry
warm start remains numerical only
accepted result normalized to canonical VQ record
transaction trace exposed
rejected trials excluded from committed totals
one accepted interval committed exactly once
```

These are verification-boundary requirements. They do not prescribe the internal SWAP5 Fortran type layout, ABI, worker scratch layout or MultiSWAP storage layout.

## Non-interference

The bridge is not allowed to change:

```text
physics
numerical policy
forcing
requested interval
mass terms
```

It must also not introduce kernel file I/O or a hidden calendar/day boundary. Legacy file translation may remain outside the kernel, consistent with the architecture invariants.

## Gate states

`tools/vq/production_adapter_gate.py` distinguishes three relevant states:

```text
BLOCKED_NO_ADMITTED_B2_SEAM
BLOCKED_NO_PRODUCTION_ADAPTER_BINDING
READY_FOR_PRODUCTION_TX_TIME_QUALIFICATION
```

The gate first reruns the full VQ-1d B2 admission. A production binding cannot bypass or weaken that gate.

## Current repository state

```text
B1.9 corrected-reference oracle          PASS
B2 reference target                      BLOCKED
production adapter binding               ABSENT
VQ-1e2 ready for production TX/TIME      false
production physics executed              false
```

The expected fail-closed reason is:

```text
b2_reference_target_not_admitted
```

## Self-qualification

The unit suite includes negative cases proving rejection of:

- a blocked B2 target;
- a nominal production binding before the B2 target is admitted;
- a missing binding file;
- a synthetic fixture binding;
- an implementation-commit mismatch;
- a B2 entrypoint mismatch;
- physics interference;
- protocol mismatch;
- missing exactly-once transaction semantics;
- stored evidence drift.

A complete temporary integrated fixture may pass the **gate logic**. That fixture pass is not B2 physics evidence.

## Architecture invariants

VQ-1e2 directly protects invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30. It also prevents the verification adapter from becoming a second kernel or from silently changing physics to satisfy a test.

## Next safe step

**VQ-1e3** begins only when TX/HY/RT provide a real admitted B2 seam and one exact non-synthetic production binding. VQ then instantiates that bridge and runs the existing named TX/TIME cases against production outputs. Only VQ-1e3 may change `B2 transaction qualification` or `B2 generic-time qualification` from `NOT_EVALUATED` to PASS/FAIL.
