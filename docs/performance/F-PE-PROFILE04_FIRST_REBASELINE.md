# F-PE-PROFILE04 — first canonical rebaseline result

Date: 2026-09-26

Measurement head: `372b2a7bef48759750518e043d2433422b555301`

Workflow run: `36220439795`

Status: `FIRST_REBASELINE_PASS`

## Results

### Setup: PLANVALID01

Paired against the pre-PLANVALID ZERO-WASTE authority:

- N=1,000 initialization median ratio: `0.794129647`;
- N=10,000 initialization median ratio: `0.331913495`;
- N=10,000 repeated runtime median ratio: `1.009564701`.

Interpretation: PLANVALID remains a setup optimization. At N=10,000 it removes about 66.8% of initialization time in this fresh run while leaving repeated runtime effectively unchanged.

### Setup: F-AHL50 representation ownership

Direct-retention / analytical initialization median ratios:

- N=1: `5.782847486`;
- N=100: `1.522545495`;
- N=1,000: `1.115894884`;
- N=10,000: `1.029505412`.

Interpretation: direct-retention preprocessing is expensive for a single application column but amortizes strongly. At N=10,000 its incremental setup cost is about 2.95%.

### Repeated Reference runtime: ZERO-WASTE exact P0 stack

- mean candidate/baseline ratio: `0.726864148`;
- median ratio: `0.726495766`;
- mean speedup: about 27.31%;
- mean delta: about -3005.85 ns per interval.

### Repeated directional runtime

- mean candidate/baseline ratio: `0.759275664`;
- median ratio: `0.761371085`;
- mean speedup: about 24.07%;
- mean delta: about -4860.73 ns per interval.

## What this run does and does not establish

This run confirms on the new canonical postimage that:
- large-N setup is now much cheaper because of PLANVALID;
- AHL setup overhead is nearly amortized at N=10,000;
- the exact ZERO-WASTE stack still delivers about 24-27% repeated-runtime reduction in its paired Reference/directional fixtures.

It does **not yet** provide one true total MultiSWAP-MODFLOW wall-clock ratio for the complete exact stack, because the setup and repeated-runtime measurements still use separate qualified fixtures and historical baselines.

Therefore the earlier planning estimate of roughly 25% total runtime reduction remains plausible but is not yet an end-to-end measured result.

## Next measurement

PROFILE04 should now add one integrated production-shaped application benchmark with the same workload executed against:
1. a pre-performance baseline authority;
2. current canonical default;
3. current canonical + F-AHL50 opt-in.

That benchmark must report total setup + repeated execution wall time and component diagnostics from the same run.

No production repair is justified from this first rebaseline alone.
