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
