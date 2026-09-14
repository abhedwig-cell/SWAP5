# F-VQ86 independent F-GC24 qualification

This qualification branch starts exactly from `F-GC24@194487ec18374ef6097e3dd687038e326f818be8`.

The owner workflow is replayed only as prerequisite/postimage-preservation evidence. Independent evidence is produced by `test_fvq86_fgc24_independent.f90`, which supplies a separate adversarial sequence over the pinned owner production postimage and pinned dummy backend fixtures.

The independent oracle covers wrapper-level prepared-reservation quiescence, layout and cross-carrier provenance rejection before backend publication, adapter-rejection local atomicity, successful committed restore exactly once, non-resurrection of transient candidate state, exact interface mass after restore, replay rejection into a non-fresh target, and fail-hard handling of a successful adapter that violates its published provenance postcondition.

No production/reference source is modified by F-VQ86. Passing this qualification is evidence for a later separate F-CI admission review; it is not canonical admission and not a whole groundwater-coupling-v1 completion claim.
