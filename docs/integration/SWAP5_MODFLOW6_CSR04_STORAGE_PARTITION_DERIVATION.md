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


## 15. Algebraic comparison: historical shared-state storage versus F-GC33

The current runtime makes the SWAP contribution to the MODFLOW equation
explicitly as a linear boundary flux. From
`mod_modflow6_linear_response_backend`:

`Q_API(H) = HCOF * H - RHS`

with

`HCOF = A * 86400 * dq_u/dH`

and

`RHS = HCOF * H_ref - A * 86400 * q_u,ref`.

Therefore

`Q_API(H) = A * 86400 * [q_u,ref + (dq_u/dH)(H-H_ref)]`.

This is a linearized **exchange-flux response**. It is not entered as a
MODFLOW STO coefficient by the SWAP5 runtime.

For one MODFLOW degree of freedom, write the groundwater residual schematically
as

`R_MF(H) = R_regional(H) + R_STO(H; S_MF) + Q_API(H)`.

Linearizing around `H_ref` gives the head Jacobian contribution

`dR_MF/dH = dR_regional/dH + dR_STO/dH + A*86400*dq_u/dH`.

The final term is the F-GC33 Schur-condensed SWAP response.

The historical shared-state formulation instead supplied the column
storage/head derivative to MODFLOW as the capacitance needed for the common
head solve and deliberately suppressed additional MODFLOW storage in the
shared top state. The two formulations can therefore be structurally
equivalent only if the F-GC33 exchange Jacobian supplies the relevant column
dynamic response and any native MODFLOW STO retained at that same shared
degree of freedom represents a genuinely additional regional state.

### Key consequence

A nonzero native MODFLOW STO term is **not mathematically required by F-GC33**
to make the SWAP response head-dependent: that dependence already exists in
`HCOF = A*dq_u/dH`.

Native STO adds a second head-derivative term to the assembled MODFLOW
equation. Whether that term is desirable is a physical model-definition
question, not a numerical necessity of the F-GC33 coupling law.

This yields a falsifiable qualification:

- run the controlled coupling with native STO tending toward zero;
- run it with nonzero native STO;
- keep the SWAP finite-window response identical;
- compare accepted head, exchange, SWAP storage and water balance.

If the intended authority is the historical shared-state limit, the near-zero
STO sequence is the relevant convergence target. If nonzero STO is retained,
its independent regional physical meaning must be declared and evidenced.

This comparison does not yet authorize changing production STO. It establishes
that native STO and the F-GC33 SWAP Jacobian are algebraically separate
head-response terms and that native STO cannot be justified merely as the
mechanism that lets MODFLOW react to SWAP.


## 16. Zero-native-STO limit: quasi-steady MODFLOW, transient coupled system

The near-zero native STO experiment must not be described as making the whole
coupled system steady state.

Schematically, for one coupling window:

`C_MF (H^{n+1}-H^n)/DeltaT + R_regional(H^{n+1}) + Q_SWAP(H^{n+1}; S_SWAP^n, F_window) = 0`.

Here `Q_SWAP` is the accepted finite-window SWAP response generated by
integrating the transient column from its accepted origin `S_SWAP^n` under
the forcing of that window.

As `C_MF -> 0`:

`R_regional(H^{n+1}) + Q_SWAP(H^{n+1}; S_SWAP^n, F_window) = 0`.

The MODFLOW groundwater equation is then quasi-steady within the coupling
window, but the coupled system remains transient because the SWAP response
depends on the accepted column state and time-window forcing. After acceptance,
`S_SWAP^{n+1}` becomes the origin of the next window.

The experiment therefore separates two kinds of memory:

1. **column/coupling memory**, carried by the accepted SWAP state and its
   finite-window response;
2. **independent regional groundwater memory**, carried by native MODFLOW STO
   through dependence on the previous accepted MODFLOW head.

This yields the scientific interpretation of the continuation experiment:

- the `C_MF -> 0` limit diagnoses the transient system in which groundwater
  head is hydraulically equilibrated each window against the transient SWAP
  response and regional groundwater fluxes;
- finite `C_MF` adds independent MODFLOW head memory;
- neither limit is declared correct a priori;
- production authority depends on whether the intended conceptual groundwater
  model contains that independent regional storage state.

The continuation should therefore use a logarithmic sequence approaching zero,
not a literal zero as its first implementation target, and report both
hydraulic-head trajectories and accepted water-balance terms.


## 17. Coupled equation reconstruction and discriminating proof

Let `S^n` be the accepted SWAP column state at the start of a coupling
window and let `H` be the MODFLOW/shared lower-face head sought for the end
of that window.

The SWAP transaction defines an implicit finite-window map

`Phi_SWAP(S^n, F, H) -> (S^{n+1}, q_i)`.

Around a trial/reference head `H_r`, F-GC30/F-GC33 exposes the condensed
response

`q_i(H) ~= q_r + J_s (H-H_r)`,

where `J_s = dq_i/dH = u/DeltaT` in the admitted response convention.

After area/unit conversion the API package contributes

`Q_i(H) = A [q_r + J_s(H-H_r)]`

to the groundwater residual.

Write the remaining MODFLOW regional-flow residual as `R_g(H)`. Native
transient groundwater storage contributes schematically

`C_g (H-H^n)/DeltaT`.

The assembled scalar form is therefore

`R_g(H) + C_g(H-H^n)/DeltaT + A[q_r + J_s(H-H_r)] = 0`.

Its Newton/head derivative contains two distinct transient-response
contributions:

`dR/dH = dR_g/dH + C_g/DeltaT + A J_s`.

This establishes algebraically:

- `A J_s` is the condensed finite-window SWAP response;
- `C_g/DeltaT` is native MODFLOW head memory;
- they are not the same coefficient and neither may be relabelled as the other;
- setting `C_g -> 0` does not remove SWAP transience because `q_r`,
  `J_s`, and the next-window map depend on `S^n`;
- retaining `C_g > 0` adds an independent dependence on the previous
  accepted MODFLOW head.

### Mass accounting

The accepted SWAP transaction remains governed by its physical column balance

`Delta S_SWAP = E_SWAP - Q_i`

under the chosen sign convention.

Interface continuity requires the groundwater equation to receive the opposite
accepted transfer. This proves exchange conservation but does not decide
whether `C_g Delta H` is an additional physical water volume.

Only when `C_g` has explicit independent regional-storage authority may a
physical combined-storage statement include that term. Otherwise it is a
head-solve/state-equation term and must not be added to SWAP storage as a
second reservoir.

### Single discriminating experiment

Use one SWAP column coupled to one transient MODFLOW cell over multiple
successive windows. Hold geometry, forcing, regional boundary conditions,
SWAP parameters and coupling response construction fixed. Vary only native
MODFLOW storage over

`Sy = 0.30, 0.05, 1e-2, 1e-3, 1e-4, 1e-5`.

For every accepted window record:

- accepted MODFLOW head `H^n`;
- imposed SWAP lower-face hydraulic head;
- SWAP diagnostic groundwater level;
- accepted interface transfer;
- SWAP storage start/end/change;
- native MODFLOW STO budget term;
- `q_r` and `J_s`;
- SWAP component mass residual and interface-ledger residual.

The primary discriminant is **memory separation**, not a preselected target
head. Apply a forcing pulse and subsequent recovery period. If trajectories
converge as `Sy -> 0`, that sequence identifies the SWAP-memory/quasi-steady
MODFLOW limit. The finite-Sy departures quantify independent MODFLOW head
memory. Whether those departures are physically required must then be decided
from application authority, not numerical greenness.

No combined physical storage acceptance test is permitted until that authority
classification is made.
