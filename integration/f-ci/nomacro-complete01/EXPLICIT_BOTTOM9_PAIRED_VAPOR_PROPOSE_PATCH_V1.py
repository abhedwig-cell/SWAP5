"""Prepare a next-batch patch without changing current qualified APP files."""
import ast, difflib, hashlib, json, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PROOF = ROOT/'integration/f-ci/nomacro-complete01'


def main():
    originals, proposed = {}, {}

    def edit(name, before, after):
        path = 'app/hybrid_water/'+name+'.py'
        if path not in originals:
            originals[path] = (ROOT/path).read_text()
            proposed[path] = originals[path]
        assert proposed[path].count(before) == 1, (name, before)
        proposed[path] = proposed[path].replace(before, after, 1)

    edit('prescribed_head_flux_boundary', '*,hysteresis=0,snow=False):', '*,hysteresis=0,snow=False,vapor=False):')
    old = ' if hysteresis not in (0,1,2) or snow and hysteresis!=0:return None\n'
    edit('prescribed_head_flux_boundary', old, old+' if vapor and (hysteresis!=0 or snow):return None\n')
    edit('prescribed_head_flux_boundary', ' if models:\n', ' active_vapor=False\n if models:\n')
    edit('prescribed_head_flux_boundary', '    if any(int(token)!=0 for token in vapor[0].split()):return None\n',
         '    if any(int(token)!=0 for token in vapor[0].split()):\n'
         '     if not active_vapor_allowed or any(int(token) not in (0,1) for token in vapor[0].split()) or not any(model>=8 for model in analytical):return None\n'
         '     active_vapor=True\n')
    # The existing local variable named vapor holds parsed rows. Preserve it and
    # keep the optional policy flag separately, before parsing those rows.
    edit('prescribed_head_flux_boundary', ' active_vapor=False\n', ' active_vapor_allowed=vapor\n active_vapor=False\n')
    edit('prescribed_head_flux_boundary', ' def civil(key):\n', ' if active_vapor_allowed and not active_vapor:return None\n def civil(key):\n')
    edit('prescribed_head_flux_boundary', ' if snow_paired(project):return 9\n',
         ' if snow_paired(project):return 9\n from prescribed_vapor_boundary import enabled as vapor_paired\n if vapor_paired(project):return 9\n')
    edit('experimental_project', "    if paired_boundary is not None:allowed['SWBOTB'].add(9)\n",
         "    if paired_boundary is None:\n        from prescribed_vapor_boundary import selection as vapor_paired_selection\n        paired_boundary=vapor_paired_selection(directory,original_output)\n    if paired_boundary is not None:allowed['SWBOTB'].add(9)\n")
    edit('hydraulic_vapor', '    boundary=selected_context(selected)\n',
         '    boundary=selected_context(selected)\n    from prescribed_vapor_boundary import selected_context as paired_vapor_context\n    if boundary is None:boundary=paired_vapor_context(selected)\n')
    edit('hydraulic_vapor', "    if boundary is not None:result['boundary_composition']=boundary\n",
         "    if boundary is not None:result['boundary_composition']=boundary\n    from prescribed_vapor_boundary import metadata as paired_metadata\n    paired=paired_metadata(project)\n    if paired is not None:result['paired_boundary_composition']=paired\n")
    edit('hydraulic_vapor', '    from analytical_cde_calendar import native_magic as calendar_native_magic\n',
         "    from prescribed_vapor_boundary import enabled as paired_vapor_enabled\n    if paired_vapor_enabled(project):return b'S5HPC007' if project.solute else b'S5HPW007'\n    from analytical_cde_calendar import native_magic as calendar_native_magic\n")
    edit('hydraulic_vapor', '    from analytical_cde_calendar import vapor_selected,native_provider as calendar_native_source\n',
         '    from prescribed_vapor_boundary import enabled as paired_vapor_enabled,native_source as paired_native_source\n    if paired_vapor_enabled(project):return paired_native_source(original)\n    from analytical_cde_calendar import vapor_selected,native_provider as calendar_native_source\n')
    edit('original_output', '            if paired_boundary_selection(project.input_directory,project.original_output) is not None:continue\n',
         '            if paired_boundary_selection(project.input_directory,project.original_output) is not None:continue\n            from prescribed_vapor_boundary import enabled as paired_vapor_enabled\n            if paired_vapor_enabled(project):continue\n')
    edit('cde_native_receipt', "    if aux[:8]==b'S5HBC005':\n",
         "    if aux[:8]==b'S5HPC007':\n        from prescribed_vapor_boundary import cde_offset\n        offset=cde_offset(aux,nodes,project)\n    if aux[:8]==b'S5HBC005':\n")
    edit('cde_native_receipt', "optional_native_prefixes={'S5HVC003':", "optional_native_prefixes={'S5HPC007':'48 + 8*(14+2*actual_layers), checked duplicated paired9 vapor domain',\n                    'S5HVC003':")
    path = 'app/hybrid_water/prescribed_vapor_boundary.py'
    originals[path] = ''
    proposed[path] = (PROOF/'EXPLICIT_BOTTOM9_PAIRED_VAPOR_PROPOSED_OWNER_V1.py').read_text()
    assert not (ROOT/path).exists()
    for path, value in proposed.items():
        ast.parse(value, filename=path)
    patch = ''.join(''.join(difflib.unified_diff(originals[path].splitlines(keepends=True), value.splitlines(keepends=True),
                    fromfile='a/'+path if originals[path] else '/dev/null', tofile='b/'+path))
                    for path, value in sorted(proposed.items()))
    target = PROOF/'EXPLICIT_BOTTOM9_PAIRED_VAPOR_PROPOSED_V1.patch'
    assert not target.exists()
    target.write_text(patch, encoding='utf8', newline='\n')
    subprocess.run(['git','apply','--check',str(target)], cwd=ROOT, check=True)
    for path, original in originals.items():
        assert ((ROOT/path).read_text() if original else '') == original
    report = dict(status='PROPOSED_SIX_FILE_ACTIVE_VAPOR_PAIRED9_PATCH_SYNTAX_AND_REAL_GIT_APPLY_CHECK_PASS_NOT_IMPLEMENTED_OR_QUALIFIED',
                  actual_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  files={p:dict(before_lf_sha256=hashlib.sha256(originals[p].encode()).hexdigest(),
                                proposed_lf_sha256=hashlib.sha256(value.encode()).hexdigest()) for p,value in proposed.items()},
                  patch_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                  existing_APP_files_modified=False, compiler_executions=0, model_executions=0,
                  existing_paired9_QBOT9_all_node_balance_unchanged=True,
                  model7_terminal_water_and_old_5_6_8_vapor_boundary_unchanged=True,
                  canonical_admission=False,
                  next='After actual280 canonical admission: apply patch, qualify frontend/native7 and original Kelvin9 water/CDE 35day/cold/all-node independent ledgers on representative models8/11 drainage0/1 Windows/Ubuntu O0/O2. Keep numerical failures and original unsupported domains explicit.')
    (PROOF/'EXPLICIT_BOTTOM9_PAIRED_VAPOR_PROPOSED_V1.json').write_text(json.dumps(report,indent=2)+'\n')
    print(report['status'], report['patch_sha256'])


if __name__ == '__main__':
    main()
