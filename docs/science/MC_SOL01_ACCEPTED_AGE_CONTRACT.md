# MC-SOL01 accepted matrix water age

Proposed bounded successor to canonical9ed5efc773b28f44b16b8922730b3fd9b8892b60.
PR1232 independently owns the reactive N day; this unit does not duplicate it.
Selective donor1117 is b6b894513fcdcf66e94824742c129616ddd7aed1.

The existing B1.11 age substep is the process authority. Independent tests extract
the unchanged age loop from SWAP/solute.f90 lines939..987, source SHA256
2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2.
The historical in-place node sweep and its numerical dispersion remain literal.
Age amount is water depth times days, cm day per node; concentration is days.
It is not chemical mass. Production is the trapezoidal accepted water volume
times elapsed days. Root extraction removes local age without a chemical TSCF.
Signed lateral drainage and lower inflow use the historical Agedrain boundary.
Internal transfers cancel; production plus external age input minus exports must
equal the change in total age amount. No correction/clipping can hide overdraw.

An additive private age owner consumes only the existing actual accepted water
trace. It verifies time, source attribution, every vertical interface and water
closure. The joint application keeps both candidate water and age tentative until
the whole interval succeeds. Rejection, retry and rollback retain committed state.
Opaque and bounded same-platform disk restart retain age amount, water endpoints,
clock, revision, immutable geometry/dispersion/boundary parameters and actual
Richards continuation. Kernel state and existing matrix/mineral layouts are unchanged.

Bounded profile: zero top exchange and pond, no rain/irrigation, macro/SSDI,
aquifer, snow, thermal coupling, chemical or crop N coupling. Prescribed age of
external inflow is not a new aquifer store. WOFOST81 is untouched. This implements
one age route, not all SW431-AGE-TRACER surface/output semantics.

Affected invariants3,4,7,9,13,21,22,23,27,29: explicit optional companion state,
read-only accepted water, atomic commit, generic intervals and hard age balance.

Test selection: first the two-provider real process closure with literal oracle,
then real Richards composition, complete balance, donor directions, invalid input,
multi-window, rejected-prefix atomicity, smaller retry and fresh-process restart.
O0/O2 run separately and retain raw costs. Composition is expected about two minutes
from the existing matrix qualification, full moving about30minutes. Broad preservation
is selected only if the stable admission source guard must change, under existing
F-CI owner authority. Highest low-air remains NOT_SELECTED_POLICY. No test PASS or
canonical admission is claimed at this initial contract checkpoint.

Later stable admission boundary: complete local moving **PASS**, execution
f5de4a6a239a2af904a2b5b5b3c8c779465ad5d4,1436.858922s, all6250tracked inputs
unchanged, FCI_RESUME_MODE=OFF. Exact reactive-peer coexistence retains both
actual full moving executions, including reactive1423.361363s/6258inputs;
no combined full execution or new hosted qualification is claimed. The final
admission receipt is MC_SOL01_ACCEPTED_AGE_STATUS.json. All full-capability
dispositions remain unchanged.

## Executed physical qualification

Primary execution1e54e292ca412fd657f95e0844fb898bbc9a981f and strengthened final driver
1d5b371a9c5de7d5e0746fa4797c267e920bfdaf are persisted in the
source-bound capsule recorded in MC_SOL01_ACCEPTED_AGE_STATUS.json. O0/O2 pass
with byte-identical opaque/disk/fresh-process continuation endpoints. The literal
loop runs150 independently specified steps, then every actual internally accepted
Richards substep in two windows with root extraction, signed drains and lower
outflow followed by inflow. Fifteen malformed/extreme carrier controls include a rejected
last substep, so no accepted prefix can leak into committed age. A high-diffusion
numerical overdraw rejects the otherwise successful water trial; smaller interval
retry succeeds. Ten damaged disk payloads per optimization include valid-CRC
semantic corruptions. Wrong owner IDs and same-ID changed parameters reject.

The standalone process has two production providers:1.51245s compile,0.07834s link,
0.00351s native across O0/O2. Actual physical composition has232 providers and
costs107.90415s compile,0.18807s link,7.58436s native. The larger closure is required
by real private Richards accepted-state, transaction and temporal restart owners;
it is not the daily development closure. All failed development and early
admission attempts are retained separately; only stable terminal execution is
qualification. No persistent object cache is introduced.

The age amount domain is0..1e12cm day per node, initial age0..1e6days, positive
water1e-8..1, node thickness1e-4..1e4cm and at most4096nodes. Later accepted ageing
may exceed the initial age bound; restart restores the bounded amount rather
than incorrectly reapplying the initial concentration ceiling. Intervals are
1e-100..1000days per substep; clocks bounded by1e8days, revisions by
100000000. Physical nonnegativity is enforced by rejecting overdraw, never
clipping. This does not assert unconditional stability of the historical explicit
sweep. Same-platform binary layout and CRC are bounded continuation
proof, not a portable cross-compiler ABI.

The initial9ed5efc7 reconciliation retained all477 matrix/mineral science inputs.
Canonical then admitted reactive N via PR1232 at26ddf94e. The current coexistence
binds all236 age inputs, all253 reactive primary inputs and16 reactive edge inputs;
227 shared hashes are identical and no peer source delta enters the age closure.
All240 matrix scientific inputs remain exact. The two old mineral implementation
changes have independent qualified original-profile preservation in the reactive
owner, rather than falsely inheriting all237 old mineral input hashes.

The strengthened maximum-finite source test caused SIGFPE in the unguarded work-unit
preimage and controlled rejection without mutation in the final production route.
This is a repaired candidate validation gap, not a historical source defect. Final
leaf-only qualification reused968 hash-verified unchanged object/module/executable
artifacts inside this live execution, with unchanged sources, compiler and environment,
separate O0/O2, and fresh execution of every required native case. It costs5.65298s
compile,0.20241s link,7.92848s native plus0.00380s process native. Complete endpoints
match both the cold-build endpoints and each other. The ordinary runner reproduces
this final driver from a cold build; no persistent cache is required.

The complete source/test/tool/reference eligibility delta is exact, including callers,
external procedures, immutable inputs, fixtures, build selection and default selectors.
The original CO2 assertions run in situ; original reactive/mineral assertions execute
at immutable admitted26ddf94e after whole-surface identity validation. Current29 age,
13 nonlinear and23 CO2 tests plus26 reactive negatives pass. Small real age, mineral
and reactive O0/O2 closures execute fresh on the combined tree. This is separate
optional companion coexistence, not simultaneous age/chemical/N commit or restart.

The full age moving execution remains frozen at its own persisted candidate while
this exact peer reconciliation runs independently. The two terminal full executions
must retain their own input/source identities; no combined hosted or full-run PASS
may be inferred. Highest low-air remains NOT_SELECTED_POLICY. A34.63s early dispatch
failure and a later censored partial run are retained, never preservation PASS.

## Remaining production blocks

| Family | Qualified bounded route and remaining work |
| --- | --- |
| Pure processes | Age production and literal advective/dispersive sweep now execute through real Fortran. |
| Reactions | Matrix decay/nonlinear partition are already admitted; N reactions are admitted by PR1232 at26ddf94e. |
| Transport and balance | Age root/drain/bottom route is locally qualified; complete capability disposition remains ACTIVE_MIGRATION. |
| Surface and aquifer | Accepted pond/rain/irrigation/runoff age budget needs its own owner receipts; aquifer remains rejected, not reopened here. |
| Crop and soil | Advective age root export preserves current water ownership; crop N supply/demand and WOFOST81 integration remain separate. |
| Continuation | This route has atomic opaque/native restart; combined chemical/N/age and default/multicolumn activation remain open. |

The next NUT block is explicit crop N supply/demand over the admitted reactive pools,
preserving WOFOST81 fixation. Prescribed reaction temperature is not accepted heat
coupling. The next SOL block is accepted surface/pond exchange, using real surface water
receipts and a complete soil-plus-pond budget. Wider Freundlich0..10 semantics,
dynamic thermal coupling and default application follow their own dependencies.
