# Conservative correction prototype

Qualified bounded research,23October2026. This code is outside production SRC and
has no native/default activation. It calls the actual positive implicit-upwind
process as a low-order predictor and changes only internal face transfers.
The interface rejects unsupported ON forcing with the original state intact;
OFF delegates directly to the original process.

The target face value uses a monotonized-central limited MUSCL-Hancock predictor.
Equal-and-opposite face corrections preserve total stock. Per-cell removal and
addition budgets restrict each face to nonnegative stock and the previous global
concentration maximum. A16-epsilon reserve acts on the correction coefficient;
no physical concentration/stock clipping or mass renormalization is used.
The original low-order boundary transfer remains unchanged. The tested pulses
are far from the boundaries, so boundary accuracy is not established.

The supported research domain is uniform constant water and linear storage,
constant downward flux, zero inlet concentration and no physical dispersion,
diffusion, decay, roots, drainage, pond, irrigation, runon, age or aquifer state.
CFL must be at most1. The numerical study fixes theta=.25,rho=1.3,q=.25cm/day,
Kf=0/.2,dt=.002day and a40cm profile;40/80/160/320cells advect Gaussian and square
cell-average pulses over2days. Each corrected profile is paired with the actual
uncorrected production process using identical physical inputs. O0/O2 compiled
closure has six production providers plus the research module.

All64 profiles pass independent analytic cell-average comparisons, nonnegative
stocks, no new concentration maxima and hard mass reconstruction. O0/O2 profile
agreement is within1e-12. The maximum recorded step and cumulative mass residuals
are respectively1.777e-15 and1.555e-15mg/cm2, rounded upwards. All32paired errors
improve; the largest corrected/baseline L1 ratio is0.6852, rounded upwards.
Each of32ON cases exercises nine unsupported forcing/CFL rollback conditions,
288successful rejections in total. These counts do not imply broader physics.

| Gaussian,320cells | Baseline peak deficit | Corrected peak deficit | Baseline L1 | Corrected L1 |
| --- | --- | --- | --- | --- |
| Kf=0 | 10.57% | 1.01% | 0.27395 | 0.01378 |
| Kf=0.2 | 5.60% | 0.73% | 0.14097 | 0.00774 |

L1 integrates absolute concentration error over depth; it is not a mass-balance
error. These zero-physical-dispersion/zero-decay cases differ from the earlier
physical-dispersion study, so the percentages are not paired with that study.
The square pulse also improves without overshoot, but remains smeared: at320cells
its L1 falls from0.79999to0.27592 forKf0 and0.51849to0.18727 forKf0.2. A sharp
front's peak alone would hide that remaining error. No formal convergence order
is claimed from this experiment.

The first checked sharp320cell O0 attempt trapped a floating-point exception:
a budget ratio overflowed when its denominator was extremely small, even though
the mathematical limiter would have been one. The fix avoids that division when
the unconstrained budget already fits. IEEE traps and physical guards remain
active. Failed sources, streams and execution checkpoint remain in the capsule.
The normalized linear mass partition also preserves exact zero sorbed stock
whenKf0, avoiding a subtraction-roundoff artifact.

Total final compile/link/native process time was8.14s locally. The initial source/raw
owner and30controls pass at the original checkpoint. After reconciling canonical
c22fe5b2, the current delegated owner and its24controls pass; the actual seven-
provider prototype execution surface remains source-exact. Six additional
evidence/false-claim controls pass.
STATUS.json and the source/raw capsule own measurements and reproduction.

This is an implemented algorithm prototype, not a production SOL fix. Actual
accepted water traces, nonuniform/changing water, nonlinear Freundlich, reaction,
physical dispersion, active crop and persisted native composition require their
own contract and qualification. Existing native application, solvers, defaults,
tolerances and all capability dispositions remain unchanged.
