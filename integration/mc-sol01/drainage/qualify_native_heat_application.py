"""Real current file heat bootstrap, independent process restart and legacy callers."""
import argparse,csv,hashlib,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--phase',choices=['pilot','full'],default='full');a=p.parse_args();build=a.build.resolve();out=a.output.resolve();out.mkdir();sha=lambda b:hashlib.sha256(b).hexdigest();b=json.loads((build/'build-complete.json').read_text());exe=build/'swap5_solute_column';events=[];results={}
for path,h in b['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
assert b['status']=='BUILT'and sha(exe.read_bytes())==b['executable_sha256']
base_swp=(ROOT/'examples/solute_column/layered_water.swp').read_text();base_nml=(ROOT/'examples/solute_column/swp_water.nml').read_text();runner=ROOT/'tools/solute/run_column.py';opt=next(x[1:]for x in b['flags']if x in ['-O0','-O2'])
def run(cmd,label,ok=True):
 start=time.monotonic();r=subprocess.run(list(map(str,cmd)),capture_output=True,input=b'',timeout=120);(out/(label+'.stdout')).write_bytes(r.stdout);(out/(label+'.stderr')).write_bytes(r.stderr);events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start));(out/'events.json').write_text(json.dumps(events,indent=2));assert (r.returncode==0)==ok,(label,r.stdout.decode()[-1000:],r.stderr.decode()[-2000:]);return r
read=lambda p:[{k:float(v)for k,v in r.items()}for r in csv.DictReader(p.open())]
for exponent in ([.5]if a.phase=='pilot'else[.5,1.,2.]):
 case=out/('bootstrap-'+str(exponent));case.mkdir();swp=case/'source.swp';source=case/'input.nml'
 swp.write_text(base_swp.replace('SWHEA=0','SWHEA=1\nSWCALT=2\nSWTOPBHEA=1\nSWBOTBHEA=1').replace('FREXP=.5','FREXP='+str(exponent))+'''\nPSAND PSILT PCLAY ORGMAT
.194 .529 .277 .021
.157 .471 .372 .010
TSOILTB=0.,5.,-1.,8.,-3.,12.
''')
 source.write_text(base_nml.replace('swp_water_bootstrap=.true.','swp_water_bootstrap=.true., swp_heat_bootstrap=.true., dynamic_temperature=.true.').replace('windows=2, ends_day=.001,.002','windows=3, ends_day=.001,.002,.003').replace('2*.','3*.').replace('\n rain_cm_day=','\n air_temperature_c=20.,2.,15.\n rain_cm_day='))
 common=[sys.executable,'-B',runner,'--exe',exe,'--input',source,'--swp',swp]
 for name,extra in [('full',[]),('split',['--stop-after','1']),('resumed',['--restart',case/'split'])]:run(common+['--output',case/name]+extra,str(exponent)+'-'+name)
 for name in ['restart.bin','state.csv','temperature.csv','endpoint.csv']:assert(case/'full'/name).read_bytes()==(case/'resumed'/name).read_bytes(),name
 rows=read(case/'full/budget.csv');assert len(rows)==3 and read(case/'resumed/budget.csv')==rows[1:]
 assert max(abs(x['water_residual_cm'])for x in rows)<1e-10 and max(abs(x['solute_residual_mg_cm2'])for x in rows)<1e-10
 temperatures=read(case/'full/temperature.csv');assert len(temperatures)==4 and all(2<=r['temperature_c']<=20 for r in temperatures)
 assert b'SWP_NATIVE_NUMERIC_HEAT_BOOTSTRAP_IMPORTED'in(case/'full/stdout').read_bytes()
 before={x.name:sha(x.read_bytes())for x in (case/'split').iterdir()}
 altered=case/'changed.swp';altered.write_text(swp.read_text().replace('.157 .471 .372 .010','.157 .471 .372 .011'))
 target=case/'forbidden-source-restart';run([sys.executable,'-B',runner,'--exe',exe,'--input',source,'--swp',altered,'--restart',case/'split','--output',target],str(exponent)+'-wrong-swp',False);assert not target.exists()
 bad=case/'override.nml';bad.write_text(source.read_text().replace('dynamic_temperature=.true.','dynamic_temperature=.true.,initial_temperature_c=4*11.'))
 target=case/'forbidden-temperature-override';run([sys.executable,'-B',runner,'--exe',exe,'--input',bad,'--swp',swp,'--output',target],str(exponent)+'-override',False);assert not target.exists()
 conflict=case/'conflicting-top.nml';conflict.write_text(source.read_text().replace('air_temperature_c=20.,2.,15.','air_temperature_c=20.,2.,15.,surface_temperature_c=3*11.'))
 target=case/'forbidden-conflicting-top';run([sys.executable,'-B',runner,'--exe',exe,'--input',conflict,'--swp',swp,'--output',target],str(exponent)+'-conflicting-top',False);assert not target.exists()
 assert before=={x.name:sha(x.read_bytes())for x in (case/'split').iterdir()}
 results[str(exponent)]=dict(water_max=max(abs(x['water_residual_cm'])for x in rows),solute_max=max(abs(x['solute_residual_mg_cm2'])for x in rows),endpoint=read(case/'full/endpoint.csv'),temperature=temperatures,files={x:sha((case/'full'/x).read_bytes())for x in ['budget.csv','state.csv','temperature.csv','endpoint.csv','restart.bin']})
# Exact source preimage main with current unchanged old provider procedures.
link=next(e['command']for e in b['events']if e['category']=='link');objects=[x for x in link if x.endswith('.o')][:-1];archives=[x for x in link if x.endswith('.a')];flags=[x for x in b['flags']if not x.startswith('-J')];old=out/'preimage_main.f90';old.write_bytes(subprocess.check_output(['git','show','de6299171e3b13d8f444993e9bf8893ad15fec72:app/solute_column/main.f90'],cwd=ROOT));pre=out/'preimage_column';run(b['compiler_command']+flags+['-J'+str(out),old,*objects,*archives,'-o',pre],'preimage-link')
meta=dict(b);meta['executable_sha256']=sha(pre.read_bytes());meta['preimage_main_sha256']=sha(old.read_bytes());meta['comparator_scope']='Original main, current unchanged existing provider procedures; new source constructor not called';(out/'build-complete.json').write_text(json.dumps(meta,indent=2))
for name,text,swptext in [('incumbent-water',base_nml,base_swp),('incumbent-explicit-heat',base_nml.replace('swp_water_bootstrap=.true.','swp_water_bootstrap=.true.,dynamic_temperature=.true.,initial_temperature_c=4*12.'),base_swp.replace('SWHEA=0','SWHEA=1'))]:
 case=out/name;case.mkdir();source=case/'input.nml';source.write_text(text);swp=case/'source.swp';swp.write_text(swptext)
 for label,binary in [('current',exe),('preimage',pre)]:run([sys.executable,'-B',runner,'--exe',binary,'--input',source,'--swp',swp,'--output',case/label],name+'-'+label)
 fs=['budget.csv','state.csv','endpoint.csv','restart.bin']+(['temperature.csv']if name.endswith('heat')else[])
 for f in fs:assert(case/'current'/f).read_bytes()==(case/'preimage'/f).read_bytes(),(name,f)
 results[name]={f:sha((case/'current'/f).read_bytes())for f in fs}
inputs=dict(b['input_sha256']);inputs.update({str(p.relative_to(ROOT)):sha(p.read_bytes())for p in [Path(__file__),runner,ROOT/'examples/solute_column/layered_water.swp',ROOT/'examples/solute_column/swp_water.nml']});report=dict(status='NATIVE_HEAT_FILE_COUPLING_RESTART_AND_INCUMBENT_PASS',optimization=opt,phase=a.phase,results=results,events=events,input_sha256=inputs,provider_build=b,source_identity_restart_rejections=len([x for x in results if x[0].isdigit()]),full_original_Andelst=False,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(report,indent=2));print(report['status'])
