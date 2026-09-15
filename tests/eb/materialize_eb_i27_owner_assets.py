from pathlib import Path

ROOT = Path('.')
old_prod = ROOT / 'src/runtime/mod_eb_i26_outer_substep_sensible_boundary_aggregation.f90'
new_prod = ROOT / 'src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90'
old_test = ROOT / 'tests/eb/test_eb_i26_outer_substep_sensible_boundary_aggregation.f90'
new_test = ROOT / 'tests/eb/test_eb_i27_outer_substep_sensible_boundary_aggregation.f90'
old_gate = ROOT / 'tests/eb/run_eb_i26_outer_substep_sensible_boundary_gate.sh'
new_gate = ROOT / 'tests/eb/run_eb_i27_outer_substep_sensible_boundary_gate.sh'
old_contract = ROOT / 'tests/eb/EB-I26_CONTRACT.md'
new_contract = ROOT / 'tests/eb/EB-I27_CONTRACT.md'
old_workflow = ROOT / '.github/workflows/eb-i26-outer-substep-sensible-boundary.yml'
new_workflow = ROOT / '.github/workflows/eb-i27-outer-substep-sensible-boundary.yml'


def require_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    return text.replace(old, new, 1)


def move(old: Path, new: Path) -> None:
    if not old.exists():
        raise SystemExit(f'missing source asset: {old}')
    if new.exists():
        raise SystemExit(f'target already exists: {new}')
    old.rename(new)


for old, new in [
    (old_prod, new_prod),
    (old_test, new_test),
    (old_gate, new_gate),
    (old_contract, new_contract),
    (old_workflow, new_workflow),
]:
    move(old, new)

for path in (new_prod, new_test, new_gate, new_contract):
    text = path.read_text()
    text = text.replace('I26', 'I27').replace('i26', 'i27')
    path.write_text(text)

# Reconcile the one inherited authority legitimately changed by F-KT22.
# Stable EB-I23/I24/I25 authorities remain byte-locked across the original
# I27 base and live canonical. The serialized backend has an explicit old/new
# lock, and the immutable F-KT22 close checkpoint must itself attest that the
# EB-I25 preservation gate passed.
text = new_gate.read_text()
old = '''BASE=9d202705d1d7063ae129166b1049f7555a7ad802

git fetch origin integration/f-ci-canonical
git merge-base --is-ancestor "$BASE" origin/integration/f-ci-canonical

declare -A LOCKS=(
  [src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90]=fc88731c12c8af5136aad13bda2a7da3d768dc4c
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=960ea116cad81e8c0db8a579982f4999b3d085ed
  [src/runtime/mod_fmr_top_sensible_boundary_carrier.f90]=299717757082ff06e98bd3aaec2c0b8b3013ea21
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
  [src/process/mod_whole_column_sensible_energy_accounting.f90]=c00efd8cdb4de947de16e1d32ae4c9f4d0590850
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/process/mod_external_liquid_water_temperature.f90]=64b85363e764d2c6e2777f5f1258abb3ac9e5abf
  [src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90]=5f27ff7a4fa67a3991c622d960a7133857dab1c2
  [src/runtime/mod_eb_i23_sensible_boundary_runtime.f90]=35dda86ca51bd91040af0672a43e2961c8db64fd
)
for path in "${!LOCKS[@]}"; do
  test "$(git rev-parse "$BASE:$path")" = "${LOCKS[$path]}"
  test "$(git rev-parse "origin/integration/f-ci-canonical:$path")" = "${LOCKS[$path]}"
done
echo 'EB_I27_INHERITED_AUTHORITY_LOCK=PASS'
'''
new = '''BASE=9d202705d1d7063ae129166b1049f7555a7ad802
FKT22_CLOSE=4a01641ffed8a2260260909825c3887db2dff1ac
FKT22_CHECKPOINT=tests/fkt/F-KT22_RECOMPOSITION_CHECKPOINT.json
FKT22_CHECKPOINT_BLOB=a9205fbe5d359e8d8f710476e5fbd2084eaff9e8
OLD_BACKEND_BLOB=960ea116cad81e8c0db8a579982f4999b3d085ed
FKT22_BACKEND_BLOB=9b4d6f7d6b63d66fe2e46eb9c46d70d08e32db13

git fetch origin integration/f-ci-canonical
git merge-base --is-ancestor "$BASE" origin/integration/f-ci-canonical
git merge-base --is-ancestor "$FKT22_CLOSE" origin/integration/f-ci-canonical

declare -A STABLE_LOCKS=(
  [src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90]=fc88731c12c8af5136aad13bda2a7da3d768dc4c
  [src/runtime/mod_fmr_top_sensible_boundary_carrier.f90]=299717757082ff06e98bd3aaec2c0b8b3013ea21
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
  [src/process/mod_whole_column_sensible_energy_accounting.f90]=c00efd8cdb4de947de16e1d32ae4c9f4d0590850
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/process/mod_external_liquid_water_temperature.f90]=64b85363e764d2c6e2777f5f1258abb3ac9e5abf
  [src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90]=5f27ff7a4fa67a3991c622d960a7133857dab1c2
  [src/runtime/mod_eb_i23_sensible_boundary_runtime.f90]=35dda86ca51bd91040af0672a43e2961c8db64fd
)
for path in "${!STABLE_LOCKS[@]}"; do
  test "$(git rev-parse "$BASE:$path")" = "${STABLE_LOCKS[$path]}"
  test "$(git rev-parse "origin/integration/f-ci-canonical:$path")" = "${STABLE_LOCKS[$path]}"
done

test "$(git rev-parse "$BASE:src/runtime/mod_fmr_serialized_reference_backend.f90")" = "$OLD_BACKEND_BLOB"
test "$(git rev-parse "origin/integration/f-ci-canonical:src/runtime/mod_fmr_serialized_reference_backend.f90")" = "$FKT22_BACKEND_BLOB"
test "$(git rev-parse "origin/integration/f-ci-canonical:$FKT22_CHECKPOINT")" = "$FKT22_CHECKPOINT_BLOB"
git show "origin/integration/f-ci-canonical:$FKT22_CHECKPOINT" | grep -Fq '"eb-i25-preservation": "PASS"'
git show "origin/integration/f-ci-canonical:$FKT22_CHECKPOINT" | grep -Fq '"admitted_production_identical_to_qualified_checkpoint": true'
git show "origin/integration/f-ci-canonical:$FKT22_CHECKPOINT" | grep -Fq '"verdict": "ADMITTED_CANONICAL_CLOSED"'
echo 'EB_I27_FKT22_BACKEND_RECONCILIATION=PASS'
echo 'EB_I27_INHERITED_AUTHORITY_LOCK=PASS'
'''
text = require_once(text, old, new, 'F-KT22 backend reconciliation')
text = require_once(
    text,
    'git diff --name-only "$BASE" HEAD | sort > changed.txt',
    'git diff --name-only --no-renames "$BASE" HEAD | sort > changed.txt',
    'bounded delta rename stability',
)
text = require_once(
    text,
    'tests/eb/test_eb_i27_outer_substep_sensible_boundary_aggregation.f90\nEOF',
    '''tests/eb/test_eb_i27_outer_substep_sensible_boundary_aggregation.f90
.github/workflows/eb-i26-outer-substep-sensible-boundary.yml
src/runtime/mod_eb_i26_outer_substep_sensible_boundary_aggregation.f90
tests/eb/EB-I26_CHECKPOINT.json
tests/eb/EB-I26_CONTRACT.md
tests/eb/run_eb_i26_outer_substep_sensible_boundary_gate.sh
tests/eb/test_eb_i26_outer_substep_sensible_boundary_aggregation.f90
tests/eb/materialize_eb_i27_owner_assets.py
EOF''',
    'bounded delta materialization allowlist',
)
new_gate.write_text(text)

# Make the reference-temperature local explicitly initialized. The first valid
# publication overwrites it before it is semantically consumed, so this only
# removes conservative compiler ambiguity and does not alter accepted values.
text = new_prod.read_text()
text = require_once(
    text,
    '    aggregate = eb_i27_outer_substep_sensible_boundary_publication_t()\n\n    if (size(publications) < 2) then',
    '    aggregate = eb_i27_outer_substep_sensible_boundary_publication_t()\n    reference_temperature_c = 0.0_real64\n\n    if (size(publications) < 2) then',
    'reference-temperature initialization',
)
new_prod.write_text(text)

# Materialize the already-green F-KT10 consecutive accepted-Richards fixture.
text = new_test.read_text()
for old, new, label in [
    ('real(real64), parameter :: dt_outer = 1.0e-4_real64',
     'real(real64), parameter :: dt_outer = 0.25_real64', 'dt'),
    ('    parameters%bottom_mode = 2', '    parameters%bottom_mode = 5', 'bottom mode'),
    ('parameters%max_iterations = 16; parameters%max_backtracking = 8',
     'parameters%max_iterations = 8; parameters%max_backtracking = 4', 'solver controls'),
    ('    parameters%min_step_duration = 1.0e-8_real64',
     '    parameters%min_step_duration = 1.0e-6_real64', 'minimum step'),
    ('    config%transaction%max_retries = 8',
     '    config%transaction%max_retries = 0', 'retry budget'),
    ('    config%max_committed_substeps = 32',
     '    config%max_committed_substeps = 4', 'committed substeps'),
    ("    heads(1) = initial_head\n    do i = 2, numnod\n      heads(i) = heads(i-1) + parameters%node_distance(i)\n    end do",
     '    heads = initial_head', 'uniform initial head'),
    ('    forcing%bottom_flux = q\n    forcing%bottom_head = -321.0_real64',
     '    forcing%bottom_flux = 12345.678_real64\n    forcing%bottom_head = initial_head + 0.01_real64',
     'bottom fixture'),
]:
    text = require_once(text, old, new, label)

old = '''    integer :: enthalpy_status

    call initialize_parameters(parameters)
    call initialize_committed_state(committed, parameters, t_start, dt_outer)
    call initialize_forcing(parameters, forcing, q)'''
new = '''    integer :: enthalpy_status
    type(b110_default_mvg_parameters_t), target :: fixture_hydraulics
    type(b110_default_mvg_provider_t) :: fixture_constitutive
    real(real64) :: fixture_heads(numnod), fixture_water(numnod), fixture_k(numnod), fixture_c(numnod), fixture_dkdh(numnod)

    call initialize_parameters(parameters)
    call initialize_b110_default_mvg_parameters(fixture_hydraulics, parameters%cofgen)
    call bind_b110_default_mvg_provider(fixture_constitutive, fixture_hydraulics, dt_outer)
    fixture_heads = initial_head
    call fixture_constitutive%evaluate(fixture_heads, fixture_water, fixture_k, fixture_c, fixture_dkdh)
    call initialize_committed_state(committed, parameters, t_start, dt_outer)
    call initialize_forcing(parameters, forcing, -fixture_k(1))'''
text = require_once(text, old, new, 'constitutive top-flux fixture')
new_test.write_text(text)

# Final gate compiles committed inputs directly. Strip both runner-only Python
# mutation blocks by replacing everything from their heading up to COMMON=(.
text = new_gate.read_text()
start = text.find('# Runner-only substitution')
common = text.find('COMMON=(', start)
if start < 0 or common < 0:
    raise SystemExit('runner-local gate block anchors missing')
text = text[:start] + '# F-KT10-derived hydrologic fixture is committed in the I27 owner test.\n' + text[common:]
text = text.replace("echo 'EB_I27_FIXTURE_PROBE=PASS'", "echo 'EB_I27_OWNER_QUALIFICATION=PASS'")
new_gate.write_text(text)

# Persist the ownership collision and immutable-evidence provenance in contract.
text = new_contract.read_text()
if '## Identifier provenance' not in text:
    text += '''\n## Identifier provenance\n\nThis capability was initially bootstrapped under the working label `EB-I26`. During reconciliation, an independently active workunit `work/eb-i26-top-liquid-outflow-sensible-transport` was found to own `EB-I26`. The outer committed-substep aggregation capability was therefore renumbered to `EB-I27` before owner qualification. The renumbering changes no scientific or runtime semantics and does not absorb any top-liquid-outflow semantics.\n\nThe consecutive accepted-Richards owner fixture is inherited from the already owner-verified F-KT10 transaction-history composition surface. EB-I27 adds restricted soil-temperature state only as required by the sensible-energy runtime; it does not change the F-KT10 hydraulic controls.\n\nF-KT22 later changed the shared serialized reference backend. EB-I27 reconciles that delta by locking the original backend blob, the admitted F-KT22 backend blob, and the immutable F-KT22 close checkpoint whose qualification jobs record `eb-i25-preservation: PASS`. All other inherited EB-I23/I24/I25 authority blobs remain unchanged.\n'''
new_contract.write_text(text)

# The materialization workflow replaces itself with the permanent read-only
# owner qualification workflow in the same repository commit.
new_workflow.write_text('''name: EB-I27 accepted outer-substep sensible-boundary owner qualification

on:
  push:
    branches:
      - work/eb-i27-accepted-outer-substep-sensible-boundary-aggregation
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
      - name: Run EB-I27 owner qualification
        shell: bash
        run: bash tests/eb/run_eb_i27_outer_substep_sensible_boundary_gate.sh
''')

print('EB_I27_OWNER_ASSETS_MATERIALIZED=PASS')