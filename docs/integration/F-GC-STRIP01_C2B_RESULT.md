# F-GC-STRIP01 C2b rainfall continuation result

## Outcome

The continuous C2a→C2b workflow completed successfully as a harness run, but the hydrologic C2b window was rejected. This is a negative qualification result, not a coupled success.

- C2a: one accepted 0.001 d equilibrium window; all 50 heads remained −1 m and each SWAP column retained 0.7499125387644275 m³ of reported storage. The state hash changed from the original state to the accepted C2a state; all revisions and interface ledger counts advanced once.
- C2b: 0.001 d beginning at day 0.001 with uniform 1 mm/d surface precipitation. The prescribed input was 0.00005 m³ over the 50 m² strip. The context and forcing setup returned status 0, then the first SWAP corrector rejected (service status 6, iteration 1, stage `swap-corrector`). No trial heads were returned and no state was published.
- After rejection, all 50 column storages remained 0.7499125387644275 m³; the committed state hash remained `997123bcf8286dff69c4b95f555645641bc7fc58b7bed757ae8dcc8b91fe7871`; revisions and ledger counts remained 1. MODFLOW prepared and solved C2b, but did not finalize the solve or time step.

The recorded 0.00005 m³ “mass residual” equals the forcing volume because the candidate was rejected and the committed state did not change. It is an unpublished trial/input diagnostic, not an accepted-window water-balance residual. No claim of physical mass loss or coupling mass-balance failure follows from it.

## Classification and next work

The run isolates the first failure to the SWAP corrector after valid forcing setup and context advancement. Available evidence does not yet separate a SWAP numerical rejection from temporal/coupling acceptance or fixture/configuration behavior. Preserve the committed C2a state and frozen preregistered limits. Next, expose the existing SWAP transaction diagnostics for the rejected attempt and determine which rejection counter/gate fired; then test the separately preregistered dynamic top-boundary route only after its compile/context issues are checked. Do not widen tolerances or begin Hupsel forcing until an accepted C2b window closes its balance.

## Provenance

- GitHub Actions run: [37112827684](https://github.com/abhedwig-cell/SWAP5/actions/runs/37112827684), conclusion `success` for the reproducibility harness.
- Run source: `65d79f753db41afe19b250d5e43a61a6c82b29b2`; canonical SWAP source used by the build: `e3bfcdca00ba89cfeea529cf9b648dcc803483ab`.
- Artifact SHA-256: `87a46839458e06b2f3a3ebe4c28889c5aad02209b51ea36ea41fee8ef2e23f2a`.
- Machine-readable record: `integration/f-gc/strip01/results/C2b_rain_continuation_run_37112827684.json`.
- Research/qualification only; no canonical admission.
