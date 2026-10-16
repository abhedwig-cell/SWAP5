# MC-SOL01 persistent surface/source successor

Status: single-owner implementation, not canonical admission. Reconciled base
`efe79f5fd58f564f54dde5ca5e575bb138c4bbb1`, including admitted PR1256.
Recovery: `integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json`.

The existing matrix companion `pond_mass` is the sole persistent chemical surface
store. Richards owns pond water depth. PR1256 already owns reconstruction,
opaque restart and explicitly enabled native V2 storage of surface mass. Those
production bytes are inherited unchanged. No parallel committed chemical owner
or alternative native codec is introduced. The leaf state is temporary process
scratch initialized from accepted matrix mass and the first hydraulic depth;
only the final matrix companion is published.

An accepted substep supplies exact time, actual begin/end pond storage (cm) and
actual downward top flux (cm/day). The new availability flag cannot be inferred
from default zero fields. Require `pond_end - pond_begin =
(rain + irrigation + qtop) * dt` within the existing absolute 1e-10 cm water budget.
Gross rain and irrigation rates are explicit forcing, not inferred from net qtop.
This bounded route excludes runoff, evaporation, runon and macropores. It cannot
silently consume their net balance as if it were gross solute-bearing input.

Reuse immutable B1.11 `SWAP/solute.f90` lines346..355 and
`evaluate_b111_pond_solute_exchange`. Concentrations are mg/cm3 and mass mg/cm2.
At qtop >= -1e-6 cm/day the historical cutoff retains surface mass. Prescribed
dry deposition (mg/cm2/day) adds mass before mixing and is separately booked as
external input, including when surface water is zero. This explicit new forcing
contract is not a claim of a legacy deposition formula or parser. Upward top flow
is excluded. Inputs are finite and bounded before arithmetic and comparisons.

Each consumed trace is tentative until its last step, whole soil-plus-surface
mass balance and reconstruction pass. Chemical rejection publishes neither an
accepted prefix nor hydraulic state. Clock continuity prevents replay. Restart
uses exactly the existing PR1256 V2 opt-in, retaining its V1 fail-closed defaults;
no mass may be removed into an unpersisted sidecar.

The shared backend extension changes observation metadata only. Begin/end pond
storage comes directly from the real request and converged candidate. Solver
equations, fluxes, physical state and acceptance policy are unchanged. Select
real O0/O2 process/literal-source, dual balance, rejection/retry/replay and
fresh-process native tests. Execute the entire original surface driver on the
current providers and require original V1 native and endpoint byte identity.
Keep source-bound immutable incumbent admission and negative evidence controls.
No full moving or unrelated solver rerun is selected merely for new valid inputs.

Actual physical fixtures cover fixed positive water depth with changing surface
mass, and dry deposition followed by rain-driven remobilization at zero depth.
The leaf also exercises varying depth. A general dynamically varying pond level
in the actual application, surface evaporation/runoff, surface age, simultaneous
N/age companions and default activation remain open. Aquifer stays rejected.
There is no full historical pond-capability or coverage-count promotion.

The earlier independent-owner prototype, all source, source-bound O0/O2 output,
failed incumbent-closure attempt and exact execution bundle remain preserved in
`MC_SOL01_POND_PRE1256_20261016.tar.xz.b64`. It is historical evidence for87bc,
not admission or qualification of the recomposed current1256 source. A later
eligibility attempt rejected dirty Python cache files before scientific review;
no failed control invocation is called PASS.
