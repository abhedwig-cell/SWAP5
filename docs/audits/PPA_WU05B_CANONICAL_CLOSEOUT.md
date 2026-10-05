# PPA-WU05B bounded frost hydraulic admission

Date: 2026-10-05. Status: canonically admitted within the bounded hydraulic scope.

PR #1018 was admitted as `5272ac9192ec1065dbe2432f73d1f1b4394437e0`.
Central reconciliation confirmed the unchanged canonical parent
`c7f9a7b85ef937347893f2fbd1653b4c00a724af` and the three declared production
changes: frost effect, constitutive decorator and serialized backend binding.
No shared mass, temperature, transaction or restart ownership was replaced.

## Qualified production behavior

The B1.11 temperature profile determines a trial-local hydraulic reduction factor.
K and dK/dh use the same factor, including the source residual-floor behavior.
Water content, capacity and storage remain with the existing constitutive owner.
The temperature profile remains with the admitted restricted sensible-temperature
owner and its committed restart layout. Rejected trials cannot advance either owner.

The admitted route is serialized Reference Richards with active restricted sensible
temperature, prescribed bottom mode 2 and exactly zero bottom flux. The runtime
infiltration oracle supplies a bounded prescribed top flux. Unsupported combinations
reject before execution. This is an empirical legacy hydraulic modifier, not an
ice-storage or latent-heat model and not field validation of general frozen-soil flow.

## Exact qualification and preservation

| Authority | Identity |
| --- | --- |
| Qualified PR head | `3a32d45365530f364689cd0416f89b561956e5f0` |
| Qualified PR merge | `9d516e45911d4ae4b4e527ad19405bb8e14cac03` |
| Qualified and admitted tree | `554305d9a03827246a2ca57817b13fe6c11a5674` |
| Dedicated full qualification | Run `37324712595`, job `111812371027`, SUCCESS |
| Canonical admission | PR #1018, merge `5272ac9192ec1065dbe2432f73d1f1b4394437e0` |

The dedicated job passed effect/provider/runtime/restart/retry at O0 and O2,
the complete unchanged F-CI moving-canonical preservation command, documentation,
strict MkDocs, JSON and whitespace checks. The merge has exactly the qualified tree.
The source SHA256 manifest is in `integration/audits/PPA_WU05B_CANONICAL_ADMISSION.json`.

Runtime oracles cover unfrozen, onset, partial and strong frost, warming and a
freeze-thaw cycle. The partial-frost infiltration case commits after 20 retries and
eight accepted substeps with residual `-2.140518e-16 cm` under the unchanged
`1e-12 cm` hard mass gate. Its accepted hydraulic and thermal states match direct
smaller-step replay within the explicit recorded limits. The actual backend restart
exports committed state and restores into an empty registry, preserving layout,
lineage, revision, time, temperature and recomputed frost factors.

Preservation includes the RossFast 216-case O0/O2 matrix, Ross12 production wiring,
adapter/selection semantics, paired solver seam and current thermal/Richards owners.
Local F-KT22 canonical/kernel boundary, production compile and production runtime
also pass at O0/O2 on the same merge-source tree. Runner repairs only add required
transitive module dependencies. The explicit frost moving-merge route checks current
transaction and solver-contract bytes against canonical HEAD^1; historical routes
retain their fixed authority pins.

## Deliberate exclusions and negative findings

- Frost root stress and compensation remain excluded. The binary legacy TSOIL < 0 C
  switch and ALPHACRIT interaction were rejected in their current form for this
  migration; any replacement requires its own biological and sink-chain contract.
- FrozenBounds is rejected in its legacy form for this bounded migration. Its drainage
  and boundary heuristics require separate owner-specific qualification or replacement.
- Snow, macropores, drainage response, nonzero bottom flux and general surface-water
  or groundwater coupling are not admitted in combination with frost.
- Temporal-indicator history, trajectory direction and sensible boundary carriers
  remain excluded for frost-enabled execution.
- Ice-water partition, latent heat and thermodynamic phase-change physics are new
  scope, not reconstructed B1.11 hydraulic functionality.

The historical EB-I25 external-outflow fixture failure was reproduced on pristine
pre-frost canonical `9605fbb1622d96f4691117f66264f13b6dd3a47b`. It was not suppressed.
Historical frozen-source CI checks do not qualify later successor trees; this
closeout does not claim blanket CI success. Exact current preservation is established
by the dedicated full qualification job instead. No numerical tolerance was loosened.

The admitted hydraulic slice is closed. Aggregate frost migration and excluded
legacy combinations are not declared complete. The current status, dependency graph
and central admission record retain that distinction.
