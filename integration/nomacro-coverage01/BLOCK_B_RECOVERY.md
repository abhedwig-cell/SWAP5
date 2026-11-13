# Original state and reaction block

Workstream SWAP5-NOMACRO-COVERAGE01; block B branch codex/nomacro-coverage02.
Base681af16d0, following pending first-block PR1669. Same isolated worktree,
separate hosted runners and distinct output artifacts. No other workstream files.

Implemented, not yet tested/qualified/admitted: original hysteresis1/2, snow,
Freundlich sorption and decomposition through explicit experimental input.
No new physical law or state codec: original binary native state already stores
snow ssnow/slw and hysteresis indeks/delp/fhyst/hm1; numerical temperature is native.
Original conserved cmsy includes dissolved plus adsorbed solute, and sampro is
sum(cmsy*dz)+csurf. Existing conserved auxiliary state and native aqueous cml
therefore carry sorption; the existing independent ledger includes decomposition.

Snow's original daily state update is outside rejected water trials. The soil/
pond substep certificate must include dt*melt, exactly the extra original
boundtop q0 term. The independent whole-day certificate still includes snow
storage, snowfall and sublimation. No tolerance/solver/time policy changes.
No-snow production arithmetic and the existing Cauchy receipt stay unchanged.

Planned actual runs: Hupsel1096 hysteresis1, hysteresis2, snow; SaltFarm1461
positive original08dS solute stock with sorption, positive0.001/day decay and
both reactions. Original Hupsel sorption parameters0.9/1.0/KF0.0001389/
0.0001378 are explicitly supplied to the two-layer SaltFarm scenario. These are
derived process configurations, not new historical projects or original workbook
variants. Check positive snow storage and positive decomposition, own day2to4/
365to367 native+auxiliary bytes, distinct-origin isolation, actual mass refusal,
external discard/replay/recovery and original-source numerical comparisons.
Final same-source first-block and three-release-profile cohorts run independently.

Frost remains refused: reference/frost-corrections/FROST-GEOMETRY-01/manifest.json
excludes SWDIVD1 and global production admission, while Hupsel uses SWDIVD1.
Do not implicitly adopt that correction or uncorrected known defects. Mixed
aquifer solute reservoir, subsurface irrigation and other state gaps stay refused.

Invariants2/3/7/13/21/23/29; physical laws, independent strict water/solute limits,
source rollback and native state ownership preserved. Existing scientific FAILs
remain; whole scientific equivalence and frost coverage are not claimed.
Next action: persist and push; dedicated hosted O0/O2 full process qualification.
