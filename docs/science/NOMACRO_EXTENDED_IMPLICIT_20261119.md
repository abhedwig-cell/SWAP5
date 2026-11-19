# Extended drainage implicit numerical composition contract

Development only; SWKIMPL1/SWDRA2 remains refused until integrated qualification.
Historical bottom6 assigns literal qbot=0 in BoundBottom and adds no bottom
Jacobian term. Its current implicit-reader exclusion is a composition guard,
not a missing original bottom-flux equation. The examined-Ksat derivative,
mean7's missing original table, AGE dry-pond policy and all other explicit
numerical/physical exclusions remain hard refused.

The new numerical interface composes the already qualified original implicit
surface mean derivative with the already qualified extended PondRunoff root.
Let G be current Kmean/disnod, J its complete soil-side flux derivative with
pond held fixed, dt the actual trial duration, and s the existing derivative
of the original runoff/supply depth with respect to pond. The coupled soil
flux derivative is J*(1+s)/(1+dt*G+s). Replacing G by J in both numerator and
denominator would differentiate the pond response incorrectly.

A separate extended_implicit_top_jacobian(G,J,dt) provider is emitted only for
the selected implicit composition. It derives its branch/stock-table slope
from the literal qualified extended_pond_top_jacobian body; only the function
name, additional scalar argument and numerator differ. The existing explicit
function and its callers remain unchanged. This interface owns no physical or
accepted state. G is finite/nonnegative; dt is finite/positive; J is finite and
may have either sign. Existing original piecewise boundary conventions remain.

The independent numerical interface probe must call real complete original
MOD_top/PondRunoff with the existing qualified root renderer, original object
closure and TTUTIL. A declared locally linear K(head) perturbation isolates
the conductivity/pond chain rule; it is a controlled derivative probe, not a
replacement Mualem soil model. Compare against central differences on smooth
outflow, limited/unlimited supply, nonlinear and elevated-stage branches,
check the explicit J=G limit and A/B/A nonmutation under O0/O2. Retain actual
sources, compiler flags, logs and executable identity. The derivative probe
threshold does not replace any absolute1e-10 water/CDE acceptance guard.

Before opening the input route, compose each existing implicit retry/event/
availability/saturation/root/interception/finite-Newton policy exactly once.
The extended strict trial frame and original coupled pond residual remain
additional strict acceptance conditions. Do not apply the explicit0 retry
predicate to implicit1, double-insert TimeControl recovery, or independently
subtract a conductivity derivative already included in the coupled tangent.
Require actual native replay to establish the required hydraulic carry for
history-off as well as history1/2; add no speculative physical store.

Then qualify short water/CDE O0/O2 and representative long integrated periods,
exact year-end/seasonal native windows, original counter/stock observations,
actual invalid-native and transactional controls. Reuse earlier history and
explicit periods only after proving their affected source/input/numerical
surface is preserved. Whole closure remains PARTIAL, science NOT_QUALIFIED,
global family/gap counts UNKNOWN and fixed named RC3 unchanged.

## Separately qualified original conductivity-cutoff defect (development)

Actual O0/O2 Windows and Ubuntu automatic CDE/history2 accepts571days then
strict original Newton rollback reaches its unchanged8ULP clock floor.
History0 fails after566days on Windows bothopts; this is not a history-only
failure. Exact native530 reproduces the original history2 failure after41days.
Actual read-only nodal/source probes locate the default Mualem hconduc shortcut
relsat>1-1e-6: node22 jumps from22.1980235224733349 at
Se0.999998998927270955 to22.76176 atSe0.999999001028285650.
FTOPH/FLRUNOFF are false; the new pond chain rule is inactive. Keeping normal
backtracking belowDTMIN does not remove the failure; that research hypothesis
is retained as a failed control and is not selected into production.

The proposed correction extends the literal original analytic Mualem formula
through this narrow near-saturation interval. Only the artificial constant-K
shortcut moves fromSe>1-1e-6 toSe>=1. Its existing consistency correction must
return zero derivative only on the actual new constant region. Other original
constitutive branches, soil parameters, watcon, moiscap, examined-Ksat refusal,
soil equations, convergence tests, timestep/rollback policy and all mass guards
remain unchanged. This changes original near-saturation reference behaviour;
it must be independently qualified as a reference-defect correction, never
presented as exact preservation of the discontinuous original function.

Apply only inside the selected implicit extended-drainage renderer. Require a
small executable using the real complete original MOD_MvG and its actual object
closure, original/corrected O0/O2 comparison, independent high-precision Mualem
values, finite-difference derivatives away from mathematical branch boundaries,
monotonicity, exact unchanged dry/other constitutive regions and A/B/A state.
Then rerun affected full numerical compositions on the actual corrected source,
with independently checked conservation/native/counters and unchanged explicit0
postimages. Earlier failed and water-success source epochs remain separately
retained. No admission is established by this development contract.
