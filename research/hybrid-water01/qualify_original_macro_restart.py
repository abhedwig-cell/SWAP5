"""Small original macro-state qualification; no full project/reference execution."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle
from original_macro_policy import build_bundle


def payload(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}


def probe(bundle,reference,output,checkpoint=None,control=None):
    script='probe_original_macro_discard.py' if control else 'probe_original_macro_block.py'
    command=[sys.executable,'-B',str(Path(__file__).with_name(script)),
        '--bundle',str(bundle),'--reference',str(reference),'--output',str(output)]
    if checkpoint:command+=['--checkpoint',str(checkpoint)]
    if control:command+=['--control',str(control)]
    result=subprocess.run(command,capture_output=True,text=True,timeout=35)
    (output.parent/(output.name+'-controller.json')).write_text(json.dumps(
        {'command':command,'exit_code':result.returncode,'stdout':result.stdout,'stderr':result.stderr},indent=2)+'\n')
    if result.returncode:raise AssertionError(result.stdout+result.stderr)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--workspace',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--reuse-o0',type=Path)
    p.add_argument('--reuse-o2',type=Path)
    p.add_argument('--prior-o2',type=Path)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    if bool(a.reuse_o0)!=bool(a.reuse_o2):raise ValueError('Both reused optimizations required')
    reference=a.workspace/'reference';started=time.perf_counter()
    report={'status':'RUNNING','platform':sys.platform,'scope':'original donor O2; day-owner kernel O0/O2; fresh1to4, own2to4, external discard and cold3to4',
        'full_project_runs':0,'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'cases':[]}
    try:
        roots={}
        for opt,reuse in [('O0',a.reuse_o0),('O2',a.reuse_o2)]:
            root=reuse or a.output/opt;roots[opt]=root
            if not reuse:
                root.mkdir();build_bundle(a.workspace/('andelst-'+opt),reference,root/'build')
                for n in ('day_donor','day_kernel'):h.executable(root/'build',n).chmod(0o755)
                probe(root/'build',reference,root/'fresh')
                probe(root/'build',reference,root/'restart',root/'fresh/accepted-column-1-day-2.zip')
                probe(root/'build',reference,root/'discard',root/'fresh/accepted-column-1-day-2.zip',root/'fresh/accepted-column-1-day-4.zip')
            meta,_=validate_bundle(root/'build',reference,h.ANDELST)
            fresh=json.loads((root/'fresh/RESULT.json').read_text());restart=json.loads((root/'restart/RESULT.json').read_text());discard=json.loads((root/'discard/RESULT.json').read_text())
            assert fresh['status']=='FRESH_4_DAYS_COMPLETE' and restart['status']=='OWN_RESTART_2_TO_4_COMPLETE'
            assert discard['status']=='DISCARD_REPLAY_COLD_RECOVERY_PASS' and restart['initial_state_exact']
            assert len(fresh['rows'])==4 and len(restart['rows'])==2
            for x,y in zip(fresh['rows'][2:],restart['rows']):
                assert all(x[k]==y[k] for k in x if k!='revision')
            for day in (3,4):
                assert payload(root/f'fresh/accepted-column-1-day-{day}.zip')==payload(root/f'restart/accepted-column-1-day-{day}.zip')
            with zipfile.ZipFile(root/'fresh/accepted-column-1-day-4.zip') as z:
                native=z.read('macro.bin');assert native[:8]==b'S5MAC006'
            maximum=max(abs(v['independent_residual_cm']) for v in fresh['rows'])
            assert maximum<=1e-6
            report['cases'].append({'optimization':opt,'build':meta,'run_root':str(root),
                'fresh_seconds':fresh['elapsed_seconds'],'restart_seconds':restart['elapsed_seconds'],
                'discard_seconds':discard['elapsed_seconds'],'maximum_daily_residual_cm':maximum,
                'complete_native_2to3_and_2to4_exact':True,'discard_and_cold3to4_exact':True,
                'native_bytes':len(native),'native_day4_sha256':h.sha(root/'fresh/accepted-column-1-day-4.zip')})
        # Exact pre-fix coherent-block cold trajectory, not an independent science oracle.
        prior=a.prior_o2
        if prior is None:
            previous=a.output/'previous_builder.py'
            previous.write_bytes(subprocess.check_output(['git','show','826c4da8abb6997d8717e5a6b8d2aefed9bd214d:app/hybrid_water/original_macro_policy.py'],cwd=ROOT))
            spec=importlib.util.spec_from_file_location('previous_macro_builder',previous)
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            prior=a.output/'prior-O2';prior.mkdir()
            module.build_bundle(a.workspace/'andelst-O2',reference,prior/'build')
            for n in ('day_donor','day_kernel'):h.executable(prior/'build',n).chmod(0o755)
            probe(prior/'build',reference,prior/'fresh')
        validate_bundle(prior/'build',reference,h.ANDELST)
        old=json.loads((prior/'fresh/RESULT.json').read_text());new=json.loads((roots['O2']/'fresh/RESULT.json').read_text())
        assert old['rows']==new['rows']
        for day in (3,4):
            x=payload(roots['O2']/f'fresh/accepted-column-1-day-{day}.zip');y=payload(prior/f'fresh/accepted-column-1-day-{day}.zip')
            assert x['result.end']==y['result.end']
            assert x['macro.bin'][8:len(y['macro.bin'])]==y['macro.bin'][8:]
        report.update(status='ORIGINAL_MACRO_COMPLETE_SHORT_RESTART_PASS',cold_predecessor_receipts_and_old_fields_exact=True,
            predecessor_source='826c4da8abb6997d8717e5a6b8d2aefed9bd214d',
            excludes=['whole481','late event','scientific equivalence','numerical rejected-timestep rollback','thread safety'])
    except Exception:
        report.update(status='FAILED',error=traceback.format_exc())
    report['qualification_wall_seconds']=time.perf_counter()-started
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'status':report['status'],'wall_seconds':report['qualification_wall_seconds']}))
    return 0 if report['status']=='ORIGINAL_MACRO_COMPLETE_SHORT_RESTART_PASS' else 2


if __name__=='__main__':raise SystemExit(main())
