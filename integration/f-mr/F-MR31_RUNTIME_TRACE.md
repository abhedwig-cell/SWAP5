# F-MR31 current-canonical runtime trace

Source authority: `integration/f-ci-canonical@49863406a6112baa9956f9396b34e7188934e0d4`.

Independent failure authority: clean F-VQ48 closeout `2274f683fe71379d44a03867ccaffaef2ce5ebce`, which demonstrated that the failed F-MR30 helper could combine a ready candidate with a different valid `root_extraction_sink` vector and still publish after a valid generic commit receipt.

## Current private execution seam

`mod_fmr_serialized_multiswap_runtime::execute_column` resolves one `forcing_index` from the logical column's `forcing_handle`. That same local index remains in scope for the complete private execution path.

The physical candidate is created by:

```fortran
call backend%run_trial(..., forcing_registry(forcing_index), ..., t0, t1, checkpoint, kernel_result, candidate, kernel_diag)
```

No later code re-resolves or substitutes the forcing handle. The same stack frame then validates completion, mass-accounting completeness and candidate readiness and finally invokes either `fmr_commit_candidate_with_receipt` or `fmr_commit_candidate`.

Therefore the private runtime already possesses an enforceable by-construction association between:

1. logical column and `forcing_handle`;
2. exact `forcing_registry(forcing_index)` supplied to physical candidate creation;
3. candidate lineage/revision/interval;
4. successful physical commit;
5. per-column result object returned for that same execution.

## Remediation decision

Do not repair the failed F-MR30 public prepare/finalize helper. Instead publish accepted actual-transpiration attribution directly on `fmr_serialized_column_result_t` after successful commit, using the exact in-scope `forcing_registry(forcing_index)` that created the candidate.

The initial restricted fields are:

```fortran
logical :: actual_transpiration_available = .false.
real(real64) :: actual_transpiration_amount = 0.0_real64
```

For the frozen restricted root-extraction profile, the postcommit amount is:

```text
sum(root_extraction_sink(:)) * (t1 - t0)
```

The runtime may mark this result available only when the exact bound root sink is allocated, finite and nonnegative and the physical commit succeeded. Failed, rejected or noncommitted executions must retain the default unavailable/zero result.

## Why this closes HN1

There is no public attribution operation receiving an arbitrary candidate and arbitrary forcing object. The caller cannot re-pair a committed candidate with another valid qrot vector. Attribution is computed inside the private execution frame from the same registry element already passed to `run_trial`.

## Mass-accounting rule

The result is attribution metadata only. It names the root-extraction subset already present in canonical `mass_out`; it is never added to `mass_out`, aggregate mass, storage change or any other water-balance term.

## Scope boundaries

This remediation does not qualify dynamic qrot reevaluation within an outer interval, SWKIMPL=1 dynamic uptake, additional uptake stress families, persistent crop accounting, or parallel root-attribution composition. Those remain separate qualification work.
