# F-CI04 Canonical Runtime and B1.10 Physical Seam

## Scope

F-CI04 adds the canonical runtime contract above the already qualified F-CI03 transaction substrate. It changes no SWAP physics, constitutive relation, Jacobian formula, solver policy or selective step-doubling policy.

The work unit solves one important integration problem: `execute_reference_interval` may legally accept a shorter internal interval after retry. A caller requesting `[t0,t1]` therefore needs a runtime layer that keeps advancing until the full requested interval is reached.

## Canonical data categories

The runtime API now distinguishes:

- persistent physical state: `canonical_state_t` implementations;
- forcing: `canonical_forcing_t` implementations;
- numerical configuration: `canonical_numerical_config_t`;
- worker-owned numerical scratch: outside persistent state;
- result and diagnostics: `canonical_result_t`;
- mass accounting: `canonical_mass_accounting_t`.

The forcing object is presented separately to `canonical_physical_model_t%prepare_interval`. It is not embedded in the persistent state contract.

## Atomic requested interval

`run_canonical_interval` clones the externally committed state into a private working state. Internal accepted substeps may update only that working state. The external state is replaced only after the requested `t1` has been reached.

Therefore:

```text
external committed state
        |
        +--> private working clone
                 |
                 +--> transaction 1 -> accepted partial step
                 +--> transaction 2 -> retry -> accepted partial step
                 +--> ... until requested t1
                 |
                 +--> one external commit
```

If a transaction fails, progress stalls, or the configured substep bound is exhausted, the external committed physical state is unchanged.

This is stronger than exposing partially advanced state to the caller and is appropriate for coupling windows and reruns.

## Generic time

The runtime uses real-valued generic `t0` and `t1`. It has no calendar, date, midnight or one-day assumption. Calendar events remain the responsibility of physical/process implementations when they are actually required.

The B1.10 physical seam contract explicitly forbids integer-day projection in the canonical seam. The existing A23BU Hupsel adapter is therefore not imported wholesale.

## Mass conservation

The F-CI03 transaction core retains its hard per-attempt mass gate. F-CI04 aggregates the maximum absolute accepted-step residual as a diagnostic.

F-CI04 deliberately does **not** claim complete interval mass accounting yet. `canonical_mass_accounting_t%complete` remains false because the current generic transaction interface does not expose accepted unrounded flux totals independently from rejected trials.

No zero totals are invented. B2 admission remains blocked until a B1.10 physical seam can supply complete accepted physical interval accounting.

## B1.10 physical adapter boundary

A future B1.10 adapter must implement `canonical_physical_model_t` and satisfy all of the following before admission:

1. use B1.10 as the exact physical source oracle;
2. accept generic `[t0,t1]` without integer-day projection in the canonical seam;
3. keep forcing separate from persistent physical state;
4. keep numerical configuration separate from physical state;
5. keep worker scratch outside the column state;
6. expose hard, unrounded accepted-interval mass accounting;
7. keep legacy file I/O outside the canonical kernel/runtime path;
8. preserve B1.10 corrected physics and numerical reference behaviour;
9. prove failed and rejected trials do not affect externally committed state;
10. retain explicit holds for unqualified irrigation/crop continuation behaviour.

## Qualification

GitHub Actions run `34081431284` passed both the F-CI03 regression job and the F-CI04 canonical-runtime job. The focused F-CI04 gate compiled and executed the runtime at strict `-O0` and `-O2` and covered:

- completion of a requested interval through multiple accepted internal steps;
- atomic rollback at the requested-interval boundary;
- hard mass rejection;
- non-calendar time;
- exact rerun repeatability;
- forcing as a separate input category;
- invalid interval rejection;
- refusal to fabricate complete mass accounting.

## Decision

`PASS_CANONICAL_RUNTIME_PHYSICAL_ADAPTER_BLOCKED`

F-CI04 admits the canonical runtime and physical seam contract, not a B1.10 physical adapter implementation.

The next integration unit may implement that adapter only against this contract and only from exact B1.10 source provenance.
