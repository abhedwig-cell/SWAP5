# TOP03 continuum-contact execution follow-up

Date: 2026-10-02. Test-only numerical execution change before replay.
Initial continuum source: 4338fc4e985f3e9e24825d209dde0eac3c770378.

The first continuum build reaches the trajectory matrix but its m8/R0.5/ns512
case exceeds the runner's 30-second per-case process bound. The run does not
complete O0/O2 qualification. Retain that command/failure and source manifest;
never classify a timeout as physical nonequivalence. A pinned-binary O0 replay
retains all 494 component/saturated/competing-branch control records from this
exact source independently of the lost in-memory incomplete runner list.

The provider currently repeats three scalar bracket initializations inside
every global Newton evaluation and again in post-solve/pre-solve diagnostics.
This is redundant qualification work on a strictly decreasing scalar F, not
necessary candidate state or physics. Move the three-start agreement check to
the standalone component controls. Each candidate uses the same deterministic
seed0 safeguarded root, with unchanged local residual and flux identity gates.
No warm-start history, cache, provider mutation, physical model, quadrature
budget or convergence tolerance is introduced. All 468 standalone controls
still require the original three bracket starts and agreement budgets.

Increase only the runner's explicit per-case process bound to 120 seconds,
retain per-case timings separately from physical output, and journal completed
raw records after each process so another timeout cannot erase completed work.
A timeout remains a hard incomplete execution gate. It cannot be passed or
silently filled with an invented flux. Numerical O0/O2 identity remains exact;
all inherited 54 trajectories and the initial 494 control-replay outputs must
remain unchanged. Repeat the same 566-case matrix at O0/O2. The independent
SciPy integral/Brent, competing-root audits, space/time and physical budgets
remain unchanged. No performance portability/admission claim follows from
this execution repair, and no Actions run is needed.
