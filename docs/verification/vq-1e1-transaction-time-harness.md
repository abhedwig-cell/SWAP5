# VQ-1e1 transaction and generic-time verifier harness

**Workstream:** VQ  
**Slice:** VQ-1e1  
**Depends on:** VQ-1d1..1d3 on the current B1.8 integration surface  
**Current corrected-reference oracle:** `B1.8`  
**Production code changed:** no

## Purpose

VQ-1e1 makes the transaction and generic-time qualification logic executable before a real integrated B2 production seam exists.

This slice qualifies the **verifier harness**, not SWAP5 physics. Its output is deliberately split into:

```text
harness_status      PASS/FAIL
b2_physics_status   NOT_EVALUATED
```

A synthetic fixture PASS therefore proves only that the verifier can recognize correct transaction/time semantics and reject injected violations. It may never be cited as a B2 physics, solver, mass-conservation or numerical-equivalence PASS.

## Adapter boundary

`tools/vq/tx_time_harness.py` defines a small object-level `QualificationAdapter` protocol:

```text
run_interval(QualificationRequest) -> IntervalExecution
```

The request carries:

- `case_id`;
- explicit `t0`, `t1`;
- committed physical state;
- forcing;
- numerical policy;
- optional numerical warm-start guess.

The returned execution carries:

- one canonical VQ-1d3 result record;
- the committed state before and after the interval;
- an attempt trace with trial identity, accepted/rejected status, physical start state, forcing fingerprint, provisional endpoint, contribution flag and numerical start guess.

This is a **VQ normalization surface**, not a production serialization or a mandated SWAP5 in-memory layout. A future TX/HY/RT adapter may map production objects into this protocol after the VQ-1d seam/result gate passes.

## Canonical result reuse

Every synthetic accepted interval is validated through the existing VQ-1d3 canonical result validator:

```text
tools/vq/b2_result_record.py
```

VQ-1e1 therefore does not create a second result or mass-accounting interpretation. Transaction/time checks are layered on top of the already-defined committed endpoint, unrounded accounting and diagnostics semantics.

## Transaction cases

### TX-ROLLBACK-01

Force one rejected trial followed by one accepted retry.

Hard harness checks include:

- the first trial is rejected;
- the retry is accepted;
- rejected work does not contribute to committed totals;
- every trial's **physical** start state equals the original committed state;
- committed input is unchanged by the rejected trial;
- exactly one rollback and exactly one commit occur;
- the accepted endpoint comes from the correct committed physical start.

### TX-COMMIT-01

A one-trial accepted interval must produce exactly one commit, no rollback and one canonical committed endpoint matching the returned record.

### TX-ACCOUNT-01

A rejected trial followed by an accepted retry must count accepted external/result/storage amounts exactly once. The fixture intentionally has an injectable fault that double-counts rejected work; the verifier must reject it even when the resulting record remains internally mass-consistent.

This distinction is important: a zero residual alone does not prove correct transaction accounting.

### TX-RERUN-01

Run exactly the same committed state, forcing, interval and numerical policy twice. The committed physical payload and endpoint must be identical for the deterministic verifier fixture.

Production qualification may later use an explicitly qualified numerical comparison policy if bitwise identity is not the intended reference requirement; VQ-1e1 does not set such a tolerance.

### TX-BC-REPLAY-01

Across retry, every trial must replay the exact same forcing/boundary-condition payload. The harness compares deterministic forcing fingerprints and the final accepted external amount.

### TX-WARM-01

A numerical warm-start guess is allowed to differ radically from the committed physical state. The warm path must still start physically from the same committed state and produce the same committed physics as the cold fixture path.

This operationalizes invariant 8: reuse of a numerical guess is allowed; reuse of the wrong physical initial state is not.

## Generic-time cases

The fixture executes the same six-hour logical interval shape starting at:

```text
TIME-00   [0, 6]
TIME-06   [6, 12]
TIME-18   [18, 24]
TIME-36   [36, 42]
```

Each case checks that the returned result and mass interval preserve the requested `t0` and `t1` exactly. No midnight, day rollover or modulo-24 normalization is allowed by the verifier.

The cases do **not** require equal SWAP physics at different absolute times. Legitimate time-dependent physics is not conflated with generic interval semantics.

## TIME-SPLIT

The synthetic additive fixture compares:

```text
[0,12]
```

with the committed chain:

```text
[0,6] -> commit -> [6,12]
```

The harness checks exact interval coverage, state continuity, equal final endpoint, equal integrated external amount and equal integrated fixture result amount.

For this synthetic additive fixture only, the comparator uses:

```text
comparison_tolerance = 0.0
production_tolerance_qualified = false
```

That exact fixture comparator is a verifier self-test. It is **not** a universal B2 split-equivalence or mass tolerance. Production TIME-SPLIT qualification must define its own accepted comparison rule against the full-accuracy reference mode.

## Fault injection qualification

`tools/vq/test_tx_time_harness.py` demonstrates fail-closed detection for:

- rejected trial mutating the retry physical start;
- duplicate commit;
- rejected-trial double accounting;
- nondeterministic rerun;
- forcing drift on retry;
- warm-start guess replacing the physical start;
- hidden calendar snapping;
- non-composable split behavior;
- stored evidence drift.

The synthetic adapter exists solely for these verifier self-tests. It is not a reduced-order SWAP implementation and is never an admissible B2 target.

## Stored evidence

The deterministic harness projection is pinned at:

```text
tools/vq/cases/vq-1e1-tx-time-harness-2026-09-06.json
```

The projection records only harness scope/status and the 11 named case statuses. It intentionally contains:

```text
b2_physics_status                    NOT_EVALUATED
production_physics_executed          false
production_mass_tolerance_qualified  false
```

CI compares the live projection with this stored evidence and separately runs the VQ-1d B2 admission gate, which remains fail-closed while no production reference seam exists.

## B1.8 relationship

B1.8 differs from B1.7 only by the qualified SWAP-013 PDI `HA/H0` invalid-input guard; valid-input numerical behavior is unchanged. VQ-1e1's transaction/time verifier semantics therefore do not change with the B1.8 repin. The clean B1.8 integration nevertheless reruns the full harness, B1.8 admission identity and SWAP-013 source-bound Fortran guard together so the audit chain stays exact.

## Architecture invariant check

VQ-1e1 directly exercises verifier logic for invariants 7, 8, 9, 13, 23, 25, 26, 29 and 30.

It does not yet qualify the production implementation against those invariants. In particular:

- invariant 7: rollback/commit logic is verifier-qualified, production pending;
- invariant 8: rerun/warm-start logic is verifier-qualified, production pending;
- invariant 9: generic interval preservation is verifier-qualified, production pending;
- invariant 13: canonical accounting is reused, but no new production mass tolerance is admitted;
- invariant 23: numerical warm-start/policy remains distinct from physical state;
- invariant 25: later runs must use the admitted full-accuracy B2 reference seam;
- invariant 26: transaction/solver diagnostics remain machine-auditable;
- invariant 29: calendar snapping is explicitly rejected;
- invariant 30: the qualification surface is documented and tested.

## Qualification decision

The intended VQ-1e1 result is:

```text
VQ-1e1 verifier harness             PASS
11 named TX/TIME fixture cases      PASS
fault-injection detection           PASS
stored harness evidence             PASS
B2 production transaction tests     NOT EVALUATED
B2 production generic-time tests    NOT EVALUATED
B2 production physics/mass PASS      NOT CLAIMED
```

## Next safe step

After the clean B1.8 VQ-1d/VQ-1e1 integration is accepted, TX/HY/RT can supply one real integrated full-accuracy B2 seam. VQ then binds that exact production commit to `QualificationAdapter` and runs the same named cases against production outputs.

Only that later production run may change transaction/generic-time status from `NOT_EVALUATED` to a real B2 qualification result.
