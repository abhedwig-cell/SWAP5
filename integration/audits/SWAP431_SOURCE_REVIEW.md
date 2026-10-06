# SWAP431 master coverage source review

Status: IN_PROGRESS_SOURCE_CENSUS. Baseline: integration/f-ci-canonical
`ca856e88e582d468a6f40971ce1f2a75e5089c40`, 2026-10-06.

This record is a recoverable census, not a declaration of full functional
coverage. The master JSON records bounded admissions and registered source
review/migration tasks separately. ACTIVE_MIGRATION can mean that replacement
or envelope evidence still needs adjudication; it does not prove that no code
exists. No new physics has been admitted by this audit.

## Source identity

The original distribution was recovered and checked through the repository's
ordered B0 to B1.11 reconstruction. All 63 B1.11 members, 1,886,519 bytes,
match manifest SHA256
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.
The evidence directory retains a deterministic compressed exact-byte source
bundle, every member hash, B0 member hashes and the changed-member list.
The integer-reader inventory is reproducible navigation; it is not alone an
exhaustive execution-path denominator. Real and logical controls and
source-reachable combinations also matter.

## Source exclusions established directly

- `MOD_cropdevelopment.f90`, read_stressors: compensation with SWDROUGHT > 1
  resets compensation to zero and raises swap_error. RootExtraction dispatches
  drought 1 to MACRO, 2/3 to MICRO. External Jarvis/Walsum after MICRO is not a
  source capability. MICRO itself is independent missing coverage.
- The salinity reader admits SWSALINITY 0..1. Osmotic-head option 2 is only
  mentioned in a comment, not an executable selected capability.
- MICRO explicitly errors for SWFROST. The main reader prohibits simultaneous
  SWFROST and SWMACRO. These combinations are not legacy migration gaps.
- `read_macropore` explicitly errors for SWSOLU > 0. Macropore solute is not an
  executable B1.11 capability. Future solute research does not change that fact.
- Macropore initialization iterates rapid drainage over `ir=1,1`. The rate
  routine uses one selected NumLevRapDra. This does not supply simultaneous
  multiple rapid-drain levels; ordinary multilevel drainage is separate.
- SWBMA selects yearly BMA balance output, not additional exchange physics.
- TCS5 raises an error and directs callers to the executable TCS7/8 routes.
- Frost modifies hydraulic conductivity/derivative, empirical root extraction
  and FrozenBounds drain/bottom heuristics. There is no ice/liquid partition or
  latent-heat state/equation in the recovered source. Phase change is outside
  this denominator.

## Independent persistent or stateful physics

Hysteresis is real hydraulic history. `hysteresis.f90` updates INDEKS, FHYST and
DELP, reversals, head and capacity. Initial wetting/drying is selected by
SWHYST 1/2. Default MvG and crack shrinkage history do not replace this.

MICRO supplies nonlinear MFLP soil/root-interface/xylem/leaf potentials, separate
Jong van Lier and de Willigen formulations, root density, saturated uptake,
stress attribution and optional hydraulic lift. Its Upw is the water sink;
UpwPot is potential/diagnostic. Saved arrays must be traced for cross-call
physical history versus reconstructible solver workspace before a candidate,
commit and restart contract can be approved. Feddes does not supply these
potential-network semantics.

The solute family includes nonlinear sorption, decomposition, aquifer salt
storage and breakthrough, pond solute and a water-age tracer. The admitted
mobile matrix salt plus Maas-Hoffman/Jarvis/Walsum/root-frost chain does not
close those distinct states and equations.

Tillage changes bulk density, hydraulic parameters, consolidation history and
water redistribution. Soil-N management contains organic turnover, mineral
transport, nitrification/denitrification, amendments, residues and N-limited
crop coupling. Potential-production Spring Barley does not replace soil N.

## Canonical reconciliation

INT13/Rutter, INT12-D/Gash and INT12-E detailed continuation are admitted within
their recorded envelopes. D2/D3, EXACT01, matrix salt, WALSAL01 and SALFRO01
are admitted. MIGMAC01..09 and PERCH21 supersede older standard-macro gap
labels. A26 is bounded live RFM admitted, but is not proof of the legacy
SWMBF2 kinematic-wave equation. SWMBF2 and the nondefault SWABS/SWSEP/SWPOWM/
SWDARCY source paths need individual review.

Frost B1..B15 admissions cover the enumerated bounded runtime profiles. B16/17
repair reference authority; B18 admits a scientific component, not backend
runtime. B19's selected runtime slice remains unimplemented and needs its
source-bound contract. Isolated B18 qualification cannot close runtime DIVDRA.

LOW03-A explicitly leaves explicit SWBOTB3 open. Its GWL/saturated-profile
resistance semantics must not be written off as merely numerical policy.
SWBOTB9 imposes both head and flux and resets last-node head/theta/K; it is
accepted by the reader and is not automatically executable plumbing.

## Decision boundaries

Historical open PRs do not reopen later canonical admissions. The retained
open-PR snapshot is bounded to the first 100 updated results and is navigation,
not an exhaustive PR inventory. No family-level rejection is made solely to
reduce the queue. The ledger's review tasks must be resolved before a final
missing-functionality count or CLOSED declaration is defensible.

## Live canonical delta

Canonical advanced to `e5eab995ef04fc813dd644025fb0f32e4f5050a1` while this review was running. All ten commits and the 18-file delta were reconciled locally. MICRO01 is a canonically admitted isolated corrected matric-flux table component; its own status explicitly sets runtime_admitted=false. It does not close either microscopic uptake formulation or hydraulic lift.

The MICRO initialization guard at RWU_micro.f90 line 232 rejects SWDOSATREL=1. Reader acceptance is not execution reachability; this selector is explicitly NOT_APPLICABLE. The internal optimal-root diagnostic has its own reachable saturated-allocation logic and remains inside MICRO stress adjudication.

### Irrigation runtime and hydraulic dispatcher refinement

Current src searches find only definitions of evaluate_fixed_irrigation_interval and evaluate_scheduled_irrigation_interval, no runtime callers. F-CI19 independently records qualified F-VQ18/F-VQ20 fixed/TCS7/DCS2 single-node SSDI process semantics and absent higher composition. TCS7 and SSDI therefore have proven missing production binding, despite existing process code. This must not erase the later separate F-APP07 TCS1/DCS2 sprinkling application admission.

Hydraulic model 4 is unscaled unimodal MvG; 5 is its finite dry-end normalized form; 6/7 are unscaled/normalized bimodal MvG. PDI is 8/9 unimodal and 10/11 bimodal, with normalization in 9/11. The source reader's broad PDI label is insufficient authority for those distinctions. Model 4's physical capability is replaced by the admitted default MvG provider as explained in the disposition decisions and bounded local curve evidence.
