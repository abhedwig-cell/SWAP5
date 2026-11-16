# Hupsel51 water receipt repair

Base: canonical f1883e6fae59658112f6b5750c395a1b54543ed2; separate branch codex/hupsel51-water-balance.
Frozen RC2 and prior failed evidence remain unchanged.
Scope: original nonmacro nonsnow explicit-bottom daily receipts; no tolerance, physical input, rollback or persistent schema changes.
Observed failure: reactive Hupsel with SWDRA0 rejects day51, independent residual1.000099586478953e-10cm, whereas summed-step residual is-9.991018965925177e-11cm. Both original O2 and O0-kernel own50->51 refusal proofs remain preserved.
Hypothesis: step-local increments do not include rounding from WatStor and daily Integral counters. Require the projected exported receipt to pass the same existing1e-10cm limit before convergence as well as the incumbent step guard. Original Newton/rollback remains the only state modifier. The helper reads accepted counters plus a candidate and writes no physical state.
Implementation: candidate predictor and strict convergence hook persisted, not yet tested. New helper keeps original accumulation order and uses wide reductions for host-fsum amounts; both binary64 kernel associations are checked. Macro/snow/reconstructed-bottom behavior is excluded.
Next: compile O2 and compare actual day51 projection/output; then short own-prefix and full1096, native day restart at50 and530, O0 generated donor/kernel, named preservation and original short comparison. If two repairs fail, reevaluate rather than tune thresholds.
Local evidence: C:\SWAP5-RC2\application-acceptance\new-variants-20261116\hupsel-reactive-undrained (read-only predecessor).
