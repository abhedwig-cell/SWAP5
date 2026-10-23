# FCT with dispersion and decay in one implicit candidate

The research route now processes the conservative FCT correction through the
implicit reactive solve. Molecular and mechanical dispersion, equilibrium
sorption and degradation act on the same candidate. The correction is a signed
interior mass exchange; its sum is zero and its right-hand-side storage remains
nonnegative. The unchanged production equations and thresholds are generated
from the exact production source; only the explicit research mass RHS and its
validation are inserted. Production dispatch and defaults remain unchanged.

Qualification on `ef2110c6` with source checkpoint `c557f7f9`:

- 24 checked O0/O2 small cases through the10-source real reactive closure.
  Independent finite-volume equations including positive dispersion and decay
  reproduce the solution with maximum residual `3.5459916253310908e-15`.
  Exact disabled-correction and zero-process delegation and negative-rate
  rejection pass. Nonlinear Freundlich0.5/1/2 equilibrium and positivity pass.
- The analytical no-flow linear-sorption diffusion/decay mode matches the exact
  discrete solution within1e-12. For a fixed one-day interval the maximum error
  against the continuous-time mode falls from0.000784034 to0.0000993791 as the
  number of steps increases4,8,16,32. Successive errors decrease by about half.
- 24 checked O0/O2 actual water/joint cases through175 sources (174 providers),
  2,292 primary accepted water substeps,480 exact rejected trials,96 exact
  retries and48 exact in-memory checkpoint continuation windows. Every window
  has positive separately measured degradation. Decay is already included in
  the production external-output total and is not added to that total twice.
- Maximum independent mass residual is `1.451069082600287e-14 mg/cm2`.
  Maximum numerical difference between O0/O2 complete output values is
  `4.440892098500626e-16`. Within each build rollback/retry/checkpoint/delegation
  comparisons remain exact, including water derivative history and provenance.
- Current composed scientific owner plus134 source/raw controls pass. The new
  sealed543-member proof passes eight controls, including a corrupted profile
  that preserves total mass and equilibrium but violates the independent
  physical equation. Initial small proof is retained alongside the full run.

The full selected compile/execution cost is115.135seconds. Physical scope is
uniform material,16cell fixed-water oracle and40/80cell real Reference water,
Freundlich0.5/1/2,20C, alpha0.25cm,Dm0.02cm2/day,decpot0.05/day for the real
water cases, and four0.1daywindows. The fixed-water process oracle uses
alpha0.25,Dm0.2,decpot0.1 where active.

This proof establishes the stated numerical equations, conservation, bounded
state, joint transaction and analytical no-flow temporal convergence. General
advective-dispersive pulse/PDE accuracy still needs its own refined reference.
Native activation, root/drainage sinks, durable disk/fresh-process restart and
crash-consistent publication remain open. Actual canonical admission is
recorded separately from this qualification-time result.

Recheck with `python integration/mc-sol01/fct_reactive/verify.py --self-test`.
