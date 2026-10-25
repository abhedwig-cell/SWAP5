"""Focused original water/heat initialization and real file restart qualification."""
import argparse,base64,csv,gzip,hashlib,io,json,re,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE='a44c346216b67a2b9db4acbcfa18c229442648a9'
p=argparse.ArgumentParser();p.add_argument('--build',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args();build=a.build.resolve();out=a.output.resolve();out.mkdir();b=json.loads((build/'build-complete.json').read_text());opt=next(x[1:]for x in b['flags']if x in ['-O0','-O2']);events=[];results={};sha=lambda x:hashlib.sha256(x).hexdigest()
for path,h in b['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
assert sha((build/'swap5_solute_column').read_bytes())==b['executable_sha256']
def run(cmd,label,cwd=None,ok=True):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd or out,capture_output=True,input=b'',timeout=90)
 for s in ['stdout','stderr']:(out/(label+'.'+s)).write_bytes(getattr(r,s))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-t,expected_success=ok));(out/'events.json').write_text(json.dumps(events,indent=2));assert(r.returncode==0)==ok,(label,r.stdout.decode()[-1000:],r.stderr.decode()[-2000:]);return r
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as archive:
 raw=archive.extractfile('SWAP/soilwater.f90').read();text=raw.decode('latin1');start=text.index('            if (gwl > 0.0d0) then');end=text.index('            end do',start)+len('            end do');block=text[start:end]
literal='module hydrostatic_literal\nimplicit none\ncontains\nsubroutine original_initialize(numnod,gwl,z,h,pond)\ninteger,intent(in)::numnod\nreal(8),intent(in)::gwl,z(:)\nreal(8),intent(out)::h(:),pond\ninteger::i\n'+block+'\nend subroutine\nend module\n';(out/'literal.f90').write_text(literal);(out/'original-soilwater.f90').write_bytes(raw)
link=next(e['command']for e in b['events']if e['category']=='link');objects=[x for x in link if x.endswith('.o')][:-1];archives=[x for x in link if x.endswith('.a')];driver=out/'driver';flags=[x for x in b['flags']if not x.startswith('-J')];test=ROOT/'tests/nut-sol/test_hydrostatic_bootstrap.f90'
run(b['compiler_command']+flags+['-J'+str(out),out/'literal.f90',test,*objects,*archives,'-o',driver],'driver-link')
original=gzip.decompress((ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.swp.gz').read_bytes()).decode('latin1');bbc=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.bbc.gz';(out/'original.bbc').write_bytes(gzip.decompress(bbc.read_bytes()));swpbase=(ROOT/'examples/solute_column/layered_heat.swp').read_text();nmlbase=(ROOT/'examples/solute_column/native_heat.nml').read_text();runner=ROOT/'tools/solute/run_column.py'
def hydro(gwl,bottom=2):return swpbase.replace('SWINCO=1',f'SWINCO=2\nSWBOTB={bottom}\nGWLI={gwl}').replace('HTB=0.,-75.,-3.,-90.','')
source_cases={'original':original,**{name:hydro(g,bottom)for name,g,bottom in [('below',-4.,2),('intersect',-2.,2),('shallow',-.5,2),('surface',0.,2),('pond',.25,2),('bottom8',-3.,8),('deep',-10000.,2),('high',1000.,2)]}}
for name,text in source_cases.items():
 file=out/(name+'.swp');file.write_text(text);r=run([driver,file.name]+(['external-bbc','original.bbc']if name=='original'else[]),'source-'+name)
 assert b'SOURCE_HYDROSTATIC_AND_HEAT_INITIALIZATION_PASS'in r.stdout
 rows=[list(map(float,line.split()[2:]))for line in r.stdout.decode().splitlines()if line.startswith('NODE ')];assert len(rows)==(112 if name=='original' else 4)
 pond=float(next(line.split()[1]for line in r.stdout.decode().splitlines()if line.startswith('POND ')))
 results['source-'+name]=dict(nodes=rows,pond=pond)
invalid={
 'bottom-touch':hydro(-3.),'bottom-near':hydro(-2.99995),'table-boundary':hydro(-2.,1),
 'missing-gwl':hydro(-2.).replace('GWLI=-2.0',''), 'missing-bottom':hydro(-2.).replace('SWBOTB=2',''),
 'nonfinite':hydro('NaN'),'below-range':hydro(-10001.),'above-range':hydro(1001.),
 'loose-restart':hydro(-2.).replace('SWINCO=2','SWINCO=3'),
 'ksatexm':hydro(-2.)+'\nKSATEXM=.1,.1\n'}
for name,text in invalid.items():
 file=out/('invalid-'+name+'.swp');file.write_text(text);run([driver,file.name],'reject-'+name,ok=False)
run([driver,'intersect.swp','omit-pond'],'reject-missing-pond-owner',ok=False)
read=lambda file:[{k:float(v)for k,v in row.items()}for row in csv.DictReader(file.open())]
for name,g,exponent in [('below',-4.,.5),('intersect',-2.,1.),('shallow',-.5,2.)]:
 case=out/('app-'+name);case.mkdir();source=case/'input.nml';swp=case/'source.swp';swp.write_text(hydro(g).replace('FREXP=0.5','FREXP='+str(exponent)));source.write_text(nmlbase.replace('initial_pond_cm=.5','initial_pond_cm=0.'))
 common=[sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',source,'--swp',swp]
 for label,extra in [('full',[]),('split',['--stop-after','1']),('resumed',['--restart',case/'split'])]:run(common+['--output',case/label]+extra,name+'-'+label)
 names=['restart.bin','state.csv','temperature.csv','endpoint.csv']
 for f in names:assert(case/'full'/f).read_bytes()==(case/'resumed'/f).read_bytes(),(name,f)
 budget=read(case/'full/budget.csv');assert len(budget)==3 and read(case/'resumed/budget.csv')==budget[1:]
 # Independent MvG/Freundlich initial inventory using source layer parameters.
 water=max(g,0.);solute=.25
 for i,(dz,z,h,temp,ts)in enumerate(results['source-'+name]['nodes']):
  layer=0 if i<2 else 1;tr,alpha,n,rhokf=[(.032,.0135,1.455,.26),(.04,.02,1.6,.6)][layer];theta=ts if h>=0 else tr+(ts-tr)/(1+abs(alpha*h)**n)**(1-1/n);c=.2+(-z)*.2;water+=dz*theta;solute+=dz*(theta*c+rhokf*c**exponent)
 assert abs(budget[0]['water_start_cm']-water)<2e-13,(name,budget[0]['water_start_cm'],water)
 assert abs(budget[0]['solute_start_mg_cm2']-solute)<2e-13,(name,budget[0]['solute_start_mg_cm2'],solute)
 assert max(abs(row['water_residual_cm'])for row in budget)<1e-10
 assert max(abs(row['solute_residual_mg_cm2'])for row in budget)<1e-10
 before={f.name:sha(f.read_bytes())for f in(case/'split').iterdir()}
 changed=case/'changed.swp';changed.write_text(swp.read_text().replace('GWLI='+str(g),'GWLI='+str(g+.01)));target=case/'forbidden-restart';run([sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',source,'--swp',changed,'--restart',case/'split','--output',target],name+'-reject-source',ok=False);assert not target.exists()
 override=case/'override.nml';override.write_text(source.read_text().replace('initial_pond_cm=0.','initial_pond_cm=.1'));target=case/'forbidden-pond';run([sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',override,'--swp',swp,'--output',target],name+'-reject-pond',ok=False);assert not target.exists();assert before=={f.name:sha(f.read_bytes())for f in(case/'split').iterdir()}
 results['app-'+name]=dict(budget=budget,water_initial_independent=water,solute_initial_independent=solute,files={f:sha((case/'full'/f).read_bytes())for f in names})
for name,g in [('surface',0.),('pond',.25)]:
 case=out/('app-reject-'+name);case.mkdir();source=case/'input.nml';swp=case/'source.swp';source.write_text(nmlbase.replace('initial_pond_cm=.5','initial_pond_cm=0.'));swp.write_text(hydro(g));target=case/'forbidden';run([sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',source,'--swp',swp,'--output',target],'reject-file-'+name,ok=False);assert not target.exists()
 # Recover comparator artifacts from the immutable accepted evidence, not a local build.
prior_capsule=ROOT/'integration/mc-sol01/drainage/NATIVE_HEAT_BOOTSTRAP_EVIDENCE.tar.xz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(prior_capsule.read_bytes())),mode='r:xz')as archive:
 manifest=json.loads(archive.extractfile('MANIFEST.json').read())
 for member in archive.getmembers():
  if member.name.startswith('app-'+opt+'/')and member.isfile():
   data=archive.extractfile(member).read();assert sha(data)==manifest[member.name]
   relative=Path(member.name).relative_to('app-'+opt);assert '..'not in relative.parts
   target=out/'predecessor'/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
# Existing three already-qualified SWINCO1 heat cases must preserve exact artifacts.
for exponent in ['0.5','1.0','2.0']:
 case=out/('incumbent-'+exponent);case.mkdir();prior=out/'predecessor'/('bootstrap-'+exponent);source=case/'input.nml';source.write_bytes((prior/'input.nml').read_bytes());swp=case/'source.swp';swp.write_bytes((prior/'source.swp').read_bytes());run([sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',source,'--swp',swp,'--output',case/'current'],'incumbent-'+exponent)
 fs=['budget.csv','state.csv','temperature.csv','endpoint.csv','restart.bin']
 for f in fs:assert(case/'current'/f).read_bytes()==(prior/'full'/f).read_bytes(),(exponent,f)
 results['incumbent-'+exponent]={f:sha((case/'current'/f).read_bytes())for f in fs}
for name in ['incumbent-water','incumbent-explicit-heat']:
 prior=out/'predecessor'/name;case=out/name;case.mkdir();source=case/'input.nml';source.write_bytes((prior/'input.nml').read_bytes());swp=case/'source.swp';swp.write_bytes((prior/'source.swp').read_bytes());run([sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',source,'--swp',swp,'--output',case/'current'],name)
 fs=['budget.csv','state.csv','endpoint.csv','restart.bin']+(['temperature.csv']if name.endswith('heat')else[])
 for f in fs:assert(case/'current'/f).read_bytes()==(prior/'current'/f).read_bytes(),(name,f)
 results[name]={f:sha((case/'current'/f).read_bytes())for f in fs}
inputs=dict(b['input_sha256'])
for path in [Path(__file__),test,runner,bbc,prior_capsule,ROOT/'examples/solute_column/layered_heat.swp',ROOT/'examples/solute_column/native_heat.nml',ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.swp.gz']:inputs[str(path.relative_to(ROOT))]=sha(path.read_bytes())
record=dict(status='HYDROSTATIC_SOURCE_HEAT_FILE_RESTART_AND_INCUMBENT_PASS',optimization=opt,results=results,events=events,input_sha256=inputs,build=b,original_soilwater_sha256=sha(raw),literal_sha256=sha((out/'literal.f90').read_bytes()),source_cases=len(source_cases),source_negative_processes=len(invalid)+1,file_cases=3,fresh_process_restarts=3,file_negative_processes=8,full_original_Andelst=False,canonically_admitted=False)
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
