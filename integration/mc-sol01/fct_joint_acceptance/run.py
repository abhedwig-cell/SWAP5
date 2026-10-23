"""Source-bound real joint trial qualification; generated fixture, no mocks."""
import argparse,hashlib,importlib.util,itertools,json,os,runpy,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
PREVIOUS=HERE.parent/'fct_accepted_trace'
sha=lambda b:hashlib.sha256(b).hexdigest()
def generated_driver():
    fixture=(PREVIOUS/'water_driver.f90').read_text().split(' open(newunit=u,')[0]
    declarations,body=(HERE/'driver.inc').read_text().split(' ! BEGIN TEST BODY\n')
    fixture=fixture.replace('program accepted_water_export','program research_joint_test',1)
    fixture=fixture.replace(' use iso_fortran_env', ' use mod_research_joint_fct\n use mod_kernel_committed_persistence\n use mod_transaction_reference,only:transaction_state_t\n use mod_solute_mobile_salt_state\n use mod_solute_compartment_state\n use mod_b111_reactive_solute_substep\n use iso_fortran_env',1)
    fixture=fixture.replace(' call get_command_argument(1,arg)',declarations+' call get_command_argument(1,arg)',1)
    return (fixture+body).encode()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    dependency=ROOT/'tests/support/augment_bartholomeus_backend_sources.py'
    spec=importlib.util.spec_from_file_location('deps',dependency);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
    generated=out/'joint_driver.f90';generated.write_bytes(generated_driver())
    storage=out/'storage_successor.f90'
    predecessor=runpy.run_path(str(PREVIOUS/'qualify_replay.py'))
    storage.write_bytes(predecessor['storage_successor']())
    extra=['app/solute_column/link_context.f90',str(PREVIOUS/'mod_research_trace_replay.f90'),str(HERE/'mod_research_joint_fct.f90'),predecessor['STORAGE']]
    # Scan committed fixture and explicit additional imports. Only the generated
    # final program is substituted; every provider remains a real source file.
    fixture=PREVIOUS/'water_driver.f90'
    sources,_=deps.strict_closure(ROOT,[str(HERE/'mod_research_joint_fct.f90'),
        'src/kernel/mod_kernel_committed_persistence.f90',str(fixture)],extra)
    sources=[generated if p==fixture else p for p in sources]
    sources.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
    inputs=[p for p in sources if p!=generated]+[dependency,Path(__file__),HERE/'driver.inc',PREVIOUS/'water_driver.f90',PREVIOUS/'qualify_replay.py']
    report=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in inputs},provider_count=len(sources)-1,
        generated={p.name:sha(p.read_bytes()) for p in [generated,storage]},events=[],cases=[],production_activated=False,disk_restart_qualified=False)
    def save():(out/'execution.json').write_text(json.dumps(report,indent=2)+'\n')
    def run(cmd,cwd):
        start=time.monotonic()
        try:cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=180)
        except subprocess.TimeoutExpired as e:cp=subprocess.CompletedProcess(cmd,124,e.stdout or b'',e.stderr or b'')
        e=dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start)
        for stream in ['stdout','stderr']:
            raw=getattr(cp,stream);e[stream]=f'{len(report["events"]):03d}.{stream}';e[stream+'_sha256']=sha(raw);(out/e[stream]).write_bytes(raw)
        report['events'].append(e)
        if cp.returncode:report['status']='CENSORED' if cp.returncode==124 else 'FAILED'
        save();assert cp.returncode==0,(e,cp.stdout[-1000:],cp.stderr[-3000:]);return e
    save();fc=os.environ.get('FC','gfortran');run([fc,'--version'],out)
    report['toolchain_files']={}
    for path in [fc,*filter(None,os.environ.get('SWAP5_FC_IDENTITY_FILES','').split(':'))]:
        p=Path(path)
        if p.is_file():report['toolchain_files'][str(p.resolve())]=sha(p.read_bytes())
    report['environment']={k:os.environ.get(k) for k in ['FC','OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','PYTHONDONTWRITEBYTECODE']}
    save()
    for opt in ['O0','O2']:
        folder=out/opt;folder.mkdir();exe=folder/'joint'
        compiled=[storage if p==ROOT/predecessor['STORAGE'] else p for p in sources]
        run([fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*compiled,'-o',exe],folder)
        for n,factor,exponent in itertools.product([40,80],[.8,1.2],[.5,1.,2.]):
            e=run([exe,n,factor,exponent],folder)
            report['cases'].append(dict(**e,optimization=opt,n=n,factor=factor,exponent=exponent));save()
    report['status']='EXECUTED';save()
    print(json.dumps(dict(status=report['status'],cases=len(report['cases']),provider_count=report['provider_count']),indent=2))
if __name__=='__main__':main()
