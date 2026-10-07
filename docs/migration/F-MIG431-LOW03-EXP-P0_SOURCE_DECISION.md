# F-MIG431-LOW03-EXP-P0 source decision

B1.11 authority is `integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json`,
member `SWAP/boundbottom.f90`, SHA-256
`5735f2b6e70408d304f6f5fa35ba659fb3422e03109630e27368933f5c10836e`.

The explicit mode-3 branch is a trial-local flux materialization, not a
Richards state rewrite.

Source control flow:

- line 77: `gwlmean = hdrain + shape_3*(gwl - hdrain)`
- line 89: `do while (gwlmean > ztopcp(node) .AND. node > 1)`
- line 93: `satnodgwl = gwlmean - zbotcp(nodnumgwl)`
- line 94: `cvalprof = satnodgwl/cofgen(3,nodnumgwl)`
- line 96: deeper full nodes contribute `dz(node)/cofgen(3,node)`
- line 102: `qbot = (deepgw-gwlmean)/(rimlay+cvalprof)`
- B1.11 subsequently adds QBOT4 when configured.

The strict `>` at line 89 is normative: equality with `ztopcp(node)`
keeps that node selected.

SWAP5 design decision: reuse the admitted LOW03 temporal control for DEEPGW
and QBOT4 clocks. Materialize the explicit qbot from trial-start groundwater
level plus geometry/Ksat, then use the existing explicit-flux bottom route.
No new solver law, committed physical state, mass owner, or Restart-v1 field
is required.

The pure provider is
`src/runtime/mod_fmr_legacy_explicit_cauchy_bottom_boundary_provider.f90`.
Application binding remains qualification-gated.
