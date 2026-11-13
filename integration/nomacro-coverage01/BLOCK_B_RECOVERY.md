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


First block admitted PR1669 at980273f81; actual tree matches qualified head.
First extended run43403320753 atdfba06aef: unchanged release and first-block
cohorts PASS. Hysteresis1 O0 own2to4 fails exact continuation (groundwater
spread4.84671923e-6cm on day3), despite successful water/solute checks.
Native format preserves scanning variables but omits the accepted hydraulic
carry after hysteresis changes h/scanning curves. Cold recomputation of theta,
conductivity and capacity is not a complete continuation of the accepted step.
Targeted repair1: only explicit experimental hysteresis adds active theta/K/
Kmean/capacity/volume/groundwater/h history to the existing auxiliary stream;
new formatS5SHS013 (solute) orS5NHS007 (water) prevents old-history ambiguity.
Strict finite/positive/conserved-water checks apply before use. Original no-hyst
formats and generated physical bodies remain unchanged. Qualify exact short
and seasonal own states; reject the repair unless exact continuation is restored.


Run43404793167 at5699485d9 proves repair1: hysteresis1 AND2 complete1096 each,
O0/O2 own2to4 and365to367 native+auxiliary endpoints, distinct-origin isolation,
external discard/replay/recovery and actual mass-refusal controls all pass.
The following snow O0 trajectory matches water/solute exactly but native TSOIL
bytes differ (193bytes in result.end; complete1361096-byte auxiliary identical).
Source temperature_numeric computes the snow-interface boundary from previously
accepted heacon(1) BEFORE the next DeVries update. Native TSOIL lacks that carry.
Targeted snow repair1: only experimental SWSNOW1 adds heacon/heacap and top/bottom
temperature carry to a format-distinct auxiliary stream. Numerical coefficients,
snow law, timestep control and tolerances unchanged. Requalify exact whole state.
