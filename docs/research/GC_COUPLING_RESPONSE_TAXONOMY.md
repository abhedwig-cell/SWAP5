# Groundwater-coupling response taxonomy

Date: 2026-09-21  
Status: RESEARCH SYNTHESIS  
Authority: GC dummy-SWAP DSW01-20 and real-SWAP MAP01-07  
Production code: read-only

## Purpose

The SWAP5-MODFLOW6 coupling currently contains several quantities with similar
dimensions but different meanings. The dummy-SWAP and real-SWAP experiments now
provide enough evidence to keep these meanings separate.

This note does not propose a production change. It fixes the vocabulary and the
equation-level interpretation that later coupling decisions must preserve.

## 1. Shared physical state

For a phreatic SWAP-MODFLOW coupling, the groundwater head can be one shared
physical state even though the two model components retain different internal
state.

The dummy-SWAP evidence shows two simultaneous facts:

1. one physical groundwater storage may be partitioned algebraically between
   model components without changing the shared head if the storage response is
   represented consistently;
2. identical groundwater head does not imply identical complete SWAP state,
   because unsaturated-zone memory can remain different and affect later
   response.

Therefore:

```
shared groundwater head != complete shared model state
```

## 2. Physical storage response

Let physical whole-column storage be `S_phys(H,...)`. A local storage
sensitivity is

```
dS_phys/dH
```

and has storage-coefficient dimensions.

In the simple drainage-free real-Richards F-GC45 fixture, MAP03 established
that the production quantity `u` agrees locally with this whole-column storage
sensitivity over the qualified head band:

```
u ~= dS_phys/dH.
```

The agreement is about 2e-5 relative over the preregistered MAP03 band.

This is a bounded result. It does not make `u` universally equal to storage
under all active SWAP processes.

## 3. Physical bottom-interface exchange

The accepted SWAP corrector exposes a whole-window bottom-outward exchange. Its
time-integrated value is the physical interface mass authority after commit.

In the same simple F-GC45 fixture MAP03 found

```
dE_bottom,out/dH ~= -u.
```

At the transaction level:

```
d(storage change)/dH + d(bottom outward exchange)/dH = 0
```

because the remaining external forcing is head-independent in that fixture.

This opposite sign is physical and follows the water balance. It must not be
confused with the sign of the production affine iteration response.

## 4. Real corrector flux q_swap

For a prescribed shared groundwater head, the real SWAP corrector returns an
accepted whole-window interface exchange. The coupling service converts this to
a mean flux `q_swap`.

The accepted interface ledger satisfies

```
ledger exchange = q_swap * duration
```

including area weighting for MultiSWAP.

MAP02 verified this directly for the F-GC45 fixture.

Therefore the accepted corrector plus committed ledger are the physical
interface-exchange authority for the accepted coupling window.

## 5. Historical predictor quantity q_u

Production constructs the historical predictor response from an accepted
prescribed-qbot trajectory:

```
u = dt / (dH_bot/dq_bot)

q_u = u * (H_end - H_start) / dt - q_bot.
```

The production cell response then retains

```
dq_u/dH = +u/dt
```

while `u` and `q_bot` are held fixed.

MAP07 establishes that this is a **partial derivative of the affine extension**,
not the total derivative of historical `q_u` across neighboring predictor
trajectories.

Along the frozen B3 predictor family:

```
dq_bot/dH ~= +u/dt
```

so the two terms in the complete historical `q_u` expression cancel to first
order. The observed total derivative is orders of magnitude smaller than
`+u/dt`.

Therefore production `+u/dt` must not be described as the physical total
derivative of predictor `q_u` across neighboring accepted predictor states.

## 6. Production affine coupling response

The MODFLOW-facing response is represented as

```
Q(H) = HCOF * H - RHS.
```

The production predictor supplies a slope based on `+u/dt`; after each real
SWAP corrector trial the service reanchors the intercept to the newly observed
corrector flux while retaining that slope.

MAP01A and MAP02 show the operational pattern:

1. initial affine predictor and real corrector can have a material intercept
   mismatch;
2. the first real corrector measures the physical response at the trial head;
3. reanchoring the intercept closes the coupled residual on the next iteration
   in the simple F-GC45 case.

Thus the retained affine slope is best classified as an **iteration-response
policy** unless and until a stronger physical identity is separately proven.

## 7. Why equal units do not imply equal physics

Several terms can have dimensions equivalent to storage/time or conductance:

- storage sensitivity divided by timestep;
- physical q-link conductance;
- derivative of a head-dependent drain sink;
- derivative of evapotranspiration response;
- derivative of bottom-interface exchange;
- numerical tangent of a coupling residual;
- production affine `+u/dt` iteration slope.

The dummy-SWAP suite demonstrates that these quantities can have identical
units while producing different physical balances and different limiting
behavior.

Therefore naming and ownership must follow the governing equation, not units
alone.

## 8. q-link versus h-link

A finite-resistance q-link has two physical heads:

```
q_ex = C * (H_1 - H_2).
```

Each side may own physically disjoint storage. As `C -> infinity`, the heads
collapse toward a common state and the combined storage governs the common-head
response.

A shared-state h-link starts from one physical head. Any HCOF term used to
coordinate the decomposed solve is not automatically a physical interface
conductance.

DSW08 demonstrates the q-link limit explicitly. No current real-SWAP evidence
establishes a finite physical resistance between duplicate phreatic heads in
the production F-GC route.

## 9. Numerical convergence versus physical correctness

DSW19 establishes a direct adversarial control: several deliberately wrong
coupling formulations converge numerically to their independently predicted
wrong heads.

Therefore:

```
MODFLOW converged
```

is not a coupling-correctness criterion.

A coupled acceptance argument needs at least:

- subsystem numerical convergence;
- coupled residual closure;
- state/transaction provenance;
- physical mass closure;
- interface ledger closure where applicable.

## 10. Slope policy and path robustness

MAP04 shows that in the very short, weak F-GC45 regime three different slope
policies converge to essentially identical accepted physics:

- current `+u/dt`;
- intercept-only;
- independently measured local corrector slope.

MAP05 falsifies general slope-policy invariance in the stronger B3 regime:
intercept-only steers the outer iteration into a prescribed-head corrector
failure.

MAP05A shows that a nonzero independently measured corrector slope can still
converge to essentially the same accepted physical state as current `+u/dt`.

MAP06 then shows why: the B3 corrector admissibility set is deterministic but
fragmented at picometre-scale offsets. Slope policy can therefore affect the
iteration path and robustness without defining the final physical solution.

This distinction is central:

```
accepted physical solution
!=
numerical path used to reach that solution.
```

## 11. Current bounded interpretation

The evidence supports the following taxonomy.

| Quantity | Current interpretation | Physical authority? |
| --- | --- | --- |
| groundwater head H | shared phreatic state | yes |
| SWAP internal state | unsaturated/process memory | yes |
| whole-column storage S | physical stored water | yes |
| dS/dH | physical local storage sensitivity | yes, when directly established |
| accepted bottom exchange | physical interface transfer over accepted window | yes |
| q_swap corrector flux | mean accepted physical interface exchange | yes |
| committed interface ledger | integrated accepted interface mass | yes |
| predictor q_bot | prescribed predictor boundary flux | predictor input |
| historical q_u | derived predictor response quantity | not by itself |
| +u/dt retained slope | partial affine iteration-response derivative | numerical/coupling policy unless separately proven |
| HCOF/RHS | MODFLOW affine representation | representation, meaning depends on source term |
| finite q-link C | physical resistance conductance only when two-state resistance is explicitly modeled | yes in that model family |

## 12. Open questions

MAP08 must identify which raw FMR acceptance predicate creates the fragmented
B3 prescribed-head corrector domain.

MAP09 then tests a separate question: whether a research-only active-drainage
prescribed-head corrector is executable when the qbot-only smooth-freatic
projection is disabled for the corrector while leaving the admitted predictor
unchanged.

Only if that reference corrector is admitted should a follow-up decompose

```
dStorage/dH,
dBottomOut/dH,
dNonBottom/dH
```

under active drainage.

No production reformulation should be selected before those component-level
questions are closed.
