# A23BN - Native in-memory physical execution seam

## Status

`PASS_NATIVE_IN_MEMORY_PHYSICAL_SEAM / LEGACY_SINGLETON_ADAPTER_ONLY`

A23BN replaces the A23BM trial/retry restart-process bridge with an in-process physical execution seam. A23BL remains the transaction owner. The B1.6 Hupsel model is initialized once through the legacy adapter; thereafter trial state is cloned, restored and advanced in memory. No subprocess or restart file participates in trial, rollback or retry.

## Main result

The first same-process probes exposed order-dependent legacy hidden state: after a full trial, replaying the same committed Hupsel checkpoint produced a different next day. The physical restart state itself was not incomplete, because A23BM had already proven fresh-process restart identity.

The contamination was isolated to two replay requirements for this fixture:

1. meteorological progression cursor: `meteo_rec`, `rain_rec`, `i_metdetail`, `fl_update_meteo`;
2. `cmsy(1:numnod)`, the derived solute mass state used to continue the CDE update from committed `cml` and `theta`.

Restoring those values together with the explicit Hupsel continuation state makes full-versus-two-half execution exactly order independent. Re-running `Meteo(1)` or `Solute(1)` during a trial is not required, so trial execution does not reread forcing or solute configuration.

## Native adapter boundary

`mod_a23bn_hupsel_native_adapter.f90` extends the generic A23BL transaction interfaces. Its transaction state contains active-sized Hupsel state arrays and the minimal legacy replay capsule needed for exact same-process replay. The adapter source contains no `SAVE`, no subprocess/system call and no restart-file dependency.

Legacy file parsing still occurs once during adapter initialization through B1.6 `SWAP(...,task=1,...)`. That I/O remains outside the A23BL transaction kernel and is explicitly transitional verification infrastructure, not the target SWAP5 in-memory input API.

The legacy B1.6 modules themselves remain global/singleton and are therefore not a MultiSWAP production implementation.

## Qualification

### O0/O2 physical gate

Both full B1.6 physical source builds plus the A23BL/A23BN code passed:

- always sampled full + two-half execution;
- full/two-half temporal state equality;
- hard water-mass gate;
- injected outer solver rejection, rollback and retry;
- rejected-trial poisoning isolation;
- exact retry endpoint equality.

O0 and O2 gate logs are byte-identical.

Accepted storage: `77.011710672204643 cm`.

Two-half water-balance residual: `-1.7872350421832550e-7 cm`, below the B1.6 hard limit `1e-6 cm`.

### Independent B1.6 oracle identity

After the accepted native transaction, a qualification-only legacy binary end-state was written. It is byte-identical to the fresh-process A23BM B1.6 oracle:

`4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9`

This compares the complete 1032-byte Hupsel restart/continuation payload, not only selected CSV values.

### Natural legacy retry signal

A measurement-only counter at the existing `TimeControl(5)` timestep-reduction branch observed **10 real internal B1.6 timestep retries** over the qualified 4-5 January continuation. The observer does not alter physical results: instrumented and uninstrumented state dumps have identical SHA-256:

`2c68fd7b14016c8e3160589970c0d5b78490e7165c9610e2da0839aabf321883`

These are internal B1.6 retries. A future native soil-water API must expose such retry/cost information explicitly instead of relying on a VQ patch.

## Architecture assessment

- Invariant 2: PASS for A23BL kernel; legacy initialization I/O remains in the external adapter.
- Invariants 3/4: PARTIAL/PASS for this fixture; physical state and the small replay capsule are explicit and active-sized, but further state classification is required before production layout is frozen.
- Invariant 5: unchanged; Newton/Jacobian scratch is not migrated here.
- Invariants 7/8: PASS for the qualified Hupsel interval, including rejection and replay from the same committed state.
- Invariant 9: A23BL is generic, but this legacy physical adapter currently accepts integer-day boundaries only. Production generic time remains pending.
- Invariant 13: PASS for the qualified interval under the B1.6 `1e-6 cm` hard gate.
- Invariants 16/27: NOT YET QUALIFIED. The wrapped B1.6 model is a global singleton and is not a scalable MultiSWAP worker implementation.
- Invariant 23: no physical option was changed to obtain the result.
- Invariant 30: source, gate and provenance evidence are retained.

## Deliberate exclusions

A23BN does not introduce selective step doubling, does not change hydraulic equations or the top Jacobian route, does not claim thread safety, and does not yet replace legacy configuration/forcing parsing with typed in-memory inputs.

## Next cut

A23BO should turn this qualified VQ seam into the first clean native physical component contract: separate physical continuation state from replay/forcing cursor state, expose solver attempt/retry diagnostics directly, and remove the legacy singleton ownership assumption for the Hupsel-capable soil-water execution path. A23BM remains the independent B1.6 oracle during that extraction.
