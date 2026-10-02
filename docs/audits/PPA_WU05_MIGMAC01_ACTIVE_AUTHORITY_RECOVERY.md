# PPA-WU05-MIGMAC01 active authority recovery
Date: 2026-10-02
Status: BLOCKED_SOURCE_BACKED_ACTIVE_INTERVAL_NOT_ESTABLISHED

## Pinned reconciliation
Research head: 6947aa40939892f4ed09b6dfea44159328175021.
Canonical head: 828df126e0c0d70f5cbfae51614bfc3b53e832a4.
Canonical delta from preregistered 6a2d948e includes changes to
src/runtime/mod_fmr_serialized_reference_backend.f90. Therefore current-canonical
preservation is not inherited wholesale from the earlier MIGMAC01 run.
No production code is changed by this recovery.

## Diagnostic run read
Run 36932614330, job 110605363246, postimage e84ac3f55cc1805e5c10ca70043a8502fa0c19e0:
MIGMAC01_ACTIVE_ACCEPTED|H2=-66.629577345080222|COVERED=0.0000000000000000|STATUS=2.
The operator and PERCH20 transaction-composition steps passed; the active assertion failed.
Restart preservation was skipped after that failure. The log does not expose the active
fixture's numerical internal/macro residuals before its assertion. No residual pass is claimed.
The B1.11 activation condition is false at the final head. This observation explains zero
covered input; it does not independently prove all composition paths correct.

## Official case inventory
Recovered existing SWAP_4.3.1.zip from the project, without requesting another upload.
Archive SHA256: 76a79498423ee612a7861efb564b10c4360a4f648396eefcf8e9011919a66039.
This hash identifies the inspected case distribution, not the canonical B0 source archive.

| Case path | SWMACRO | Z_TP | Input SHA256 |
| --- | --- | --- | --- |
| cases/1.hupselbrook/swap.swp | 0 | absent | a54d110efa0cf003b23537109a3aea83f17f941fa875a5de6aefd65291405b5b |
| cases/2.grassgrowth/swap.swp | 0 | absent | 2f21cc9d269b435a9b20d1072bce6433b945946cd72ebebd5285c67acb2ab196 |
| cases/3.macroporeflow/swap.swp | 1 | 0.0 | c87ef0f8561f90277a2ae22f74fd12e050e4cafb26cb3b475768a737c76c059b |
| cases/4.salinitystress/tools/template/swap.swp | 0 | absent | 923c1527d074f154db16c844d7094c15886257e8190864e57d0b41baca645486 |

The active official Andelst case explicitly configures Z_TP=0 at line 332.
It cannot furnish an unmodified covered-top interval. Other supplied cases disable macropores.
Moving its top below the surface would create a new controlled reference experiment, not an
interval extracted from this official configuration.

## Recovered Andelst state
Existing andelst_perched_authority.csv was retrieved and inspected:
SHA256 beb34e72b310fc1c8bac01404b9b821751aae4b0d7deb903955995e56fa60a97; 112 nodes.
Its columns are node, z_cm, h_start_cm, theta_start, h_end_cm, theta_end, theta_s,
theta_r, qrot_cm_d, qssdi_cm_d, qdra_cm_d, frarmtrx.
Node 2 starts at -0.53552933724089669 cm and ends at -0.72528471093657798 cm;
its matrix fraction is 0.96. It contains no IcTopMp, complete macropore pre/post state,
covered transfer or accepted-step time metadata. It cannot establish G2.
The repository PERCH19 source_h snapshot has positive shallow heads, but its explicit
macropore initialization uses top_node=1. Positive heads alone do not establish covered
geometry or covered source ownership.

Library title searches found the existing Andelst CSV and historical macropore source,
state contracts and patches. Content searches for covering-layer, IcTopMp and Z_TP
returned source/patch or parameter-inventory evidence, not a complete accepted covered
interval. This is a bounded search result, not a claim that no such case exists anywhere.

## Decision and next exact evidence
Under the MIGMAC01 preregistration stop rule, G2 remains blocked. The synthetic fixture
must not be tuned into a qualification fixture. No candidate, canonical admission,
closeout or migration-gap removal is claimed. M2 remains separate.

To reopen G2, recover an actual covered-top reference case, or explicitly preregister
a controlled B1.11 covering-layer reference experiment with fixed scientific rationale
before examining its outputs. Capture IcTopMp, full matrix/macropore accepted origin,
immutable geometry/hydraulics, forcing, time/dt, source-reduction history, potential and
limited covered amounts, accepted state and unrounded mass terms. A modified Andelst
experiment must be labeled as modified; the existing PERCH source heads cannot silently
be reclassified as an official covered interval.

Only after that authority exists: replay the active SWAP5 route, prove all twelve
acceptance observations, reconcile the shared backend against current canonical, run
the declared preservation gates on the persisted postimage, then assess admission.
