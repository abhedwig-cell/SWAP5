# PPA-WU05-B Legacy frost hydraulic boundary authority

Date: 2026-09-19

Status: `SOURCE_MATERIALIZATION_BLOCKED / REVIEW-ONLY OWNER BOUNDARIES FROZEN`

Original review base: `integration/f-ci-canonical@add4adf54be39251ccbb6b000eed01e98326fb83`.  
Live reconciliation: `integration/f-ci-canonical@e473afc2d378a2567a59cc0db1577b4c724feeb2` via two-parent checkpoint `023cc58fecd1a4f916cdbd7bf92f1f93740c54a4`; no WU05-B review-surface, production or reference overlap.

## Purpose

PPA-WU05-B is the frost authority workunit selected by the closed PPA-WU05 dependency triage. Its purpose is not to invent a new freeze-thaw model. It must recover the exact SWAP 4.3.1 B1.11 `frozencond` / `temperature` dependencies, classify frost-related state and recomputability, and freeze a clean temperature-to-hydraulic interface before any production migration.

The workunit reaches one firm scientific boundary and one firm blocker.

The firm boundary is that the legacy migration target is a **hydraulic frost modifier**, not a thermodynamic latent-heat/ice-storage model.

The blocker is that the complete byte-exact B1.11 `frozencond.f90` and `temperature.f90` source bodies are not currently materialized on the repository/project tool surface. Their exact identities are pinned, but detailed equation, state, update-order and restart claims cannot be made from hashes alone.

## Corrected-reference identity

The corrected reference is B1.11, member manifest:

`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`

The relevant files are unchanged from B0 through B1.11:

```text
SWAP/frozencond.f90
edd16b08ff238ee41d264d1c4870726f1232fb1143c1340f2dc21f94a3b909cf

SWAP/temperature.f90
92c39d296f41a60cfe3b66f8d1886ea938a53b4e0ea49e7ae1a23dd9680bd338
```

No admitted B1 patch changes either file.

That proves source identity and provenance. It does **not** prove the detailed state topology without source materialization.

## Existing SWAP5 thermal authority

Current canonical already contains a restricted sensible-soil-temperature owner.

That owner is authoritative for:

- an optional committed temperature profile;
- read-only hydraulic water-content views used by the sensible heat solve;
- its own thermal workspace;
- separate energy-closure diagnostics in its restricted profile.

Its admission explicitly excludes:

- frost;
- latent heat;
- phase change;
- snow plus soil-temperature composition;
- a new combined water-plus-thermal timestep acceptance policy.

PPA-WU05-B preserves those holds.

## Legacy target versus new physics

The migration boundary is:

```text
legacy B1.11 frost
    = temperature-dependent hydraulic frost effect
    != explicit thermodynamic freeze-thaw model
```

The legacy migration authority does not establish an explicit ice-water storage state, latent heat of freezing/thawing, or a closed snow-soil freeze-thaw energy budget.

Any future introduction of those quantities is model development and requires separate scientific authority. Under PPA-WU05 sequencing it belongs to the explicit new-physics phase-change track, not to a claim of byte-equivalent legacy frost migration.

## Hydraulic ownership

The Richards/hydraulic owner remains authoritative for:

- pressure head;
- water content;
- conductivity;
- constitutive derivatives;
- Jacobian assembly;
- accepted water state and mass.

A frost process must not acquire HeadCalc/Newton/Jacobian ownership.

A later typed legacy-frost route may consume the committed/current temperature view and whatever hydraulic/configuration views the exact source trace proves. It may publish an explicit frost-effect result. The exact DTO fields, dimensions and update timing remain intentionally unfrozen.

## K and dK/dh consistency

The following invariant is already non-negotiable even before equation materialization.

If frost modifies the active hydraulic conductivity relation, the same candidate/accepted frost effect must be represented consistently in:

- K;
- dK/dh or other derivative terms of the active K relation;
- the resulting Richards Jacobian.

This preserves the SWAP-011 principle that the implicit Jacobian differentiates the actual active conductivity relation.

A hidden or stale frost factor across Newton updates, backtracking or retries is not admissible.

This is an architecture/science consistency rule. It is not an assertion about the exact legacy equation.

## Transaction and restart boundary

PPA-WU05-B does not infer whether every legacy frost field is recomputable or whether any field is true continuation state.

Until exact source trace:

```text
persistent frost state  UNKNOWN_DO_NOT_INFER
restart payload          UNKNOWN_DO_NOT_INFER
recomputable frost data  UNKNOWN_DO_NOT_INFER
```

If source trace later identifies physical continuation state, it must be:

1. read from the committed checkpoint;
2. mutated only in a trial-local candidate;
3. discarded on rejection;
4. committed atomically with the accepted water/thermal interval;
5. represented explicitly in restart state.

If the source instead proves a field is purely algebraic from accepted temperature/hydraulic state, it should remain recomputable and not be persisted merely for convenience.

## Mass and energy semantics

A hydraulic frost factor is not an independent water mass flux or storage term.

Likewise, no latent-heat energy storage is admitted here.

The workunit therefore forbids two common conflations:

- booking a conductivity-reduction factor as water storage;
- treating the existence of `frozencond` as proof of a thermodynamic phase-change model.

## Macropore, snow and root-stress composition

Legacy frost plus macropore remains fail closed until exact source and option-compatibility authority are recovered.

Snow plus frost/temperature is a separate later composition problem. The current restricted daily snow route and restricted sensible-temperature route do not together imply a freeze-thaw energy model.

Frost-related root stress remains downstream of an admitted frost view. PPA-WU05-F cannot proceed to production before such a view exists.

## Source-materialization blocker

The exact source identities are known, but the complete source bodies are not available through the current repository/project tool surface.

Recovery attempted in this program includes:

- B0 and B1.11 manifests;
- current canonical tree;
- historical Git trees;
- historical S9/S11/A23 patch evidence;
- historical constitutive-performance evidence;
- historical energy-accounting evidence;
- the previously uploaded SWAP 4.3.1 archive in the Project/Library.

The archive is locatable but current raw-byte export/materialization is blocked by the file-surface access path. Historical Git trees do not contain the full legacy frost source blobs.

This is therefore a real source-materialization blocker, not an unresolved architecture choice.

## Frozen later slices

### PPA-WU05-B1

Exact B1.11 `frozencond.f90` and `temperature.f90` materialization plus call/state census.

Status: `BLOCKED_SOURCE_MATERIALIZATION_REQUIRED`.

### PPA-WU05-B2

Typed legacy hydraulic frost-effect contract plus exact equation oracle.

Held on B1.

### PPA-WU05-B3

Reference Richards composition including K/dKdh/Jacobian consistency and atomic thermal-hydraulic transaction.

Held on B2.

### PPA-WU05-B4

Snow plus frost/temperature composition.

Held on B3 plus separate snow-energy authority.

## Non-claims

PPA-WU05-B does not claim:

- production frost;
- explicit ice content;
- latent heat;
- thermodynamic freeze-thaw closure;
- complete frost restart state;
- complete frost recomputability;
- snow/frost composition;
- frost root stress;
- macropore/frost compatibility;
- new solver or timestep policy.

## Verdict

`OWNER_AND_NONCONFLATION_BOUNDARIES_FROZEN_DETAILED_FROST_AUTHORITY_BLOCKED_ON_EXACT_SOURCE_MATERIALIZATION`

This review can be persisted as the authoritative blocker boundary. It cannot honestly satisfy the parent WU05-B exit condition for exact equation/state trace until B1 source materialization succeeds.


## Current source-materialization recheck

On 2026-09-19 the project Library surface was rechecked directly. The exact `SWAP_4.3.1(6).zip` archive and several byte-size-identical duplicates are visible, but none exposes an authorized raw-byte materialization path. The audit folder also contains hundreds of loose `.f90` artifacts; a recursive inventory found no loose `frozencond.f90` or `temperature.f90`.

This confirms that the blocker is access to the exact source bytes, not uncertainty about where the archive is stored.


## Qualification

The review-only frost authority gate passed on 2026-09-19:

- workflow `PPA-WU05-B frost authority`, run `35426148761`;
- authority job `105852323316`: PASS;
- independent-contract job `105852323606`: PASS;
- Documentation run `35426148696`: PASS;
- F-CI canonical qualification run `35426148676`: PASS, all 15 jobs successful.

This qualifies the fail-closed authority boundary and source-materialization blocker. It does not admit frost production.
