# PPA-WU05-A27 pressure-aware receiver result

Date: 2026-10-02  
Status: RETAINED_NEGATIVE_REFINEMENT_RESULT; BACKEND_RECONCILED; RESEARCH_ONLY

## Current-canonical backend reconciliation

A27 was first reconciled with canonical `e50a1bad6482b0aaeaf25a87e1fd1b1d5e19a846`. The first backend run exposed a stale compile harness, not a physics regression: the serialized backend used the LOW03 legacy head-bottom-boundary provider but the inherited A26 compile list did not compile that module.

After the temporary harness repair, run 36975017925 passed the A26 live-trial preparer, serialized backend O0/O2 gate, actual Richards binding, A27 column ablation, finite exchange and reverse-exchange gates.

Canonical then advanced to `3869ec27a7314375fd7919debb6abe7c6450f261` with the Bartholomeus oxygen production postimage, including a changed serialized backend and a generalized dependency augmenter for the backend compile gate. A27 therefore reconciled again at merge commit `b57a2c65c468a6d2fb3812a4e8902b410f575c22`, taking the current canonical backend compile harness rather than retaining the A27-specific manual LOW03 source-list patch.

Persisted qualification run 36976462557, job 110741257480, is green. It passed:
- A26 live trial preparer;
- A26 serialized backend compile;
- A26 actual Richards binding;
- A27 column ablation;
- A27 finite exchange;
- A27 reverse exchange.

This requalifies only those gates on the reconciled postimage. It does not qualify the full A/B/C benchmark or the pressure-aware research seam below.

## Ownership decision

For continued A27 research, Reference Richards remains the sole owner of matrix water storage. A future lateral wall profile is auxiliary shape/history only and cannot add independent matrix water to an unchanged full-volume Richards ledger. Saturated pressure remains separate authority and is taken from the accepted Reference head, not reconstructed from saturated theta and not represented with the numerical capacity floor.

The finite receiver owns only its own explicit storage. Signed exchange is booked once to the Reference source/sink and with the exact opposite amount to the receiver candidate. This selection is a research architecture boundary, not a production RFM contract change.

## Preregistered pressure-receiver seam

The seam used the actual Reference Richards solver, actual default MvG hydraulics and actual standard saturated-exchange primitive. It exercised an initially low finite receiver plus fill, drain and rewet pulses so that moving contact changed repeatedly.

Run 36975724320 retained the original preregistered failure. All per-step gates were reached without failure: signed source/sink ownership, opposite receiver receipt, Reference mass balance, combined matrix-plus-receiver ledger, accepted-state immutability, reject/replay, both exchange directions and moving-contact changes. The run then failed only the final matrix-refinement gate.

| dt day | final receiver cm | final matrix storage cm | bottom cumulative cm | max combined ledger cm | positive steps | reverse steps | contact changes |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.010000 | 2.997183463797101 | 39.953576257981915 | 2.571467288690836 | 6.21725e-15 | 21 | 9 | 5 |
| 0.005000 | 2.997176727503557 | 39.982575014322350 | 2.181864084835953 | 6.27276e-15 | 40 | 20 | 7 |
| 0.002500 | 2.997203715998348 | 39.993499100623019 | 2.125958137975689 | 7.54952e-15 | 80 | 40 | 7 |

The receiver difference between 0.005 and 0.0025 day is only about 2.70e-5 cm, but the matrix-storage difference is about 0.010924 cm. The preregistered limit was 0.005 cm. That gate therefore remains **FAIL**.

## Frozen refinement extension

The addendum changed no physical parameter, forcing pulse, ownership rule, conductance or tolerance. It added dt 0.00125 and 0.000625 day and preregistered decreasing successive matrix differences plus a final difference <=0.005 cm.

Run 36976029998 gave:

| dt day | final receiver cm | final matrix storage cm | bottom cumulative cm | max combined ledger cm | positive steps | reverse steps | contact changes |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.001250 | 2.997194782356727 | 39.997461558251253 | 2.078182756332306 | 7.32747e-15 | 160 | 80 | 7 |
| 0.000625 | 2.997202431963886 | 40.001680263005625 | 2.064159081822163 | 1.19904e-14 | 320 | 160 | 7 |

Successive matrix-storage differences over all five dt values are:
- 0.028998756340435 cm;
- 0.010924086300669 cm;
- 0.003962457628234 cm;
- 0.004218704754372 cm.

The final absolute difference is below 0.005 cm, but the final difference increases relative to the preceding one. The preregistered monotone-refinement gate therefore also remains **FAIL**. The two finest receiver storages differ by only 7.65e-6 cm and the combined water ledger remains near machine precision. This is not a mass-ownership failure.

The pressure-receiver research executable stopped at the retained O0 failure, so no O0/O2 identity claim is made for this negative seam experiment.

## Concrete moving-contact confounder in the source operator

The standard saturated-exchange primitive itself changes reverse-exchange conductance law at `hmp=0`.

For `delh<0` and `hmp>0`, it uses `cdarcy * matrix_fraction`. For `hmp<=0` and default `swsep=0`, it instead uses:

`shape_factor * 16 / diameter^2 * ksat_horizontal * dz * matrix_fraction`.

The A27 fixture froze `cdarcy=5e-4 /day`, `shape_factor=0.1`, `diameter=20 cm`, `Ks=31.22501566 cm/day` and `dz=10 cm`. The submerged reverse coefficient is therefore 0.0005/day, whereas the seep-face coefficient is 1.2490006264/day, a factor about 2498 larger. In addition, `macro_saturated_fraction` scales the positive macro-to-matrix branch at the top contact but is not applied to the reverse `hmp>0` branch.

That source discontinuity is a concrete reason not to interpret the failed moving-contact refinement as a clean test of explicit versus monolithic execution. The present experiment does not isolate it as the sole cause of the non-monotone final difference. It does show that the naive seam mixed two exchange regimes without a qualified physical mapping across their transition.

## Research/production boundary

The auxiliary no-double-storage ownership survives the test and is retained. The naive moving-contact pressure seam does not qualify.

Do not repair this by changing a tolerance or tuning `cdarcy` after the result. The next pressure-aware research contract must first define a physically defensible saturated/seep transition, or a continuous subcell pressure/contact operator, and then repeat moving-contact refinement under the same parameter mapping. Only after that should lateral wall-profile memory be attached to the seam.

Separately, the full production A/B/C benchmark remains open and should continue to use the actual admitted RFM runtime as C. Current production RFM still has nonnegative matrix sources and cannot represent the reverse exchange demonstrated by the standard operator. Wet/reverse-exchange cases must therefore remain visible as negative controls rather than being removed or silently repaired inside comparator C.

No speedup, stability, E1 production envelope or canonical admission is claimed here.
