# F-ROMV MDE Stage 1 adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV-MDE-S1  
**Decision:** **STOP_SIMPLE_TEMPLATE_LOCAL_ROM**  
**Scope:** the preregistered B01 nine-state bilinear controlled-affine closure only

## 1. Why this is not a solver-equivalence test

This stage was re-framed before model fitting to distinguish a reduced hydrological model from an alternative numerical route to the same Richards solution.

Reference Richards and RossFast can reasonably be challenged on very tight numerical/hydrological equivalence because they are alternative numerical routes inside the same process model.

A reduced model is different. It may intentionally discard information. It can therefore remain useful with non-zero hydrological error if that error is acceptable for a declared application. The governing F-ROMV acceptance model consequently separates:

- non-negotiable integrity constraints;
- application-dependent hydrological fidelity;
- computational cost.

The ROM-0 numerical floors remain measurement context, not universal ROM tolerances. No 1%, 2% or other application threshold was introduced after seeing Stage-1 results.

## 2. Frozen Stage-1 model

The model was fitted only on ROM1AR2 discovery histories D01-D08.

State:

- total water storage carried explicitly;
- seven 20-cm band contrasts relative to the deepest band;
- the previously qualified deepest-band half-cell contrast G8;
- total dimension: 9.

Closure:

- controlled affine/bilinear regression;
- state plus forcing and state-forcing interaction terms;
- SVD pseudoinverse;
- no ridge tuning;
- no neural architecture;
- top exchange supplied exactly by the forcing;
- bottom exchange predicted;
- storage advanced from the water balance;
- no hidden mass correction.

The frozen OOD rule was deliberately simple: all state coordinates inside the discovery componentwise min/max box and a forcing tuple observed during discovery.

## 3. Held-out result

The closure fails its preregistered integrity gate.

On H03, target steps 41-56 are classified as inside the frozen input domain, yet the closure produces physically impossible candidate states. At the first failure it predicts approximately:

- total storage: -1630.49 cm;
- bottom outward exchange for one interval: 1689.18 cm;
- terminal bottom flux: 2.11e6 cm d-1;
- reconstructed water-content range: about -182 to +12.5.

There are 16 such water-content-bound failures. There are no structural water-ledger failures because storage is carried conservatively by construction, and no non-finite results.

These impossible candidates are not accepted in the analysis. Full-order states were used only as **diagnostic recovery after the failure** so that the remainder of the held-out histories could still be characterized. That recovery does not change the Stage-1 no-go.

## 4. Why this is not simply an OOD-state problem

The first failing H03 state is inside the frozen componentwise discovery box. More strongly, under standardized state coordinates it is only about 0.0119 Euclidean units from a discovery input with the same BOTTOM_HEAD_FALL forcing.

The regression matrix is technically full rank, but poorly conditioned:

- rank: 40/40;
- condition number: about 1.49e11;
- coefficient L2 norm: about 2.43e8;
- largest absolute coefficient: about 8.91e7.

Thus tiny changes between nearly identical states can be amplified catastrophically. The main Stage-1 failure is closure identifiability/stability, not merely that a held-out state lies far beyond a sampled min/max range.

The componentwise min/max gate is also shown to be insufficient as a safety certificate. It can classify an input as in-domain while the closure is locally unstable there.

## 5. Purpose-dependent fidelity after diagnostic recovery

The application lenses are retained because they reveal more than a single RMSE.

### Long-term/regional balance proxy

H01 is reproduced extremely closely. That is positive evidence that a smooth, single-regime subset of B01 is highly compressible.

H02 is different. Its actual cumulative bottom exchange over evaluated intervals is about 0.1056 cm, while the hybrid diagnostic has about 0.0912 cm cumulative error. That is not a subtle solver-level discrepancy; it changes the exchange signal materially.

H03 contains the physical-admissibility failures and therefore cannot qualify this closure for a balance application, regardless of any later percentage tolerance.

H04 falls back on all 63 evaluated transitions because its combined forcing tuples were absent from discovery. It is hydrologically safe under fallback but provides no ROM online-value evidence for that challenge.

### Groundwater-coupling hydraulic proxy

Across the held-out hybrid diagnostic, terminal bottom-flux sign is wrong on 32/252 intervals. Bottom exchange and terminal bottom flux errors are also material in H02/H03.

This is insufficient evidence for a groundwater-coupled application. No live MODFLOW coupling is claimed by Stage 1.

### Fast-event / transition lens

H02 has actual bottom-flux reversals at steps 25 and 57. The hybrid diagnostic produces reversals at 16, 25, 31, 34, 45, 62 and 64.

This is a clear example of why annual or cumulative agreement cannot be used as a universal ROM criterion. A model may be tolerable for one application and unusable for event-sensitive inference.

### Profile-sensitive scientific use

A reduced state was never required to reconstruct the full pressure-head profile exactly. Nevertheless physical state bounds are non-negotiable. The H03 failures therefore close this simple closure for scientific/process use as well.

## 6. Relation to MetaSWAP precedent

MetaSWAP remains a relevant positive precedent for the **principle** of deliberate hydrological reduction. Its published evaluation did not demand numerical identity with SWAP. Instead applicability was evaluated through groundwater model efficiency and evapotranspiration differences under different soils, root-zone depths, groundwater conditions and years.

That precedent supports F-ROMV's purpose-dependent acceptance framework. It does **not** rescue the Stage-1 bilinear closure and it does not provide numerical acceptance thresholds for SWAP5.

The more interesting implication is architectural: a quasi-steady or tabulated physical-reduction family may occupy a better regional cost-fidelity point than a globally propagated dynamic regression state. That question should be tested independently rather than by repeatedly regularizing the failed Stage-1 closure on already exposed H01-H04.

## 7. Decision

**STOP_SIMPLE_TEMPLATE_LOCAL_ROM** means:

- stop this exact nine-state bilinear closure;
- do not tune ridge/SVD thresholds or OOD distances against exposed H01-H04;
- do not run the expensive direct-comparator stage for this closure;
- do not infer that all template-local ROMs are impossible;
- do not infer that reduced hydrological models must meet solver-equivalence tolerances.

A successor is scientifically defensible only if it is independently specified and uses new unexposed validation evidence.

The two most defensible successor questions are now:

1. whether a better-conditioned, locally defined dynamic closure can be specified using discovery-only principles and then tested on genuinely new histories; or
2. whether a quasi-steady/integrated-manifold physical reduction, motivated by the MetaSWAP precedent but derived clean-sheet, occupies a better cost-fidelity frontier for regional or groundwater-coupled applications.

Given the Stage-1 instability, the second question is currently the cleaner next discriminator. It changes the reduction hypothesis instead of tuning the failed regression until it works.

No production ROM is authorized.
