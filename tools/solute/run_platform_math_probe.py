"""One bounded fresh-source math-runtime discriminator, not qualification."""
import argparse,hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--days',type=int,default=5)
p.add_argument('--no-contract',action='store_true')
p.add_argument('--common-isa',action='store_true')
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();events=[]
if a.common_isa:a.no_contract=True
def run(label,command,timeout=120):
    command=list(map(str,command));env=dict(os.environ)
    if a.no_contract and command[:2]==[sys.executable,'-B']:
        command=command[:2]+[str(ROOT/'tools/solute/platform_fp_bootstrap.py')]+command[2:]
        env['SWAP5_PRIVATE_FP_JOURNAL']=str(a.output/'COMPILER_CALLS.jsonl')
        if a.common_isa:env['SWAP5_PRIVATE_FP_COMMON_ISA']='1'
    begin=time.perf_counter();r=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=timeout)
    (a.output/(label+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
    events.append(dict(label=label,command=list(map(str,command)),seconds=time.perf_counter()-begin,returncode=r.returncode))
    (a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
    assert r.returncode==0,(label,r.stdout,r.stderr)
    return r.stdout
reference=a.output/'provider';bundle=a.output/'bundle';cold=a.output/'cold'
cli=[sys.executable,'-B','tools/solute/run_water.py','--no-macro-release']
run('prepare',cli+['--prepare-sources','--reference-work',reference],240)
base=cli+['--reference-work',reference,'--model','HYBRID_HUPSEL_WATER']
run('build',base+['--build-only','--kernel-opt','O2','--output',bundle])
run('cold-input',base+['--build-bundle',bundle,'--output',cold,'--days',1],30)
observer=a.output/'observer';observer.mkdir()
main=(bundle/'swap_main.f90').read_text(encoding='cp1252')
(observer/'swap_main.f90').write_text(main,encoding='cp1252')
csv=(bundle/'swap_csv_output.f90').read_text(encoding='cp1252')
anchor='   subroutine set_values_scalar()'
assert csv.count(anchor)==1
csv=csv.replace(anchor,anchor+'\n   use variables, only: rc1_h=>h,rc1_qbot=>qbot,itnumb\n   use MOD_SoilTemperature, only: rc1_tsoil=>tsoil')
anchor='   dstor_1    = wasrdm1 - iwasrdm1beg';assert csv.count(anchor)==1
csv=csv.replace(anchor,"""   write(*,'(a,*(1x,es25.17e3))') 'RC1_HEAD',gwl,rc1_qbot,rc1_h(1:numnod)
   write(*,'(a,*(1x,es25.17e3))') 'RC1_HEAT',rc1_tsoil(1:numnod)
   write(*,'(a,*(1x,i0))') 'RC1_HIST',itnumb(:,1)
"""+anchor)
(observer/'swap_csv_output.f90').write_text(csv,encoding='cp1252')
fixture=ROOT/'tools/solute/platform_quadmath_probe.c';table=ROOT/'tools/solute/platform_math_table.c'
tables={}
for mode in (('native',) if a.no_contract else ('native','quadmath')):
    exe=a.output/(mode+('-table.exe' if os.name=='nt' else '-table'))
    run(mode+'-table-build',['gcc','-O2','-fno-builtin',table,*([fixture,'-lquadmath'] if mode=='quadmath' else ['-lm']),'-o',exe],30)
    output=run(mode+'-table',[exe],10)
    tables[mode]=[dict(function=s.split()[0],argument=float.fromhex(s.split()[1]).hex(),result=float.fromhex(s.split()[2]).hex()) for s in output.splitlines()]
libraries={}
for name in ('libquadmath.a','libquadmath.so','libquadmath-0.dll'):
    path=Path(subprocess.check_output(['gfortran','-print-file-name='+name],text=True).strip())
    if not path.is_file() and os.name=='nt':path=Path(shutil.which('gfortran')).parent/name
    if path.is_file():libraries[name]=dict(path=str(path.resolve()),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
(a.output/'MATH_RUNTIME.json').write_text(json.dumps(dict(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),toolchain=json.loads((reference/'PREPARED.json').read_text())['toolchain'],libraries=libraries,source_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),tables=tables,separate_operations=a.no_contract,common_isa=a.common_isa),indent=2)+'\n')
run('compiler-target',['gfortran','-Q','-O2','--help=target'],10)
if a.no_contract:
    run('compiler-selected-target',['gfortran','-Q','-O2','-ffp-contract=off',*(['-march=x86-64','-mtune=generic'] if a.common_isa else []),'--help=target'],10)
run('model-probe',[sys.executable,'-B','tools/solute/diagnose_polish_feedback.py','--bundle',bundle,'--reference',reference,'--full',cold,'--observer',observer,'--output',a.output/'probe','--same-core' if a.no_contract else '--quadmath','--days',a.days],150)
(a.output/'RESULT.json').write_text(json.dumps(dict(status='PRIVATE_MATH_DISCRIMINATOR_COMPLETED_NOT_QUALIFIED',probe=json.loads((a.output/'probe/RESULT.json').read_text()),events=events),indent=2)+'\n')
print('PRIVATE_MATH_DISCRIMINATOR_COMPLETED_NOT_QUALIFIED',flush=True)
