# TOP03 conductivity-cut counterfactual: repair route falsified

Removing the inherited near-saturation conductivity shortcut alone is explicitly falsified as a robust repair. It eliminates the measured conductivity jump but increases nonlinear failures under both tested line-search policies. No production source, kernel acceptance, mass ownership or participant semantics changed.

## Source-bound outcome

Research checkpoint e452ebab26523c825cda5e5fdd92b7911d009b0c generates a scratch-only provider: Se>1-1e-6 becomes Se>=1. All other provider operations remain unchanged. The required pre-integration oracle reduces the original 0.1799453461 cm/day jump to 1.3102695e-8 cm/day at the +/-1e-9 cm bracket, retaining the unsaturated-side value. This is the intended counterfactual, not an accidental unchanged source.

| Policy | Baseline failures | Counterfactual failures | Repaired | New failures |
| --- | ---: | ---: | ---: | ---: |
| Original Newton progress | 109 | 155 | 3 | 49 |
| Pressure-aware progress | 80 | 126 | 16 | 62 |

Each policy covers 702 trajectories per build: two geometries, three lower-boundary modes, three initial profiles, three external-head histories, thirteen fixed grids. All four runners finish O0 and O2: 2808 counterfactual integrations in total. Numerical records excluding CPU are exactly identical across optimization levels. All 156 saturated analytical controls per policy pass. Maximum accepted aggregate mass residual is 8.21121e-13 cm; accepted soil and surface gates remain enforced. Failed solves are never included as accepted endpoints.

The original-policy new failures include 24 prescribed-flux mode2 and22 prescribed-head mode5 cases, previously complete under the baseline. The improvement in some free-drainage cases is therefore not a general gain. The pressure-aware variant repairs16 but introduces62 failures. Do not promote a selectively successful grid or profile.

For trajectories complete under both reference and counterfactual, maximum complete-window differences are 3.722015e-4 cm top transfer, 3.126112e-4 cm bottom transfer and5.959027e-5 cm storage. These are declared reference changes, not proof of broad physical equivalence. Refinement sequences are persisted in the result and raw records; finest shallow wet free-drainage completion remains irregular and deep wet free-drainage still fails through4096 steps. A completed grid alone is not a temporal accuracy certificate.

## What this establishes

The inherited discontinuity remains a real source feature. Its removal repairs a subset of cases and changes other trajectories, so it is relevant to the numerical system. But it is neither a complete explanation nor a sufficient robust fix. The tested single-change route is closed. No claim follows that the discontinuous coupled residual has no root, that all saturation transitions are harmless, or that a different consistent Jacobian/globalization could not work.

This result does not justify changing B1/B2 reference physics. Reference correction requires a demonstrated defect and qualification under docs/verification/principles.md and ADR-0005. A future solver proposal should first demonstrate source-consistent frozen-origin residual and Jacobian behaviour for one bounded counterexample, including interior constitutive derivatives and near-saturation branches, before another broad matrix. Retain the reference constitutive law for that diagnosis. Do not add another unverified smoothing, threshold or tolerance change.

TOP03 remains unqualified: the independent BASE temporal exact-state identity blocker, throughput accuracy, live top-active candidate, component receipt/replay/exactly-once qualification and canonical backend reconciliation remain prerequisites. Canonical reviewed0d44f0195c94a9732c67b5e77f2148912df9bbc8; its intervening lower-boundary feasibility/composition work does not change these standalone production dependencies. AGENTS is unchanged. No Actions run or canonical admission; PR#956 stays draft.

## Reproduction

Run `tests/fapp/run_sw_rib_top03_cut_counterfactual.sh` with shallow/deep stubs and geometry2/3, once without a third argument (stock) and once with `strict`. Use separate RUNNER_TEMP directories. Save logs as `/tmp/top03-counterfactual-g{2,3}-{stock,strict}.log`, then run `python tests/fapp/analyze_sw_rib_top03_cut_counterfactual.py`. The runner uses the existing surface-transition fixture and observational terminal-trace generator. The analyzer consumes persisted baseline terminal-trace records, asserts O0/O2 identity and hard controls, and persists bounded CSV evidence. Exact hashes and classification are in `TOP03_CUT_COUNTERFACTUAL_RESULT.json` and `evidence/cut_counterfactual/`.
