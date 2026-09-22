# SWAP5–MODFLOW6 coupling taxonomy: state, storage, flux and response

Date: 2026-09-21  
Status: RESEARCH SYNTHESIS AFTER DUMMY-SWAP + MAP02/MAP03 + PUB-GC E4

This note reconciles the dummy-SWAP concept testbank, the real-SWAP MAP02/MAP03
experiments, and the already admitted PUB-GC E4 response-identity evidence.

It is a semantic map, not a production-code change.

## 1. Start from one physical system

For a shared-head vadose-zone/groundwater formulation, the phreatic hydraulic
head is one physical state:

```
H = shared groundwater / phreatic head
```

That does **not** imply that the complete SWAP state is one-dimensional.
Internal unsaturated storage, pressure-head profiles, vegetation/process state
and other memory can remain SWAP-owned.

DSW11 and DSW15 demonstrate this explicitly: two columns can share the same
groundwater head yet respond differently because their internal memory differs.

## 2. Storage is a physical volume response

Define whole-column storage over one accepted origin/window as:

```
S(H, xi)
```

where `xi` denotes SWAP-owned internal memory.

A local shared-head storage response is:

```
J_S = d(Delta S)/dH.
```

MAP03 and PUB-GC E4 B1 independently show, for the simple drainage-free
F-GC45 fixture:

```
J_S ~= +3.403e-5
u_A ~= +3.403e-5.
```

This is a real hydrological storage sensitivity for that local state/window.

It is dynamic, state- and window-dependent. It is not a universal static soil
specific yield.

PUB-GC E4 B3 is the required counterexample to over-generalization:

```
u_A = 2.6657e-4
J_S = 2.8822e-4
```

so the two finite-window maps differ by about 8.1% in magnitude.

## 3. Bottom exchange is a different physical object

The real prescribed-head SWAP corrector returns accepted whole-window bottom
exchange:

```
V_R(H)
```

and mean interface flux:

```
q_swap(H) = V_R(H) / DeltaT.
```

The local integrated interface response is:

```
J_R = dV_R/dH.
```

The public SWAP-interface sign is outward from SWAP.

MAP03 gives, in the simple fixture:

```
J_R ~= -J_S.
```

This is not a sign-conversion accident. It follows from the water balance when
the remaining non-bottom balance is head-independent.

## 4. The differentiated water balance is the primary identity

Let

```
B(H)
```

be the whole-window non-bottom net balance in the sign convention used by
PUB-GC E4.

Mass closure gives:

```
Delta S - B + V_R = 0
```

and therefore:

```
J_S - J_B + J_R = 0.
```

In the current simple fixture:

```
J_B ~= 0
```

so:

```
J_S ~= -J_R.
```

This is why a storage interpretation and a signed bottom-exchange
interpretation are algebraically aliased in the low-flux control.

A non-zero `J_B` is required to separate them physically rather than only by
boundary-value-map definition.

## 5. Native qbot and accepted q_swap

Native SWAP lower-boundary flux uses:

```
qbot > 0 : into the SWAP profile
```

The public interface uses:

```
q_swap > 0 : outward from SWAP
```

thus:

```
q_swap = -qbot * unit_conversion.
```

The corrector ledger integrates accepted `q_swap` only after coupled
acceptance and publication.

This ledger is the interface-mass authority.

Rejected predictor/corrector trials contribute zero authoritative interface
mass.

## 6. u_A is a finite-window predictor response

The admitted F-GC30 response is:

```
u_A = DeltaT * (dH_end/dqbot)^(-1)
```

for the prescribed-bottom-flux predictor map:

```
qbot -> H_end.
```

Independent PUB-GC E4 finite differences verify this strongly.

Therefore `u_A` is neither an arbitrary tuning coefficient nor a universal
head-to-exchange Jacobian.

It is typed by:

- accepted origin;
- coupling window;
- predictor boundary condition;
- active process envelope;
- derivative provenance.

## 7. Historical q_u is not the accepted bottom ledger

The historical predictor algebra is:

```
q_u = u_A * (H_end-H_start)/DeltaT - qbot.
```

This object combines a head/storage-like response term with the native bottom
flux.

F-GC40 then represents its local affine response as:

```
q_u(H) ~= q_ref + (u_A/DeltaT)*(H-H_ref).
```

F-GC33 maps that line exactly to MODFLOW HCOF/RHS.

Thus `q_u` is the MODFLOW-facing predictor/effective-exchange response used
during iteration.

It must not be silently identified with the accepted corrector
`q_swap(H)` or with the final interface ledger.

## 8. Corrector response J_R is a different finite-window map

The prescribed-head corrector map is:

```
H -> V_R(H)
```

with derivative:

```
J_R = dV_R/dH.
```

PUB-GC E4 establishes that:

- low-flux B1/B2/B4: `|J_R| ~= u_A`;
- stronger B3: `|J_R|/u_A ~= 1.08119`;
- B5: `u_A` remains identifiable while no symmetric local `J_R` exists.

Therefore no universal identity

```
u_A == +/- J_R
```

is scientifically valid.

## 9. Why MAP02 found opposite slopes

MAP02 measured in the B1-like F-GC45 fixture:

```
production q_u slope  = +u_A/DeltaT
real q_swap slope     ~= -u_A/DeltaT.
```

MAP03 then independently showed:

```
d(Delta S)/dH          ~= +u_A
d(V_bottom,out)/dH     ~= -u_A
d(Delta S+V_bottom,out)/dH = 0.
```

So the sign inversion is physically explained by the mass balance and the fact
that the two slopes belong to different response objects.

## 10. What reanchoring does

F-GC39/F-GC49 uses the current affine response to drive MODFLOW.

After a real SWAP corrector at head `H_k`, the current production route
reanchors the affine intercept to the measured corrector flux while retaining
the qualified slope policy:

```
q_affine,new(H)
  = q_swap(H_k) + s_policy*(H-H_k).
```

In the first admitted contract:

```
s_policy = u_A/DeltaT.
```

This should be interpreted as **coupling response information / an iteration
slope policy**, not as newly published physical mass.

Final physical mass still comes from the accepted corrector plus exactly-once
ledger publication.

## 11. HCOF is a numerical matrix coefficient

For MODFLOW:

```
Q(H) = HCOF*H - RHS
```

and F-GC33 sets:

```
HCOF = A*86400*s_policy.
```

Therefore HCOF may numerically have dimensions resembling a conductance or
storage/time term.

Its physical meaning is inherited from the response object used to build it.

It is **not automatically**:

- a physical interface conductance;
- an additional storage reservoir;
- a Darcy resistance;
- the accepted interface flux.

DSW01/02/07/19 show why confusing these roles produces exact, predictable
wrong solutions even when MODFLOW converges.

## 12. True q-link conductance is separate

A physical q-link with two states has:

```
q_ex = C*(H_1-H_2).
```

Here `C` represents an actual resistance/conductance between two physically
distinct state locations.

DSW08/18 show:

- finite `C`: two legitimate heads and physical exchange;
- `C -> infinity`: heads collapse toward one shared state;
- storage ownership remains a separate question.

Thus a q-link conductance must not be inferred from `u_A/DeltaT`.

## 13. Shared storage ownership

For one shared state, physical storage must be counted once.

DSW02 proves that one storage can be algebraically partitioned between
components if the partition is consistent.

Counting the same storage twice gives the independently predicted
double-storage signature.

The storage ledger therefore needs explicit ownership even when head is shared.

## 14. Solver convergence is not physical correctness

DSW19 deliberately constructs several wrong coupling terms that MODFLOW solves
successfully.

Therefore acceptance requires separate gates for:

1. subsystem numerical convergence;
2. coupled residual closure;
3. physical water-balance closure;
4. state/ledger publication authority.

No one gate substitutes for the others.

## 15. Current interpretation after MAP03

The evidence supports this hierarchy:

```
shared H
  physical state coordinate

SWAP internal xi
  additional memory needed to predict future response

S(H,xi)
  physical storage

qbot
  native SWAP lower-boundary flux

q_swap / V_R
  real corrector bottom-interface exchange
  accepted integral is mass authority after publication

u_A
  finite-window prescribed-flux predictor response

J_S
  head-driven storage response

J_R
  head-driven interface-exchange response

J_B
  head-driven non-bottom balance response

q_u(H)
  MODFLOW-facing historical affine predictor/effective-exchange response

HCOF/RHS
  numerical representation of the currently selected affine response policy
```

These objects can share units or have similar numerical values without being
interchangeable.

## 16. Next decisive experiment

The remaining coupling-algorithm question is not semantic but numerical:

> If the physical corrector and mass ledger are held fixed, does changing only
> the affine slope policy change the converged physical solution, or only the
> route/work needed to reach it?

A controlled live-MODFLOW comparison should therefore use one immutable
physical SWAP origin and compare at least:

1. current supplied `+u_A/DeltaT`;
2. zero retained slope / intercept-only response;
3. exact local corrector `J_R/DeltaT` where independently available;
4. optionally a cold secant learned from corrector history.

All variants must use the same coupled residual, corrector candidates, final
acceptance criterion and mass-ledger publication.

The expected invariant is the final accepted physical state/mass within the
fixed tolerance. Only convergence work/path is allowed to differ.
