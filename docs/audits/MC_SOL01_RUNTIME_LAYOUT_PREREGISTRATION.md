# MC-SOL01 runtime state-layout preregistration

Status: PREREGISTERED_FOR_IMPLEMENTATION  
Date: 2026-10-07

## Current authority

The admitted matrix-solute route uses
`FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED` and persists only the existing
`fmr_mobile_salt_component_t` dissolved matrix mass. The restart contract
accepts that layout when `physical%salt` is ready.

MC-SOL01 introduces persistent stores that cannot be reconstructed from
dissolved concentration alone:

- sorbed matrix constituent mass;
- pond constituent mass;
- aquifer constituent mass, after the SWBR source defect is resolved;
- water-age amount and its pond history.

Treating a state carrying any of those stores as
`FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED` would be false restart identity.

## Decision for the next production slice

Add a new explicit solute layout identity for the first bounded matrix SOL01
composition. The first production slice should contain:

- existing dissolved mobile matrix mass;
- sorbed matrix mass;
- pond solute mass.

Aquifer and age are not included in that first layout because each has a
separate source/ownership issue. Aquifer is blocked on the reproduced SWBR
out-of-bounds coefficient defect. Age has its own source-production and pond
history semantics.

The existing admitted `MOBILE_DISSOLVED` and
`MOBILE_DISSOLVED_MACROPORE` layouts remain unchanged.

## State carrier

Prefer a dedicated derived transaction-state family rather than silently
adding optional fields whose presence is not encoded in template identity.

The derived SOL01 state must:

1. extend the existing B1.10/B1.11 physical state so the Richards backend can
   consume the same hydraulic fields;
2. retain the existing dissolved `salt` component;
3. own the SOL01 companion store;
4. override `clone` so rejected candidates and checkpoint replay copy all
   persistent solute stores atomically;
5. validate node count and finite/nonnegative mass before execution.

## Restart contract

`fmr_restart_state_matches_template` must fail closed:

- old mobile-dissolved template + SOL01 derived state: reject;
- SOL01 template + old base state: reject;
- SOL01 template + missing/invalid companion store: reject;
- SOL01 template + valid dissolved and companion stores: accept.

A fresh-process restart test must serialize/reconstruct the exact same physical
inventories and produce identical next accepted results.

## Transaction/mass contract

The production step must advance water first to an accepted trial trajectory,
then advance dissolved transport and SOL01 internal transfers against that same
candidate water trace. Sorption is an internal dissolved/sorbed transfer.
Pond-to-matrix exchange is an internal pond/matrix transfer. Decay is an
external constituent sink.

Rejected water/solute attempts publish none of those transfers.

Whole-system constituent closure is:

`dissolved + sorbed + pond + cumulative external outputs - cumulative external inputs`

within the qualified slice. No hidden concentration rescaling is permitted.

## Held boundaries

- No macropore solute. B1.11 explicitly rejects `SWSOLU>0` with macropores.
- No SWBR aquifer production binding until the source-defect decision is
  explicit and qualified.
- No age-tracer admission from this layout.
- Existing Maas-Hoffman/Jarvis/Walsum/SALFRO01 admissions are unchanged.
- Existing mobile-dissolved restart layout identity is unchanged.
