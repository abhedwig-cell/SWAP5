"""Actual native crop/root/water/solute daily composition and complete restart."""
import argparse
import csv
from datetime import date,timedelta
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def rows(p):return [{k:float(v) for k,v in r.items()} for r in csv.DictReader(p.open())]


def main():
    ap=argparse.ArgumentParser()
    for opt in ['O0','O2']:
        for kind in ['crop-reader','root-reader','column','baseline-column']:
            ap.add_argument('--'+kind+'-'+opt,type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    paths=['tests/nut-sol/qualify_crop_root_joint.py','tools/solute/run_crop_daily.py','tools/solute/run_column.py']
    report={'status':'RUNNING','inputs':{p:sha(ROOT/p) for p in paths},'events':[],'builds':{},'cases':{},'invalid_inputs':0,'fresh_restarts':0,'fallow_preservation':{}}
    def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
    def run(cmd,cwd,valid=True):
        start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,input=b'',capture_output=True,timeout=180)
        index=len(report['events'])
        for stream in ['stdout','stderr']:(out/f'{index:04d}.{stream}').write_bytes(getattr(r,stream))
        report['events'].append({'command':list(map(str,cmd)),'cwd':str(cwd),'returncode':r.returncode,'expected_success':valid,'seconds':time.perf_counter()-start})
        save();assert (r.returncode==0)==valid,(cmd,r.stdout[-3000:],r.stderr[-3000:])
        return r
    original=(ROOT/'examples/solute_column/daily_fallow.swp').read_text()
    for opt in ['O0','O2']:
        folder=out/opt;folder.mkdir()
        binaries={kind:getattr(args,kind.replace('-','_')+'_'+opt).resolve() for kind in ['crop-reader','root-reader','column','baseline-column']}
        report['builds'][opt]={}
        for kind,exe in binaries.items():
            build=json.loads((exe.parent/'build-complete.json').read_text())
            assert build['status']=='BUILT' and build['executable_sha256']==sha(exe)
            assert all(sha(ROOT/p)==h for p,h in build['input_sha256'].items())
            assert all(sha(exe.parent/p)==h for p,h in build['generated_input_sha256'].items())
            report['builds'][opt][kind]=build
        for name in ['dry','drought','oxygen','ponded','rain','no-salt-uptake','linear','maturity']:
            case=folder/name;case.mkdir()
            swp=original.replace('SWCROP=0','SWCROP=1').replace('TSTART=28-feb-2024','TSTART=27-feb-2024').replace('TEND=01-mar-2024','TEND=05-mar-2024').replace("METFIL='daily_fallow.met'","METFIL='weather.met'")
            swp+='''
TSCF=.5
RDS=3.
CFEVAPPOND=1.
SWCFBS=0
SWREDU=0
CROPSTART CROPEND CROPFIL CROPTYPE
28-feb-2024 03-mar-2024 'crop' 1
'''
            if name=='drought':swp=swp.replace('HTB=0.,-75.,-3.,-90.','HTB=0.,-14000.,-3.,-14000.')
            if name=='oxygen':swp=swp.replace('HTB=0.,-75.,-3.,-90.','HTB=0.,-5.,-3.,-5.')
            if name=='no-salt-uptake':swp=swp.replace('TSCF=.5','TSCF=0.')
            if name=='linear':swp=swp.replace('FREXP=.5','FREXP=1.')
            crp='''IDEV=1
LCC=4
SWHARV=0
SWCF=1
SWINTER=0
SWCO2=0
SWPREP=0
SWSOW=0
SWGERM=0
SWRD=1
KDIR=.7
KDIF=.6
LAITB=0.,.2,1.,3.,2.,1.
CFTB=0.,.8,1.,1.2,2.,.9
RDTB=0.,1.,1.,2.,2.,3.
RDCTB=0.,2.,.5,1.,1.,0.
SWDROUGHT=1
SWOXYGEN=0
HLIM3L=-1000.
HLIM3H=-500.
HLIM4=-16000.
ADCRL=.1
ADCRH=.5
'''
            if name=='oxygen':crp=crp.replace('SWOXYGEN=0','SWOXYGEN=1\nHLIM1=0.\nHLIM2U=-10.\nHLIM2L=-20.')
            if name=='maturity':crp=crp.replace('IDEV=1\nLCC=4','IDEV=2\nTSUMEA=10.\nTSUMAM=20.\nTBASE=0.').replace('SWHARV=0','SWHARV=1\nDVSEND=1.')
            weather='DD MM YYYY TMIN TMAX RAIN ETREF\n';rain=[]
            for i in range(8):
                day=date(2024,2,27)+timedelta(days=i);rain_mm=[0.,1.,0.,.5,0.,0.,0.,0.][i] if name=='rain' else 0.
                etref=.02 if name=='drought' else .2
                weather+=f'{day.day} {day.month} {day.year} 15. 15. {rain_mm:.8f} {etref:.8f}\n';rain.append(rain_mm*.1)
            for filename,text in [('input.swp',swp),('crop.crp',crp),('weather.met',weather)]: (case/filename).write_text(text)
            common=[sys.executable,ROOT/'tools/solute/run_crop_daily.py','--crop-reader',binaries['crop-reader'],'--root-reader',binaries['root-reader'],'--exe',binaries['column'],'--swp',case/'input.swp','--crop',case/'crop.crp','--met',case/'weather.met']
            if name=='ponded':common+=['--initial-pond-cm','.5']
            for target,extra in [('full',[]),('split',['--stop-after','3']),('resumed',['--restart',case/'split'])]:
                run(common+['--output',case/target]+extra,case)
            for path in ['state.csv','endpoint.csv','restart.bin']:
                assert (case/'full'/path).read_bytes()==(case/'resumed'/path).read_bytes()
            encoded=(case/'full/input.nml').read_text()
            for key,expected in [('ROOT_TABLE_POINTS',3),('UPPER_LAYER_BOTTOM_NODE',2),
                                 ('MAXIMUM_ROOT_DEPTH_CM',3.),('HLIM3L',-1000.),('HLIM3H',-500.),
                                 ('HLIM4',-16000.),('ADCRL',.1),('ADCRH',.5)]:
                value=re.search(r'\b'+key+r'\s*=\s*([-+0-9.eEdD]+)',encoded)
                assert value and float(value.group(1).replace('D','E').replace('d','e'))==expected,(key,encoded)
            for key,expected in [('ROOT_RELATIVE_DEPTH',[0.,.5,1.]),('ROOT_DENSITY',[2.,1.,0.])]:
                value=re.search(r'\b'+key+r'\s*=([^=]+?)(?=\n\s*[A-Z_][A-Z_0-9]*\s*=)',encoded,re.S)
                assert value
                decoded=[]
                for token in value.group(1).split(','):
                    token=token.strip()
                    if not token:continue
                    if '*' in token:
                        count,number=token.split('*');decoded += [float(number.replace('D','E').replace('d','e'))]*int(count)
                    else:decoded.append(float(token.replace('D','E').replace('d','e')))
                assert len(decoded)==500 and decoded[:3]==expected and all(x==0. for x in decoded[3:]),key
            budget=rows(case/'full/budget.csv');assert len(budget)==8
            assert rows(case/'resumed/budget.csv')==budget[3:]
            for i,r in enumerate(budget):
                for substance,unit in [('water','cm'),('solute','mg_cm2')]:
                    residual=r[f'{substance}_end_{unit}']-r[f'{substance}_start_{unit}']-r[f'{substance}_in_{unit}']+r[f'{substance}_out_{unit}']
                    assert abs(residual)<1e-10 and abs(r[f'{substance}_residual_{unit}'])<1e-10
                gross=r['water_end_cm']-r['water_start_cm']-rain[i]+r['soil_evaporation_cm']+r['pond_evaporation_cm']+r['runoff_cm']+r['actual_transpiration_cm']
                assert abs(gross)<1e-10,(name,i,gross)
                assert -1e-15<=r['actual_transpiration_cm']<=r['potential_transpiration_cm']+1e-12
                assert abs(r['potential_transpiration_cm']-r['actual_transpiration_cm']-r['drought_reduction_cm']-r['oxygen_reduction_cm'])<1e-12
            assert sum(r['actual_transpiration_cm'] for r in budget)>0
            if name=='dry':assert all(abs(r['actual_transpiration_cm']-r['potential_transpiration_cm'])<1e-12 for r in budget)
            if name=='drought':assert sum(r['drought_reduction_cm'] for r in budget)>0
            if name=='oxygen':assert sum(r['oxygen_reduction_cm'] for r in budget)>0
            if name=='no-salt-uptake':assert abs(budget[-1]['solute_end_mg_cm2']-budget[0]['solute_start_mg_cm2'])<1e-10
            elif name!='rain':assert sum(r['solute_out_mg_cm2'] for r in budget)>0
            assert budget[0]['actual_transpiration_cm']==budget[-1]['actual_transpiration_cm']==0.
            if name=='maturity':assert all(r['actual_transpiration_cm']==0. for r in budget[2:])
            report['cases'][opt+'-'+name]={'budget':budget,'rain_cm':rain,'restart_sha256':sha(case/'full/restart.bin')}
            report['fresh_restarts']+=1
        base=folder/'dry'
        # New crop caller with an entirely fallow period must reproduce the
        # unchanged incumbent application, including accepted adaptive history.
        case=folder/'fallow';case.mkdir()
        for f in ['input.swp','crop.crp','weather.met']:(case/f).write_bytes((base/f).read_bytes())
        (case/'input.swp').write_text((case/'input.swp').read_text().replace(
            "28-feb-2024 03-mar-2024 'crop' 1", "01-apr-2024 10-apr-2024 'crop' 1"))
        cmd=[sys.executable,ROOT/'tools/solute/run_crop_daily.py','--crop-reader',binaries['crop-reader'],
             '--root-reader',binaries['root-reader'],'--exe',binaries['column'],'--swp',case/'input.swp',
             '--crop',case/'crop.crp','--met',case/'weather.met','--output',case/'new']
        run(cmd,case)
        document=(case/'new/input.nml').read_text();assert document.count('&CROP')==1
        (case/'old.nml').write_text(document.split('&CROP',1)[0])
        run([sys.executable,ROOT/'tools/solute/run_column.py','--exe',binaries['baseline-column'],
             '--swp',case/'input.swp','--input',case/'old.nml','--output',case/'old'],case)
        equal={}
        for f in ['state.csv','endpoint.csv','restart.bin']:
            assert (case/'new'/f).read_bytes()==(case/'old'/f).read_bytes(),(opt,f)
            equal[f]=sha(case/'new'/f)
        a,b=rows(case/'new/budget.csv'),rows(case/'old/budget.csv');assert len(a)==len(b)==8
        assert all(all(x[k]==y[k] for k in y) for x,y in zip(a,b))
        assert all(x['actual_transpiration_cm']==0. for x in a)
        report['fallow_preservation'][opt]=equal
        invalid=[('physical-oxygen','crop.crp','SWOXYGEN=0','SWOXYGEN=2'),('compensation','crop.crp','SWOXYGEN=0','SWOXYGEN=0\nSWCOMPENSATE=1'),
                 ('density-order','crop.crp','RDCTB=0.,2.,.5,1.,1.,0.','RDCTB=0.,2.,0.,1.,1.,0.'),
                 ('empty-density','crop.crp','RDCTB=0.,2.,.5,1.,1.,0.','RDCTB=0.,0.,.5,0.,1.,0.'),
                 ('stress-order','crop.crp','ADCRH=.5','ADCRH=.05'),('depth','input.swp','RDS=3.','RDS=4.'),
                 ('rain-mode','input.swp','SWRAIN=0','SWRAIN=1'),('evaporation-off','input.swp','SWRAIN=0','SWRAIN=0\nSWEVAP=0'),('snow','input.swp','SWSNOW=0','SWSNOW=1'),('nutrients','input.swp','SWCROP=1','SWCROP=1\nSWCROPSNM=1'),('bad-calendar','weather.met','29 2 2024','1 3 2024')]
        for name,filename,old,new in invalid:
            case=folder/('invalid-'+name);case.mkdir()
            for f in ['input.swp','crop.crp','weather.met']:(case/f).write_bytes((base/f).read_bytes())
            assert old in (case/filename).read_text();(case/filename).write_text((case/filename).read_text().replace(old,new))
            cmd=[sys.executable,ROOT/'tools/solute/run_crop_daily.py','--crop-reader',binaries['crop-reader'],'--root-reader',binaries['root-reader'],'--exe',binaries['column'],'--swp',case/'input.swp','--crop',case/'crop.crp','--met',case/'weather.met','--output',case/'forbidden']
            run(cmd,case,False);assert not (case/'forbidden').exists();report['invalid_inputs']+=1
        # Validate the entire plan before a requested fallow-only prefix can
        # publish an invalid future configuration.
        document=(base/'full/input.nml').read_text()
        for name,extra in [('zero-density',' root_density=500*0d0'),
                           ('future-no-roots',' root_depth_cm(3)=0d0, potential_transpiration_cm_day(3)=.1d0'),
                           ('second-sink',None)]:
            case=folder/('invalid-plan-'+name);case.mkdir()
            if extra is None:
                modified=document.replace('\n/\n&surface','\n root_cm_day(1)=.1d0\n/\n&surface',1)
                assert modified!=document
            else:
                prefix,slash,ending=document.rpartition('/')
                assert slash and not ending.strip()
                modified=prefix+'\n'+extra+'\n/\n'
            (case/'input.nml').write_text(modified)
            run([sys.executable,ROOT/'tools/solute/run_column.py','--exe',binaries['column'],
                 '--input',case/'input.nml','--swp',base/'input.swp','--output',case/'forbidden','--stop-after','1'],case,False)
            assert not (case/'forbidden').exists();report['invalid_inputs']+=1
        # Complete original bytes bind continuation, including inactive/comment bytes.
        for filename in ['crop.crp','weather.met','input.swp']:
            case=folder/('changed-'+filename);case.mkdir()
            for f in ['input.swp','crop.crp','weather.met']:(case/f).write_bytes((base/f).read_bytes())
            with (case/filename).open('a') as stream:stream.write('\n* exact restart provenance change\n')
            cmd=[sys.executable,ROOT/'tools/solute/run_crop_daily.py','--crop-reader',binaries['crop-reader'],'--root-reader',binaries['root-reader'],'--exe',binaries['column'],'--swp',case/'input.swp','--crop',case/'crop.crp','--met',case/'weather.met','--output',case/'forbidden','--restart',base/'split']
            run(cmd,case,False);assert not (case/'forbidden').exists();report['invalid_inputs']+=1
    report.update(status='NATIVE_CROP_ROOT_JOINT_O0_O2_PASS',full_historical_migration=False,substep_stress_feedback=False)
    save();print(json.dumps({k:v for k,v in report.items() if k not in ['events','inputs','builds','cases']}))


if __name__=='__main__':main()
