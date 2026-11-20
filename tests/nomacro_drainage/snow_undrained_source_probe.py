"""Compile actual undrained ordinary Snow forms from retained original inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','baseline','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--only-labels',nargs='+');a=p.parse_args();a.output.mkdir()
    baseline=json.loads(a.baseline.read_text(encoding='utf-8'))
    if a.only_labels and set(a.only_labels)-set(baseline['cases']):raise ValueError('Foreign source case')
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        baseline=str(a.baseline),baseline_sha256=original.m.sha(a.baseline),cases={},model_executions=0,
        scientific_qualification=False,canonical_admission=False)
    try:
        for label,c in baseline['cases'].items():
            if a.only_labels and label not in a.only_labels:continue
            inputs=Path(c['input_root']);out=a.output/label;out.mkdir();build=a.build_root/label/'bundle'
            actual={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs.iterdir() if f.is_file()}
            assert actual==c['inventory'],'Original named input changed'
            project=original.m.e.load(inputs,original_output=True)
            sys.path.insert(0,str(original.ROOT/'app/hybrid_water'))
            from snow_undrained import selection
            selected=selection(project);assert selected and selected['swbotb']==c['parameters']['bottom'] and selected['swdra']==0
            command=[sys.executable,'-B',str(original.ROOT/'tools/solute/run_water.py'),'--model',project.model,
                '--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),
                '--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            item=q['cases'][label]=dict(input_root=str(inputs),build_root=str(build),command=command,
                actual_selected_domain=selected,optimization=a.optimization)
            with (out/'build.stdout').open('x') as stdout,(out/'build.stderr').open('x') as stderr:
                r=subprocess.run(command,cwd=original.ROOT,stdout=stdout,stderr=stderr,timeout=180)
            item['returncode']=r.returncode
            if (build/'BUILD.json').exists():item['actual_BUILD_sha256']=original.m.sha(build/'BUILD.json')
            r.check_returncode();original.m.validate_bundle(build,a.reference_work,project)
            assert not list(out.rglob('accepted-*.zip'))
            print(label,'ACTUAL_ORIGINAL_COMPILED_SOURCE_CLOSURE_PASS',flush=True)
        q['status']='ACTUAL_SNOW_UNDRAINED_SOURCE_FORMS_PASS_NOT_SCIENTIFICALLY_QUALIFIED'
    except Exception as error:q.update(status='ACTUAL_SOURCE_PROBE_FAILED_NOT_QUALIFIED',error=repr(error));raise
    finally:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
