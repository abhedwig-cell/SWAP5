# SWAP5-MODFLOW6 response contract after dummy-SWAP and real-SWAP mapping

Date: 2026-09-21
Status: RESEARCH CONTRACT SYNTHESIS, production read-only

## Purpose

This note records the coupling objects that have now been separated by the
dummy-SWAP concept testbank and the real-SWAP MAP01-MAP07 work.

The aim is not to change production code. The aim is to prevent one symbol or
coefficient from silently changing meaning between physical storage,
bottom-interface mass, predictor sensitivity and numerical iteration policy.

## 1. Interface head, phreatic state and internal state are distinct

MAP11 source reconciliation sharpens the state definition for the current
F-GC route.

The exchanged production coordinate is:

```
H_interface = hydraulic head on the SWAP lower coupling plane
```

The canonical predictor source explicitly states that this coupling-plane head
is **not** the freatic groundwater level. The head-driven corrector maps
`H_interface` back to SWAP `bottom_head`.

A true phreatic shared-state h-link would instead impose:

```
H_phreatic,SWAP = H_phreatic,MODFLOW
```

together with an explicit common storage-ownership relation. That is a
different model contract and is not established by the current F-GC45
qualification fixture.

A SWAP column also owns internal memory:

```
xi = pressure-head profile, unsaturated storage, process state, ...
```

so even in a future shared-phreatic-state formulation equal head would not
imply equal complete SWAP state. DSW11 and DSW15 demonstrate this point.

## 2. Physical storage

For a fixed accepted SWAP origin and coupling window:

```
DeltaS(H; xi0)
```

is the physical whole-column storage change under a prescribed terminal shared
head.

Its local response is:

```
J_S = d(DeltaS)/dH.
```

MAP03 shows for the simple drainage-free F-GC45 fixture:

```
J_S ~= +u_A.
```

PUB-GC E4 B3 is the required counterexample to treating this as a universal
identity:

```
u_A = 2.665743709e-4
J_S = 2.882176720e-4.
```

Thus `u_A` can locally coincide with storage response without being a
universal storage coefficient.

## 3. Physical bottom-interface exchange

The accepted prescribed-head SWAP corrector produces whole-window bottom
outward exchange:

```
V_R(H)
```

and its mean flux:

```
q_swap(H) = V_R(H)/DeltaT.
```

This is the physical interface-exchange object.

After coupled acceptance, the groundwater-interface ledger integrates this
accepted corrector exchange exactly once. Rejected predictor/corrector trials
publish no authoritative interface mass.

Its local response is:

```
J_R = dV_R/dH.
```

For the simple MAP03 fixture:

```
J_R ~= -J_S ~= -u_A.
```

That sign is physical under the public outward-from-SWAP convention.

## 4. Native qbot

Native SWAP lower-boundary flux uses the opposite interface orientation:

```
qbot > 0  into the SWAP profile
q_swap > 0 outward from SWAP
```

therefore:

```
q_swap = -qbot * unit_conversion.
```

Do not use the same sign statement for native qbot and public q_swap.

## 5. Predictor response u_A

F-GC30 canonically admitted the drainage-free predictor sensitivity:

```
u_A = DeltaT / (dH_end/dqbot)
```

for a prescribed-bottom-flux predictor family.

This is a finite-window directional response with provenance:

- accepted origin;
- time window;
- bottom-flux control coordinate;
- active-process envelope;
- accepted-trajectory derivative route.

F-GC30 explicitly did not reinterpret accepted storage change as coupling
storage.

## 6. Historical q_u

The admitted historical response is:

```
q_u = u_A*(H_end-H_start)/DeltaT - qbot.
```

This is not the accepted bottom-interface ledger.

It combines:

1. a head-change term;
2. the prescribed predictor bottom flux.

Two different derivatives must therefore be distinguished.

### 6.1 Partial affine derivative

Holding `u_A` and `qbot` fixed:

```
partial q_u / partial H = +u_A/DeltaT.
```

F-GC40 stores this as the tile/cell affine slope and F-GC33 maps it exactly to
MODFLOW HCOF/RHS.

This is the current production iteration-response slope policy.

### 6.2 Total derivative along the predictor family

Along neighboring predictor solutions, qbot itself changes with H:

```
dqbot/dH ~= u_A/DeltaT
```

on the independently qualified E4 predictor plateau.

Hence, for frozen u_A:

```
d q_u/dH
  = u_A/DeltaT - dqbot/dH
  ~= 0.
```

MAP07 frozen-evidence reconstruction finds the total historical q_u derivative
to be O(1e-6) of the production partial slope when pointwise u variation is
included, and O(1e-8) under frozen-u first-order cancellation.

Therefore:

```
+u_A/DeltaT
```

must not be described as the total derivative of historical q_u across the
predictor family.

## 7. Corrector response versus predictor response

The prescribed-head corrector is a different map:

```
H -> q_swap(H).
```

Its derivative is:

```
dq_swap/dH = J_R/DeltaT.
```

MAP02/MAP03 show in the simple fixture:

```
dq_swap/dH ~= -u_A/DeltaT
```

while the production affine policy uses:

```
s_policy = +u_A/DeltaT.
```

This is not a unit/sign conversion error. These derivatives belong to different
maps.

## 8. What reanchoring means

After a real corrector evaluation at H_k, the current coupling service forms:

```
q_affine,new(H)
  = q_swap(H_k) + s_policy*(H-H_k).
```

The intercept is therefore a measured physical corrector flux.

The retained slope is an iteration-response policy.

That line should not be described as a newly measured physical bottom-flux
law unless its slope was independently obtained from the corrector map.

## 9. What MAP04/MAP05/MAP05A establish

MAP04, very short F-GC45 window:

- +u_A/DeltaT;
- zero slope;
- measured corrector slope;

all reach effectively the same accepted physical state and ledger.

MAP05, stronger B3 response:

- current +u policy remains admissible;
- intercept-only path reaches a corrector-domain failure before the conjunctive
  gate closes.

MAP05A:

- independently measured negative corrector slope J_R/DeltaT is admissible;
- it reaches the same accepted state and ledger as current +u;
- it uses the same three coupling iterations in that case.

Therefore slope policy can affect path robustness even when accepted physics is
invariant between admissible policies.

No universal performance ranking is established.

## 10. HCOF/RHS

MODFLOW receives:

```
Q(H) = HCOF*H - RHS.
```

F-GC33 is an exact algebraic transform of the selected affine response.

HCOF inherits the semantics of the chosen slope policy. It is not
automatically:

- physical storage;
- a Darcy conductance;
- physical bottom flux;
- accepted interface mass.

The dummy-SWAP DSW19 controls show that a wrong physical formulation can still
be numerically converged by MODFLOW.

## 11. True q-link conductance remains separate

A physical finite-resistance q-link requires two physical heads:

```
q_ex = C*(H_1-H_2).
```

DSW08/DSW18 show the expected two-state behavior and the C -> infinity
shared-state limit.

No current evidence justifies identifying `u_A/DeltaT` with such a physical
conductance.

## 12. Coupling acceptance must remain multi-gate

A coupled result is accepted only when separate questions are satisfied:

1. Did MODFLOW converge numerically?
2. Did the coupled SWAP/MODFLOW residual close?
3. Did the physical water balance close?
4. Is the correct candidate accepted from the authoritative origin?
5. Was interface mass published exactly once?
6. Is the response derivative valid for its declared map and control
   coordinate?

These gates are not interchangeable.

## 13. Current contract vocabulary

Use these names consistently:

```
H_interface
  lower coupling-plane hydraulic head in the current F-GC route

H_phreatic
  shared water-table state only in an explicitly defined phreatic h-link

xi_swap
  SWAP-owned internal memory

DeltaS
  physical whole-column storage change

J_S
  prescribed-head storage derivative

qbot
  native SWAP bottom flux, positive into SWAP

q_swap / V_R
  prescribed-head corrector bottom exchange, outward from SWAP
  accepted integral is interface-mass authority

J_R
  prescribed-head physical bottom-exchange derivative

u_A
  prescribed-flux predictor response coefficient

q_u
  historical predictor/effective-exchange response

partial_q_u_slope
  +u_A/DeltaT at fixed qbot and u_A

total_q_u_predictor_slope
  total derivative along neighboring predictor states

s_policy
  affine iteration slope retained after corrector reanchoring

HCOF/RHS
  MODFLOW matrix representation of the selected affine iteration response
```

## 14. Pending boundary

MAP06 is still required to characterize the structured B3 corrector
admissibility domain that caused the MAP05 intercept-only failure.

MAP07 CI preservation is still required, although its frozen-evidence
recalculation already establishes the partial-versus-total derivative
distinction.

Until those are closed:

- do not change production slope policy;
- do not widen corrector admissibility;
- do not rename u_A as universal storage;
- do not call +u_A/DeltaT the physical bottom-exchange Jacobian;
- do not collapse q_u and q_swap into one quantity.
