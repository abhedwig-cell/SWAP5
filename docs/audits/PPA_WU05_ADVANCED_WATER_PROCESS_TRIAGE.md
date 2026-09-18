# PPA-WU05 Advanced water-process triage

Date: 2026-09-18

Status: `DEPENDENCY_GRAPH_FROZEN / IMPLEMENTATION_HELD`

Canonical reconcile base: `integration/f-ci-canonical@ff56b8c1565821cf1d23f980e754905d8920371e`.

## Purpose

PPA-WU05 separates three advanced water-process families that were previously
grouped mainly by absence from the current production envelope:

1. macropore flow;
2. frost / temperature-dependent hydraulic restrictions;
3. advanced root-water uptake and stress beyond the admitted drought-only
   macro-Feddes route.

The workunit is triage-only. It changes no production or reference source. Its
output is an evidence-backed dependency graph, acceptance boundaries and a
sequenced first migration target.

## Corrected B1.11 source authority

The authority is SWAP 4.3.1 corrected B1.11, member-manifest SHA-256

`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

A complete patch-target audit shows only two B1 repairs directly touch the
advanced-water source family:

- SWAP-001 modifies `macropore.f90`;
- SWAP-007 modifies `oxygenstress.f90`.

The corrected authorities are therefore:

- macropore B0 `1cb5a2ce...d2187d0b`, corrected B1
  `f44049c5...eed7bf106f`;
- oxygenstress B0 `2db206bf...e5735`, corrected B1
  `8c0c27c7...11a87`.

SWAP-001 is an array-shape/initialisation correctness repair. It is not a
physics change. A future macropore migration must use the corrected B1 source,
not reproduce the B0 non-conformable assignment.

SWAP-007 is a Newton quotient representability guard. It routes pathological
tiny-derivative cases into the already existing oxygen-stress restart mechanism
instead of overflowing. It is not authority to simplify the oxygen model or to
ignore its continuation state.

The following advanced-water members are untouched by all B1 patches and
therefore retain their B0 file identity in B1.11:

- `macrorate.f90`: `537a8486...7d4dcc7`;
- `macroporeoutput.f90`: `39a0497c...5a8b0a`;
- `rootextraction.f90`: `8b7b2846...09af78cd5`;
- `RWU_micro.f90`: `cac3d723...b90477`;
- `solute.f90`: `2fc85920...80e7a2`;
- `frozencond.f90`: `edd16b08...b909cf`;
- `temperature.f90`: `92c39d29...0bd338`.

## Current production anchors

### Root-water sink owner

Current canonical root uptake is deliberately narrow. F-CI31 admits a stateless
macro-Feddes drought-only route that consumes potential transpiration,
current root distribution and a clean committed pressure-head view and produces
one nodewise `root_extraction_sink`.

That sink remains the single physical root-water mass owner.

F-CI31 explicitly does not claim oxygen, salinity, frost, compensation,
MICRO/Jong-van-Lier, macropore uptake or SWKIMPL=1 dynamic root-sink
reevaluation.

This is an important design constraint for WU05: advanced stressors should be
composed into that root-water sink authority where source physics permits it.
They must not create competing mass owners simply because the legacy module
boundary was monolithic.

### Sensible soil-temperature owner

F-CI43/F-CI45 admit sensible one-dimensional soil heat conduction with a
persistent node-temperature profile.

They explicitly exclude:

- frost;
- phase change;
- latent heat;
- snow + soil-temperature combined production profile;
- a new combined water + thermal timestep-acceptance policy.

Frost cannot therefore be introduced by relabelling the existing sensible heat
route.

### Restart topology

The current FMR restart contract is fail-closed and optional-state-layout
specific. New advanced physical state must obtain a declared topology and
reconstruction contract. Payload presence is not sufficient authority.

## Macropore: physical state versus execution scratch

Macropore is the largest state/mass/restart surface in this triage, but it also
has the strongest recovered architecture evidence.

### Corrected legacy authority

SWAP-001 is mandatory authority for `macropore.f90`. The corrected shape
semantics are part of the reference precondition. No future candidate may use
legacy-bug compatibility as a reason to restore the B0 assignment.

### Recovered physical-state evidence

Historical S12o evidence identified seven fields as committed macropore
physical/history state:

- `ICpBtDm`;
- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`;
- `VlMpDmCp`;
- `WaUnMpDmCp`;
- `VlMpDyCp`.

The active-sized layout was strongly qualified against a corrected fixed-array
reference and demonstrated large memory reduction with output preservation.
That is prior evidence, not current SWAP5 production admission.

The most important warning from that evidence is transaction-related:
`SorpDmCp` and `ThtSrpRefDmCp` were trial-mutable while the then-current
rollback path did not restore all such fields.

A SWAP5 migration must therefore source-trace **every trial-mutable macropore
field**, not merely copy the seven-field historical state object and assume the
transaction is complete.

### Recovered scratch evidence

Two historical lines support a clean execution-scratch boundary:

- S12r recovered a broad active-sized MACRORATE/SATFLOW/ABSORPTION/RAPIDDRAIN
  scratch design, but did not retain enough executable qualification for
  admission;
- A23au independently showed that five hidden SATFLOW/ABSORPTION `SAVE`
  arrays can be explicit worker/job scratch, with local reentrancy and strong
  memory reduction while preserving qualified results.

The target rule is therefore strong even though the historical patches are not
portable production authority:

**recomputable rate workspace is worker/job scratch, not committed state and not
restart payload.**

### Mass and transaction requirements

Macropore migration must distinguish:

- external inputs/outputs crossing the complete soil column;
- matrix-to-macropore and macropore-to-matrix internal transfers;
- macropore storage change;
- drainage/root interactions.

Internal transfers must not be booked as net column mass losses or gains.
Accepted external fluxes must be booked exactly once.

Every trial-mutable physical/history field must be restored on rejection.
Scratch may be discarded or reused independently of rollback.

Parallel MultiSWAP requires per-column disjoint physical state and worker-local
scratch. Legacy module-global views may not become hidden shared state.

## Frost: split the legacy hydraulic modifier from new thermodynamics

The earlier envelope entry bundled “frost, phase change and hydraulic feedback”
too broadly.

F-PM07 source analysis shows that the legacy decomposition is more specific:

- Soil Temperature owns/materializes temperature.
- The frost route consumes temperature and derives hydraulic restrictions,
  including `rfcp` and frost geometry such as `nodfrostbot`,
  `zfrosttop` and `zfrostbot`.
- Those frost fields were not found in restart serialization and are
  reconstructible from committed temperature, parameters and geometry.
- Frost then affects hydraulic conductivity, drainage and bottom-flux behavior.
- During a reference-compatible water solve, the temperature view is lagged:
  the water trial consumes the previously materialized/committed temperature;
  temperature advances after an accepted water solve.

This supports a future **Legacy Frost Hydraulic Modifier** process boundary.

It does **not** establish authority for an explicit ice-content state, latent
heat or a new thermodynamic phase-change formulation. Those would be new-physics
work and must not be smuggled into a “frost migration”.

The legacy frost + macropore incompatibility is also a physical-option
constraint and remains fail-closed until separately qualified.

## Advanced root uptake is not one process family

F-PM05 had already shown that the admitted drought-only Feddes seam is the
smallest state-free root process. WU05 decomposes the held advanced routes.

### Oxygen stress

The corrected B1 oxygen source includes SWAP-007.

F-PM05 identifies oxygen/root-development memory when oxygen/root-growth options
are active. The exact minimal continuation layout has not yet been source-bound
into a typed contract.

Oxygen should therefore be treated as a prospective stress/reduction provider
around the existing root-water mass owner **only if** a dedicated source review
proves that separation. It is not yet safe to model it as a stateless factor.

It also consumes a temperature-related process view according to the F-PM07
consumer inventory.

### Salinity stress

Salinity depends on solute/osmotic state. SWAP5 does not yet have the required
admitted typed solute-state owner for this composition. Salinity root stress is
therefore dependency-blocked rather than merely unimplemented.

### Frost root stress

This must wait for an admitted legacy frost view. It may then reduce the root
sink through the existing root owner. It cannot independently introduce frost
state.

### Compensated root uptake

This may be structurally narrower than oxygen, but exact redistribution order,
state/timing and interaction with nodewise reduction must first be source-bound.
Current authority is insufficient for a production candidate.

### Root-development feedback

Stress-dependent root extension belongs to crop/root-development continuation,
not to the root-water mass owner. Any accepted feedback must be coordinated with
the crop transaction.

### MICRO / Jong-van-Lier

F-PM05 identifies persistent state when microscopic uptake is enabled.
MICRO/Jong-van-Lier is an alternative uptake model, not just another algebraic
stress multiplier. It requires its own model-state and qualification program.

### Macropore-related uptake

This is downstream of a macropore state/flux owner. It cannot be admitted ahead
of the macropore capability it consumes.

### SWKIMPL=1 dynamic root-sink reevaluation

This is numerical coupling semantics, not another biological stress option. It
requires an explicit nonlinear-solver iteration contract and, where relevant,
root-response sensitivity/derivative coverage. It belongs in a separate
numerical workunit.

## Dependency graph

The primary ordering is:

```text
sensible temperature
        |
        v
legacy frost hydraulic modifier
        |
        +----------------------> frost root stress
        |
        +----------------------> drainage/bottom hydraulic modifiers

typed solute owner ------------> salinity root stress

macropore state + mass owner
        |
        +----------------------> full macropore rate/flow runtime
        |
        +----------------------> macropore-related root uptake
        |
        +----------------------> parallel macropore execution

crop/root-development owner ---> root-growth feedback

existing root-water sink owner <--- oxygen / salinity / frost / compensation
                                   modifiers where source separation permits
```

Every advanced root route must converge back to one accepted nodewise root-water
sink and one mass-booking path.

## Prioritization

The ranking uses:

- use relevance;
- dependency unblocking;
- scientific risk;
- architecture maturity;
- strength of reference/prior evidence;
- qualification cost.

### 1. PPA-WU05-A: Macropore state and transaction foundation

This is the first advanced-water migration target.

It is **not** full macropore production admission.

The bounded scope is:

- source-trace all committed/history and trial-mutable macropore fields from
  corrected B1.11;
- define an active-sized typed state;
- define complete candidate/rollback semantics;
- define restart payload and optional-state topology;
- separate all recomputable MACRORATE/helper workspace into worker scratch;
- define mass-transfer ownership and exactly-once external booking;
- prove disjoint per-column state and worker scratch for future MultiSWAP.

Why first:

- high relevance for structured soils;
- unblocks full macropore flow, macropore-related root uptake and future parallel
  macropore execution;
- strongest recovered ownership/memory evidence;
- can be qualified as a state/transaction foundation without altering equations;
- directly closes the historical rollback weakness.

### 2. PPA-WU05-B: Legacy frost hydraulic modifier boundary

Recover and qualify the temperature-to-hydraulic/drainage/bottom modifier
contract while preserving the lagged legacy ordering.

No latent-heat or new phase-change claim.

### 3. PPA-WU05-C: Oxygen state and reduction-seam review

Recover exact minimal oxygen/root-development continuation state and decide
whether oxygen can be cleanly composed around the existing root-water sink
owner.

This is review-first, not implementation-first.

### Later slices

- compensated root uptake source trace;
- salinity after solute-state admission;
- frost root stress after frost-view admission;
- MICRO/Jong-van-Lier after independent model-state authority;
- SWKIMPL=1 under a separate nonlinear numerical program;
- explicit thermodynamic phase change only under explicit new-physics authority.

## Safe parallelism

The following review work is ownership-disjoint:

- PPA-WU05-A macropore state lifecycle trace and PPA-WU05-B frost modifier
  source trace;
- oxygen minimal-state review and compensated-uptake source trace;
- solute-owner work and macropore-owner work.

The following must be serialized:

- macropore state foundation before full macropore production;
- macropore production owner before macropore-related root uptake;
- frost modifier before frost root stress;
- solute state before salinity root stress;
- oxygen minimal state before oxygen candidate;
- any advanced root modifier before a final single-sink mass-booking admission.

## Acceptance criteria for PPA-WU05-A

A future PPA-WU05-A candidate must at minimum prove:

1. exact corrected B1.11 source-field lifecycle inventory;
2. all trial-mutable physical/history fields covered by rollback;
3. no worker scratch in restart state;
4. split-run restart identity;
5. A/B/A deterministic state replay;
6. failed-then-accepted retry equality from the same checkpoint;
7. exact internal-transfer versus external-mass classification;
8. hard whole-column mass closure;
9. active-sized state with no compile-time-max committed arrays;
10. per-column state disjointness and worker-local scratch;
11. preservation of non-macropore current production profiles;
12. no macropore physics equation change.

Only after that foundation is admitted may a separate workunit expose active
macropore flow in the normal production runtime.

## Triage verdict

`DEPENDENCY_GRAPH_FROZEN_FIRST_TARGET_MACROPORE_STATE_TRANSACTION_FOUNDATION`

PPA-WU05 does not admit macropore, frost or advanced root-stress physics. It
turns a broad “advanced water processes” backlog into independently owned,
dependency-aware migration slices and selects a first bounded target without
overstating current production capability.
