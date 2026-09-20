# CSR-04 storage-partition derivation

Date: 2026-09-20

Status: **SCIENTIFIC DERIVATION CHECKPOINT, IMPLEMENTATION NOT AUTHORIZED**

Live canonical reconciliation: `integration/f-ci-canonical@3a815edda7cf5e155272b68ae49d440fd5db9138`.

## 1. Purpose

This note derives the minimum coupled control-volume statement needed to decide whether the existing SWAP finite-window response coefficient `u` can be combined physically with MODFLOW STO without double counting.

It does not alter F-GC30/F-GC33 algebra and does not introduce a new coupling method.

## 2. Separate control volumes

Let the SWAP column control volume have water storage `S_s`, external non-interface source/sink integral `E_s`, and lower-face transfer `Q_i`.

Choose one sign convention for the derivation: `Q_i > 0` means water leaves SWAP and enters the MODFLOW groundwater control volume.

Then over one coupling window:

`Delta S_s = E_s - Q_i`.

Let the MODFLOW groundwater control volume have storage `S_g`, non-interface groundwater source/sink integral `E_g`, and receive the same interface transfer:

`Delta S_g = E_g + Q_i`.

Adding the two equations gives:

`Delta(S_s + S_g) = E_s + E_g`.

The interface transfer cancels. This is the physical invariant the coupled implementation must preserve.

## 3. What the existing SWAP response represents mathematically

The current predictor perturbs prescribed lower-boundary flux from one accepted SWAP origin and obtains the terminal lower-face head response:

`dH_b/dq_b`.

The admitted coefficient is:

`u = DeltaT / (dH_b/dq_b)`.

Therefore:

`u/DeltaT = dq_b/dH_b`

for the local finite-window inverse response used by the predictor, subject to the pinned sign convention.

The dimensions are consequently those of a flux-to-head slope. When inserted into the MODFLOW affine boundary term, `u/DeltaT` behaves algebraically like a conductance/storage-rate coefficient. This dimensional fact does **not** by itself identify `u` with a physical aquifer storage coefficient.

The finite-window map already contains the response of all SWAP state variables that change during the prescribed-qbot replay. Hence `u` is a condensed dynamic response of the SWAP column, not a separately measured water volume.

## 4. MODFLOW STO is different authority

MODFLOW STO contributes transient storage associated with the GWF cells through specific storage and, for convertible cells, specific yield according to the selected STO formulation.

Thus the groundwater equation already has an independently defined derivative of groundwater stored water with respect to head.

The SWAP affine package term is a boundary/exchange response. It may be combined with STO only if its head derivative represents the derivative of **interface transfer conditional on the SWAP control volume**, rather than a second booking of the same groundwater storage represented by STO.

## 5. Key distinction

The physically relevant question is therefore not:

> Is `u` a storage coefficient?

but:

> Which state-volume response has been Schur-condensed into `dq_i/dH_b`, and is any of that same water volume already represented by the MODFLOW STO derivative?

This resolves an important ambiguity in earlier wording. `u` is storage-like in the coupled matrix but must not be labelled a physical storage coefficient without a control-volume derivation.

## 6. Candidate physical partition consistent with the current architecture

The cleanest non-overlap contract is:

- SWAP owns all water storage represented inside the finite SWAP column down to its fixed lower face;
- MODFLOW owns groundwater storage in its GWF control volume below/outside that coupling plane;
- the shared quantity is only the lower-face transfer `Q_i`;
- the derivative supplied by SWAP to MODFLOW is the head sensitivity of that interface transfer after eliminating SWAP internal states.

Under this contract, the SWAP response slope is a boundary Jacobian/Schur-complement term. It is **not** additional MODFLOW STO.

This formulation is mathematically coherent only when the MODFLOW cell storage volume does not also include the same physical saturated material represented as SWAP column storage.

## 7. Why current topology cannot yet prove the candidate partition

The present tile-to-cell topology maps a SWAP column to a MODFLOW cell but does not define a vertical control-volume cut that excludes the SWAP-represented saturated storage from the MODFLOW STO volume.

The existing identity head transfer also does not create such a partition. Equal hydraulic head at an interface is compatible with distinct control volumes, but it does not establish them.

Therefore the candidate partition above cannot yet be promoted to production authority.

## 8. Two admissible ways to close CSR-04

### A. Non-overlapping geometric partition

Define the SWAP lower face as a true model-domain interface and configure MODFLOW STO only for the groundwater volume not represented by SWAP.

Then F-GC30/F-GC33 can be interpreted as condensed interface response, with no overlap correction.

This is conceptually the cleanest route, but may not match the intended regional MODFLOW discretization where the mapped cell extends through material also represented by the SWAP column.

### B. Overlapping models with explicit mathematical correction

If SWAP and MODFLOW intentionally represent overlapping saturated storage, derive the duplicated storage derivative and remove it exactly once from the assembled coupled equation.

No such correction is currently specified or qualified in SWAP5. Implementing one now would be new coupling physics/architecture and is not authorized by this workunit.

## 9. Qualification that can discriminate the issue

A decisive CSR-04 experiment should use a closed or tightly controlled one-column/one-cell system with nonzero transient storage and no confounding drainage/root/atmospheric terms.

Required observations per coupling window:

- accepted SWAP storage change;
- accepted MODFLOW STO storage change;
- accepted interface transfer;
- all external fluxes;
- combined-system residual;
- terminal SWAP lower-face head and MODFLOW head;
- F-GC30 response `u` and the affine package slope.

Run at least:

1. SWAP-only perturbation to verify `Delta S_s = E_s-Q_i`;
2. MODFLOW-only transient storage perturbation to verify its STO balance;
3. coupled case with the intended partition;
4. sensitivity to vertical overlap/partition choice if the production topology permits overlap.

The primary acceptance condition is component and combined water balance, not merely head convergence or interface residual.

## 10. Decision

The derivation narrows CSR-04 substantially:

- `u` should be treated as a condensed finite-window interface-response coefficient, not automatically as a physical storage coefficient;
- MODFLOW STO remains groundwater-volume storage authority;
- simultaneous use requires an explicit state/storage-ownership interpretation; geometric overlap alone neither proves nor disproves dynamic double counting;
- current SWAP5 topology does not yet establish either.

Disposition remains:

`CSR04_STATE_SPACE_INTERPRETATION_REFINED_QUALIFICATION_REQUIRED`.

The next admissible implementation step is **not** to alter F-GC30/F-GC33. It is to materialize an explicit vertical storage-domain/topology contract and a controlled nonzero-storage qualification fixture. A realistic Hupsel/E7 rerun remains premature.


## 11. Refined state-space interpretation

A further coupling interpretation must be distinguished from the purely geometric
partition above.

The MODFLOW degree of freedom can represent a regional groundwater hydraulic
head while SWAP retains the vertically resolved column state, including its
diagnostic phreatic groundwater level. In that interpretation the coupling
condition

`H_MF = H_SWAP,bottom`

does not imply

`H_MF = z_GW,SWAP`.

The latter equality would only follow under hydrostatic conditions without the
vertical gradients/resistances represented inside the SWAP column.

This means geometric overlap of a MODFLOW cell and a SWAP column is not, by
itself, proof of duplicated storage. The stronger question is whether the two
sets of state equations contain the same independent dynamic water-storage
degree of freedom twice.

Under this interpretation:

- MODFLOW STO controls the transient response of the regional groundwater-head
  degree of freedom to groundwater-system stresses and the interface exchange;
- SWAP storage controls the transient vertically resolved column state;
- the SWAP-derived `u/DeltaT = dq_i/dH_b` remains the condensed sensitivity of
  interface transfer to bottom hydraulic head, not an additional MODFLOW STO
  volume;
- the SWAP diagnostic phreatic level remains a SWAP result and is not prescribed
  by the MODFLOW head.

This is a candidate scientific interpretation, not yet production authority.

## 12. Stronger discriminating experiment

The controlled qualification must therefore test state-space independence in
addition to bookkeeping closure.

Hold SWAP constitutive physics and the coupling formulation fixed and vary only
the MODFLOW STO parameterization over at least two nonzero values. For each
case record:

- accepted MODFLOW head trajectory;
- accepted SWAP bottom hydraulic head;
- accepted SWAP diagnostic groundwater level where available;
- accepted interface transfer;
- MODFLOW native STO contribution;
- SWAP storage change;
- `u` and `u/DeltaT`;
- both component residuals and the combined residual.

The expected structural result is not invariance of the coupled solution.
Changing MODFLOW storage should change the temporal response of the MODFLOW
head and therefore may change SWAP and interface exchange indirectly.

The discriminant is instead that no extra SWAP storage term is introduced into
the MODFLOW storage ledger and no MODFLOW STO term is introduced into the SWAP
ledger. The models interact through the shared head/flux interface while each
retains its own state evolution.

Consequently, a successful mass-balance test alone is necessary but not
sufficient. CSR-04 requires both:

1. conservative accepted component/combined budgets; and
2. evidence that the two storage operators have distinct state-space roles
   under a controlled MODFLOW-STO perturbation.

The earlier non-overlap geometry remains one sufficient realization, but is no
longer treated as the only scientifically coherent interpretation.


## 13. Historical authority correction: do not assume additive STO

Historical coupling literature changes the burden of proof.

Van Walsum & Veldhuizen (2011), in their shared-state-variable treatment of
MetaSWAP-MODFLOW, explicitly distinguish an h-link from a q-link. For the
q-link to approach the h-link, the top MODFLOW layer is made confined and its
additional storage coefficient is driven close to zero. This is direct evidence
that adding ordinary MODFLOW storage on top of the vertically represented
soil/groundwater response can be an unwanted extra state rather than an
automatically additive physical reservoir.

The later MetaSWAP coupling formulation likewise describes a communal control
volume and a dynamic storage coefficient relating head change to the combined
MetaSWAP/MODFLOW flux balance. This reinforces that storage treatment is part
of the coupling formulation, not merely two independent ledgers to be summed.

Therefore the previous candidate rule
`Delta S_SWAP + Delta S_MF = total physical storage change`
is withdrawn as a default CSR-04 acceptance criterion.

The current SWAP5 experiment with two nonzero MODFLOW Sy values remains useful
only as a diagnostic sensitivity experiment. It must not be interpreted as
evidence that nonzero Sy is scientifically required or that both storage terms
are physically additive.

New authority question:

> In the intended full-SWAP q-link formulation, which storage/capacitance term
> is required in the MODFLOW equation to obtain the shared hydraulic-head
> solution without introducing an additional physical storage degree of freedom
> already represented by SWAP?

Until that is reconstructed, production STO magnitude and interpretation remain
scientifically unadmitted.


## 14. Reconstructed historical role of MODFLOW storage

The 2011 shared-state-variable formulation resolves the ambiguity more strongly
than the earlier CSR-04 hypotheses.

In that formulation the combined MetaSWAP control-volume water balance is the
mass authority. A storage coefficient derived from the MetaSWAP storage
relationship is supplied to MODFLOW so that MODFLOW can update the shared head
inside its nonlinear solution. The paper explicitly states that the storage
change computed by MODFLOW in this equation serves the convergence of the
MODFLOW head and the MetaSWAP groundwater level; the final MODFLOW flux is then
used to finalize the MetaSWAP profile.

Therefore, for that historical h-link formulation, the MODFLOW-side storage
term in the coupling equation is not an independently additive physical
reservoir. It is the solver-facing representation of the coupled storage-head
relationship whose water-balance authority remains with the column model.

This does not yet prove that the present full-SWAP F-GC30/F-GC33 formulation is
mathematically identical to the MetaSWAP h-link. Full SWAP uses a fixed
lower-face hydraulic head and a finite-window q-to-head response rather than a
MetaSWAP storage table with groundwater level as the shared state. The relevant
analogy is therefore structural, not literal.

### Consequence for current qualification

CSR-04 must now separate three questions:

1. **Mass authority:** which component owns the accepted physical water balance?
2. **Head-solve capacitance/Jacobian:** which coefficient is communicated to
   MODFLOW to make the coupled head solve represent the column response?
3. **Independent regional storage:** is any native MODFLOW STO term physically
   intended in addition to that communicated column response?

The current F-GC38 nonzero-STO experiment answers only question 3
diagnostically. It cannot establish the answer.

For the full-SWAP formulation, the next derivation must compare the assembled
MODFLOW equation containing native STO plus the F-GC33 affine response with the
linearized accepted SWAP finite-window balance. The proof obligation is to
identify whether native STO is an independent regional term, should vanish/be
negligible in the shared state, or would duplicate part of the SWAP response.

Until that algebraic equivalence is established, native STO remains a
qualification variable rather than admitted coupled physics.
