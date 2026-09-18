# F-GC41 Whole-window acceptance and retry

F-GC41 starts at the boundary deliberately left open by F-GC39. It does not alter predictor/corrector science.

The contract has two phases. Before publication, retained SWAP candidate, MODFLOW timestep and prepared exchange ledger must independently prove readiness for the exact same window identity. Any failure here is retryable: discard reversible SWAP/ledger state, invalidate the abandoned MODFLOW runtime, reconstruct from the last accepted timestep and enter a fresh smaller window.

After all preflights pass, the coordinator crosses a publication point. MODFLOW `finalize_time_step`, SWAP publication and prepared-ledger commit may then occur exactly once. No ordinary scientific or provenance rejection is allowed after this point. A platform failure in this region is a durability/restart problem and must not be represented as transactional rollback.

The executable first qualification uses deterministic participants. It proves zero publication on every preflight failure, exact success ordering, fail-closed invalid identity, and that a failure after the publication point is never mislabeled as a safe smaller-window retry.

Live MODFLOW `finalize_time_step` remains excluded until a non-mutating readiness seam is qualified.
