# NUM-UNC canonical reconciliation checkpoint 2026-09-19

Old observation baseline: `187e30153c890151768e929170d14bb22af1d86d`.
Reconciled execution baseline: `308a619c91d2cc3dae7f7aa143cfbe97c780c635`.
Timing: before any P0A0 scientific execution.

## Delta relevant to NUM-UNC

Between the original baseline and this checkpoint, the only `src/` path changed is `src/solver/mod_reference_richards_temporal_indicator.f90`.

The admitted change is PPA-ROOT-HYD01. It extends the restricted Richards temporal-indicator envelope so that a bound `b110_root_sink_provider_t` can be represented by its prescribed root-sink vector. Previously any associated root sink made the temporal indicator unavailable.

The Reference nonlinear solve path, HeadCalc residual insertion of the lagged root sink, current Feddes process, material parameters and Reference mass diagnostic used by P0A0 are unchanged.

P0A0 does not call the temporal indicator. The source change nevertheless creates a compile dependency from the temporal-indicator module to `mod_b110_root_sink_provider`; the research build lists are updated accordingly.

## Research-branch reconciliation

The research branch was merged with canonical checkpoint `308a619...` before A0 execution. Existing P0C and P0B scientific result files retain their original execution provenance. Their preservation workflows may be replayed on the reconciled baseline, but such replay does not rewrite the original result provenance.

All NUM-UNC workflows now explicitly check out `research/num-unc-p0`. This prevents unrelated future movement of the PR base from silently changing the executable research state.

## Scientific consequence

No P0 hypothesis, physical case, threshold, continuation range, forcing schedule or amplification criterion is changed by this reconciliation. P0A0 remains preregistered exactly as before the failed pre-execution infrastructure run.
