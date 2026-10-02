# PPA-WU05-MIGMAC01 canonical-first reconciliation result

Date: 2026-10-02
Status: QUALIFIED_CANONICAL_ADMISSION_CANDIDATE
Reconcile base: 800f6a9b429ed2a392e4c3778951bb92eca042aa
Qualified reconcile head: 3743d5f693339584178ce99c3b6aea4108138dbf
Owning research candidate: cfc3a904297fbab53b07997db4e327bfc6cc15cc

The reconcile branch was created from current canonical rather than by merging
the stale research history. Non-conflicting MIGMAC01 production files were
composed directly. The three shared files were composed semantically:

- HeadCalc retains canonical LOW03 typed resistive-bottom behavior and adds the
  qualified MIGMAC01 matrix-area, stable storage increment and source short-step
  macropore policy.
- mod_soil_water_solver_contract retains LOW03 boundary resistance semantics and
  adds the matrix-area carrier and stable constitutive storage-increment API.
- mod_fmr_serialized_reference_backend retains current Bartholomeus oxygen and
  lower-boundary production code and adds MIGMAC01 matrix-area propagation,
  covering-parameter propagation, root+macropore composition, storage ownership
  and temporal scaling.

No canonical oxygen or LOW03 production authority was replaced by the older
research-branch file image.

Persisted exact-postimage evidence:

- corrected-source job:
  https://github.com/abhedwig-cell/SWAP5/actions/runs/36991961561/job/110789993201
- focused canonical backend job:
  https://github.com/abhedwig-cell/SWAP5/actions/runs/36991961511/job/110789992942

Both are SUCCESS on 3743d5f693339584178ce99c3b6aea4108138dbf.

Gates include source-backed corrected Reference O0/O2, transaction lifecycle,
A9 top input, A10 rapid drainage, PERCH20 transaction continuation and restart,
plus the A26 live-trial/backend compile gate on the combined canonical surface.

G7 remains documented as incomplete last-rate carrier attribution, not as proven
bitwise B1.11 rate parity.

This head is qualified for canonical admission review. Canonical admission and
closeout are not claimed until the PR is actually merged and the resulting
canonical SHA is verified.
