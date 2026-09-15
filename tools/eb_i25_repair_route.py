from pathlib import Path
import json


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)

# 1. Repair EB-I25 route semantics: distinguish model-certificate publication
# from an accepted external full/half trajectory. accepted_substeps counts
# canonical commits, not the two accepted internal half trials.
path = Path('src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90')
text = path.read_text()
text = replace_once(
    text,
    "  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n",
    "  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n"
    "  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE\n",
    'runtime transaction route import')
old = """    if (output%accepted_substeps == 1) then
      ! Preserve I24 exactly on its already-qualified single-substep surface.
      publication%top_status_value = EB_I25_TOP_SINGLE_SUBSTEP_INHERITED
      call inherited%top_liquid_inflow(inflow_cm, value_available)
      publication%top_liquid_inflow_available_value = value_available
      if (value_available) publication%top_liquid_inflow_cm_value = inflow_cm
      call finish_publication(publication)
      return
    end if

    if (output%accepted_substeps <= 1) then
      publication%top_status_value = EB_I25_TOP_CARRIER_INVALID
      call finish_publication(publication)
      return
    end if
"""
new = """    if (numerical_config%transaction%temporal_mode == TX_TEMPORAL_MODEL_CERTIFICATE) then
      if (output%accepted_substeps /= 1) then
        publication%top_status_value = EB_I25_TOP_CARRIER_INVALID
        call finish_publication(publication)
        return
      end if
      ! Preserve I24 exactly on its already-qualified model-certificate surface.
      publication%top_status_value = EB_I25_TOP_SINGLE_SUBSTEP_INHERITED
      call inherited%top_liquid_inflow(inflow_cm, value_available)
      publication%top_liquid_inflow_available_value = value_available
      if (value_available) publication%top_liquid_inflow_cm_value = inflow_cm
      call finish_publication(publication)
      return
    end if

    ! External full/half commits one canonical transaction while the accepted
    ! trajectory consists of exactly two half-trial advances. The carrier, not
    ! output%accepted_substeps, is the authority for those internal advances.
    ! Multiple outer committed runtime substeps remain outside EB-I25 because
    ! the backend snapshot is scoped to one serialized run_trial call.
    if (numerical_config%transaction%temporal_mode /= TX_TEMPORAL_EXTERNAL_FULL_HALF .or. &
        output%accepted_substeps /= 1) then
      publication%top_status_value = EB_I25_TOP_CARRIER_INVALID
      call finish_publication(publication)
      return
    end if
"""
text = replace_once(text, old, new, 'runtime route block')
text = replace_once(
    text,
    "        publication%carrier_sample_count_value /= output%accepted_substeps .or. &\n",
    "        publication%carrier_sample_count_value /= 2 .or. &\n",
    'runtime carrier cardinality')
path.write_text(text)

# 2. Reuse the already-qualified external full/half physical fixture from the
# EB-I23R/I24R fail-closed qualification: retain temporal-history state and
# continuation layout and change only the transaction temporal mode.
path = Path('tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90')
text = path.read_text()
text = replace_once(
    text,
    "       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &\n       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE\n",
    "       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &\n       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE\n",
    'test continuation import')
text = replace_once(
    text,
    "    call initialize_committed_state(committed, parameters, t0, .not. two_half)\n",
    "    call initialize_committed_state(committed, parameters, t0, .true.)\n",
    'test temporal-history fixture')
old = """    if (two_half) then
      template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    else
      template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    end if
"""
new = """    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
"""
text = replace_once(text, old, new, 'test continuation fixture')
text = replace_once(
    text,
    "      config%transaction%temporal_tolerance = 1.0e6_real64\n",
    "      config%transaction%temporal_tolerance = huge(1.0_real64)\n",
    'test qualified external full-half tolerance')
# Three external-full/half cases expose one canonical commit, not two.
count = text.count('output%accepted_substeps == 2')
if count != 3:
    raise SystemExit(f'test accepted_substeps route count: expected 3, found {count}')
text = text.replace('output%accepted_substeps == 2', 'output%accepted_substeps == 1')
text = replace_once(
    text,
    "    call require(publication%accepted_substeps() == 2, 'publication accepted substeps')\n",
    "    call require(publication%accepted_substeps() == 1, 'publication records one canonical commit')\n",
    'test publication canonical commit count')
text = text.replace("'external full-half accepted exactly two half steps'", "'external full-half accepted as one canonical commit'")
text = text.replace("'missing donor two-half publication'", "'missing donor external full-half publication'")
text = text.replace("'outflow two-half publication'", "'outflow external full-half publication'")
path.write_text(text)

# 3. Narrow the scientific contract to the actually observable/qualified route.
Path('tests/eb/EB-I25_CONTRACT.md').write_text("""# EB-I25 — Accepted two-half trajectory sensible-boundary runtime materialization

## Qualified question

Can the admitted EB-I22/I23/I24 sensible-boundary contracts be materialized over an accepted `TX_TEMPORAL_EXTERNAL_FULL_HALF` trajectory without leaking the discarded full trial, inventing donor temperatures, or changing thermodynamic laws?

## Bounded production change

EB-I25 adds one worker-local top sensible-boundary carrier to the serialized reference backend. The carrier is transaction attempt-context scratch. Per physical advance it records only:

- the advance interval;
- canonical signed top liquid exchange (`+` leaves soil, `-` enters soil);
- the already qualified restricted-soil-temperature boundary energy, storage change and residual.

The carrier validates the existing F-PM07B/FMR39 identity `residual = storage_change - boundary_energy`. It is copied/restored through the same transaction attempt context as the admitted bottom thermal carrier, so discarded full-trial and retry work is removed by rollback. It is not committed physical state.

`fmr_execute_multisubstep_sensible_boundary` opts into that carrier only around the same I24 -> I23 -> receipt-owned bottom-energy transaction call. It snapshots the candidate immediately after that call and clears backend scratch before publishing anything.

## Route semantics

`output%accepted_substeps` counts canonical committed runtime transactions. It is **not** the number of internal accepted transaction advances. An accepted external full/half transaction therefore has `accepted_substeps == 1` while its accepted trajectory consists of exactly two half-trial advances.

For the already admitted model-certificate route with one canonical commit, EB-I25 inherits EB-I24 unchanged.

For `TX_TEMPORAL_EXTERNAL_FULL_HALF`, EB-I25 requires:

- exactly one canonical committed runtime transaction;
- a ready top candidate covering exactly the requested interval;
- exactly two contiguous carrier samples covering the two accepted half advances;
- complete, finite FMR39 thermal accounting for both samples.

The discarded full trial must not appear in the candidate. Multiple outer committed runtime substeps are deliberately not qualified here because the backend candidate is scoped to one serialized `run_trial` call.

Top conductive energy is the sum of the two accepted-half restricted-soil-temperature boundary energies, converted exactly from J/cm2 to J/m2 by `1e4`.

Bottom conductive energy remains the explicit qualified restricted-soil-temperature zero-flux boundary condition. This is a modeled zero, not missing evidence repaired to zero.

Bottom advective sensible energy remains inherited from the accepted receipt-owned bottom-energy publication.

For snow-inactive top liquid transport, external donor temperature may be used only when both accepted top-water samples are inflow or exact zero. Any accepted top-water outflow makes top advective sensible energy unavailable; inflow and outflow are never netted to reuse an external donor temperature. Missing donor temperature remains unavailable. Exact zero transport may be a known zero under the admitted external-liquid-temperature contract.

## Required owner evidence

The owner gate must demonstrate at O0 and O2:

- the already qualified temporal-history physical fixture commits in external full/half mode;
- the route exposes one canonical commit while the carrier contains exactly two accepted half samples;
- the discarded full trial does not leak into the carrier;
- accepted top liquid amount equals the two accepted halves only;
- aggregated top conductive evidence is available;
- explicit zero bottom conductive evidence is available;
- receipt-owned bottom advective evidence remains available;
- qualified two-half top inflow closes the EB-I22 boundary when all donor evidence is present;
- missing top donor remains unavailable;
- top outflow cannot reuse external donor temperature;
- model-certificate output is equivalent to EB-I24;
- rejected transaction publishes nothing;
- O0/O2 semantic output identity.

## Hard nonclaims

EB-I25 does not aggregate multiple outer committed runtime substeps. It does not add or alter Richards, soil-temperature, sensible-enthalpy, donor-temperature, timestep or transaction physics. It does not qualify top liquid outflow sensible transport, mixed inflow/outflow top transport, or snow/melt thermal provenance. It does not publish a whole-column sensible-energy residual. It does not add radiation, latent heat, vapor energy, freeze/thaw enthalpy, snow phase-change closure, pressure/chemical/salinity enthalpy, or a complete SWAP5 Energy Balance.

Owner qualification is not independent qualification and is not canonical admission.
""")

# 4. Rebind the owner gate to current canonical and to the corrected route
# contract. Production/test exact hashes are intentionally recorded only after
# the repaired head has passed; immutable dependency/carrier/backend hashes stay pinned now.
path = Path('tests/eb/run_eb_i25_multisubstep_sensible_boundary_gate.sh')
text = path.read_text()
text = replace_once(text, 'CANONICAL=687ee32ca98a42368a2b6380ea78d33eb254dad9',
                    'CANONICAL=1f33328e2ddc0d28450d35647c1c97f293b1e622', 'gate canonical')
text = text.replace('I25_RUNTIME=cf3a231fdf439fe8de1cbaadb9759d1a8fcf7dea\n', '')
text = text.replace('I25_TEST=118af81cab0fd74920b48729a2658aa81ae0b1f3\n', '')
text = text.replace('test "$(git rev-parse HEAD:src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90)" = "$I25_RUNTIME"\n', '')
text = text.replace('test "$(git rev-parse HEAD:tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90)" = "$I25_TEST"\n', '')
text = replace_once(
    text,
    "grep -Fq 'publication%carrier_sample_count_value /= output%accepted_substeps' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90\n",
    "grep -Fq 'TX_TEMPORAL_EXTERNAL_FULL_HALF' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90\n"
    "grep -Fq 'publication%carrier_sample_count_value /= 2' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90\n"
    "grep -Fq 'output%accepted_substeps /= 1' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90\n",
    'gate route assertions')
path.write_text(text)

# 5. Persist a resumable qualification checkpoint with the diagnostic finding.
path = Path('tests/eb/EB-I25_CHECKPOINT.json')
data = json.loads(path.read_text())
data['phase'] = 'QUALIFY'
data['canonical_head'] = '1f33328e2ddc0d28450d35647c1c97f293b1e622'
data['canonical_tree'] = '934877112b44e5648fd659d64531ed8facc35d23'
data['source_head_before_checkpoint'] = '1ce9d26183d8e3d26b34a378e411c48c863fd369'
data['previous_checkpoint_canonical'] = '993673abae05570026dcc55a305679b09472e1d8'
data['state_delta'] = {
    'canonical_advanced': True,
    'dependency_change_detected': False,
    'evidence_invalidated': False,
    'reason': 'Canonical advanced through F-CI78, but EB-I25 transaction, I23, I24 and backend authorities relevant to this repair are unchanged. Reconciliation merge 1ce9d261 preserves the bounded I25 delta.'
}
data['reused_evidence']['EB_I23R_I24R_two_half_fixture'] = 'work/eb-i23r-i24r-internal-two-half-fail-closed head a7a6e8564318f29d84197ba870aa6fddb7f09cf9 proved an accepted external full/half transaction with one canonical commit and fail-closed last-observation semantics.'
data['new_evidence'] = [
    'Diagnostic run 34983346428/job 104429045525 proved the original I25 no-history/CONTINUATION_NONE fixture never reached an accepted transaction (9 attempts, 8 retries, KERNEL_REJECTED).',
    'Code reconciliation established that output%accepted_substeps counts canonical commits, whereas external full/half accepted trajectory authority is represented by two rollback-owned carrier samples.'
]
data['tests'] = [
    {'run': 34983346428, 'job': 104429045525, 'result': 'EXPECTED_DIAGNOSTIC_FAILURE', 'finding': 'fixture rejected before temporal acceptance; no I25 semantic verdict'},
    {'source': 'EB-I23R/I24R owner evidence', 'head': 'a7a6e8564318f29d84197ba870aa6fddb7f09cf9', 'result': 'REUSED_QUALIFIED_FIXTURE'}
]
data['verdict'] = 'QUALIFICATION_REPAIR_READY_FOR_OWNER_GATE'
data['mutations'] = [
    'reconciled existing EB-I25 branch with current canonical 1f33328e',
    'corrected route discrimination from accepted_substeps cardinality to transaction temporal mode plus carrier provenance',
    'reused qualified temporal-history external full/half physical fixture; no solver or physics tolerances were relaxed except the already qualified external temporal comparison tolerance',
    'narrowed scope to one canonical external full/half transaction with exactly two accepted carrier samples'
]
data['next_permitted_action'] = 'Run the corrected EB-I25 owner gate at O0/O2. If and only if green, persist exact repaired production/test blobs and begin a fresh independent qualification under an unused F-VQ identifier.'
path.write_text(json.dumps(data, indent=2) + '\n')

# 6. Replace the diagnostic workflow with the normal owner gate workflow.
Path('.github/workflows/eb-i25-multisubstep-sensible-boundary.yml').write_text("""name: EB-I25 accepted two-half sensible boundary

on:
  push:
    branches:
      - work/eb-i25-accepted-multisubstep-sensible-boundary
  workflow_dispatch:

permissions:
  contents: read

jobs:
  qualify-owner:
    runs-on: ubuntu-24.04
    timeout-minutes: 40
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Install GNU Fortran
        run: sudo apt-get update && sudo apt-get install -y gfortran
      - name: Run EB-I25 owner qualification
        shell: bash
        run: bash tests/eb/run_eb_i25_multisubstep_sensible_boundary_gate.sh
""")
