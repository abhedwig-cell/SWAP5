"""Real original aquifer source/reference using the actual production evaluator.

The index-only branch observes the actual remaining legacy update. It is a
diagnostic, never a qualified reference. Corrected soil/box/compound ledgers
must meet the unchanged1e-10 absolute guard; no whole-model B1 promotion.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[4]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
import user_prepare
from fixed_irrigation_cases import create
spec=importlib.util.spec_from_file_location('aquifer_source',Path(__file__).with_name('source.py'))
correction=importlib.util.module_from_spec(spec);spec.loader.exec_module(correction)


def assignment(text,name,value):
    text,n=re.subn(r'(?mi)^([ \t]*'+name+r'[ \t]*=[ \t]*)[^!\r\n]+',lambda m:m[1]+str(value)+' ',text)
    assert n==1,name
    return text


def fixture(case,soil,concentration,kf,decay,thickness):
    create(case,'water-file-surface')
    path=case/'swap.swp';body=path.read_text(encoding='cp1252')
    for name,value in dict(SWSOLU=1,SWIRFIX=0,SWBR=1,SWMONTH=0,DAQUIF=repr(thickness),POROS='0.35',KFSAT=repr(kf),
                           DECSAT=repr(decay),CDRAINI=repr(concentration),
                           INLIST_CSV="'WATBAL,SOLBAL,GWL'").items():body=assignment(body,name,value)
    start=body.index('  CMLTB =');end=body.index('* End of table',start)
    table,n=re.subn(r'(?m)^([ \t]*-?[\d.]+[ \t]+)[\d.]+',lambda m:m[1]+repr(soil),body[start:end]);assert n==2
    path.write_text(body[:start]+table+body[end:]+'\nNUM_DECIMALS = 12\n',encoding='cp1252')


def validate(case,stdout):
    rows=list(csv.DictReader([v for v in (case/'result_output.csv').read_text().splitlines() if v.strip() and not v.startswith('*')]))
    aq=[list(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('AQUIFER_CUMULATIVE ')]
    soil=[list(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('AQUIFER_SOIL ')]
    assert len(rows)==len(aq)==len(soil)==1097,(len(rows),len(aq),len(soil))
    assert all(len(v)==7 and all(map(math.isfinite,v)) for v in aq)
    assert all(len(v)==9 and all(map(math.isfinite,v)) for v in soil)
    maxima=dict(soil=0.,box=0.,exchange=0.,compound=0.,reported=0.)
    for day,(a,s) in enumerate(zip(aq[1:],soil[1:]),1):
        previous,old=aq[day-1],soil[day-1]
        end,delta,rain,irrig,bottom,drain,decay,root,reported=s
        incoming,outflow,box_decay=[a[i]-previous[i] for i in (3,4,5)]
        residuals=dict(soil=math.fsum([end,-old[0],-rain,-irrig,-bottom,drain,decay,root]),
            box=math.fsum([a[2],-previous[2],-incoming,outflow,box_decay]),exchange=math.fsum([incoming,-drain]),
            compound=math.fsum([end,a[2],-old[0],-previous[2],-rain,-irrig,-bottom,decay,root,outflow,box_decay]),
            reported=reported)
        for name,value in residuals.items():maxima[name]=max(maxima[name],abs(value))
    return dict(days=1096,max_residual_mg_cm2=maxima,initial_box_stock_mg_cm2=aq[0][2],
                final_box_stock_mg_cm2=aq[-1][2],actual_soil_input_mg_cm2=aq[-1][3]-aq[0][3],
                actual_surface_export_mg_cm2=aq[-1][4]-aq[0][4],actual_box_decay_mg_cm2=aq[-1][5]-aq[0][5],
                minimum_concentration_mg_cm3=min(v[0] for v in aq),loss_limited_steps=aq[-1][6],
                capacity_cm=aq[0][1])


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir();reference=a.reference_work.resolve();user_prepare.validate(reference)
    provider=reference/'build';objects=provider/'swap-obj';ttutil=provider/'ttutil-obj'
    original=(provider/'swap-selected/solute.f90').read_bytes();csv_source=(provider/'swap-selected/swap_csv_output.f90').read_bytes()
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                profiles={},events=[],step_policy=correction.STEP_POLICY,safety_factor=correction.SAFETY,
                helper_canonical_sha256=correction.HELPER,whole_scientific_equivalence='NOT_QUALIFIED',b1_promotion=False,
                SWAP5_activation=False,chemical_guard_mg_cm2=1e-10)
    def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    def call(command,directory,label,cap=60):
        started=time.perf_counter();run=subprocess.run(list(map(str,command)),cwd=directory,capture_output=True,timeout=cap)
        (directory/(label+'.stdout')).write_bytes(run.stdout);(directory/(label+'.stderr')).write_bytes(run.stderr)
        result['events'].append(dict(command=list(map(str,command)),seconds=time.perf_counter()-started,returncode=run.returncode));save()
        return run
    save()
    try:
        for opt in ('O0','O2'):
            for mode in ('legacy-index-only','corrected'):
                name=mode+'-'+opt;build=out/name;build.mkdir()
                (build/'solute.f90').write_bytes(correction.source(original,mode=mode))
                (build/'swap_csv_output.f90').write_bytes(correction.reference_csv(csv_source))
                (build/'mod_aquifer_solute_reservoir.f90').write_bytes(correction.helper_source())
                flags=['-'+opt,'-std=legacy','-ffree-line-length-none','-ffixed-line-length-none','-fallow-argument-mismatch',
                       '-fcheck=bounds','-fbacktrace','-ffp-contract=off','-march=x86-64','-mtune=generic',
                       '-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(ttutil)]
                for unit in ('mod_aquifer_solute_reservoir','solute','swap_csv_output'):
                    run=call(['gfortran',*flags,'-c',build/(unit+'.f90'),'-o',build/(unit+'.o')],build,unit+'-compile')
                    assert run.returncode==0,run.stderr.decode(errors='replace')
                exe=build/'swap_aquifer.exe'
                linked=[path for path in sorted(objects.glob('*.o')) if path.name not in ('solute.o','swap_csv_output.o')]
                linked += [build/(unit+'.o') for unit in ('mod_aquifer_solute_reservoir','solute','swap_csv_output')]
                run=call(['gfortran','-o',exe,*linked,ttutil/'libttutil.a'],build,'link');assert run.returncode==0,run.stderr.decode(errors='replace')
                result['profiles'][name]=dict(cases={},flags=flags,executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                    generated_sha256={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in build.glob('*.f90')});save()
                specs=[('soil-transfer',1.,0.,0.,0.,100.)]
                if mode=='corrected':specs += [('box-release',0.,1.,0.,0.,100.),('sorption-decay',1.,0.25,0.2,0.001,100.),('stiff-loss',0.,1.,0.,10.,0.1)]
                for key,soil,concentration,kf,decay,thickness in specs:
                    case=build/key;fixture(case,soil,concentration,kf,decay,thickness)
                    inventory={path.relative_to(case).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in case.rglob('*') if path.is_file()}
                    run=call([exe,'./swap.swp'],case,'reference',40);assert (case/'swap.ok').exists(),run.stderr.decode(errors='replace')
                    report=validate(case,run.stdout.decode(errors='replace'));report['input_sha256']=inventory
                    result['profiles'][name]['cases'][key]=report;save();print(name,key,report['max_residual_mg_cm2'],report['loss_limited_steps'],flush=True)
                    if mode=='corrected':
                        assert all(v<=1e-10 for v in report['max_residual_mg_cm2'].values()),report
                        assert report['minimum_concentration_mg_cm3']>=0,report
                    else:assert report['max_residual_mg_cm2']['compound']>1e-10,'Legacy time/ledger inconsistency not exposed'
        result['status']='CORRECTED_ORIGINAL_AQUIFER_SOIL_BOX_COMPOUND_REFERENCE_O0_O2_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
