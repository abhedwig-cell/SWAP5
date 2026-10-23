# Bounded flux-correction research

Baseline7a498cd61,23October2026. Research only; no native or default activation.
The prototype calls the actual positive implicit-upwind process, then replaces
only internal advective face transfers toward a MUSCL-Hancock predictor. Face
corrections have opposite signs in adjacent cells. Per-cell outgoing/incoming
budgets limit them to nonnegative total stock and the preceding global maximum
concentration. No negative-stock clipping or concentration rescaling is allowed.
A tiny roundoff margin is applied to the limiter coefficient, not to stocks.

The ON domain is downward uniform constant flux, uniform cells and constant
water/linear storage R=theta+rho*Kf, zero inflow concentration, no pond/age/aquifer,
no diffusion/dispersivity, decay, drainage, root, irrigation or runon source.
CFL=q*dt/(R*dx)<=1 is mandatory. Unsupported forcing rejects with exact original
state. OFF delegates to the existing process. The low-order production boundary
flux remains the boundary authority; only internal faces change. Smooth/sharp
pulses remain far from boundaries, so no general boundary accuracy claim follows.

Select checked O0/O2 small real production closure, Gaussian and square pulses,
Kf0/0.2 and40/80/160/320cells, fixeddt=.002day, and explicit unsupported/CFL
rollback controls. Expected build/native cost30seconds; no new full-column
compile or unrelated owner execution. Preserve failed observations. Success
requires original hard mass certificate, nonnegative stocks, no new maxima,
matching O0/O2 profiles and measured improvement against analytic cell averages.
No nonlinear Freundlich, changing-water, heat/source/restart/native compatibility
is inferred. Wider support needs a separate contract and physical qualification.
