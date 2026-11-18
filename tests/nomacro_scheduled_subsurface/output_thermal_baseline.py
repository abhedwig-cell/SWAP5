"""Actual preceding canonical thermal physics versus explicit dense output reset0."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import struct
import subprocess
import sys
import zipfile
import output_thermal_runtime as probe
from original_output_baseline import assignment

m=probe.m;ROOT=probe.ROOT;BASE='dcd880bbc0b6ff62fd2a28c68b080ac0811090ac'
RUNNER="""from pathlib import Path
import importlib.util,json,sys,subprocess
root,build,reference,inputs,out=map(Path,sys.argv[1:6]);original=sys.argv[6]=='1';policy=sys.argv[7]
spec=importlib.util.spec_from_file_location('actual_thermal_source',root/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);p=m.e.load(inputs,original_output=original,time_step_policy=policy)
if out.exists():
 data=m.rows(out);assert len(data)==35;m.validate_bundle(build,reference,p);report=dict(status='ACTUAL_COMPLETED_THERMAL_TRAJECTORY_REVALIDATED',days=35,budgets=m.check(data),build_sha256=m.sha(build/'BUILD.json'))
else:report,data=m.trajectory(build,reference,p,out,35,{2,4,8,19,23,30,34,35},90)
(out.parent/'RUN.json').write_text(json.dumps(dict(status='ACTUAL_THERMAL_SOURCE_TRAJECTORY_PASS',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),original_output=original,trajectory=report),indent=2)+'\\n')
"""


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','baseline-root','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True);ap.add_argument('--resume',action='store_true');a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=a.baseline_root,text=True).strip()==BASE
    assert not subprocess.check_output(['git','status','--porcelain'],cwd=a.baseline_root,text=True).strip()
    runner=a.output/'actual-source-runner.py';runner.write_text(RUNNER);q=dict(status='RUNNING',baseline=BASE,optimization=a.optimization,profiles={})
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for kind in ('water-snow','water-hys2','chemical-snow','water-frost-drained'):
            out=a.output/kind;out.mkdir(exist_ok=a.resume);inputs=out/'input'
            if not inputs.exists():
                probe.fixture(inputs,kind,1);p=inputs/'swap.swp';p.write_text(assignment(p.read_text(encoding='cp1252'),'SWRES',0),encoding='cp1252')
            policy='original-adaptive-event-closure-v1' if kind=='water-frost-drained' else 'original-adaptive-day-seed-v1';images={}
            for label,root,original in [('baseline',a.baseline_root,False),('current',ROOT,True)]:
                build=out/(label+'-build');run=out/label;run.mkdir(exist_ok=a.resume);command=[sys.executable,'-B',str(root/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',inputs,'--experimental-time-step-policy',policy,'--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
                if original:command+=['--original-output']
                if not (a.resume and (build/'BUILD.json').exists()):
                    r=subprocess.run(list(map(str,command)),cwd=root,capture_output=True,text=True,timeout=180);(run/'build.stdout').write_text(r.stdout);(run/'build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
                r=subprocess.run([sys.executable,'-B',str(runner),str(root),str(build),str(a.reference_work),str(inputs),str(run/'trajectory'),str(int(original)),policy],cwd=root,capture_output=True,text=True,timeout=120);(run/'run.stdout').write_text(r.stdout);(run/'run.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
                images[label]=json.loads((build/'BUILD.json').read_text())
            actual,old=images['current'],images['baseline'];assert {k:v for k,v in actual['project'].items() if k!='case'}=={k:v for k,v in old['project'].items() if k!='case'} and actual['inputs']==old['inputs']
            for field in ('donor_flags','kernel_flags','donor_modules','ttutil_modules','ttutil_library'):assert actual['identity'].get(field)==old['identity'].get(field),(kind,field)
            assert set(old['identity']['donor_objects'])-set(actual['identity']['donor_objects'])=={'integral.o'} and not set(actual['identity']['donor_objects'])-set(old['identity']['donor_objects'])
            assert all(v==old['identity']['donor_objects'][k] for k,v in actual['identity']['donor_objects'].items())
            canonical_kernel={}
            for path,digest in actual['identity']['kernel_sources']:
                current=(ROOT/path).read_bytes();prior=(a.baseline_root/path).read_bytes();assert hashlib.sha256(current).hexdigest()==digest and hashlib.sha256(prior).hexdigest()==dict(old['identity']['kernel_sources'])[path]
                assert current.replace(b'\r\n',b'\n')==prior.replace(b'\r\n',b'\n');canonical_kernel[path]=hashlib.sha256(current.replace(b'\r\n',b'\n')).hexdigest()
            canonical_policy_sources={}
            policy_paths={
              'frost_reference':{'source_sha256':'app/hybrid_water/frost_reference.py'},
              'time_event_closure':{'source_sha256':'app/hybrid_water/time_event_closure.py','terminal_receipt_sha256':'app/hybrid_water/terminal_water_receipt.f90'},
              'conserved_subsurface_solute':{'source_sha256':'app/hybrid_water/conserved_subsurface_solute.py','correction_sha256':'reference/swap-4.3.1/patches/NOMACRO-SUBSURFACE-SOLUTE-01/source.py','fixed_reader_sha256':'app/hybrid_water/fixed_irrigation_file.py'}}
            for field,paths in policy_paths.items():
                x,y=actual['identity'].get(field),old['identity'].get(field);assert (x is None)==(y is None)
                if x is None:continue
                assert {k:v for k,v in x.items() if k not in paths}=={k:v for k,v in y.items() if k not in paths},(kind,field)
                for key,path in paths.items():
                    current=(ROOT/path).read_bytes();prior=(a.baseline_root/path).read_bytes();assert hashlib.sha256(current).hexdigest()==x[key] and hashlib.sha256(prior).hexdigest()==y[key],(field,key)
                    assert current.replace(b'\r\n',b'\n')==prior.replace(b'\r\n',b'\n');canonical_policy_sources[path]=hashlib.sha256(current.replace(b'\r\n',b'\n')).hexdigest()
            original=(a.reference_work/'build/swap-selected/integral.f90').read_text(encoding='cp1252');rendered=(out/'current-build/integral.f90').read_text(encoding='cp1252')
            body=lambda text:text[text.index('   case (3)'):text.index('   case default',text.index('   case (3)'))]
            observed=body(rendered)
            pattern=r"(?m)^([ \t]*)hybrid_receipt_increment=([^\n]+)\n[ \t]*call observe_output_increment\([^\n]+\n[ \t]*if\(hybrid_receipt_status[^\n]+\n[ \t]*(\w+)\s*=\s*\3\s*([+-])\s*hybrid_receipt_increment[ \t]*$"
            observed,count=re.subn(pattern,lambda m:m[1]+m[3]+' = '+m[3]+' '+m[4]+' '+m[2].strip(),observed)
            inherited=r"(?m)^([ \t]*)hybrid_receipt_increment=([^\n]+)\n[ \t]*(\w+)\s*=\s*\3\s*([+-])\s*hybrid_receipt_increment\s*\n[ \t]*if\(hybrid_output_frame%active\)then\n[ \t]*call observe_output_increment\([^\n]+\n[ \t]*if\(hybrid_receipt_status[^\n]+\n[ \t]*end if[ \t]*$"
            observed,oldcount=re.subn(inherited,lambda m:m[1]+m[3]+' = '+m[3]+' '+m[4]+' '+m[2].strip(),observed);assert count==3 and oldcount>=12,(count,oldcount)
            tokens=lambda text:re.sub(r'\s+','',re.sub(r'(?m)!.*$','',text)).lower()
            assert tokens(observed)==tokens(body(original)),'Original physical Integral task3 statements changed'
            left=m.rows(out/'baseline/trajectory');right=m.rows(out/'current/trajectory');maxima={}
            for field in ('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm'):
                assert all(len(x[field])==len(y[field]) for x,y in zip(left,right));maximum=max(abs(a-b) for x,y in zip(left,right) for a,b in zip(x[field],y[field]));maxima[field]=maximum;assert maximum<=1e-10,(kind,field,maximum)
            native={};project=m.e.load(inputs,original_output=True,time_step_policy=policy);selected=probe.selection(project);header=struct.pack('<10i',1,project.nodes,0,int(project.solute),selected['swhyst'],1,selected['swfrost'],selected['swdra'],1,2)
            for day in (2,4,8,23,34,35):
                with zipfile.ZipFile(out/f'baseline/trajectory/accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(out/f'current/trajectory/accepted-column-1-day-{day}.zip') as y:
                    raw=y.read('macro.bin');assert raw.count(header+header)==1;offset=raw.index(header+header);oldraw=x.read('macro.bin');assert offset==len(oldraw) and raw[8:offset]==oldraw[8:] and y.read('result.end')==x.read('result.end'),(kind,day)
                    native[str(day)]=dict(complete_old_physical_prefix_exact=True,result_end_exact=True,new_output_domain_offset=offset,old_complete_native_bytes=len(oldraw),projection='comparison only: typed8bytecodec and appended output/calendar state excluded; no checkpoint adoption or rebinding')
            full=out/'current/trajectory';windows=[probe.own(out/'current-build',a.reference_work,project,full,right,s,t,out/('own-'+str(s)),resume=a.resume and (out/('own-'+str(s))).exists()) for s,t in ((2,4),(19,23),(30,34))]
            q['profiles'][kind]=dict(actual_build=actual,baseline_build_sha256=m.sha(out/'baseline-build/BUILD.json'),baseline_run=json.loads((out/'baseline/RUN.json').read_text()),current_run=json.loads((out/'current/RUN.json').read_text()),physical_provider_inputs_exact=True,canonical_kernel_sources=canonical_kernel,canonical_policy_sources=canonical_policy_sources,original_integral_task3_statements_exact=True,comparison_only_metadata_projection=dict(case_tag='different explicit output policies, identical complete input bytes and physical project metadata',kernel='actual independently validated raw build identities retained; only Git-canonical LF source bytes compared',integral='one original provider integral.o replaced by observed real Integral with literal original task3 statements; no other provider object differs'),maximum_actual_differences=maxima,native=native,own=windows);save();print(kind,a.optimization,'ACTUAL_CANONICAL_THERMAL_PHYSICS_AND_DENSE_RESET0_NATIVE_PASS',maxima,flush=True)
        q['status']='FOUR_ACTUAL_CANONICAL_THERMAL_PHYSICAL_NATIVE_RESET0_CONTEXTS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
