"""Source-bound current CI selection; historical admissions stay immutable.

This is not a replacement historical oracle or whole-science admission. It
inherits sealed full-run evidence only for the exact tested runtime and permits
three literal CI forwarding insertions. Any subsequent runtime change must choose
and qualify its own successor. L adds a separately sealed prescribed-head
qualification plus fresh closed6 and unchanged named-source preservation.
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SEALED = '4ee0e08b095b945870dce54032e0d886478fb4c4'
ORIGINAL_RUNTIME = '6e2cd26f873f9a935af92816a2f1d947df9293c7'
RUNTIME = 'f1d1c13a295c5b54ec11e03d864de7030ca09008'
L_RUNTIME = 'dadbda8128c16d8ba8dd858e5ac3a0b64a9a2b75'
L_ADMITTED = '30f7a21ff0b3437ea937476c72ca11421d2d03de'
M_RUNTIME = 'f6ce291e4c28e88ee3c1b47a206da12433a92c38'
M_ADMITTED = '6136101463762b1dd18419fe0260965eccd482c7'
N_RUNTIME = '6afb72468c0060df60694d4b69ee8619fdc93062'
N_ADMITTED = '8dcda0fb247ae7823d720817d6340114d5227728'
O_RUNTIME = 'e8d78740663a879945f05b4ecd445db30554ceac'
O_ADMITTED = 'fec7b4415932a9c48826e134ce76340adb855778'
CURRENT_RUNTIME = '7bf2f817b2a025ed25670730d4745dcbb8c4001b'
P_WINDOWS = '5a59d1799476feb6f709743724e0072669a42692'
P_PRESERVATION = '6c93d5a2f7876cec051f169182a59c22a54a4788'
P_SEALED = '3678bcd846a313c6d4f60f27b8d08d6c2f3f7f36'
P_ADMITTED = '0f12c639da5c4dadf488282dc8e110d2a8ad1874'
Q_RUNTIME = '33f7363965c137f017ce756fa6b5a07dc4287051'
Q_WINDOWS = 'c6b9a94d8566ab06526a4083d8c7e8a086229337'
Q_SEALED = 'fde1f3f0090f9c6f8ffaec7b66ddaab441ed34c3'
Q_ADMITTED = '67ddba2692cc13f89cfc29100836f2d6a4b80eec'
R_RUNTIME = '75e5b45a1b7a8705d6d364156a1ad4434107dfdf'
R_WINDOWS = '4da8feaff8134ca64cdf8133fcf3126313a6135e'
R_PREFLIGHT = '30ae92bec2d52e536ab438dc4d8b51a6a10fc5c3'
R_SEALED = '779c4714de5b0c3d2e781993d9d85941864317c4'
R_ADMITTED = 'a9044fdab7e333058c6a4dab34884e56e33c35a9'
S_RUNTIME = 'b97a04d2c9509e4aa49a29a9a582df2ac4dd33d2'
S_UBUNTU = '451b28ea4a1b68611952c55437bdcf37c6017ac4'
S_SEALED = '504fd73906740b9c43a2d54371184980d7e42e5a'
S_PROOF = 'integration/f-ci/nomacro-complete01/'
O_WINDOWS = '6bb58557252f3c7ab8da27efe18e8cbe53bffe5d'
O_SEALED = '5fcb0622c4ab0c89618d92b9541dcc7f85f4c799'
N_SEALED = '4b6e470b64cd0c5b9967cfb0b4e35c778d8fafe5'
M_EXECUTED = '166d4b7b5fe9ba0f6ea3aa8af6f5d55d66a904ad'
M_POND_EXECUTED = '65bfe12195af15c1ed39167edbd996e643941c55'
M_SEALED = '182d1c464bad3ae011ff18d64103e2a88eb78702'
L_SEALED = '69561229a73b6c0085b2023935b8be09d1262710'
L_PROOF = 'integration/nomacro-coverage01/'
COMPOSED_JSON_SHA256 = '0fafaad32f544eb487668f1393fc5e4bd7848af7dc0d69ec3738716dc99a3985'
COMPOSED_RAW_SHA256 = '5dd145a3f54950ef09aa5ad6316729abf981b14c8c896a0d1815f5f6c5292f25'
BASE = '3fb625da73031885624987d42ad922cb184c96e5'
PROOF = 'integration/f-ci/hupsel51-water-balance/'
SELF = 'tests/hupsel51/verify_successor.py'
TEST = 'tests/hupsel51/test_successor.py'
FCI = '.github/workflows/fci-canonical.yml'
MC = '.github/workflows/mc-sol01-column-input.yml'
CHEM = '.github/workflows/mc-sol01-swp-reader.yml'
QUALIFY = '.github/workflows/hupsel51-water-balance.yml'
COMPOSED_STEP = '''      - name: Shared soil-air receipt template O0/O2 after composition
        run: python3 -B tools/solute/check_soil_air_receipt.py --reference-work "$RUNNER_TEMP/hupsel51-provider" --output "$RUNNER_TEMP/hupsel51-soil-air"
'''
COMPOSED_ARTIFACT = '            ${{ runner.temp }}/hupsel51-soil-air\n'
FCI_INSERT = '''          if [[ -f tests/hupsel51/verify_successor.py ]]; then
            # Exact current repair proof, not a relabelled historical admission.
            python3 -B tests/hupsel51/test_successor.py
            python3 -B tests/hupsel51/verify_successor.py
            python3 -m pip install -r tests/dataqual15_hupsel/requirements-science.txt
            python3 -B tests/modularity/run_modular_tests.py \\
              --case assimilation --case boesten --case drainage --case low_air_policy \\
              --case root_contract --case root_oxygen --output "$RUNNER_TEMP/modular-feedback"
          el'''
MC_OLD = '        run: python -B tests/nut-sol/verify_surface_age_successor.py\n'
MC_NEW = '''        run: |
          if [[ -f tests/hupsel51/verify_successor.py ]]; then
            # The actual column O0/O2/restart test above still runs unchanged.
            python -B tests/hupsel51/verify_successor.py
          else
            python -B tests/nut-sol/verify_surface_age_successor.py
          fi
'''
CHEM_OLD = '''          python -B integration/audits/verify_swp_reader.py
          python -B integration/audits/verify_swp_reader.py --self-test
'''
CHEM_NEW = '''          if [[ -f tests/hupsel51/verify_successor.py ]]; then
            # Live chemistry/input/water/ETref/restart tests above are unchanged.
            python -B tests/hupsel51/test_successor.py
            python -B tests/hupsel51/verify_successor.py
          else
            python -B integration/audits/verify_swp_reader.py
            python -B integration/audits/verify_swp_reader.py --self-test
          fi
'''


def require(ok, label):
    if not ok:
        raise ValueError(label)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def blob(ref, path):
    return git('show', ref + ':' + path)


def validate_scope(paths):
    allowed = {SELF, TEST, FCI, MC, CHEM, PROOF+'README.md', PROOF+'RECOVERY.md',
               PROOF+'COMPOSED_WINDOWS.json', PROOF+'COMPOSED_WINDOWS_RAW.zip',
               QUALIFY}
    require(set(paths) <= allowed, 'unqualified successor delta: '+str(set(paths)-allowed))


def validate_workflow(path, current, previous):
    if path == FCI:
        require(current.count(FCI_INSERT) == 1, 'missing/duplicate bounded F-CI selection')
        current = current.replace(FCI_INSERT, '          ', 1)
    elif path == MC:
        require(current.count(MC_NEW) == 1, 'missing/duplicate bounded column selection')
        current = current.replace(MC_NEW, MC_OLD, 1)
    elif path == CHEM:
        require(current.count(CHEM_NEW) == 1, 'missing/duplicate bounded chemistry selection')
        current = current.replace(CHEM_NEW, CHEM_OLD, 1)
    else:
        insertion = "      - 'tests/hupsel51/**'\n"
        require(current.count(insertion) == 1, 'missing/duplicate composed qualification trigger')
        current = current.replace(insertion, '', 1)
        require(current.count(COMPOSED_STEP) == 1, 'missing/duplicate composed soil-air check')
        current = current.replace(COMPOSED_STEP, '', 1)
        require(current.count(COMPOSED_ARTIFACT) == 1, 'missing/duplicate composed component raw output')
        current = current.replace(COMPOSED_ARTIFACT, '', 1)
    require(current == previous, 'historical workflow body changed: '+path)


def validate_runs(profiles):
    for opt in ('O0', 'O2', 'named'):
        expected = {'undrained': 1096} if opt != 'named' else {'grass': 1827, 'hupsel': 1096, 'salt': 1461}
        require(set(profiles[opt]) == set(expected), 'missing full trajectory')
        for name, days in expected.items():
            r = profiles[opt][name]
            require(r['status'] == 'FULL_PASS' and r['full_days'] == days, 'incomplete trajectory')
            require(r['budgets']['days'] == days, 'incomplete daily balances')
            for key in ('max_water_cm', 'max_kernel_cm', 'max_solute_mg_cm2'):
                v = r['budgets'][key]
                require(math.isfinite(v) and 0 <= v <= 1e-10, 'balance limit: '+key)
            windows = {(w['start'], w['end']) for w in r['restart_windows']}
            target = {(50, 52), (530, 532)} if name == 'undrained' else ({(109, 111)} if name == 'salt' else {(365, 367)})
            require(windows == target, 'missing own restart window')
            for w in r['restart_windows']:
                require(all(w[k] is True for k in ('exact_physical', 'exact_csv', 'exact_native_auxiliary', 'origin_unchanged')), 'nonexact native own restart')


def validate_l(q, preservation, components):
    require(q['runtime_source'] == preservation['runtime_source'] == L_RUNTIME, 'foreign L source')
    require(q['status'] == 'ALL_SELECTED_PRESCRIBED_HEAD_FULL_TRAJECTORIES_AND_OWN_RESTARTS_PASS', 'L incomplete')
    require(q['full_configurations'] == 6 and q['complete_model_days'] == 6576, 'L full trajectory count')
    require(q['science'] == preservation['science'] == 'NOT_QUALIFIED', 'L scientific promotion')
    expected = {mode+'-head-'+kind for mode in ('water', 'chemical') for kind in ('fixed', 'table', 'bbc')}
    records = [r for report in q['reports'].values() for r in report['configurations']]
    full = [r for r in records if r['full_period_pass']]
    require(len(full) == 6 and {r['configuration'] for r in full} == expected, 'L missing configuration')
    for r in records:
        require(r['exact_day_suffix'] and r['exact_native_auxiliary'] and r['active_crop_exact_native_window'] == [530, 532], 'L native continuation')
        for key in ('maximum_water_residual_cm', 'maximum_solute_residual_mg_cm2'):
            v = r[key]
            require(v is None or math.isfinite(v) and 0 <= v <= 1e-10, 'L hard balance')
        if r['full_period_pass']:
            require(r['completed_days'] == r['requested_days'] == 1096, 'L partial trajectory')
            require(all(r[k] is True for k in ('foreign_lower_receipt_refused_before_output', 'independent_distinct_origins', 'external_discard_replay_exact', 'external_disk_recovery', 'inconsistent_mass_refused_without_commit')), 'L transaction/binding preservation')
    windows = q['natural_regime_windows']
    require(len(windows) == 24 and {(w['configuration'], w['optimization'], w['regime']) for w in windows} == {(n, opt, regime) for n in expected for opt in ('O0', 'O2') for regime in ('inflow', 'outflow')}, 'L signed outlet window coverage')
    require(all(w['physical_exact'] and w['native_exact'] and w['origins_unchanged'] for w in windows), 'L nonexact outlet restart')
    require(q['original_full_invalid_DATE5_refused'] and q['short_past_all_knots_cold_exact'], 'L original table validation contract')
    require(preservation['status'] == 'L_CURRENT_CLOSED6_AND_NAMED_PRESERVATION_PASS', 'L preservation incomplete')
    p = preservation['profiles']
    require(set(p) == {'O0', 'O2', 'grass', 'hupsel', 'salt'}, 'L preservation cohort')
    for opt in ('O0', 'O2'):
        require(p[opt]['all_generated_execution_sources_exact'] and p[opt]['all_1096_physical_daily_rows_exact'], 'L closed6 physical/source drift')
    for name in ('grass', 'hupsel', 'salt'):
        require(p[name]['status'] == 'ACTUAL_NAMED_GENERATED_SOURCES_AND_INPUTS_EXACT' and p[name]['publisher_source_exact'] and p[name]['budget_source_git_blob_exact'], 'L named dependency drift')
    require(components['runtime_source'] == L_RUNTIME, 'foreign component source')
    require(components['prescribed_head']['status'] == 'PRODUCTION_ORIGINAL_PRESCRIBED_HEAD_RECEIPT_O0_O2_PASS', 'L receipt component')
    require(components['soil_air']['status'] == 'PRODUCTION_ORIGINAL_SOIL_AIR_RECEIPT_O0_O2_PASS', 'L soil-air component')
    require(components['pond']['status'] == 'ORIGINAL_LINEAR_POND_TANGENT_O0_O2_PASS' and set(components['pond']['profiles']) == {'O0', 'O2'}, 'L pond component')


def verify_l(c):
    git('merge-base', '--is-ancestor', L_RUNTIME, L_SEALED)
    git('merge-base', '--is-ancestor', L_SEALED, 'HEAD')
    require(not git('diff', L_RUNTIME, L_ADMITTED, '--', 'src', 'app', 'reference', 'tools'), 'admitted L runtime differs from qualified L source')
    # The immutable seal contains reviewed docs/evidence, not a moving allowlist.
    # Later changes may update only this selector/tests and the admission receipt.
    paths = set(git('diff', '--name-only', L_SEALED, L_ADMITTED).decode().splitlines())
    require(paths <= {SELF, TEST, L_PROOF+'BLOCK_L_MERGE.json', L_PROOF+'BLOCK_L_CI_SELECTION.json'}, 'unqualified delta after L evidence seal')
    def sealed_json(name):
        path = L_PROOF+name+'.json'
        require(blob('HEAD', path) == blob(L_SEALED, path), 'L sealed proof changed: '+name)
        return json.loads((ROOT/path).read_text())
    q = sealed_json('BLOCK_L_QUALIFICATION')
    p = sealed_json('BLOCK_L_CURRENT_PRESERVATION')
    components = sealed_json('BLOCK_L_COMPONENT_RESULT')
    validate_l(q, p, components)
    validate_runs(dict(O0={'undrained': p['profiles']['O0']['full']}, O2={'undrained': p['profiles']['O2']['full']}, named=c['Windows']['named']))
    for label in ('FIRST_MATRIX', 'READER_MATRIX', 'READER_DEFAULT', 'FULL_TRAJECTORIES', 'LOCAL', 'DEFAULT_PRESERVATION'):
        m = sealed_json('BLOCK_L_'+label+'_ARCHIVE')
        path = L_PROOF+m['archive']
        require(hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == m['sha256'], 'L raw capsule identity: '+label)
    return q, p


def validate_m(q, previous, pond, components):
    require(q['qualification_source'] == M_RUNTIME and q['runtime_source'] == M_EXECUTED, 'foreign M source')
    require(q['status'] == 'ALL_SIX_ORIGINAL_SURFACE_INPUT_CONFIGURATIONS_QUALIFIED', 'M incomplete')
    require(q['full_configurations'] == 6 and q['complete_model_days'] == 6576 and q['full_period_optimization'] == 'O2', 'M full count/profile')
    require(q['mass_guard_cm'] == 1e-10 and q['mass_guard_changed'] is False, 'M mass guard changed')
    require(q['whole_scientific_equivalence'] == 'NOT_QUALIFIED' and q['nominal_runon_1e10_accuracy'].startswith('FAILED_NOT_QUALIFIED'), 'M failed diagnostic promoted')
    expected = {mode+'-'+kind for mode in ('water', 'chemical') for kind in ('pond-table', 'runon-file', 'surface-combined')}
    require(set(q['reports']) == expected, 'M missing configuration')
    for field in ('maximum_water_residual_cm', 'maximum_solute_residual_mg_cm2'):
        v = q[field]
        require(math.isfinite(v) and 0 <= v <= 1e-10, 'M summary hard balance')
    for key, report in q['reports'].items():
        old = key.endswith('pond-table')
        require(q['per_configuration_executed_sources'][key] == (M_POND_EXECUTED if old else M_EXECUTED), 'M execution provenance')
        require(report['status'] == 'EXPERIMENTAL_SURFACE_INPUT_OPTIONS_PASS', 'M incomplete case')
        if not old:
            require(report['executed_runtime_source'] == M_EXECUTED and report['source_commit'] == M_RUNTIME and report['resumed_exact_run'] == 43864567262 and report['completed_physics_reexecuted'] is False, 'M completed physics rebound/rerun')
            require(report['original_references']['literal'].get('retained_original_output_failure') is True, 'M literal failure erased')
            require(report['original_references']['csv']['swap_ok'] is True and len(report['events']) == 16 and all(e['returncode'] != 0 and e['expected_refusal'] for e in report['events']), 'M missing completion checks')
        records = report['configurations']
        require(len(records) == 2 and {r['optimization'] for r in records} == {'O0', 'O2'}, 'M optimization coverage')
        for r in records:
            require(r['configuration'] == key, 'M foreign configuration report')
            require(not r['solute_active'] or r['maximum_solute_residual_mg_cm2'] is not None, 'M missing chemical balance')
            require(r['exact_day_suffix'] and r['exact_native_auxiliary'] and r['active_crop_exact_native_window'] == [530, 532], 'M nonexact native continuation')
            for field in ('maximum_water_residual_cm', 'maximum_solute_residual_mg_cm2'):
                v = r[field]
                require(v is None or math.isfinite(v) and 0 <= v <= 1e-10, 'M hard balance')
            w = r['surface_event_exact_native_windows']
            require(w['physical_exact'] and w['native_exact'] and w['origins_unchanged'] and w['windows'] == [[199, 201], [529, 531]], 'M event continuation')
            if r['optimization'] == 'O2':
                require(r['full_period_pass'] and r['completed_days'] == r['requested_days'] == 1096, 'M partial full trajectory')
                require(all(r[k] is True for k in ('foreign_surface_schedule_refused_before_output', 'independent_distinct_origins', 'external_discard_replay_exact', 'external_disk_recovery', 'inconsistent_mass_refused_without_commit')), 'M transaction/binding preservation')
                if not old:
                    witness = r['original_runon_event_witness']
                    require(witness['original_clock_contract_pass'] and witness['original_dtCrit_days'] == 1e-8, 'M original event clock changed')
                    require({v['day'] for v in witness['records']} == {3, 200, 365, 530, 730}, 'M missing pulse')
                    require(any(v['strict_nominal_1e10_diagnostic_pass'] is False for v in witness['records']), 'M nominal failure erased')
                    for v in witness['records']:
                        nominal = {3: 8*.1, 200: 12*.1, 365: 6*.1, 530: 10*.1, 730: 4*.1}[v['day']]
                        require(v['nominal_cm'] == nominal and v['difference_cm'] == v['actual_integrated_cm']-nominal, 'M altered pulse quantity/diagnostic')
                        require(v['original_event_clock_bound_cm'] == 2e-8*nominal+8*math.ulp(nominal), 'M inflated clock uncertainty')
                        require(math.isfinite(v['actual_integrated_cm']) and abs(v['difference_cm']) <= v['original_event_clock_bound_cm'], 'M event input outside original clock contract')
                        require(v['strict_nominal_1e10_diagnostic_pass'] == (abs(v['difference_cm']) <= 1e-10), 'M false nominal diagnostic')
    require(previous['status'] == 'M_INACTIVE_L5_CLOSED6_SOURCE_PRESERVATION_PASS' and previous['runtime_source'] == M_EXECUTED and previous['all_host_execution_functions_classes_AST_exact'], 'M prior execution ownership drift')
    require(set(previous['profiles']) == {'head5', 'closed6'} and all(p['status'] == 'ACTUAL_PRIOR_EXECUTION_SOURCES_AND_INPUTS_PRESERVED' and p['generated'] and p['kernel_sources'] for p in previous['profiles'].values()), 'M missing prior source preservation')
    require(pond['status'] == 'BOTH_POND_TABLE_FULL_AND_NATIVE_COHORTS_INHERITED_ON_ACTUAL_SOURCE_PRESERVATION' and pond['runtime_source'] == M_EXECUTED and pond['prior_runtime_source'] == M_POND_EXECUTED, 'M pond inheritance identity')
    require(set(pond['profiles']) == {m+'-pond-table-'+o for m in ('water', 'chemical') for o in ('O0', 'O2')} and all(p['status'] == 'POND65_FULL_AND_NATIVE_DEPENDENCY_PRESERVED' for p in pond['profiles'].values()), 'M unqualified pond dependency')
    require(components['runon_reader']['status'] == 'COMPLETE_ORIGINAL_RUNON_READER_O0_O2_PASS' and components['pond_component']['status'] == 'ACTUAL_ORIGINAL_SCHEDULED_POND_O0_O2_PASS', 'M component qualification missing')
    require(components['original_invalid_table']['status'] == 'ORIGINAL_FULL_INVALID_POND_TABLE_REFUSED_ZERO_DAYS', 'M original invalid-domain guard')


# Test/evidence-only additions have no production dependency delta. These
# exact files retain their own native FAILs; M qualification is not extended.
M_VERIFICATION_ONLY = {'tests/nomacro_mixtures/run.py': '23a6d79b62fb9fee24a059373cfcb6330f536f49', 'tests/nomacro_mixtures/finish.py': 'fad203c6a37c8ab1e812b584aa94769249c5f0b9', 'integration/nomacro-mixtures01/COMPLETION.json': 'c591aa527fefef3695e179bc53e7e631924a6163', 'integration/nomacro-mixtures01/INITIAL_RESULT.json': '5da7bf8def2233fbc259a4c6cd464b13149c811e', 'integration/nomacro-mixtures01/INPUTS.json': 'd089d6ed5845b4af26b5b3abb9614e7a2c9f8862', 'integration/nomacro-mixtures01/RAW_MANIFEST.json': '2eef14da5461df914c65731877e799095faabba8', 'integration/nomacro-mixtures01/RAW_PLATE.zip': '85a99043ad1c9397dead33b570937ef86b6cbdd2', 'integration/nomacro-mixtures01/RAW_SURFACE.zip': '4171ee373b4737d12f4866cc3c0ddd84bc513cd2', 'integration/nomacro-mixtures01/README.md': '40fe36c323085f628e2be0c606d7d4cbf21adbd0', 'integration/nomacro-mixtures01/RECOVERY.md': '1025a76512ac44831bd46c1fac9877926044b787', 'integration/nomacro-mixtures01/SUMMARY.json': '907dd6ee8fc45900c436f273c09b7bda8a24f69c'}


def verify_m():
    git('merge-base', '--is-ancestor', M_RUNTIME, M_SEALED)
    git('merge-base', '--is-ancestor', M_SEALED, 'HEAD')
    git('merge-base', '--is-ancestor', L_ADMITTED, M_RUNTIME)
    require(not git('diff', M_RUNTIME, M_ADMITTED, '--', 'src', 'app', 'reference', 'tools'), 'runtime differs from qualified M source')
    require(not git('diff', M_EXECUTED, M_RUNTIME, '--', 'src', 'app', 'reference', 'tools/solute/run_water.py', 'tools/solute/surface_input_cases.py', 'tools/solute/qualify_surface_schedule.py'), 'M physical runtime changed during verification completion')
    paths = set(git('diff', '--name-only', M_SEALED, M_ADMITTED).decode().splitlines())
    require(paths <= {SELF, TEST, L_PROOF+'BLOCK_M_CI_SELECTION.json', L_PROOF+'BLOCK_M_MERGE.json'} | set(M_VERIFICATION_ONLY), 'unqualified delta after M evidence seal')
    for path, expected in M_VERIFICATION_ONLY.items():
        require(git('rev-parse', 'HEAD:'+path).decode().strip() == expected, 'changed test-only mixture file: '+path)
    def sealed_json(name):
        path = L_PROOF+name+'.json'
        require(blob('HEAD', path) == blob(M_SEALED, path), 'M sealed proof changed: '+name)
        return json.loads((ROOT/path).read_text())
    q = sealed_json('BLOCK_M_QUALIFICATION')
    validate_m(q, sealed_json('BLOCK_M_PRIOR_SOURCE_PRESERVATION'), sealed_json('BLOCK_M_POND_SOURCE_PRESERVATION'), sealed_json('BLOCK_M_LOCAL_ASSESSMENT'))
    grass = sealed_json('BLOCK_M_GRASS_SOURCE_PRESERVATION')
    require(grass['status'] == 'M_ACTUAL_REGISTERED_GRASS_EXECUTION_SOURCES_EXACT_TO_SEALED_L' and grass['runtime_source'] == M_EXECUTED and grass['qualification_source'] == M_RUNTIME and grass['generated'] and grass['kernel_sources'] and grass['inputs'], 'M named Grassgrowth source preservation')
    for label in ('FIRST_MATRIX', 'FULL_RUNON_WITNESS_FAILURE', 'FIRST_DEFAULT', 'DEFAULT_PRESERVATION', 'FIRST_COMPLETION', 'LITERAL_REFERENCE_FAILURE', 'COMPLETED_RUNON', 'LOCAL'):
        m = sealed_json('BLOCK_M_'+label+'_ARCHIVE')
        require(hashlib.sha256((ROOT/L_PROOF/m['archive']).read_bytes()).hexdigest() == m['sha256'], 'M raw capsule identity: '+label)
    return q


def validate_n(q, preservation, component, inline, refused):
    require(q['runtime_source'] == preservation['runtime_source'] == inline['source_commit'] == refused['source_commit'] == N_RUNTIME, 'foreign N source')
    require(q['status'] == 'ALL_SIX_EXTERNAL_FIXED_IRRIGATION_CONFIGURATIONS_QUALIFIED', 'N incomplete')
    require(q['full_configurations'] == 6 and q['complete_model_days'] == 6576 and q['full_period_optimization'] == 'O2', 'N full count/profile')
    require(q['mass_guard_cm'] == 1e-10 and q['mass_guard_changed'] is False and q['new_state_codec'] is False and q['solver_or_time_policy_changed'] is False, 'N changed conservation/runtime policy')
    require(q['whole_scientific_equivalence'] == 'NOT_QUALIFIED' and q['chemical_subsurface'].startswith('EXPLICIT_NATIVE_REFUSAL') and q['reversed_or_outside_depth'].startswith('EXPLICIT_NATIVE_REFUSAL'), 'N unsupported physics promoted')
    expected = {'water-file-'+k for k in ('sprinkler','surface','subsurface','subsurface-interval')} | {'chemical-file-'+k for k in ('sprinkler','surface')}
    require(set(q['reports']) == expected, 'N missing configuration')
    for field in ('maximum_water_residual_cm', 'maximum_solute_residual_mg_cm2'):
        v = q[field]; require(math.isfinite(v) and 0 <= v <= 1e-10, 'N summary hard balance')
    for key, report in q['reports'].items():
        require(report['source_commit'] == N_RUNTIME and report['status'] == 'EXPERIMENTAL_FIXED_IRRIGATION_FILE_OPTIONS_PASS', 'N report identity')
        records = report['configurations']
        require(len(records) == 2 and {r['optimization'] for r in records} == {'O0','O2'}, 'N optimization coverage')
        for r in records:
            require(r['configuration'] == key and r['exact_day_suffix'] and r['exact_native_auxiliary'] and r['active_crop_exact_native_window'] == [530,532], 'N own native continuation')
            require(r['solute_active'] == key.startswith('chemical-'), 'N chemical dispatch')
            require(not r['solute_active'] or r['maximum_solute_residual_mg_cm2'] is not None, 'N missing chemical balance')
            for field in ('maximum_water_residual_cm','maximum_solute_residual_mg_cm2'):
                v = r[field]; require(v is None or math.isfinite(v) and 0 <= v <= 1e-10, 'N hard balance')
            w = r['fixed_irrigation_event_exact_native_windows']
            require(w['physical_exact'] and w['native_exact'] and w['origins_unchanged'] and w['windows'] == [[4,6]], 'N event continuation')
            kind = 2 if 'subsurface' in key else (0 if key.endswith('sprinkler') else 1)
            require(r['original_irrigation_type'] == kind, 'N irrigation type')
            channels = w['actual_fixed_irrigation_cm']['5']
            used, unused = ('subsurface','gross_surface') if kind == 2 else ('gross_surface','subsurface')
            require(math.isfinite(channels[used]) and channels[used] > 0 and channels[unused] == 0, 'N missing/wrong input channel')
            if r['optimization'] == 'O2':
                require(r['full_period_pass'] and r['completed_days'] == r['requested_days'] == 1096, 'N partial trajectory')
                require(all(r[k] is True for k in ('foreign_fixed_file_policy_refused_before_output','independent_distinct_origins','external_discard_replay_exact','external_disk_recovery','inconsistent_mass_refused_without_commit')), 'N transaction/binding preservation')
    events = q['event_windows']
    require(len(events) == 12 and {(w['configuration'],w['optimization']) for w in events} == {(k,o) for k in expected for o in ('O0','O2')}, 'N event cohort')
    require(all(w['physical_exact'] and w['native_exact'] and w['origins_unchanged'] and w['window'] == [4,6] for w in events), 'N event summary drift')
    require(preservation['status'] == 'N_PRIOR_M_L5_AND_NAMED_SOURCE_PRESERVATION_PASS' and preservation['science'] == 'NOT_QUALIFIED', 'N prior-source preservation')
    require(set(preservation['profiles']) == {'water-surface-combined','chemical-surface-combined','registered-grass','prescribed-head5'}, 'N missing prior cohort')
    require(all(p['status'] == 'ACTUAL_PRIOR_SOURCE_INPUT_AND_POLICY_PRESERVED' and p['generated'] and p['kernel_sources'] and p['inputs'] for p in preservation['profiles'].values()), 'N prior dependency drift')
    require(component['status'] == 'ACTUAL_GUARDED_FIXED_IRRIGATION_FILE_O0_O2_PASS' and component['subsurface_chemical'].startswith('EXPLICIT_NATIVE_REFUSAL'), 'N original component')
    require(len(component['profiles']) == 2 and {p['optimization'] for p in component['profiles']} == {'O0','O2'}, 'N component optimization')
    for p in component['profiles']:
        require(len(p['positive']) == 6 and all(v['returncode'] == 0 and not v['refused'] and v['values'] for v in p['positive']), 'N component delivery')
        require(not p['past_last']['refused'] and p['past_last']['values'][0][0] == '3', 'N exhausted-table continuation')
        require(len(p['refusals']) == 9 and len(p['chemical_type2_refusals']) == 2 and all(v['refused'] and v['values'] is None for v in p['refusals']+p['chemical_type2_refusals']), 'N original domain/chemical refusals')
    require(inline['status'] == 'ACTUAL_INLINE_AND_FILE_STORAGE_EQUIVALENCE_PASS' and len(inline['profiles']) == 2 and all(p['physical_all_six_days_exact'] and p['final_native_payload_exact'] for p in inline['profiles']), 'N storage representation drift')
    require(refused['status'] == 'ACTUAL_UNSUPPORTED_CHEMICAL_AND_REVERSED_GEOMETRY_REFUSALS_PASS' and {p['name'] for p in refused['profiles']} == {'chemical-subsurface','reversed-depth'} and all(p['status'] == 'ACTUAL_NATIVE_INPUT_REFUSAL_ZERO_ACCEPTED_DAYS' for p in refused['profiles']), 'N unsupported native input accepted')


def verify_n():
    git('merge-base','--is-ancestor',N_RUNTIME,N_SEALED)
    git('merge-base','--is-ancestor',N_SEALED,'HEAD')
    git('merge-base','--is-ancestor',M_ADMITTED,N_RUNTIME)
    require(not git('diff',N_RUNTIME,N_ADMITTED,'--','src','app','reference','tools'), 'runtime differs from qualified N source')
    paths = set(git('diff','--name-only',N_SEALED,N_ADMITTED).decode().splitlines())
    require(paths <= {SELF,TEST,L_PROOF+'BLOCK_N_CI_SELECTION.json',L_PROOF+'BLOCK_N_MERGE.json'}, 'unqualified delta after N evidence seal')
    def sealed_json(name):
        path = L_PROOF+name+'.json'
        require(blob('HEAD',path) == blob(N_SEALED,path), 'N sealed proof changed: '+name)
        return json.loads((ROOT/path).read_text())
    q = sealed_json('BLOCK_N_QUALIFICATION')
    validate_n(q,sealed_json('BLOCK_N_PRIOR_SOURCE_PRESERVATION'),sealed_json('BLOCK_N_GUARDED_COMPONENT_RESULT'),sealed_json('BLOCK_N_INLINE_FILE_EQUIVALENCE'),sealed_json('BLOCK_N_ACTUAL_NATIVE_REFUSALS'))
    for label in ('FULL_TRAJECTORIES','DEFAULT_PRESERVATION','LOCAL'):
        m = sealed_json('BLOCK_N_'+label+'_ARCHIVE')
        require(hashlib.sha256((ROOT/L_PROOF/m['archive']).read_bytes()).hexdigest() == m['sha256'], 'N raw capsule identity: '+label)
    for name in ('ORIGINAL_COMPONENT_RESULT','REVERSED_INTERVAL_DIAGNOSTIC','WINDOWS_SHORT_RESULT','DEFAULT_PRESERVATION_RESULT','ASSESSMENT'):
        sealed_json('BLOCK_N_'+name)
    return q


def validate_o(q, previous, component, legacy, defaults):
    require(q['runtime_source'] == O_RUNTIME and q['Windows_execution_source'] == O_WINDOWS and q['Windows_runtime_surface_exact_to_Ubuntu'], 'foreign O execution source')
    require(q['status'] == 'BOTH_PLATFORMS_COMPLETE_SCHEDULED_POND_HISTORY_O0_O2_QUALIFIED' and q['full_configurations'] == 2 and q['full_trajectories'] == 8 and q['complete_model_days'] == 8768 and q['full_native_windows'] == 32, 'O incomplete full/native cohort')
    require(q['mass_guard_cm'] == 1e-10 and q['tolerances_changed'] is False and q['physical_equations_changed'] is False, 'O changed conservation/physics')
    require(q['whole_scientific_equivalence'] == q['whole_energy'] == 'NOT_QUALIFIED' and q['old_failed_mixture_evidence'].startswith('UNCHANGED'), 'O historical science/native failure promoted')
    for field in ('maximum_water_residual_cm','maximum_kernel_residual_cm','maximum_solute_residual_mg_cm2'):
        v=q[field];require(math.isfinite(v) and 0<=v<=1e-10, 'O summary hard balance')
    require(set(q['platforms']) == {'Windows','Ubuntu'}, 'O missing platform')
    for platform,cases in q['platforms'].items():
        require(set(cases) == {'water-surface-history','chemical-surface-history'}, 'O missing physical case')
        for key,report in cases.items():
            require(report['source_commit'] == (O_WINDOWS if platform=='Windows' else O_RUNTIME) and report['status'] == 'COMPLETE_SCHEDULED_POND_HISTORY_O0_O2_PASS', 'O report provenance')
            require(set(report['profiles']) == {'O0','O2'} and report['science'] == 'NOT_QUALIFIED' and report['water_guard_cm'] == report['solute_guard_mg_cm2'] == 1e-10, 'O optimization/guard coverage')
            for r in report['profiles'].values():
                require(r['status'] == 'FULL_PASS' and r['days'] == r['budgets']['days'] == 1096, 'O partial trajectory')
                for field in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):
                    v=r['budgets'][field];require(math.isfinite(v) and 0<=v<=1e-10, 'O daily hard balance')
                if platform=='Windows':require(r['all_1096_physical_rows_exact_to_failed_source'], 'O prior physical drift')
                require(r['short']['status'] == 'SHORT_PASS' and r['short']['days'] == 5 and r['short']['own']['exact_native'], 'O missing local short native gate')
                require(len(r['own']) == 4 and {(w['start'],w['end']) for w in r['own']} == {(2,4),(199,201),(365,367),(530,532)}, 'O missing full native window')
                require(all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['own']), 'O nonexact native continuation')
                c=r['controls'];require(all(c[k] is True for k in ('foreign_policy_refused','independent_origins','inconsistent_mass_refused','external_discard_replay_exact','external_disk_recovery')), 'O transaction/isolation preservation')
                require(len(c['native_refusals']) == 4 and {v['name'] for v in c['native_refusals']} == {'old-format','pond-nan','pond-negative','foreign-clock'} and all(v['returncode'] != 0 and v['accepted_days'] == 0 for v in c['native_refusals']), 'O native domain accepted')
    require(previous['status'] == 'O_PRIOR_J_PLATE_N_M_L5_AND_NAMED_SOURCE_PRESERVATION_PASS' and previous['qualification_source'] == O_RUNTIME and previous['qualified_runtime_surface_exact'], 'O prior-source identity')
    require(set(previous['profiles']) == {'water-surface-combined','chemical-surface-combined','registered-grass','prescribed-head5','water-file-subsurface-interval','chemical-file-sprinkler','water-plate-history','chemical-plate-history'}, 'O missing prior cohort')
    require(all(p['status'] == 'ACTUAL_PRIOR_GENERATED_SOURCES_INPUTS_POLICIES_EXACT' and p['generated'] and p['kernel_sources'] and p['inputs'] for p in previous['profiles'].values()), 'O prior dependency drift')
    for c,status,n in ((component,'PRODUCTION_ORIGINAL_SCHEDULED_POND_CODEC_O0_O2_PASS',18),(legacy,'PRODUCTION_ORIGINAL_TOP_HISTORY_CODEC_O0_O2_PASS',15)):
        require(c['status'] == status and len(c['profiles']) == 2 and {p['optimization'] for p in c['profiles']} == {'O0','O2'}, 'O complete original codec component')
        require(all(p['roundtrip_exact'] and p['staged_read_before_assignment'] and p['positive']['returncode'] == 0 and len(p['refusals']) == n and all(v['returncode'] != 0 for v in p['refusals']) for p in c['profiles']), 'O component roundtrip/domain/staging')
    require(defaults['status'] == 'EXPERIMENTAL_GENERIC_SURFACE_SMOKE_PASS' and defaults['source_commit'] == O_RUNTIME and len(defaults['profiles']) == 8 and all(p['every_exercised_native_exact'] for p in defaults['profiles']), 'O default preservation')


def verify_o():
    git('merge-base','--is-ancestor',O_RUNTIME,O_SEALED)
    git('merge-base','--is-ancestor',O_SEALED,'HEAD')
    git('merge-base','--is-ancestor',N_ADMITTED,O_RUNTIME)
    surface=('src','app','reference','tools','tests/nomacro_pond_history','tests/nomacro_mixtures')
    require(not git('diff',O_RUNTIME,O_ADMITTED,'--',*surface), 'runtime differs from qualified O source')
    require(not git('diff',O_WINDOWS,O_RUNTIME,'--',*surface), 'O Windows/Ubuntu physical runtime differs')
    paths=set(git('diff','--name-only',O_SEALED,O_ADMITTED).decode().splitlines())
    require(paths <= {SELF,TEST,L_PROOF+'BLOCK_O_CI_SELECTION.json',L_PROOF+'BLOCK_O_MERGE.json'}, 'unqualified delta after O evidence seal')
    def sealed_json(name):
        path=L_PROOF+name+'.json';require(blob('HEAD',path)==blob(O_SEALED,path), 'O sealed proof changed: '+name)
        return json.loads((ROOT/path).read_text())
    q=sealed_json('BLOCK_O_QUALIFICATION')
    validate_o(q,sealed_json('BLOCK_O_PRIOR_SOURCE_PRESERVATION'),sealed_json('BLOCK_O_COMPONENT_RESULT'),sealed_json('BLOCK_O_LEGACY_COMPONENT_RESULT'),sealed_json('BLOCK_O_DEFAULT_PRESERVATION_RESULT'))
    for label in ('FULL_TRAJECTORIES','DEFAULT_PRESERVATION','LOCAL'):
        m=sealed_json('BLOCK_O_'+label+'_ARCHIVE');require(hashlib.sha256((ROOT/L_PROOF/m['archive']).read_bytes()).hexdigest()==m['sha256'], 'O raw capsule identity: '+label)
    sealed_json('BLOCK_O_OBSERVATION')
    return q


def validate_p(q,current,later,previous,component,defaults,references):
    require(q['status']=='TWO_FREE_ORIGINAL_PARTIAL_FROST_CONFIGURATIONS_QUALIFIED' and q['runtime_source']==CURRENT_RUNTIME and q['Windows_execution_source']==P_WINDOWS, 'foreign/incomplete P source')
    require(q['full_configurations']==2 and q['full_trajectories']==8 and q['complete_model_days']==8768 and q['full_native_standard_windows']==32 and q['active_native_windows']==48, 'P incomplete full/native cohort')
    require(q['mass_guard_cm']==1e-10 and not q['tolerances_changed'] and not q['solver_or_time_policy_changed'] and not q['new_persistent_frost_codec'] and not q['global_B1_snapshot_promoted'], 'P changed physical/numerical/reference policy')
    require(q['whole_scientific_equivalence']==q['whole_energy']=='NOT_QUALIFIED' and 'day21' in q['retained_failures'] and 'preflight-refused' in q['retained_failures'], 'P failed coupled frost/science promoted')
    def mass(value):
        require(type(value) in (float,int) and math.isfinite(value) and 0<=value<=1e-10, 'P hard balance')
    for name in ('maximum_water_residual_cm','maximum_kernel_residual_cm','maximum_solute_residual_mg_cm2'):mass(q[name])
    require(set(q['platforms'])=={'Windows','Ubuntu'}, 'P missing platform')
    cuts={(9,11),(170,172),(374,376),(535,537),(739,741),(901,903)}
    for platform,cases in q['platforms'].items():
        require(set(cases)=={'water-frost-free','chemical-frost-free'}, 'P unsupported or missing physical scope')
        for key,report in cases.items():
            require(report['source_commit']==(P_WINDOWS if platform=='Windows' else CURRENT_RUNTIME) and report['status']=='COMPLETE_BOUNDED_FROST_O0_O2_PASS' and report['science']=='NOT_QUALIFIED', 'P report provenance')
            selected=report['selected_physical_controls']
            require(selected['SWDRA']==0 and selected['SWBOTB']==7 and selected['SWTOPBHEA']==2 and selected['future_crop_SWDROUGHT']==1 and selected['SWSOLU']==int(key.startswith('chemical')), 'P unqualified drainage/root/forcing dispatch')
            require(set(report['profiles'])=={'O0','O2'}, 'P optimization scope')
            for r in report['profiles'].values():
                require(r['status']=='FULL_PASS' and r['days']==r['budgets']['days']==1096, 'P partial trajectory')
                for name in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):mass(r['budgets'][name])
                require(len(r['own'])==4 and {(w['start'],w['end']) for w in r['own']}=={(2,4),(199,201),(365,367),(530,532)} and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['own']), 'P standard native continuation')
                w=r['frost_witness'];records=w['actual_records']
                require(w['actual_daily_original_records']==len(records)==1096 and len(w['initial_original_uncomputed_diagnostic'])==6 and w['initial_original_uncomputed_diagnostic'][-1]==0, 'P initial datum counted as accepted day')
                require(all(len(v)==6 and all(math.isfinite(x) for x in v) and 0<=v[0]<=v[1]<=1 and v[-1]==1 for v in records), 'P invalid original frost witness')
                require(w['days_with_reduction']==sum(v[0]<1 for v in records)>0 and w['minimum_rfcp']==min(v[0] for v in records) and w['days_with_zero_factor']==0, 'P false or fully-blocked activation claim')
                if key.startswith('chemical'):require(w.get('total_original_frost_uptake_reduction_cm',0)>0, 'P chemical/root frost not exercised')
                active=r['active_frost_exact_native_windows']
                if platform=='Ubuntu':
                    require(len(active)==6 and {(v['start'],v['end']) for v in active}==cuts and all(all(v[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for v in active), 'P current all-year active native continuation')
                else:require(active['windows']==[[9,11],[170,172]] and active['native_exact'] and active['physical_exact'] and active['origins_unchanged'], 'P original completed Windows active windows')
                c=r['controls'];require(all(c[k] is True for k in ('foreign_policy_refused','independent_origins','inconsistent_mass_refused','external_discard_replay_exact','external_disk_recovery')), 'P transaction/isolation guard')
                require(len(c['native_refusals'])==4 and all(v['returncode']!=0 and v['accepted_days']==0 for v in c['native_refusals']), 'P native invalid state accepted')
    expected={mode+'-'+opt for mode in ('water','chemical') for opt in ('O0','O2')}
    require(current['runtime_source']==P_PRESERVATION and current['prior_executed_source']==P_WINDOWS and current['status']=='P_FOUR_COMPLETED_FREE_FROST_TRAJECTORIES_INHERITED_ON_FRESH_EXACT_SOURCE_AND_ACTIVE_NATIVE_PRESERVATION' and set(current['profiles'])==expected, 'P current inheritance provenance')
    require(all(v['status']=='ACTUAL_CURRENT_FREE_FROST_SOURCES_INPUTS_AND_ACTIVE_NATIVE_PRESERVED' and v['generated'] and v['kernel_sources'] and v['inputs'] and v['all_172_physical_rows_exact_to_prior_full'] and len(v['actual_prefix']['own'])==3 and all(w['exact_native'] and w['exact_physical'] and w['exact_csv'] and w['origin_unchanged'] for w in v['actual_prefix']['own']) for v in current['profiles'].values()), 'P inherited physical/native dependency drift')
    require(later['status']=='ALL_FOUR_CURRENT_LATER_YEAR_FROST_NATIVE_PASS' and set(later['profiles'])==expected, 'P missing later-year Windows closure')
    for r in later['profiles'].values():
        require(r['current_source']==CURRENT_RUNTIME and r['native_start_day']==172 and r['accepted_days']==731 and r['all_physical_rows_exact_to_prior_full'], 'P later-year physical/source drift')
        require(len(r['own'])==4 and {(v['start'],v['end']) for v in r['own']}==cuts-{(9,11),(170,172)} and all(all(v[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) and v['full_trace_origin_day']==172 for v in r['own']), 'P later-year native/csv origin')
    require(previous['status']=='P_PRIOR_O_J_PLATE_N_M_L5_AND_NAMED_SOURCE_PRESERVATION_PASS' and previous['runtime_source']==CURRENT_RUNTIME and len(previous['profiles'])==10 and all(v['status']=='ACTUAL_PRIOR_GENERATED_SOURCES_INPUTS_POLICIES_EXACT' and v['generated'] and v['kernel_sources'] and v['inputs'] for v in previous['profiles'].values()), 'P prior capability source preservation')
    require(component['status']=='ACTUAL_ORIGINAL_GUARDED_FROST_COMPONENT_O0_O2_PASS' and set(component['profiles'])=={'O0','O2'} and component['original_reporting_differences']=={'O0':2,'O2':2}, 'P original component/source failure erased')
    for r in component['profiles'].values():
        require(r['physical_cases_exact_original_guarded']==24 and len(r['guarded']['records'])==7 and all(v['returncode']!=0 for v in r['guarded']['records'][1:]), 'P original component invalid-domain publication')
    require(defaults['status']=='EXPERIMENTAL_GENERIC_SURFACE_SMOKE_PASS' and defaults['source_commit']==CURRENT_RUNTIME and len(defaults['profiles'])==8 and all(v['every_exercised_native_exact'] for v in defaults['profiles']), 'P default source/native preservation')
    require(references['corrected_source_sha256']=='d5dd195187d4581e09d19e6afdd4066c0fdb23eee84f8f87947251d2778724d2' and len(references['profiles'])==2 and all(v['status']=='COMPLETE_CORRECTED_ORIGINAL_DIAGNOSTIC_REFERENCE' and v['original_rows']==v['swap5_rows']==1097 and v['scientific_equivalence']=='NOT_QUALIFIED' and v['identical_executed_inputs'] for v in references['profiles'].values()), 'P original diagnostic promoted or incomplete')


def verify_p():
    git('merge-base','--is-ancestor',CURRENT_RUNTIME,P_SEALED);git('merge-base','--is-ancestor',P_SEALED,'HEAD');git('merge-base','--is-ancestor',O_ADMITTED,CURRENT_RUNTIME)
    require(not git('diff',CURRENT_RUNTIME,P_ADMITTED,'--','app','src','reference','tools','tests/nomacro_frost','tests/nomacro_pond_history','tests/nomacro_mixtures'), 'runtime differs from qualified P source')
    require(not git('diff',P_PRESERVATION,CURRENT_RUNTIME,'--','app','src','reference','tools'), 'P fresh Windows preserved runtime drift')
    paths=set(git('diff','--name-only',P_SEALED,P_ADMITTED).decode().splitlines());require(paths<={SELF,TEST,L_PROOF+'BLOCK_P_CI_SELECTION.json',L_PROOF+'BLOCK_P_MERGE.json'}, 'unqualified delta after P seal')
    def sealed_json(name):
        path=L_PROOF+name+'.json';require(blob('HEAD',path)==blob(P_SEALED,path), 'P sealed proof changed: '+name);return json.loads((ROOT/path).read_text())
    q=sealed_json('BLOCK_P_QUALIFICATION')
    validate_p(q,*(sealed_json('BLOCK_P_'+name) for name in ('CURRENT_FREE_PRESERVATION','LATER_NATIVE_RESULT','PRIOR_SOURCE_PRESERVATION','COMPONENT_RESULT','DEFAULT_PRESERVATION_RESULT','ORIGINAL_REFERENCE_RESULT')))
    for name in ('PREFLIGHT_WATER','PREFLIGHT_CHEMICAL'):
        r=sealed_json('BLOCK_P_'+name);require(r['status']=='BOUNDED_ORIGINAL_FROST_PREFLIGHT_AND_ACTUAL_SOURCE_GUARDS_PASS' and len(r['negative_controls'])==14 and r['foreign_actual_source_refused'] and r['foreign_original_chain_refused'], 'P preflight/source guard')
    for name in ('FIRST_TRAJECTORY_FAILURE','DRAINAGE21_FAILURE','CENSORED_AND_MICRO_REFUSAL','ORIGINAL_CHEMICAL_DRAIN_REFUSAL','VERIFICATION_COMPLETION'):sealed_json('BLOCK_P_'+name)
    for label in ('FULL_TRAJECTORIES','DEFAULT_PRESERVATION','LOCAL'):
        r=sealed_json('BLOCK_P_'+label+'_ARCHIVE');require(hashlib.sha256((ROOT/L_PROOF/r['archive']).read_bytes()).hexdigest()==r['sha256'], 'P raw capsule identity')
    return q


def validate_q(q,prior,free,component,timer,defaults,preflights,references):
    require(q['status']=='BOUNDED_WATER_FROST_DRAINAGE_EVENT_AND_TERMINAL_RECEIPT_QUALIFIED' and q['runtime_source']==Q_RUNTIME, 'Q source or incomplete qualification')
    require(q['Windows_O0_execution_source']==Q_WINDOWS and q['Windows_O2_execution_source']==q['Ubuntu_execution_source']==q['verification_completion_source']==Q_RUNTIME and q['source_app_src_reference_exact_between_Windows_executions'] is True, 'Q execution/completion provenance')
    require((q['full_configurations'],q['full_trajectories'],q['complete_model_days'],q['full_native_standard_windows'],q['active_native_windows'],q['short_native_windows'])==(1,4,4384,16,24,4), 'Q incomplete full/native cohort')
    require(q['numerical_policy']=='original-adaptive-event-closure-v1' and q['mass_guard_cm']==1e-10 and all(q[k] is False for k in ('tolerances_changed','new_persistent_codec','new_Jacobian','global_B1_snapshot_promoted','all_option_completion','native_counts_include_initial_uncomputed_frost_datum')), 'Q changed policy/scope')
    require(q['whole_scientific_equivalence']==q['whole_energy']=='NOT_QUALIFIED' and 'day21' in q['retained_failures'] and 'day367' in q['retained_failures'] and 'chemical' in q['retained_failures'], 'Q historical failure or science promoted')
    def mass(value):require(type(value) in (int,float) and math.isfinite(value) and 0<=value<=1e-10, 'Q hard independent mass guard')
    for name in ('maximum_water_residual_cm','maximum_kernel_residual_cm'):mass(q[name])
    require(set(q['platforms'])=={'Windows','Ubuntu'}, 'Q missing platform')
    active={(9,11),(170,172),(374,376),(535,537),(739,741),(901,903)}
    standard={(2,4),(199,201),(365,367),(530,532)}
    def native(windows,expected):
        require(len(windows)==len(expected) and {(w['start'],w['end']) for w in windows}==expected and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in windows), 'Q incomplete/extraneous/nonexact native window')
    for platform,report in q['platforms'].items():
        require(report['source_commit']==(Q_WINDOWS if platform=='Windows' else Q_RUNTIME) and report['status']=='COMPLETE_TIMECONTROL_FROST_DRAINAGE_O0_O2_PASS' and report['numerical_policy']==q['numerical_policy'] and report['science']=='NOT_QUALIFIED', 'Q actual report provenance')
        require(report['configuration']=='water-frost-drained' and report['water_guard_cm']==report['solute_guard_mg_cm2']==1e-10, 'Q physical/mass scope')
        selected=report['selected_physical_controls']
        require(all(selected[k]==v for k,v in dict(SWMACRO=0,SWSOLU=0,SWFROST=1,SWSNOW=1,SWHYST=2,SWDRA=1,SWBOTB=6,SWTOPBHEA=2,future_crop_SWDROUGHT=1).items()), 'Q unqualified physical forcing')
        require(set(report['profiles'])=={'O0','O2'}, 'Q missing optimization')
        for r in report['profiles'].values():
            require(r['status']=='FULL_PASS' and r['days']==r['budgets']['days']==1096, 'Q incomplete trajectory')
            for key in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):mass(r['budgets'][key])
            native(r['own'],standard);native(r['active_frost_exact_native_windows'],active)
            short=r['short'];require(short['status']=='SHORT_PASS' and short['days']==5, 'Q missing short gate');native([short['own']],{(2,4)})
            w=r['frost_witness'];records=w['actual_records']
            require(w['actual_daily_original_records']==len(records)==1096 and len(w['initial_original_uncomputed_diagnostic'])==6 and w['initial_original_uncomputed_diagnostic'][-1]==0, 'Q initial datum counted as physical activation')
            require(all(len(v)==6 and all(math.isfinite(x) for x in v) and 0<=v[0]<=v[1]<=1 and v[-1]==1 for v in records), 'Q invalid actual frost witness')
            require(w['days_with_reduction']==sum(v[0]<1 for v in records)>0 and w['minimum_rfcp']==min(v[0] for v in records) and w['days_with_zero_factor']==0, 'Q false/full-block frost activation')
            require(all(any(records[d-1][0]<1 for d in range(cut+1,end+1)) for cut,end in active), 'Q seasonal window without actual frost')
            c=r['controls'];require(all(c[k] is True for k in ('foreign_policy_refused','independent_origins','inconsistent_mass_refused','external_discard_replay_exact','external_disk_recovery')), 'Q external transaction/isolation/refusal gap')
            require(len(c['native_refusals'])==4 and all(v['returncode']!=0 and v['accepted_days']==0 for v in c['native_refusals']), 'Q corrupted native accepted')
    require(prior['status']=='Q_PRIOR_O_J_PLATE_N_M_L5_AND_NAMED_SOURCE_PRESERVATION_PASS' and prior['runtime_source']==Q_RUNTIME and len(prior['profiles'])==10 and q['prior_preservation_configs']==12, 'Q prior coverage missing')
    require(all(v['status']=='ACTUAL_PRIOR_GENERATED_SOURCES_INPUTS_POLICIES_EXACT' and v['generated'] and v['kernel_sources'] and v['inputs'] for v in prior['profiles'].values()), 'Q prior generated source drift')
    require(free['status']=='P_FREE_FROST_FULL_EVIDENCE_INHERITED_ON_EXACT_SOURCE_AND_ACTIVE_NATIVE' and set(free['profiles'])=={'water','chemical'}, 'Q missing P frost preservation')
    for v in free['profiles'].values():
        require(v['source']==Q_RUNTIME and v['status']=='ACTUAL_PRIOR_P_FREE_SOURCES_AND_ACTIVE_NATIVE_PRESERVED' and v['generated'] and v['kernel_sources'] and v['inputs'] and v['all_172_physical_rows_exact'] is True and v['prefix']['days']==172, 'Q P physical/runtime preservation')
        native(v['prefix']['own'],{(2,4),(170,172)})
    require(component['status']=='ACTUAL_ORIGINAL_INTEGRAL3_WATSTOR_TERMINAL_O0_O2_PASS' and component['physical_cases_per_optimization']==12 and set(component['profiles'])=={'O0','O2'}, 'Q complete terminal component missing')
    for r in component['profiles'].values():
        require(sum(line.startswith('TERMINAL') for line in r['commands'][-1]['stdout'].splitlines())==12 and all(v['returncode']==0 for v in r['commands']) and len(r['negative_controls'])==3 and all(v['returncode']!=0 for v in r['negative_controls']), 'Q terminal component source/domain gate')
    require(timer['status']=='ACTUAL_ORIGINAL_CORRECTED_TIMECONTROL_COMPONENT_O0_O2_PASS' and set(timer['profiles'])=={'O0-original','O0-corrected','O2-original','O2-corrected'}, 'Q original clock reference component missing')
    for opt in ('O0','O2'):
        before=timer['profiles'][opt+'-original']['values'];after=timer['profiles'][opt+'-corrected']['values']
        require(len(after)==len(before)==5 and before[0][4]<0 and before[4][4]<0 and before[1:4]==after[1:4] and all(v[3]==1 and v[4]==0 for v in after), 'Q clock defect or unchanged controls erased')
    require(defaults['status']=='EXPERIMENTAL_GENERIC_SURFACE_SMOKE_PASS' and defaults['source_commit']==Q_RUNTIME and len(defaults['profiles'])==8 and all(v['every_exercised_native_exact'] for v in defaults['profiles']), 'Q default preservation')
    require(set(preflights)=={'Windows','Ubuntu'}, 'Q missing source/refusal platform')
    for r in preflights.values():require(r['source_commit']==Q_RUNTIME and r['status']=='EXPLICIT_EVENT_CLOSURE_POLICY_AND_ACTUAL_SOURCE_REFUSALS_PASS' and len(r['negative_controls'])==10 and sum(v.get('no_output') is True and v.get('returncode',0)!=0 for v in r['negative_controls'])==4, 'Q implicit policy or foreign actual source accepted')
    require(references['status']=='COMPLETE_CORRECTED_ORIGINAL_DIAGNOSTIC_REFERENCE' and references['source_commit']==Q_RUNTIME and references['original_rows']==references['swap5_rows']==1097 and references['science']=='NOT_QUALIFIED' and references['corrected_timecontrol_sha256']=='7419088428e538da100a2c30c4b32f90fc2799d34f3336f4139cb55fb0f84f57' and references['corrected_frost_sha256']=='d5dd195187d4581e09d19e6afdd4066c0fdb23eee84f8f87947251d2778724d2', 'Q original reference identity or science promoted')


def verify_q():
    git('merge-base','--is-ancestor',P_ADMITTED,Q_RUNTIME);git('merge-base','--is-ancestor',Q_RUNTIME,Q_SEALED);git('merge-base','--is-ancestor',Q_SEALED,'HEAD')
    require(not git('diff',Q_WINDOWS,Q_RUNTIME,'--','app','src','reference'), 'Q Windows/Ubuntu physical runtime drift')
    require(not git('diff',Q_RUNTIME,Q_ADMITTED,'--','app','src','reference','tools','tests/nomacro_time_event','tests/nomacro_frost','tests/nomacro_pond_history','tests/nomacro_mixtures','.github'), 'runtime differs from qualified Q source')
    reference='reference/swap-4.3.1/patches/TIME-EVENT-CLOSURE-01/'
    changed=set(git('diff','--name-only',CURRENT_RUNTIME,Q_RUNTIME,'--','src','reference').decode().splitlines())
    require(changed=={reference+n for n in ('COMPONENT_RESULT.json','README.md','manifest.json','minimal.patch','run.py','test_time_event.f90')}, 'unqualified Q kernel/reference delta')
    paths=set(git('diff','--name-only',Q_SEALED,Q_ADMITTED).decode().splitlines());require(paths<={SELF,TEST,L_PROOF+'BLOCK_Q_CI_SELECTION.json',L_PROOF+'BLOCK_Q_MERGE.json'}, 'unqualified delta after Q evidence seal')
    def sealed(name):
        path=L_PROOF+'BLOCK_Q_'+name+'.json';require(blob('HEAD',path)==blob(Q_SEALED,path), 'Q sealed evidence changed: '+name);return json.loads((ROOT/path).read_text())
    q=sealed('QUALIFICATION')
    validate_q(q,*(sealed(n) for n in ('PRIOR_SOURCE_PRESERVATION','PRIOR_P_FREE_PRESERVATION','COMPONENT_RESULT','TIME_COMPONENT_RESULT','DEFAULT_PRESERVATION_RESULT')),dict(Windows=sealed('PREFLIGHT_WINDOWS'),Ubuntu=sealed('PREFLIGHT_UBUNTU')),sealed('ORIGINAL_REFERENCE_RESULT'))
    require(q['platforms']['Windows']==sealed('WINDOWS_RESULT') and q['platforms']['Ubuntu']==sealed('UBUNTU_RESULT'), 'Q embedded/raw report mismatch')
    for name in ('DAY367_STRICT_FAILURE','ORIGINAL_SNOW_CLOCK_FINDING','VERIFICATION_COMPLETION','ASSESSMENT','PRIOR_P_PREFLIGHT'):sealed(name)
    for label in ('FULL_TRAJECTORIES','DEFAULT_PRESERVATION','LOCAL','OBSERVATION'):
        m=sealed(label+'_ARCHIVE');require(hashlib.sha256((ROOT/L_PROOF/m['archive']).read_bytes()).hexdigest()==m['sha256'], 'Q raw capsule changed')
    return q


def validate_r(q,prior,free,prior_q,component,defaults,preflights,derivative,repair):
    require(q['status']=='FOUR_ORIGINAL_TABULATED_DRAINAGE_CONFIGURATIONS_QUALIFIED' and q['runtime_source']==R_RUNTIME and q['Windows_execution_source']==R_WINDOWS and q['Ubuntu_execution_source']==R_RUNTIME and q['Windows_preflight_source']==R_PREFLIGHT, 'R actual execution source')
    require((q['full_configurations'],q['full_trajectories'],q['complete_model_days'],q['full_native_standard_windows'],q['short_native_windows'])==(4,16,17536,64,16), 'R incomplete full/native scope')
    require(q['mass_guard_cm']==1e-10 and q['tolerances_changed'] is False and q['new_persistent_codec'] is False and q['new_tangent_formula'] is False and q['clock_policy_changed'] is False and q['reused_original_pond_tangent'] is True and q['new_independent_historical_projects']==0, 'R changed physical/numerical policy')
    require(q['whole_scientific_equivalence']==q['whole_energy']=='NOT_QUALIFIED' and q['all_option_completion'] is False and 'day51' in q['retained_failures'] and 'not rebound' in q['retained_failures'], 'R science/failure promotion')
    def mass(value):require(type(value) in (float,int) and math.isfinite(value) and 0<=value<=1e-10, 'R hard independent water/solute balance')
    for key in ('maximum_water_residual_cm','maximum_kernel_residual_cm','maximum_solute_residual_mg_cm2'):mass(q[key])
    def native(windows,expected):require(len(windows)==len(expected) and {(w['start'],w['end']) for w in windows}==expected and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in windows), 'R missing/nonexact native owner')
    expected={'water-drain-table','chemical-drain-table','water-drain-signed','chemical-drain-signed'}
    require(set(q['platforms'])=={'Windows','Ubuntu'}, 'R missing platform')
    for platform,cases in q['platforms'].items():
        require(set(cases)==expected, 'R missing/extraneous physical configuration')
        for key,report in cases.items():
            require(report['source_commit']==(R_WINDOWS if platform=='Windows' else R_RUNTIME) and report['configuration']==key and report['status']=='COMPLETE_TABULATED_DRAINAGE_O0_O2_PASS' and report['science']=='NOT_QUALIFIED', 'R incomplete actual trajectory report')
            s=report['selected_physical_controls'];require(s['SWMACRO']==0 and s['SWDRA']==s['SWDIVD']==s['DRAMET']==1 and s['SWSOLU']==int(key.startswith('chemical')) and s['signed_table']==key.endswith('signed'), 'R unsupported physical dispatch')
            require(set(report['profiles'])=={'O0','O2'}, 'R optimization missing')
            for r in report['profiles'].values():
                require(r['status']=='FULL_PASS' and r['days']==r['budgets']['days']==1096, 'R partial period')
                for name in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):mass(r['budgets'][name])
                native(r['own'],{(2,4),(199,201),(365,367),(530,532)});native([r['short']['own']],{(2,4)});require(r['short']['status']=='SHORT_PASS' and r['short']['days']==5, 'R missing short gate')
                exposure=r['drainage_signed_exposure'];require(exposure['days_positive']>0 and (exposure['days_negative']>0 if key.endswith('signed') else exposure['days_negative']==0), 'R requested drain/infiltration branch not exercised')
                c=r['controls'];require(all(c[k] is True for k in ('foreign_policy_refused','independent_origins','inconsistent_mass_refused','external_discard_replay_exact','external_disk_recovery')) and len(c['native_refusals'])==4 and all(x['returncode']!=0 and x['accepted_days']==0 for x in c['native_refusals']), 'R external/isolation/native refusal missing')
    require(prior['status']=='R_PRIOR_O_J_PLATE_N_M_L5_AND_NAMED_SOURCE_PRESERVATION_PASS' and prior['runtime_source']==R_RUNTIME and len(prior['profiles'])==10 and q['prior_preservation_configs']==13 and all(x['status']=='ACTUAL_PRIOR_GENERATED_SOURCES_INPUTS_POLICIES_EXACT' and x['generated'] and x['kernel_sources'] and x['inputs'] for x in prior['profiles'].values()), 'R prior source drift')
    require(free['status']=='P_FREE_FROST_FULL_EVIDENCE_INHERITED_ON_EXACT_SOURCE_AND_ACTIVE_NATIVE' and set(free['profiles'])=={'water','chemical'}, 'R P free preservation missing')
    for r in free['profiles'].values():
        require(r['source']==R_RUNTIME and r['generated'] and r['kernel_sources'] and r['inputs'] and r['all_172_physical_rows_exact'] is True and r['prefix']['days']==172, 'R P source/native drift');native(r['prefix']['own'],{(2,4),(170,172)})
    require(prior_q['status']=='ACTUAL_Q_FROST_DRAINAGE_SOURCE_INPUT_POLICY_AND_NATIVE_PRESERVED' and prior_q['source_commit']==R_RUNTIME and prior_q['generated'] and prior_q['kernel_sources'] and prior_q['inputs'] and prior_q['all_21_physical_rows_exact'] is True and prior_q['prefix']['days']==21, 'R Q conservation/source drift');native([prior_q['prefix']['own']],{(19,21)})
    require(component['status']=='ACTUAL_ORIGINAL_TABULATED_DRAINAGE_O0_O2_PASS' and component['source_sha256']=='48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc' and component['physical_cases_per_optimization']==15 and set(component['profiles'])=={'O0','O2'}, 'R complete original component missing')
    for r in component['profiles'].values():require(all(x['returncode']==0 for x in r['records']) and sum(line.startswith('TABLE_DRAIN') for line in r['records'][-1]['stdout'].splitlines())==15, 'R native original branch failure')
    require(defaults['status']=='EXPERIMENTAL_GENERIC_SURFACE_SMOKE_PASS' and defaults['source_commit']==R_RUNTIME and len(defaults['profiles'])==8 and all(r['every_exercised_native_exact'] for r in defaults['profiles']), 'R default preservation gap')
    require(set(preflights)=={'Windows','Ubuntu'} and set(preflights['Ubuntu'])==expected, 'R preflight platform gap')
    for platform,reports in [('Windows',{'water-drain-signed':preflights['Windows']}),('Ubuntu',preflights['Ubuntu'])]:
        for key,r in reports.items():
            require(r['source_commit']==(R_PREFLIGHT if platform=='Windows' else R_RUNTIME) and r['status']=='ORIGINAL_TABLE_DRAINAGE_PREFLIGHT_AND_DRFIL_PASS' and r['actual_bundle_validated'] is True and len(r['negative_controls'])==5 and all(x['returncode']!=0 and x['no_output'] is True for x in r['negative_controls']), 'R invalid input accepted')
            if key=='water-drain-signed':
                c=r['custom_file_probe'];require(c['actual_selected_drain_file']=='drains/selected.dra' and c['unused_swap_dra_method']==2 and c['days']==53, 'R actual DRFIL owner not tested');native([c['own']],{(50,53)})
    require(derivative['status']=='EXACT_QUALIFIED_ORIGINAL_LINEAR_POND_FUNCTION_INHERITED_NEW_COUPLED_BRANCH_TESTED' and derivative['actual_template_git_diff_empty'] is True and derivative['derivative_component']['status']=='ORIGINAL_LINEAR_POND_TANGENT_O0_O2_PASS' and derivative['whole_original_native_status']=='ACTUAL_ORIGINAL_SCHEDULED_POND_O0_O2_PASS', 'R original pond owner inheritance changed')
    require(repair['status']=='ORIGINAL_POND_TANGENT_REUSE_PREFIX53_O0_O2_NATIVE_PASS' and set(repair['profiles'])=={'O0','O2'}, 'R failed-day repair not tested')
    for r in repair['profiles'].values():require(r['days']==53, 'R prefix incomplete');native([r['own']],{(50,53)})


def verify_r():
    git('merge-base','--is-ancestor',Q_ADMITTED,R_RUNTIME);git('merge-base','--is-ancestor',R_RUNTIME,R_SEALED);git('merge-base','--is-ancestor',R_SEALED,'HEAD')
    require(not git('diff',R_WINDOWS,R_RUNTIME,'--','app','src','reference','tools','tests/nomacro_drainage/run.py','tests/nomacro_drainage/controls.py'), 'R Windows/Ubuntu physical source drift')
    require(not git('diff',R_RUNTIME,R_ADMITTED,'--','app','src','reference','tools','tests/nomacro_drainage','tests/nomacro_time_event','tests/nomacro_frost','tests/nomacro_pond_history','tests/nomacro_mixtures','.github'), 'runtime differs from qualified R source')
    paths=set(git('diff','--name-only',Q_RUNTIME,R_RUNTIME,'--','app','src','reference').decode().splitlines());require(paths=={'app/hybrid_water/daily_host.py','app/hybrid_water/experimental_project.py'}, 'R unqualified kernel/reference/application delta')
    require(not git('diff','166d4b7b5fe9ba0f6ea3aa8af6f5d55d66a904ad',R_RUNTIME,'--','app/hybrid_water/hybrid_step_budget.f90'), 'R reused pond formula changed')
    paths=set(git('diff','--name-only',R_SEALED,R_ADMITTED).decode().splitlines());require(paths<={SELF,TEST,L_PROOF+'BLOCK_R_CI_SELECTION.json',L_PROOF+'BLOCK_R_MERGE.json'}, 'unqualified delta after R seal')
    def sealed(name):
        path=L_PROOF+'BLOCK_R_'+name+'.json';require(blob('HEAD',path)==blob(R_SEALED,path), 'R sealed proof changed: '+name);return json.loads((ROOT/path).read_text())
    q=sealed('QUALIFICATION');validate_r(q,*(sealed(n) for n in ('PRIOR_SOURCE_PRESERVATION','PRIOR_P_FREE_PRESERVATION','PRIOR_Q_PRESERVATION','COMPONENT_RESULT','DEFAULT_PRESERVATION_RESULT')),dict(Windows=sealed('PREFLIGHT_WINDOWS'),Ubuntu=sealed('UBUNTU_PREFLIGHT')),sealed('POND_COMPONENT_INHERITANCE'),sealed('REPAIRED_PREFIX53'))
    for platform in ('Windows','Ubuntu'):
        for mode in ('water','chemical'):
            for kind in ('table','signed'):require(q['platforms'][platform][mode+'-drain-'+kind]==sealed(platform.upper()+'_'+mode.upper()+'_'+kind.upper()), 'R embedded/raw report differs')
    for name in ('SIGNED_DAY51_FAILURE','OLD_O2_FAILURE','VERIFICATION_COMPLETION','ASSESSMENT'):sealed(name)
    component=sealed('UBUNTU_COMPONENT_RESULT');require(component['status']=='ACTUAL_ORIGINAL_TABULATED_DRAINAGE_O0_O2_PASS' and component['source_commit']==R_RUNTIME and component['physical_cases_per_optimization']==15, 'R missing actual Ubuntu native component')
    for label in ('FULL_TRAJECTORIES','DEFAULT_PRESERVATION','LOCAL'):
        m=sealed(label+'_ARCHIVE');require(hashlib.sha256((ROOT/L_PROOF/m['archive']).read_bytes()).hexdigest()==m['sha256'], 'R raw capsule changed')
    return q


def validate_s(q, named, comparison, isolation, preflights):
    require(q['status']=='ORIGINAL_SCHEDULED_SUBSURFACE_WATER_POINT_INTERVAL_QUALIFIED' and q['runtime_source']==q['Windows_execution_source']==S_RUNTIME and q['Ubuntu_execution_source']==S_UBUNTU, 'S actual source identity')
    require((q['full_configurations'],q['full_trajectories'],q['complete_model_days'],q['standard_full_native_windows'],q['active_full_native_windows'],q['short_native_windows'])==(2,8,8768,24,8,8), 'S incomplete trajectory/native scope')
    require(q['mass_guard_cm']==1e-10 and math.isfinite(q['maximum_water_residual_cm']) and 0<=q['maximum_water_residual_cm']<=1e-10, 'S changed or invalid mass guard')
    require(all(q[name] is False for name in ('tolerances_changed','physical_equations_changed','new_persistent_codec')) and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['functional_completion']=='PARTIAL' and q['chemical_subsurface']=='REFUSED_INHERITED_DEFECT_UNCORRECTED', 'S physics/chemical/science promotion')
    require(set(q['platforms'])=={'Windows','Ubuntu'}, 'S missing platform')
    for platform,cases in q['platforms'].items():
        require(set(cases)=={'point','interval'}, 'S missing depth family')
        for name,report in cases.items():
            require(report['status']=='FULL_O0_O2_PASS' and report['configuration']==name and report['source_commit']==(S_RUNTIME if platform=='Windows' else S_UBUNTU) and report['science']=='NOT_QUALIFIED' and report['water_guard_cm']==1e-10, 'S incomplete actual report')
            require(report['inputs']['selectors']['SWMACRO']==report['inputs']['selectors']['SWSOLU']==0 and set(report['profiles'])=={'O0','O2'}, 'S changed physical scope')
            for opt,r in report['profiles'].items():
                require(r['status']=='FULL_PASS' and r['days']==r['budgets']['days']==1096, 'S incomplete model period')
                for key in ('max_water_cm','max_kernel_cm'):require(math.isfinite(r['budgets'][key]) and 0<=r['budgets'][key]<=1e-10, 'S water budget failed')
                require(len(r['own'])==3 and {w['start'] for w in r['own']}=={2,365,530} and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['own']), 'S ordinary/year native missing')
                require(r['short']['days']==5 and all(r['short']['own'][k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')), 'S short own native missing')
                active=r['active_own'];require(all(active[k] is True for k in ('full_period_physical_csv_suffix_exact','exact_native','origin_unchanged','active_external_discard_replay_exact','active_external_disk_recovery')), 'S active native/external missing')
                exposure=r['subsurface_exposure'];require(math.isfinite(exposure['total_cm']) and exposure['total_cm']>0 and active['actual_irrigation_day'] in exposure['days'], 'S process never active')
                require(all(r['controls'][k] is True for k in ('foreign_policy_refused','inconsistent_mass_refused','external_discard_replay_exact','external_disk_recovery')), 'S acceptance/rollback/recovery missing')
    require(set(named)=={'grass','hupsel','salt'} and all(named[k]['status']=='FULL_PASS' and named[k]['full_days']==days and all(w['exact_native_auxiliary'] is True for w in named[k]['restart_windows']) for k,days in (('grass',1827),('hupsel',1096),('salt',1461))), 'S named full/native regression missing')
    require(comparison['status']=='ALL_EIGHT_ACTUAL_COMPOSITION_TRAJECTORIES_AND_NATIVE_EXACT' and len(comparison['profiles'])==8 and all(v['days']==1096 and v['all_physical_rows_exact'] is True and v['all_csv_rows_exact'] is True and v['complete_terminal_native_exact'] is True for v in comparison['profiles'].values()), 'S actual composition drift')
    require(set(isolation['profiles'])=={'O0','O2'} and all(v['status']=='INTERLEAVED_INDEPENDENT_ORIGINS_ACTIVE_IRRIGATION_PASS' and v['alternating_steps']==6 for v in isolation['profiles'].values()), 'S independent active origins missing')
    require(set(preflights)=={'Windows','Ubuntu-point','Ubuntu-interval'}, 'S missing native input/refusal platform')
    for report in preflights.values():
        require(report['status']=='SCHEDULED_SSDI_ORIGINAL_READER_AND_ACTIVE_TRANSACTIONS_PASS', 'S incomplete preflight')
        tests=report['checks'];refusals=[v for v in tests if v.get('status')=='REFUSED'];require(len(refusals)==7 and sum(v['test']=='future-chemical-SSDI' for v in refusals)==1, 'S native or future chemical input refusal missing')
        require({(v['test'],v.get('optimization')) for v in refusals if v['test']!='future-chemical-SSDI'}=={(name,opt) for name in ('reversed','outside-domain','nonfinite') for opt in ('O0','O2')}, 'S actual original reader domains missing')


def verify_s():
    git('merge-base','--is-ancestor',R_ADMITTED,S_RUNTIME);git('merge-base','--is-ancestor',S_RUNTIME,S_SEALED);git('merge-base','--is-ancestor',S_SEALED,'HEAD')
    paths=set(git('diff','--name-only',R_ADMITTED,S_RUNTIME,'--','app','src','reference','tools').decode().splitlines())
    require(paths=={'app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/experimental_project.py','app/hybrid_water/scheduled_subsurface_irrigation.py'}, 'S unqualified physical dependency delta')
    surface=['app','src','reference','tools','.github','tests/nomacro_scheduled_subsurface/run.py','tests/nomacro_scheduled_subsurface/preflight.py','tests/nomacro_drainage','tests/nomacro_mixtures']
    require(not git('diff',S_RUNTIME,'HEAD','--',*surface), 'runtime differs from qualified S source')
    require(not git('diff',S_RUNTIME,S_UBUNTU,'--',*[p for p in surface if p!='.github']), 'S actual Ubuntu runtime drift')
    require(set(git('diff','--name-only',S_RUNTIME,S_UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'}, 'S carrier changed physical source')
    def sealed(name):
        path=S_PROOF+name+'.json';require(blob('HEAD',path)==blob(S_SEALED,path),'S immutable proof changed: '+name);return json.loads((ROOT/path).read_text())
    q=sealed('QUALIFICATION')
    validate_s(q,sealed('WINDOWS_NAMED'),sealed('COMPOSITION_COMPARE'),sealed('WINDOWS_ISOLATION'),dict(Windows=sealed('WINDOWS_PREFLIGHT'),**{'Ubuntu-point':sealed('UBUNTU_POINT_PREFLIGHT'),'Ubuntu-interval':sealed('UBUNTU_INTERVAL_PREFLIGHT')}))
    for platform in ('Windows','Ubuntu'):
        for case in ('point','interval'):require(q['platforms'][platform][case]==sealed(platform.upper()+'_'+case.upper()),'S embedded/raw report differs')
    for label in ('WINDOWS_RAW','UBUNTU_RAW','HISTORICAL_RAW'):
        record=sealed(label+'_ARCHIVE');require(record['all_members_forward_verified'] is True and hashlib.sha256((ROOT/S_PROOF/record['archive']).read_bytes()).hexdigest()==record['sha256'],'S raw evidence changed')
    diagnostic=sealed('ORIGINAL_CHEMICAL_AUDIT');require(diagnostic['classification']=='INHERITED_DEFECT' and diagnostic['subsurface_all_output_rows_exact_across_concentration'] is True and diagnostic['surface_solute_maximum_differences']['S_IRRIG']==48.0 and diagnostic['production_change'] is False,'S inherited chemical defect lost')
    for name in ('PRIOR_SOURCE_COMPARISON','ORIGINAL_REFERENCE_POINT','ORIGINAL_REFERENCE_INTERVAL','WINDOWS_NAMED_COMMANDS','UBUNTU_POINT_ARTIFACT','UBUNTU_INTERVAL_ARTIFACT'):sealed(name)
    allowed={SELF,TEST,S_PROOF+'CI_SELECTION.json',S_PROOF+'STATUS.json',S_PROOF+'MERGE_RECEIPT.json',S_PROOF+'GAP_MATRIX.json'}
    require(set(git('diff','--name-only',S_SEALED,'HEAD').decode().splitlines())<=allowed,'unqualified delta after S seal')
    return q


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('pulse_admission',ROOT/'tests/irrigation_pulse/verify.py')
    pulse=importlib.util.module_from_spec(spec);spec.loader.exec_module(pulse)
    return pulse.verify()
    git('merge-base', '--is-ancestor', SEALED, 'HEAD')
    git('merge-base', '--is-ancestor', RUNTIME, 'HEAD')
    require(not git('diff', RUNTIME, CURRENT_RUNTIME, '--', 'src', 'reference'), 'unqualified kernel/reference delta')
    paths = git('diff', '--name-only', RUNTIME, '206938ff7737a669341d1cb2a9318c185ed5b08a').decode().splitlines()
    validate_scope(paths)
    require(not git('diff', 'HEAD', '--', 'src', 'app', 'reference', 'tools', 'tests', '.github', 'integration'), 'dirty qualified surface')
    for p in (FCI, MC, CHEM):
        validate_workflow(p, (ROOT/p).read_text(), blob(SEALED, p).decode().replace('\r\n', '\n'))
    validate_workflow(QUALIFY, (ROOT/QUALIFY).read_text(), blob(RUNTIME, QUALIFY).decode().replace('\r\n', '\n'))
    # Fixed Git anchor, not a manifest that can be resealed on the current head.
    for p in ('WINDOWS.json', 'WINDOWS_RAW.json', 'WINDOWS_RAW.zip', 'UBUNTU.json', 'UBUNTU_RAW.zip', 'CI_ADJUDICATION.json'):
        # Compare committed blobs: Git's Windows CRLF checkout conversion is
        # not a scientific edit. Dirty tracked files are refused above; raw
        # archive bytes are additionally hashed below on the actual filesystem.
        require(blob('HEAD', PROOF+p) == blob(SEALED, PROOF+p), 'sealed proof changed: '+p)
    w = json.loads((ROOT/PROOF/'WINDOWS.json').read_text())
    u = json.loads((ROOT/PROOF/'UBUNTU.json').read_text())
    require(w['runtime_source_commit'] == u['head_sha'] == ORIGINAL_RUNTIME, 'wrong original runtime identity')
    require(w['water_guard_cm'] == w['solute_guard_mg_cm2'] == 1e-10 and w['tolerances_changed'] is False, 'changed tolerance')
    require(w['RC2_modified'] is False and w['release_unchanged'] is True, 'RC2 mutated')
    require(w['science'].startswith('NOT_QUALIFIED'), 'whole science promoted')
    validate_runs(w['Windows'])
    validate_runs(u['profiles'])
    for case in w['named_RC2_preservation'].values():
        require(case['generated_original_units_byte_exact'] and case['all_physical_daily_fields_exact_to_RC2'] and case['max_groundwater_difference_cm'] == 0, 'named RC2 changed')
    m = json.loads((ROOT/PROOF/'WINDOWS_RAW.json').read_text())
    digest = lambda data: hashlib.sha256(data).hexdigest()
    raw = ROOT/PROOF/'WINDOWS_RAW.zip'
    require(digest(raw.read_bytes()) == m['sha256'], 'Windows capsule hash')
    with zipfile.ZipFile(raw) as z:
        require(len(z.namelist()) == len(set(z.namelist())) and set(z.namelist()) == set(m['members']), 'Windows raw inventory')
        for p, h in m['members'].items():
            require(digest(z.read(p)) == h, 'Windows raw member: '+p)
    require(digest((ROOT/PROOF/'UBUNTU_RAW.zip').read_bytes()) == u['artifact_sha256'], 'Ubuntu capsule hash')
    # PR1687 entered canonical before the actual PR1686 merge. Its disjoint
    # lower-boundary receipt changes the host/build identity. Old proof cannot
    # qualify that composition: require fresh actual-merge executions instead.
    require(digest(blob('HEAD', PROOF+'COMPOSED_WINDOWS.json')) == COMPOSED_JSON_SHA256, 'composed proof identity')
    c = json.loads((ROOT/PROOF/'COMPOSED_WINDOWS.json').read_text())
    require(c['runtime_source_commit'] == RUNTIME and c['actual_merge_tree_exact'], 'wrong actual merge identity')
    require(c['water_guard_cm'] == c['solute_guard_mg_cm2'] == 1e-10 and not c['tolerances_changed'], 'composed tolerance changed')
    require(c['whole_scientific_equivalence'] == 'NOT_QUALIFIED', 'composed science promoted')
    validate_runs(c['Windows'])
    require(c['soil_air_component_status'] == 'PRODUCTION_ORIGINAL_SOIL_AIR_RECEIPT_O0_O2_PASS', 'shared template composition untested')
    require(c['pond_component_status'] == 'ORIGINAL_LINEAR_POND_TANGENT_O0_O2_PASS', 'pond derivative composition untested')
    require(all(p['all_physical_daily_fields_exact'] and p['all_physical_csv_rows_exact'] for p in c['prior_physical_preservation'].values()), 'composed physical drift')
    require(digest((ROOT/PROOF/'COMPOSED_WINDOWS_RAW.zip').read_bytes()) == COMPOSED_RAW_SHA256, 'composed raw capsule identity')
    q, p = verify_l(c)
    m = verify_m()
    n = verify_n()
    o = verify_o()
    p = verify_p()
    current = verify_q()
    latest = verify_r()
    scheduled = verify_s()
    return dict(status='HUPSEL51_BOUNDED_CURRENT_SUCCESSOR_PASS', runtime=S_RUNTIME,
                current_N_full_days=n['complete_model_days'], current_N_proof_anchor=N_SEALED,
                current_O_full_days=o['complete_model_days'],current_O_proof_anchor=O_SEALED,
                current_P_full_days=p['complete_model_days'],current_P_proof_anchor=P_SEALED,
                current_Q_full_days=current['complete_model_days'],current_Q_proof_anchor=Q_SEALED,
                current_R_full_days=latest['complete_model_days'],current_R_proof_anchor=R_SEALED,
                current_scheduled_subsurface_full_days=scheduled['complete_model_days'],current_scheduled_subsurface_proof_anchor=S_SEALED,
                integrated_frost_drainage='QUALIFIED only explicit original-adaptive-event-closure-v1; old day21/day367 FAIL retained',
                prior_composed_runtime=RUNTIME, current_L_proof_anchor=L_SEALED,
                current_L_full_days=q['complete_model_days'],
                current_M_full_days=m['complete_model_days'], current_M_proof_anchor=M_SEALED,
                current_M_physical_source=M_EXECUTED,
                original_nominal_runon_accuracy=m['nominal_runon_1e10_accuracy'],
                closed6_current_full_native_O0_O2='INHERITED from sealed L full/native PASS on actual current source preservation',
                named_full_evidence='INHERITED on exact generated sources/inputs/policies; binary identity NOT claimed',
                proof_anchor=SEALED, original_canonical_parent=BASE,
                actual_composition_parents=c['actual_merge_parents'],
                historical_guards='UNCHANGED; not current-source authorities',
                column_physics='UNCHANGED; live O0/O2 column test remains required',
                whole_scientific_equivalence='NOT_QUALIFIED')


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
