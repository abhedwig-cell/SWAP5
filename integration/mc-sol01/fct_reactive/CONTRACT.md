# Research FCT with implicit dispersion and decay

Baseline `ef2110c6b0f1aa315eabb00c3672705b6d51a3bf`. MC-SOL01 owns this
isolated research successor. Production source, defaults and public interfaces
remain unchanged. Invariants: one signed mass exchange per interior face,
nonnegative source storage, unchanged physical constitutive laws, explicit
decay ledger, and whole water/chemical rejection before publication.

The frozen advection FCT supplies a desired conservative interior correction.
Reconstruct its face transfers from cumulative differences against the real
advection-only implicit candidate. Limit the transfers against original total
storage and the original-water concentration maximum. Insert the resulting
zero-sum mass vector into the right-hand side of the existing implicit reactive
solve. Physical advection, molecular and mechanical dispersion, Freundlich
storage and temperature/moisture decay are solved together. Decay is included
in the existing external-output total and also reported separately, never added
twice. This is a new numerical composition requiring its own qualification.

`generate.py` creates a source-bound research successor of the real production
reactive solver. It reuses production forcing/receipt types and retains every
physical formula and acceptance threshold. Changes are module/routine naming,
an optional conservative mass RHS, validation and insertion of that RHS.
No hand-copied physical solver is maintained. With correction disabled call the
original production interface; with both physical processes zero delegate the
frozen FCT exactly. All generated sources and original inputs enter evidence.

Select checked local O0/O2 small process tests first: no-flow diffusion mode and
uniform reaction analytical discrete oracles, combined constant-flow linear
oracle, zero-process exact delegation, nonlinear equilibrium/positivity/mass,
late rejection and batch atomicity. Then real172-provider water/joint fixture
on40/80cells,0.8/1.2conductivity,Freundlich0.5/1/2,four0.1daywindows,
alpha0.25cm,Dm0.02cm2/day,decpot0.05/day. Preserve exact retry and opaque
in-memory checkpoint continuation. Expected small build<5s and joint build/run
100s,180s per-process bound. Full F-CI, native year, RossFast and highest-low-air
are not selected: no production scientific source change.

Qualification does not activate production or establish disk/fresh-process or
crash-consistent joint persistence, root/drainage sinks or full MC-SOL01 closure.
