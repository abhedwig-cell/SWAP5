# F-GC-STRIP01 C2b rainfall continuation result

## Outcome

The continuous C2a→C2b workflow completed successfully as a harness run, but the hydrologic C2b window was rejected. This is a negative qualification result, not a coupled success.

- C2a: one accepted 0.001 d equilibrium window; all 50 heads remained −1 m and each SWAP column retained 0.7499125387644275 m³ of reported storage. The state hash changed from the original state to the accepted C2a state; all revisions and interface ledger counts advanced once.
- C2b: 0.001 d beginning at day 0.001 with uniform 1 mm/d surface precipitation. The prescribed input was 0.00005 m³ over the 50 m² strip. The context and forcing setup returned status 0, then the first SWAP corrector rejected (service status 6, iteration 1, stage `swap-corrector`). No trial heads were returned and no state was published.
- After rejection, all 50 column storages remained 0.7499125387644275 m³; the committed state hash remained `997123bcf8286dff69c4b95f555645641bc7fc58b7bed757ae8dcc8b91fe7871`; revisions and ledger counts remained 1. MODFLOW prepared and solved C2b, but did not finalize the solve or time step.

The recorded 0.00005 m³ “mass residual” equals the forcing volume because the candidate was rejected and the committed state did not change. It is an unpublished trial/input diagnostic, not an accepted-window water-balance residual. No claim of physical mass loss or coupling mass-balance failure follows from it.

## Classification and diagnostic replay

The second instrumented run retained the same coupled outcome. All 50 MODFLOW trial heads were exactly −1.0 m and passed the research fixture's head-domain guard. The C API returned FMR context status 5 (`FMR_GW_APP_CONTEXT_PARTICIPANT_FAILED`), so the failure is downstream of the head-domain guard in the SWAP participant path.

To expose the numerical rejection counters without changing canonical sources, the research fixture then ran an isolated direct backend trial for each column using the recorded head (−1.0 m), rain forcing (0.1 cm/day), C2b time interval (0.001–0.002 d), and the same committed C2a state. All 50 diagnostic trials returned canonical transaction status 2 (`CANONICAL_STATUS_TRANSACTION_FAILED`), with 0 accepted substeps, 3 solver rejections, 6 temporal rejections, 0 mass rejections, 0 admission rejections, 9 attempts, and 8 retries. The direct diagnostic trials were discarded; the coupled C2a committed state remained unchanged.

These counters come from isolated diagnostic replays rather than counters read from the original context call. They localize the reproduced SWAP failure to solver/temporal rejection before mass acceptance. The root numerical cause remains unresolved.

## Rain-free control and exact replay

A separate fresh-process run performed 50 direct transaction diagnostics at the initial C2a state before any coupled operation. Every no-rain trial at −1.0 m over 0.001 d completed with one accepted substep and zero solver, temporal, mass, or admission rejections. The profile state hash was unchanged after all diagnostic trials.

The same run executed the complete continuous C2a→C2b sequence twice in separate processes. The two sequence JSON files were byte-identical (SHA-256 `bdccb32f739bcfe7ebdd3453701434e7d0ea8f4eae831cbf7d408e532b178451`). Direct C2b diagnostic replays again returned the same per-column pattern: 0 accepted substeps, 3 solver rejections, 6 temporal rejections, and no mass or admission rejections.

This matched-head, matched-window control indicates that the imposed 1 mm/day surface rainfall activates the reproduced SWAP solver/temporal rejection pattern in this fixture. It does not identify the underlying estimator or nonlinear-solver cause. The diagnostic rejection counters are from isolated backend replays, not counters from the original application-context call.

Machine-readable comparison: `integration/f-gc/strip01/results/C2a_C2b_forcing_diagnostic_run_37114071020.json`.

## Next work

Keep registered physical forcing, 0.001 d duration, head/flux/mass gates, retry policy, and physics unchanged. Inspect the canonical SWAP temporal and solver rejection sources with the isolated control evidence. The separately preregistered B1.11 dynamic-surface route remains useful and is being rerun with a fresh second-window context; its results must remain separate because it excludes Richards temporal history. Do not begin Hupsel forcing until an accepted coupled window closes its balance.

## Provenance

- GitHub Actions run: [37112827684](https://github.com/abhedwig-cell/SWAP5/actions/runs/37112827684), conclusion `success` for the reproducibility harness.
- Run source: `65d79f753db41afe19b250d5e43a61a6c82b29b2`; canonical SWAP source used by the build: `e3bfcdca00ba89cfeea529cf9b648dcc803483ab`.
- Artifact SHA-256: `87a46839458e06b2f3a3ebe4c28889c5aad02209b51ea36ea41fee8ef2e23f2a`.
- Machine-readable record: `integration/f-gc/strip01/results/C2b_rain_continuation_run_37112827684.json`.
- Research/qualification only; no canonical admission.
