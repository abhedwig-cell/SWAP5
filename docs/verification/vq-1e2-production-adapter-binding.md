# VQ-1e2 production-adapter binding gate

**Workstream:** VQ  
**Slice:** VQ-1e2  
**Current corrected-reference oracle:** `B1.10`  
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

## Binding identity

A valid binding must identify one exact 40-character implementation commit and bind the VQ bridge to exactly the same B2 entrypoint path, reference-seam path, result-contract path and `reference` numerical policy.

It must declare:

```text
production_target = true
synthetic_fixture = false
qualification_adapter_protocol = VQ-QualificationAdapter-v1
```

The VQ-1e1 synthetic adapter can therefore never satisfy production admission.

## Transaction/time mapping

The bridge must preserve generic interval forwarding, committed-state retry origin, exact forcing replay, numerical-only warm start, canonical result normalization, transaction traces, exclusion of rejected trials from committed totals and exactly one commit of an accepted interval.

The bridge may not change physics, numerical policy, forcing, requested interval or mass terms, and it may not introduce kernel file I/O or hidden calendar boundaries.

These requirements constrain the verification boundary, not the internal SWAP5 Fortran type layout, ABI, worker scratch or MultiSWAP storage layout.

## Current repository state

```text
B1.10 corrected-reference oracle         PASS
B2 reference target                      BLOCKED
production adapter binding               ABSENT
VQ-1e2 ready for production TX/TIME      false
production physics executed              false
```

The expected fail-closed reason is `b2_reference_target_not_admitted`. Staging of the separate SWAP-004 legacy candidate does not alter this B2 observation.

## Self-qualification

The unit suite proves rejection of a blocked B2 target, premature/missing binding, synthetic fixture binding, implementation-commit mismatch, B2 entrypoint mismatch, protocol mismatch, physics interference, missing exactly-once semantics and stored-evidence drift. A complete temporary fixture may pass gate logic but is not B2 physics evidence.

## Architecture invariants

VQ-1e2 directly protects invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30.

## Next safe step

VQ-1e3 first admits execution itself. Only after the real B2 seam passes VQ-1d and its non-synthetic bridge passes VQ-1e2 may VQ-1e3 load that adapter and run the named production TX/TIME suite.
