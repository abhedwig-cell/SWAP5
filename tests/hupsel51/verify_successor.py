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
CURRENT_RUNTIME = '6afb72468c0060df60694d4b69ee8619fdc93062'
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
    require(q['runtime_source'] == preservation['runtime_source'] == inline['source_commit'] == refused['source_commit'] == CURRENT_RUNTIME, 'foreign N source')
    require(q['status'] == 'ALL_SIX_EXTERNAL_FIXED_IRRIGATION_CONFIGURATIONS_QUALIFIED', 'N incomplete')
    require(q['full_configurations'] == 6 and q['complete_model_days'] == 6576 and q['full_period_optimization'] == 'O2', 'N full count/profile')
    require(q['mass_guard_cm'] == 1e-10 and q['mass_guard_changed'] is False and q['new_state_codec'] is False and q['solver_or_time_policy_changed'] is False, 'N changed conservation/runtime policy')
    require(q['whole_scientific_equivalence'] == 'NOT_QUALIFIED' and q['chemical_subsurface'].startswith('EXPLICIT_NATIVE_REFUSAL') and q['reversed_or_outside_depth'].startswith('EXPLICIT_NATIVE_REFUSAL'), 'N unsupported physics promoted')
    expected = {'water-file-'+k for k in ('sprinkler','surface','subsurface','subsurface-interval')} | {'chemical-file-'+k for k in ('sprinkler','surface')}
    require(set(q['reports']) == expected, 'N missing configuration')
    for field in ('maximum_water_residual_cm', 'maximum_solute_residual_mg_cm2'):
        v = q[field]; require(math.isfinite(v) and 0 <= v <= 1e-10, 'N summary hard balance')
    for key, report in q['reports'].items():
        require(report['source_commit'] == CURRENT_RUNTIME and report['status'] == 'EXPERIMENTAL_FIXED_IRRIGATION_FILE_OPTIONS_PASS', 'N report identity')
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
    git('merge-base','--is-ancestor',CURRENT_RUNTIME,N_SEALED)
    git('merge-base','--is-ancestor',N_SEALED,'HEAD')
    git('merge-base','--is-ancestor',M_ADMITTED,CURRENT_RUNTIME)
    require(not git('diff',CURRENT_RUNTIME,'HEAD','--','src','app','reference','tools'), 'runtime differs from qualified N source')
    paths = set(git('diff','--name-only',N_SEALED,'HEAD').decode().splitlines())
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


def verify():
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
    return dict(status='HUPSEL51_BOUNDED_CURRENT_SUCCESSOR_PASS', runtime=CURRENT_RUNTIME,
                current_N_full_days=n['complete_model_days'], current_N_proof_anchor=N_SEALED,
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
