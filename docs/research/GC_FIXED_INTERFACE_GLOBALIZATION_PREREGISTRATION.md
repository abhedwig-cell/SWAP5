# Fixed-interface coupling globalization research plan

Date: 2026-09-21
Status: PREREGISTERED NEXT PHASE

## Question

Given a physical outward SWAP response q(H) with local derivative p=dq/dH and a groundwater residual R(H), which linearization/globalization closes the fixed-interface equation robustly without changing accepted physical exchange semantics?

## Frozen semantics

- H is hydraulic head at the fixed geometric coupling plane.
- q>0 is SWAP -> groundwater.
- accepted mass is the final physical SWAP corrector exchange, never the affine working surrogate.
- physical storage inventories remain disjoint.
- rejected corrector trials have zero authority.

## Candidate numerical policies

P0 current surrogate:
  s=+u/dt, exact reanchor after every accepted trial.

P1 physical Newton tangent:
  s=dq/dH, using -u/dt only where independently qualified as that derivative.

P2 Picard:
  s=0, exact reanchor.

P3 relaxed current surrogate:
  compute raw P0 update, then H_{k+1}=H_k+alpha(H_raw-H_k), 0<alpha<=1.

P4 safeguarded physical tangent:
  P1 inside the admissible corrector envelope; reject/contract a proposed head step that lies outside the envelope.

No policy is production-admitted by this preregistration.

## Analytical qualification family

For a scalar groundwater storage response a=dq_gw/dH and locally affine physical SWAP response p=dq/dH, a reanchored surrogate slope s gives

  e_{k+1} = rho e_k,
  rho = (p-s)/(a-s)

under the sign convention q_swap=q_gw.

A relaxed update gives

  rho_alpha = 1-alpha+alpha*rho.

Qualification:
- fixed-point consistency is necessary but not sufficient;
- local contraction requires |rho|<1;
- relaxed contraction requires |rho_alpha|<1;
- a physical Newton slope s=p gives rho=0 for the affine local problem, provided the groundwater denominator is nonsingular;
- trial-envelope admissibility is an independent gate.

## Prospective experiments

G01: reproduce NH01/PB01 for P0-P3 and compare measured versus derived rho.
G02: sweep groundwater storage response a while holding SWAP p fixed; locate singular and unstable regions without post-hoc policy tuning.
G03: sweep p/a ratio and derive policy phase diagram.
G04: nonlinear NH03 response: compare Newton, Picard, positive surrogate and safeguarded Newton from multiple preregistered starts.
G05: real F-GC44 corrector: use only admissible head perturbations; estimate p prospectively and test one-step local predictions without committing rejected states.
G06: asymmetric admissibility: test step contraction/safeguard independently of residual convergence.
G07: only after G01-G06, evaluate whether a general production algorithm can be admitted.

## Decision gate

A production algorithm must separately satisfy:
1. physical fixed-point correctness;
2. mass/transaction authority;
3. local convergence;
4. finite perturbation robustness within declared envelope;
5. behavior at/near singular response ratios;
6. no dependence on undocumented MODFLOW solver stabilization.


## G03-LIVE / G05 / G06 concrete protocol (2026-09-21)

This section freezes the live F-GC44 instantiation before reading its result.

G03-LIVE identifies the effective local MODFLOW response with constant-flux API
probes, not with a moving affine intercept. Each probe uses HCOF=0, prescribes
q_gw in {-4e-8,-2e-8,-1e-8,+1e-8,+2e-8,+4e-8} m/s, starts from a fresh copy of
the F-GC44 MODFLOW model and the same accepted XOLD, and iterates MODFLOW to its
own convergence before recording (H,q_gw). The fitted a=dq_gw/dH is therefore
an intrinsic groundwater response over the sampled local head range.

Finite real-SWAP starts are fixed prospectively at
{-1e-6,-5e-7,+5e-7,+1e-6,+2e-6} m relative to href.

The earlier interpretation of the first -2e-6 m local-scan result is withdrawn
before the replacement G06 run. Source inspection shows participant status 4 is
CANDIDATE_BUSY. The historical test left trial(href) live before the first scan
point, so that point did not execute the corrector and cannot define a head
admissibility boundary.

Replacement G06 first reproduces that status-4 ordering artifact explicitly.
It then evaluates the cold-process head grid
{-1e-4,-5e-5,-2e-5,-1e-5,-5e-6,-2e-6,-1e-6,
 +1e-6,+2e-6,+5e-6,+1e-5,+2e-5,+5e-5,+1e-4} m relative to href.
Every point runs in a fresh process from the same accepted physical origin.
Only participant status 6 (TRIAL_FAILED) counts as a corrector failure.
Status 4 is forbidden in the clean scan.

If one or more status-6 points occur, G06 selects the failure with the smallest
absolute head perturbation, breaking ties toward the negative perturbation, and
applies fixed factor-1/2 contractions toward href for at most 12 contractions.
If no status-6 point occurs in the fixed grid, G06 records that the safeguard
trigger was not exercised and makes no broader envelope claim.

P3 does not tune alpha from finite-start trajectories. It uses
alpha*=1/(1-rho_P0), computed once from frozen real-SWAP p and the prospectively
measured G03-LIVE a, provided 0<alpha*<=1.

P4 uses physical-tangent reanchoring plus a fixed factor-1/2 head-step
contraction whenever a proposed SWAP corrector head is inadmissible. Rejected
trials are discarded and have zero mass/state authority.

All G03-LIVE/G05/G06 runs are diagnostic. They must leave SWAP revision, time,
ledger count and committed interface exchange at the immutable accepted origin.
No production HCOF/RHS source is changed by these experiments.
