# F-PE-APPQUAL01 — first measured Reference baseline

Date: 2026-09-25

Status: `REFERENCE_BASELINE_MEASURED`

## Source

APPQUAL01 workflow run: 36104927576

PR merge test source: `87468320323e25d18757a5bfb61c78966aefa6c4`

Runner:

- Ubuntu 24.04.5
- gfortran 13.3.0
- O2 benchmark build

These timings are shared-runner observations. The structural scaling result and same-workload comparisons are stronger evidence than absolute wall-clock portability.

## B1 Reference scaling

The cleaned production Reference Richards route completed one accepted interval for every participant with zero reported maximum mass residual.

| workload | columns | init s | run s | ns/column |
| --- | ---: | ---: | ---: | ---: |
| B1-S100 | 100 | 0.000363027 | 0.001232278 | 12322.78 |
| B1-S1000 | 1000 | 0.00368873 | 0.010608947 | 10608.947 |
| B1-S10000 | 10000 | 0.169091622 | 0.106024102 | 10602.4102 |

Observed large-N execution is close to linear in participant count.

At S10000:

- one accepted production interval: ~0.1060 s;
- execution cost: ~10.60 microseconds/column;
- initialization: ~0.1691 s;
- maximum reported mass residual: 0.

Initialization is larger than one interval at S10000 but is a one-time owner/setup cost in a persistent production application. It must therefore remain separated from repeated timestep cost.

## B0 live coupled production seed

The current F-GC49D production ABI + MODFLOW6 6.8.0 live seed completed successfully.

Observed:

- 3 real SWAP participants;
- 2 MODFLOW interface cells;
- 5 coupling iterations;
- 5 MODFLOW solve calls;
- coupling loop ~0.002313345 s;
- maximum cell residual ~1.10e-20 m/s;
- MODFLOW/SWAP/ledger publication gates PASS.

B0 remains a semantic seed, not scaling authority.

## Interpretation

The first useful production denominator is now available:

`T_ref_10000 ~= 0.106 s / accepted interval`

for the current B1 Reference workload on this runner.

This makes the next challenger comparison meaningful.

A 2x faster column representation would save roughly 0.053 s per 10,000-column interval before considering coupling effects.

A 10x reduction in participant count would potentially dominate small single-column optimizations, provided aggregation error remains inside the application envelope.

No extrapolation to annual wall-clock runtime is authorized until the number of accepted intervals, retries and coupling iterations in a representative transient workload is measured.

## Next gate

The next direct challenger is RossFast because:

- it already exists as a production-capable solver binding;
- Reference-vs-RossFast scientific characterization already exists;
- the remaining integration gap is explicit model selection in the production bootstrap.

APPQUAL01 will add an opt-in, fail-closed model-selection configuration while preserving Reference as the default.
