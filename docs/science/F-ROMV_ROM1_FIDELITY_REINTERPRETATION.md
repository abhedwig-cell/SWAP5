# F-ROMV reinterpretation of ROM-1 evidence as a hydrological-fidelity curve

**Workstream:** F-ROM  
**Status:** reinterpretation only; historical ROM-1 decisions remain immutable  
**Purpose:** translate prior numerical-floor ambiguity evidence into purpose-dependent hydrological fidelity information

## 1. Why reinterpret rather than reclassify

ROM-1B1/B2 correctly asked a strict state-sufficiency question under the original proposition:

> can a reduced coordinate retain future-relevant information down to the independently measured Reference numerical scale?

Under that question Z1, Z2, Z4 and Z8 were all discovery-ambiguous.

F-ROMV does **not** overturn that result.

The new question is different:

> what is the absolute hydrological scale of the information that is lost, and could that loss be acceptable for a declared application?

The answer cannot be read from the ratio to the numerical Reference floor alone. Total-storage Reference differences are close to floating-point scale, so even a hydrologically tiny response difference can appear billions of times larger than that floor.

## 2. Frozen evidence used

Authority remains the immutable ROM-1 research checkpoint and workflow artifacts.

- ROM1B1 collision census: workflow run 35379652400.
- ROM1B2 frozen-pair future probes: workflow run 35392762490.
- ROM1B2 artifact digest: sha256:5cb11dbd45491b956ed8136c1602907c1e11bddfde0e12ac2741fbab0c38993c.
- no held-out histories were used by ROM1B2;
- no B14 evidence was used;
- pair manifests were frozen before future probes.

For each coordinate ROM1B2 used eight deliberately difficult collision pairs, four future probes and three horizons.

These are **adversarial ambiguity tests**, not a representative error distribution over normal SWAP operation.

## 3. Absolute response-separation scales

The table below reports absolute differences between the future responses of frozen collision-pair members.

| Coordinate | Dimension | Mean absolute total-storage response separation | Median | P95 | Maximum | Maximum terminal bottom-flux separation |
|---|---:|---:|---:|---:|---:|---:|
| Z1 | 1 | 0.001743 cm | 0.000271 cm | 0.006595 cm | 0.008426 cm | 0.5912 cm d-1 |
| Z2 | 2 | 0.001230 cm | 0.000257 cm | 0.004776 cm | 0.006751 cm | 0.4804 cm d-1 |
| Z4 | 4 | 0.001230 cm | 0.000257 cm | 0.004776 cm | 0.006751 cm | 0.4804 cm d-1 |
| Z8 | 8 | 0.000874 cm | 0.000163 cm | 0.002899 cm | 0.003422 cm | 0.3157 cm d-1 |

For intuition only, the maximum storage-response separations are approximately:

- Z1: 0.084 mm;
- Z2/Z4: 0.068 mm;
- Z8: 0.034 mm.

These are not ROM prediction errors. They are response differences between states that the corresponding reduced coordinate regarded as colliding or nearly colliding under the frozen coordinate tolerance.

A deterministic closure that cannot robustly resolve those coordinate differences has to absorb this response ambiguity somehow.

## 4. Why the same evidence supports different application judgments

### 4.1 Long-term or regional water balance

Storage-response separations of hundredths of a millimetre over these short probes may be negligible for some seasonal or annual water-balance questions.

The original ROM-1 numerical-floor test cannot answer that application question because it was intentionally much stricter.

This makes low-dimensional storage coordinates scientifically plausible candidates for regional balance work, subject to long-horizon bias and recharge/ET tests.

### 4.2 Groundwater exchange

ROM1B2 found bottom-exchange response differences on the same absolute scale as total-storage response differences, because the top forcing was identical between pair members.

For Z8 the maximum cumulative bottom-exchange separation was about 0.00342 cm over the frozen probe.

Whether that matters depends on the coupling/application time scale and on accumulation over long simulations. A small one-probe discrepancy may become unacceptable if it is systematic.

### 4.3 Fast flux and transition behaviour

Terminal bottom-flux differences are much less benign.

The maximum Z8 terminal-flux separation was about 0.316 cm d-1, or 3.16 mm d-1. Z1 reached about 0.591 cm d-1.

That scale can matter for event timing, capillary-rise/percolation transitions or tightly coupled groundwater response even when cumulative storage differences remain small.

This is the clearest evidence that one scalar accuracy metric is unsuitable.

## 5. Limits of a dimension frontier

The Z1, Z2, Z4 and Z8 numbers should not be interpreted as a clean monotonic convergence experiment.

Each coordinate had its own frozen adversarial pair manifest. Z2 and Z4 even share the same maximum/summary response scales because their selected hard pairs overlap strongly.

The evidence therefore defines **coordinate-specific ambiguity envelopes**, not a universal law of error versus dimension.

A future cost-fidelity experiment should use a common held-out workload for all candidate reductions.

## 6. What this says about the failed Stage-1 closure

The ROM1B2 reinterpretation and F-ROMV-MDE-S1 answer different questions.

ROM1B2 says that relatively coarse state descriptions can lose only small amounts of cumulative storage response in some adversarial cases, while losing much more instantaneous flux information.

F-ROMV-MDE-S1 says that the first bilinear dynamic closure was numerically unstable and physically inadmissible even with a nine-dimensional state.

Thus the main bottleneck has shifted:

> evidence for useful state compression exists for some outputs, but a stable, conservative and well-bounded online closure has not yet been demonstrated.

That strengthens the case for testing a structured/tabulated or quasi-steady physical closure instead of adding complexity to the failed global regression.

## 7. Consequence for the cost-fidelity frontier

The next frontier should have at least two hydrological axes rather than one:

1. cumulative/balance fidelity, including storage, ET and recharge/drainage bias;
2. transient/event fidelity, including flux magnitude, sign and regime-transition timing.

Computational cost forms the third axis.

Candidate routes can then occupy different useful regions:

- a quasi-steady model may be strong on cost and long-term balance but weak on event timing;
- a local dynamic ROM may retain more transient fidelity at higher cost;
- coarse Richards may be slower but more robust across regime transitions;
- Reference/RossFast remain the high-fidelity numerical comparators.

No candidate is declared superior without a named application envelope.
