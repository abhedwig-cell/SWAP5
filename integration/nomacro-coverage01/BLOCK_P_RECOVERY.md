# Block P: original bounded frost/snow/history integration

Baseline canonicalfec7b4415932a9c48826e134ce76340adb855778 (O PR1694).
Owning reference: reference/swap-4.3.1/frost-corrections/FROST-GEOMETRY-01,
manifest targetd5dd195187d4581e09d19e6afdd4066c0fdb23eee84f8f87947251d2778724d2,
based on reporting-only FROST-DRAIN-01 whose exact base is the immutable431
frozencond.f90 edd16b08ff238ee41d264d1c4870726f1232fb1143c1340f2dc21f94a3b909cf.
Accepted bounded reference authority: docs/audits/PPA_WU05B7_GUARDED_REFERENCE_GEOMETRY.md.
No global B1/B0, macro, general solver, MODFLOW or unrelated migration selected.

Implement/qualify only explicit experimental SWFROST1,SWHEA1,SWCALT2,SWSNOW1,
SWHYST2,SWDIVD0,SWDRA0/1,SWMACRO0. Existing complete snow thermal and
hysteretic/microscopic original history owners are prerequisites for this first
frost integration. Original limits0/-1C; derived ordinary drainage has explicit
SWDIVD0. Keep SWDIVD1, no-heat, analytic/no-snow/no-history and surface-water frost
outside this qualification. No silent fallback. Full historical projects stay3.

Use the exact admitted complete corrected original MOD_frost source, with both
manifest links verified, distinct source-bound recipe, actual native closure
O0/O2 and original/guarded geometry/refusal diagnostics. No new frost formula,
front interpretation, clipping, shifted values, relaxed mass or numerical policy.
Uniform fully frozen/invalid fronts must refuse before physical flux assignment.
Do not silently repair or promote the retained original last-node omission.

Before adding persistent fields, establish original call order: SoilWater/heat
initialization precedes native full history restore; FrozenCond recomputes all
active rfcp, nodfrostbot and front diagnostics from restored TSOIL/TETOP before
RootExtraction/BoundBottom/FrozenBounds use. TFROST limits come from exact inputs.
Qualify exact own windows; if a real missing complete owner is found, reassess
that whole owner. Do not add scalar caches or infer state from outputs.

First actual component then local O0/O2 short trials, followed by complete
water/chemical undrained and ordinary-drain snow/history periods, every daily
independent water/kernel/chemical guard1e-10, exact native2/199/365/530 and actual
frost-reduction witnesses. A no-activation full run is a control, not positive
frost qualification. Preserve actual generated sources for inactive default,
N/M/L/O/J and named cohorts; no completed unrelated period reruns. Follow any
selected hosted runs through terminal; seal failures, docs, existing scoped
current owner and exact canonical merge after complete qualification.

Status: bounded owner selected; no P production implementation or qualified run.
Invariants: explicit original state/clock, independent conserved balances,
strict invalid-domain refusal, immutable historical evidence and references.

Effective source finding: SWDIVD is read only from the DRFIL.dra selected by
PATHDRAIN+DRFIL, not from swap.swp. SWDRA0 never reads it and uses original
module default0. The first fixture failed before compile/model while attempting
a nonexistent main-deck assignment; retained as INITIAL_FIXTURE_FAILURE. The
original reader also actually refuses SWSOLU1 with SWDIVD0. Positive P cohort is
therefore water/chemical undrained and water ordinary-drained, each frost+snow+
hysteresis2. Chemical drained is an actual original-reader negative control,
not an admitted positive configuration. No numerical repair has been attempted.
