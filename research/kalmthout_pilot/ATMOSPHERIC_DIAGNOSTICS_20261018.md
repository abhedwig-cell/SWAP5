# Kalmthout atmosphere sensitivity, 2026-10-18

## Exact evidence

- Current-workbranch source: `de4358ce854335c8d5b3cb0e2a318a5eda48b095`.
- GitHub Actions run: https://github.com/abhedwig-cell/SWAP5/actions/runs/39116652486
- Artifact: `kalmthout-current-pilot`, id `12132726361`.
- Grid: 1024 500-m cells; one representative column simulated.
- Hourly ERA5 inputs: 2024-01-01 through 2026-10-01 inclusive, 24120 hours.
- Owner bootstrap qualification gate: PASS.
- Rutter 48-hour physical smoke: 48/48 hours PASS.
- Rainfall-only Rutter/Reference physics: 24120/24120 hours PASS.

## Atmospheric sensitivity

| Scale of SWAP PM evaporation demand | Completed hours | First failed hour | Solver rejections | Temporal rejections | Mass rejections |
| ---: | ---: | --- | ---: | ---: | ---: |
| 0.25 | 4334 | 2024-06-29T14:00 | 428 | 0 | 0 |
| 0.50 | 3185 | 2024-05-12T17:00 | 571 | 0 | 0 |
| 0.75 | 2486 | 2024-04-13T14:00 | 410 | 0 | 0 |
| 1.00 | 1645 | 2024-03-09T13:00 | 507 | 0 | 0 |

All four failures were `ADMITTED` profiles with `completed=false`, `committed=false`;
the failing hour had no rainfall and the reported solver status was 2 (`legacy-reference-retry` for all but 0.25, where last route was `not-run`).
The 0.25, 0.50, 0.75 and 1.00 failures occurred under daily PM reference ET of approximately
4.4953, 4.8847, 3.6281 and 1.9793 mm/d respectively.
Recent preceding accepted hours carried finite, near-roundoff mass residuals.

## Interpretation and next scientific gate

The failure is not explained by temporal-error or mass-admission tolerances. A stronger
evaporation demand causes earlier failure, consistent with cumulative drying and the dry
atmospheric boundary / Richards constitutive trajectory reaching a difficult regime.
This is a diagnostic association, not yet proof of a specific constitutive or boundary bug.

Do not weaken mass conservation or silently add water/evaporation caps to force completion.
Pin an accepted-state checkpoint just before first failure and record top-layer head,
water content, ponding, actual evaporation, atmospheric potential, top flux, bottom flux,
solver nonlinear route and candidate failure stage. Compare dry-top state/flux with
the SWAP 4.3.1 reference policy and qualify any fix against the permanent owner gate
and representative wet/dry transitions. RossFast is out of scope.

## Reproducibility

The 2026-10-18 diagnostic matrix run is a failed overall CI job *by design* while
any full-atmosphere case fails. The failure must not hide the independent successful
rainfall-only baseline. Earlier experimental `pure-flux preflight` was removed because
it changed the failure to hour 23 for all evaporation factors, including zero.
That modification has no positive scientific evidence and must not be promoted.

## 2026-10-18 accepted-state and regime-transition findings

Focused run: https://github.com/abhedwig-cell/SWAP5/actions/runs/39118301423 .
The last accepted state at 2024-03-09T13:00 (before the failed hour) had
top pressure head +1.000847627 cm, top water content 0.423 m3/m3
(equal to configured saturation), pond depth 0.000847627 cm,
and potential soil evaporation 0.166700951 cm/d.
The earlier interpretation as cumulative *drying* is **falsified** for
this failure: the top node was saturated and marginally ponded.

Focused dynamic-top evaluation:
https://github.com/abhedwig-cell/SWAP5/actions/runs/39118742658 .
Accepted trial-start preflight repeatedly changes between
`ponded-head` (regime 2, analytic head derivative present) and
`surface-flux` (regime 1, derivative not applicable), with ponding
on the order of 1e-15 cm under repeated solver step refinement.
The Rutter physical boundary returns `AVAILABLE` on both sides
and conserves mass on accepted predecessors, but the Newton / retry
trajectory does not complete this interval (507 solver rejections;
zero temporal or mass rejections).

The failure mechanism is therefore localized to a **regime transition
near zero surface storage at a saturated top node**. This is still
a diagnostic localization, not proof that the switching threshold itself
is erroneous. A scientifically admissible repair requires a branch-
consistent nonlinear / complementarity treatment against the SWAP 4.3.1
reference, plus Rutter wet/dry head/flux transition gates with unchanged
transactional rollback and hard mass criteria.

Do not promote the earlier unconditional pure-flux preflight: it failed
rainfall-only at hour 23. RossFast is not involved.

The temporary `KALMTHOUT_TOP_REGIME` instrumentation in the work branch
is bounded to the diagnostic time window, and must be removed before
production admission.

## SWAP 4.3.1 source-side comparison, 2026-10-18

Source read at pilot HEAD `d44053ea594a77e93209022bb6f3d85ae5fca631`:
`reference/swap-4.3.1/b1_11_frost_source/SWAP/boundtop.f90`,
`reference/swap-4.3.1/b1_11_frost_source/SWAP/headcalc.f90`,
`src/solver/mod_b110_dynamic_top_boundary_provider.f90` and
`src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90`.

The source-derived correspondence is explicit:
- Both old and new compute `q1 = -q0 - pondm1/dt`, test atmospheric limiting flux `q1 >= 0 and q1 > Emax`, and use `h0 = h(1)-disnod(1)*(q1/k1max+1)` for flux versus ponded head.
- Both use `h0 <= 1e-6 cm` for the flux branch and the analytical `p1, p2, h0max` ponding formula for the other branch.
- The experimental rewriting `h0max=(p1*p2)*h0` is algebraically equivalent in the no-macropore/no-runoff entry and is **not** a scientific change to legacy regime selection.
- Legacy `headcalc.f90` also explicitly checks individual compartment flux residuals and head iterations, followed by the ponded-surface mass balance when `ftoph`. Corresponding SWAP5 solver iteration order, Jacobian and route switching have **not** yet been proven equivalent.
- Existing postimage run 39122723811 failed at the exact previous interval, with 547 solver rejects, zero temporal rejects and zero mass rejects. Thus cancellation alone is ruled out as a sufficient remedy.

The next discriminating test is a **real-production-interface** solver trial from the persisted last accepted state at the 2024-03-09 13:00 interval, recording per-Newton-iteration candidate top head, branch, residual, Jacobian/derivative and backtracking decision at O0/O2. Contrast the legacy `boundtop/headcalc` iterate-level decision with the new provider and solver. Preserve exact evap demand, accepted state, mass threshold and rollback. Do not substitute threshold tuning, arbitrary demand scaling or RossFast. The source comparison itself is analysis, not test/qualification evidence.

## Exact Newton trace result, 2026-10-18

Focused production execution at SHA `937b95a018803875a51b640f856979ac9f0ca2b8`:
https://github.com/abhedwig-cell/SWAP5/actions/runs/39125001908 .
Terminal **FAILURE** with the same first failed weather interval `2024-03-09T13:00`;
22 accepted substeps, 547 solver rejections, zero temporal and zero mass rejections.
`KALMTHOUT_NEWTON_TRACE=1` logs the real `src/legacy/b1_10_port/headcalc.f90`
and does not alter solver decisions.

The trace reveals a severe nonlinear step instability at the saturated top:
old top-node head is about `+1.0 cm`, while candidate Newton top-node
heads reach approximately `-2.06e4 cm` during `surface-flux` iterations.
As dt shrinks into ~`2.8e-14 d`, reported `Fmax` exceeds `1.2e13`
and residual square norm reaches `1.9e26`; dt refinement does not cure
the instability. These are unaccepted trial candidates, not committed
physical states or measured groundwater depletion.

Verified source comparison:
`src/legacy/b1_10_port/headcalc.f90` builds the Newton Jacobian from
the current state and evaluates the dynamic top provider again in
`vector_F(2)` after candidate update. In the flux branch the
top boundary contributes prescribed qtop; in the head branch it contributes
`-kmean(1)*gradient`, including a derivative of the candidate surface head.
The legacy `boundtop.f90` / `headcalc.f90` likewise reselect the
top regime while iterating, but *equivalence of iterate trajectory and
Jacobian construction has not been established*.

The evidence is consistent with a poor Newton step / nonsmooth regime
transition. It **does not yet establish** whether the root cause is a
Jacobian defect, backtracking acceptance, initial constitutive state,
or interacting process contract. The next minimal qualifying experiment
must capture pre-step `F(1)`, Jacobian diagonal/off-diagonal, Newton
increment, trial damping, and regime on both sides of the transition,
then check directional consistency by finite differences on the
actual production interface. Do not change hard mass gates or atmospheric
demand, and do not call this test a successful historical simulation.
