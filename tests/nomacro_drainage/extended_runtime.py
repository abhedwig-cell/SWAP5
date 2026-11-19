"""One bounded original extended-drainage composition batch, not family closure."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as prior
m=prior.m
CASES=('prescribed','fixed','automatic','table','water')


def fixture(case, output):
    original=ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'
    shutil.copytree(original,output)
    path=output/'swap.swp';text=path.read_text(encoding='cp1252')
    def replace(body,key,value):
        result,count=re.subn(r'(?mi)^([ \t]*'+key+r'[ \t]*=[ \t]*)\d+',lambda x:x.group(1)+str(value),body)
        if count!=1:raise ValueError('Missing original fixture selector '+key)
        return result
    text=replace(text,'SWDRA',2)
    if case=='water':
        text=replace(text,'SWSOLU',0)
        # This is a declared water-only configuration. Every original future
        # crop must also disable its chemical salinity-stress dependency.
        for crop in output.glob('*.crp'):
            body=crop.read_text(encoding='cp1252')
            crop.write_text(replace(body,'SWSALINITY',0),encoding='cp1252')
    path.write_text(text,encoding='cp1252')
    cofani=re.findall(r'(?mi)^[ \t]*COFANI[ \t]*=[^\r\n]*',(original/'swap.dra').read_text(encoding='cp1252'))
    if len(cofani)!=1:raise ValueError('Missing original per-horizon anisotropy')
    levels=3 if case=='water' else 2
    swsrf=3 if case in ('prescribed','automatic') else 2
    text='* Declared extended geometry; all original readers and physical processes remain active.\nSWDIVD = 1\n'+cofani[0]+'\nALTCU = 0.0\nNRSRF = '+str(levels)+'\nSWDISLAY = 0\n'
    text+='LEV SWDTYP L ZBOTDRE GWLINF RDRAIN RINFI RENTRY REXIT WIDTHR TALUDR\n'
    for i in range(levels):text+=f'{i+1} 2 10.0 {-100+20*i}.0 -150.0 100.0 200.0 0.0 0.0 100.0 1.0\n'
    text+='SWNRSRF = 0\nSWSRF = '+str(swsrf)+'\n'
    if swsrf==3:text+='DATEPRI WLP\n2002-01-01 -60.0\n2002-01-05 -50.0\n2004-12-31 -60.0\n'
    if case=='prescribed':
        text+='SWSEC = 1\nDATESEC WLS\n2002-01-01 -40.0\n2002-01-05 -60.0\n2004-12-31 -40.0\n'
    else:
        automatic=case=='automatic';method=2 if case=='table' else 1
        initial=-75.0 if automatic else -90.0 if case=='water' else -45.0
        text+=f'SWSEC = 2\nWLACT = {initial}\nOSSWLM = 1.0\nNMPER = 2\n'
        text+='IMPER_4B IMPEND SWMAN WSCAP WLDIP INTWL\n'
        text+=f'1 2002-01-15 {2 if automatic else 1} {0.10 if automatic else 0.03} 5.0 3\n'
        text+=f'2 2005-01-01 {2 if automatic else 1} {0.15 if automatic else 0.08} 5.0 2\n'
        text+='SWQHR = '+str(method)+'\n'
        if method==1:
            text+='SOFCU = 1000.0\nIMPER_4C HBWEIR ALPHAW BETAW\n'
            text+=f'1 {-70 if automatic else -50}.0 0.2 1.5\n2 {-70 if automatic else -45}.0 0.3 1.5\n'
        else:
            text+='IMPER_4D IMPTAB HHTAB QHTAB\n'
            for period in (1,2):
                for index,(head,rate) in enumerate([(100.,1.),(0.,.4),(-40.,.1),(-60.,0.)],1):
                    text+=f'{period} {index} {head} {rate}\n'
        if automatic:
            text+='IMPER_4E1 DROPR HDEPTH\n1 1.0 -25.0\n2 2.0 -25.0\n'
            text+='IMPER_4E2 IMPPHASE WLSMAN GWLCRIT HCRIT VCRIT\n'
            text+='1 1 -55.0 0.0 0.0 0.0\n1 2 -40.0 -50.0 -100.0 5.0\n'
            text+='2 1 -50.0 0.0 0.0 0.0\n2 2 -35.0 -50.0 -100.0 5.0\n'
    (output/'swap.dra').write_text(text,encoding='ascii')
    return dict(original_project='reference/swap-4.3.1/projects/1.hupselbrook',
                declared_configuration=case,cofani=cofani[0],
                inputs={p.relative_to(output).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in output.rglob('*') if p.is_file()})


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case',choices=CASES,required=True)
    p.add_argument('--days',type=int,choices=(5,35,1096),default=35)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),case=a.case,optimization=a.optimization,requested_days=a.days,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',public_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        q['fixture']=fixture(a.case,a.output/'input');project=m.e.load(a.output/'input');build=a.build_root/a.case
        q.update(build_root=str(build),input_root=str(a.output/'input'));save()
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,
                 '--experimental-project',project.input_directory,'--reference-work',str(a.reference_work),
                 '--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        start=time.monotonic();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
        (a.output/'build.stdout').write_text(r.stdout,encoding='utf8');(a.output/'build.stderr').write_text(r.stderr,encoding='utf8')
        q['build']=dict(command=command,returncode=r.returncode,seconds=time.monotonic()-start);save();r.check_returncode()
        windows=[(2,4)]
        if a.days>=35:windows += [(14,17),(30,35)]
        if a.days==1096:windows += [(363,367),(530,532),(1094,1096)]
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',a.days,{a.days,*(v for pair in windows for v in pair)},240)
        q['cold']=[];save()
        for low,high in windows:
            q['cold'].append(m.own(build,a.reference_work,project,a.output/'trajectory',data,low,high,a.output/('cold-'+str(low))));save()
        q.update(status='ACTUAL_EXTENDED_ORIGINAL_SOIL_SURFACE_COMBINED_NATIVE_PERIOD_PASS',
                 maximum_surface_residual_cm=max(abs(r['surfacewater']['independent_surface_residual_cm']) for r in data),
                 maximum_combined_residual_cm=max(abs(r['surfacewater']['independent_combined_residual_cm']) for r in data),
                 surface_supply_cm=sum(r['surfacewater']['supply_cm'] for r in data),
                 surface_discharge_cm=sum(r['surfacewater']['discharge_cm'] for r in data),
                 actual_rejected_original_trials=sum(r['surfacewater']['rejected_steps'] for r in data))
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],a.case,a.optimization,a.days,flush=True)


if __name__=='__main__':main()
