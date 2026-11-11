# External daily acceptance for the consolidated hybrid route

Proposed application adapter on canonical30026511e8d03f6c77bc30377d60a65259afb2fc.
The shared Groundwater Coupling v1 / restricted-pc1 authorities already qualify
head/datum, whole-window exchange, transaction lineage and accepted publication.
They are held fixed. The existing hybrid DailyHost.step commits immediately and
has no external accept/discard gate. This is the concrete uncovered seam.

The RT-TX application adapter owns one external coupling identity, accepted day,
revision and immutable schema3 native/auxiliary checkpoint. Every prepare creates
a private ordinary DailyHost from that exact accepted origin; cold day0 uses the
unchanged original initialization. Original forcing remains fixed. A local kernel
acceptance is only an external proposal; it does not publish in the externally
accepted output directory. The public proposal explicitly says committed=False.
A caller may inspect whole-window water/solute/uptake accounting and signed bottom
exchange, then accept or discard. No new groundwater backend, forcing feedback,
MODFLOW expansion or process formulation is admitted.

Accept verifies origin and proposal bytes again, uses the EXISTING durable C
publisher and schema3 codec, then advances the external accepted clock/revision.
Discard only removes the live proposal reference; accepted files/clock/revision
remain unchanged. A retry starts fresh native and kernel processes at the same
accepted origin. Private diagnostic files remain retained but are never exposed as
accepted coupling state. One live proposal per owner; foreign/stale/duplicate
proposals refuse. Distinct owners use exclusive new output directories.

Restart binding adds adapter source SHA, explicit coupling identity and original
forcing policy to the original build/input identity. Receipt lineage binds parent
checkpoint SHA, accepted origin day/revision and exact one-day1900 clock window.
Native checkpoint adoption is explicit; ordinary recovery rejects another coupling
identity or source/build/project. There is no new native codec or general framework.
Failures from durable publication poison the live owner: replacement may already
have happened. Never pretend rollback after failed directory sync. Recovery must
explicitly inspect and verify the disk checkpoint; no subsequent prepare is allowed.

Bottom exchange is a whole-window amount in cm, positive OUT of SWAP. Its mean
is amount*0.01/(duration_day*86400) m/s; volume is amount*0.01*area_m2 m3.
This is the existing groundwater interface convention, NOT inward native qbot or
an instantaneous terminal flux. No pressure head is relabelled as hydraulic head.
The original boundary modes (Andelst3, Grass1, Hupsel6) remain unchanged. Original
forcing and profile maps retain their independently qualified limitations.

Allowed changed interfaces: new application-only Python adapter and direct real
owner qualifier. Held fixed: DailyHost, all donor/kernel/physics sources, original
inputs, tolerances, existing Fortran coupling contracts and native/default routes.
No shared scientific denominator or previous full-project acceptance is widened.

Acceptance selected in integration/f-ci/HYBRID_DAILY_COUPLING_20261111.json:
real unchanged original O2 donors with both qualified O0/O2 kernels, all3projects;
prepare/discard/exact same-origin retry; accepted payloads and fresh external disk
recovery; peer isolation and foreign/stale/busy/mutated-state refusals; actual
post-replacement publication-failure recovery; correct units/windows; no external
publication before accept. Reuse original admitted binaries only after exact
source/generated/executable/input checks. No full original model or reference rerun.
Windows and Ubuntu26 actual execution plus independent retained proof auditing
precede canonical admission. Total native-feedback cap180s, expected120sWindows/
30sLinux including existing C publisher compilation; native CPU costs UNKNOWN.

The measured successor loads the existing stateless C publisher once per external
owner, lazily on its first proposal, and binds each private host before first
advance. It never changes DailyHost or recompiles C per daily proposal. Same-
platform prior/native payloads and ambiguous publication semantics must remain exact.
