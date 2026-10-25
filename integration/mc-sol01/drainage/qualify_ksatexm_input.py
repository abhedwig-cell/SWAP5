"""Selected native input/provider and current coupled file qualification."""
import argparse,base64,csv,gzip,hashlib,io,json,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();build=a.build.resolve();b=json.loads((build/'build-complete.json').read_text());sha=lambda x:hashlib.sha256(x).hexdigest();events=[];results={}
for path,h in b['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
def run(cmd,label,ok=True):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,input=b'',timeout=90)
 for s in ['stdout','stderr']:(out/(label+'.'+s)).write_bytes(getattr(r,s))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,expected_success=ok,seconds=time.monotonic()-t));(out/'events.json').write_text(json.dumps(events,indent=2));assert(r.returncode==0)==ok,(label,r.stderr.decode()[-2000:]);return r
link=next(e['command']for e in b['events']if e['category']=='link');objects=[x for x in link if x.endswith('.o')][:-1];archives=[x for x in link if x.endswith('.a')];flags=[x for x in b['flags']if not x.startswith('-J')];driver=out/'driver';test=ROOT/'tests/nut-sol/test_ksatexm_input.f90';run(b['compiler_command']+flags+['-J'+str(out),test,*objects,*archives,'-o',driver],'link')
original=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006';(out/'original.swp').write_bytes(gzip.decompress((original/'b111-swap.swp.gz').read_bytes()));(out/'original.bbc').write_bytes(gzip.decompress((original/'b111-swap.bbc.gz').read_bytes()))
r=run([driver,'original.swp','original.bbc'],'original');vectors=[list(map(float,x.split()[2:]))for x in r.stdout.decode().splitlines()if x.startswith('NODE ')];assert len(vectors)==112
for c in vectors:
 if c[9]>c[2]:
  m=c[6];se=1/(1+abs(-2*c[3])**c[5])**m;k=c[2]*se**c[4]*(1-(1-se**(1/m))**m)**2
  assert abs(c[10]-se)<2e-14 and abs(c[11]-k)<2e-12
results['original']=vectors
swpbase=(ROOT/'examples/solute_column/hydrostatic_heat.swp').read_text();nmlbase=(ROOT/'examples/solute_column/hydrostatic_heat.nml').read_text();runner=ROOT/'tools/solute/run_column.py';read=lambda p:list(csv.DictReader(p.open()))
for name,values in [('below','.002,.004'),('equal','.00475,.008'),('active','.0475,.08')]:
 case=out/name;case.mkdir();source=case/'input.nml';swp=case/'source.swp';source.write_text(nmlbase.replace('swp_water_bootstrap=.true.','swp_water_bootstrap=.true.,swp_ksatexm_bootstrap=.true.'));swp.write_text(swpbase+'\nKSATEXM='+values+'\n');run([driver,str(swp.relative_to(out))],'component-'+name)
 common=[sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',source,'--swp',swp]
 for label,extra in [('full',[]),('split',['--stop-after','1']),('resumed',['--restart',case/'split'])]:run(common+['--output',case/label]+extra,name+'-'+label)
 fs=['state.csv','endpoint.csv','temperature.csv','restart.bin'];
 for f in fs:assert(case/'full'/f).read_bytes()==(case/'resumed'/f).read_bytes(),(name,f)
 budget=read(case/'full/budget.csv');assert len(budget)==3 and read(case/'resumed/budget.csv')==budget[1:]
 for row in budget:assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
 disabled=case/'disabled.nml';disabled.write_text(nmlbase);target=case/'forbidden';run([sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',disabled,'--swp',swp,'--output',target],name+'-disabled',False);assert not target.exists()
 changed=case/'changed.swp';changed.write_text(swp.read_text().replace('KSATEXM='+values,'KSATEXM=.05,.09'));target=case/'forbidden-restart';run([sys.executable,'-B',runner,'--exe',build/'swap5_solute_column','--input',source,'--swp',changed,'--restart',case/'split','--output',target],name+'-restart-source',False);assert not target.exists()
 results[name]=dict(budget=budget,files={f:sha((case/'full'/f).read_bytes())for f in fs})
assert results['below']==results['equal'],'source no-op domain differs';assert results['active']['files']['state.csv']!=results['equal']['files']['state.csv'],'active conductivity route not observable'
for name,value in [('negative','-.1,.08'),('zero','0.,.08'),('high','100001.,.08'),('nan','NaN,.08'),('short','.08')]:
 swp=out/('invalid-'+name+'.swp');swp.write_text(swpbase+'\nKSATEXM='+value+'\n');run([driver,str(swp.relative_to(out))],'reject-'+name,False)
inputs=dict(b['input_sha256']);inputs.update({str(p.relative_to(ROOT)):sha(p.read_bytes())for p in [Path(__file__),test,runner,ROOT/'examples/solute_column/hydrostatic_heat.swp',ROOT/'examples/solute_column/hydrostatic_heat.nml',original/'b111-swap.swp.gz',original/'b111-swap.bbc.gz']});record=dict(status='KSATEXM_INPUT_COMPONENT_COUPLED_RESTART_PASS',results=results,events=events,input_sha256=inputs,build=b,source_nodes=112,coupled_cases=3,fresh_process_restarts=3,rejected_processes=11,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
