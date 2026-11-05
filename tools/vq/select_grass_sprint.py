"""Owner selection only; NOT_SELECTED_IMPACT is never a scientific PASS."""
import argparse, json, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
APP='app/solute_project/hupsel_rotation_restart.f90'
ENTRY='tests/dataqual15/verify_current_native_admission.py'
NATIVE_CROP_CODEC='src/adapter/mod_wofost_crop_native_codec.f90'
NATIVE_CROP_CRC='src/adapter/mod_crop_soil_n_joint_restart_file.f90'
POLICY={'.github/workflows/dataqual15-grass-sprint.yml','tools/vq/select_grass_sprint.py',
        'tests/dataqual15_hupsel/test_grass_sprint_selection.py'}


def classify(changed,native_unchanged):
    affected=[]
    for path in changed:
        if path in {APP,ENTRY,NATIVE_CROP_CODEC,NATIVE_CROP_CRC}|POLICY or path=='integration/dataqual15/STATUS.json':continue
        if path.startswith(('src/','app/','tests/dataqual15/','tools/solute/','integration/dataqual15/')):
            affected.append(path)
    run=bool(affected)or not native_unchanged
    return dict(run_grass=run,reason='OWNED_DEPENDENCY_CHANGED'if run else'NOT_SELECTED_IMPACT',
                affected=affected,native_authority_unchanged=native_unchanged,
                requires_current_source_guard=bool(set(changed)&({APP,ENTRY,NATIVE_CROP_CODEC,NATIVE_CROP_CRC}|POLICY)),scientific_pass=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--base',required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--github-output',type=Path);a=p.parse_args()
    changed=subprocess.check_output(['git','diff','--name-only','--no-renames',a.base,'HEAD'],cwd=ROOT,text=True).splitlines()
    def native(ref):
        raw=subprocess.check_output(['git','show',ref+':integration/dataqual15/STATUS.json'],cwd=ROOT)
        return json.loads(raw).get('native_disk_restart_20261102')
    result=classify(changed,native(a.base)==native('HEAD'))
    if not result['run_grass']and result['requires_current_source_guard']:
        sys.path.insert(0,str(ROOT/'tests/dataqual15_hupsel'))
        status=json.loads((ROOT/'integration/dataqual15/STATUS.json').read_text())
        if status.get('native_rotation_crc_successor_20261105'):
            from rotation_native_admission import SCOPE,guard
        elif status.get('native_crop_logical_successor_20261105'):
            from production_crop_logical_admission import SCOPE,guard
        else:
            from production_diagnostic_admission import SCOPE,current_guard as guard
        scope=json.loads((ROOT/SCOPE).read_text());guard(scope)
        result['exact_current_admission_route_guard']='PASS_NO_SCIENCE_INHERITANCE_GRANTED'
    result.update(base=a.base,head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),changed=changed)
    a.output.write_text(json.dumps(result,indent=2)+'\n')
    if a.github_output:
        with a.github_output.open('a')as f:f.write('run_grass='+str(result['run_grass']).lower()+'\n')
    print(result['reason'])


if __name__=='__main__':main()
