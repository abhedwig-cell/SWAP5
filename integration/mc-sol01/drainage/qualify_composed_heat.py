"""Typed combined restart and real481-day Boesten/drainage/heat lifecycle."""
import argparse,csv,hashlib,json,os,re,runpy,struct,subprocess,sys,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();bundle=a.bundle.resolve();events=[];results={};sha=lambda b:hashlib.sha256(b).hexdigest()
def run(cmd,label,ok=True):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),capture_output=True,timeout=240)
 for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,expected_success=ok,seconds=time.monotonic()-t));(out/'events.json').write_text(json.dumps(events,indent=2));assert(r.returncode==0)==ok,(label,r.stdout.decode()[-1000:],r.stderr.decode()[-2000:]);return r
meta=json.loads((bundle/'column/build-complete.json').read_text());physical=meta['source_build'];objects=[e['command'][-1]for e in physical['events']if e['category']=='compile'][:-1];archive=Path(physical['flags'][physical['flags'].index(next(x for x in physical['flags']if x.startswith('-J')))][2:])/'libttutil.a';flags=[x for x in meta['flags']if not x.startswith('-J')];driver=out/'typed-restart';test=ROOT/'tests/nut-sol/test_composed_heat_restart.f90'
run(meta['compiler_command']+flags+['-J'+str(out),test,*objects,archive,'-o',driver],'typed-link');rawfile=out/'pair.bin';run([driver,'create',rawfile],'typed-create');raw=rawfile.read_bytes();assert raw[:8]==b'S5PT0002';run([driver,'read',rawfile,out/'roundtrip.bin'],'typed-read');assert raw==(out/'roundtrip.bin').read_bytes()
pair=struct.pack('=dd',2.,.5);assert raw.count(pair)==1;offset=raw.index(pair)
def changed(data):return bytes(data[:-4])+struct.pack('=I',zlib.crc32(bytes(data[:-4])))
corruptions={}
for name,values in [('negative-spev',(-1.,.5)),('negative-saev',(2.,-1.)),('nan-pair',(float('nan'),.5))]:
 data=bytearray(raw);data[offset:offset+16]=struct.pack('=dd',*values);corruptions[name]=changed(data)
data=bytearray(raw);data[:8]=b'S5PT0001';corruptions['wrong-tag']=changed(data);data=bytearray(raw);data[-1]^=1;corruptions['crc']=bytes(data);corruptions['truncated']=raw[:-40]
for name,data in corruptions.items():
 file=out/(name+'.bin');file.write_bytes(data);run([driver,'reject',file],'typed-'+name)
run([driver,'reject-parameter',rawfile],'typed-parameter')
case=out/'project';runpy.run_path(str(ROOT/'tests/nut-sol/qualify_native_cauchy3.py'))['fixture'](case);source=(case/'project.swp').read_text().replace('SWHEA=0','SWHEA=1\nSWCALT=2\nSWTOPBHEA=1\nSWBOTBHEA=1').replace('SWDC=0','SWDC=1\nDECPOT=.001,.002\nGAMPAR=.05\nRTHETA=.3\nBEXP=1.\nFDEPTH=1.,1.')
source+='\nPSAND PSILT PCLAY ORGMAT\n.194 .529 .277 .021\n.157 .471 .372 .010\nTSOILTB=0.,5.,-40.,8.,-120.,12.\n';common=[sys.executable,'-B',ROOT/'tools/solute/run_project.py',case/'project.swp','--bundle',bundle,'--native-hydraulics','--native-heat','--temporal-tolerance','.01','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero'];rows=lambda p:list(csv.DictReader(p.open()))
for name,text in [('boesten',source),('plain',source.replace('SWREDU=2','SWREDU=0').replace('FREXP=.5','FREXP=2.'))]:
 (case/'project.swp').write_text(text);folder=out/name;folder.mkdir()
 for label,extra in [('full',[]),('split',['--stop-after','365']),('resumed',['--restart',folder/'split'])]:run(common+['--output',folder/label]+extra,name+'-'+label)
 files=['state.csv','endpoint.csv','temperature.csv','restart.bin'];budget=rows(folder/'full/budget.csv');assert len(budget)==481 and budget[365:]==rows(folder/'resumed/budget.csv')
 for f in files:assert(folder/'full'/f).read_bytes()==(folder/'resumed'/f).read_bytes()
 assert(folder/'full/restart.bin').read_bytes()[:8]==(b'S5PT0002'if name=='boesten'else b'S5PT0001')
 for row in budget:
  assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10 and float(row['observed_heat_residual_j_cm2'])<=1e-9
  assert abs(float(row['potential_transpiration_cm'])-float(row['actual_transpiration_cm'])-float(row['drought_reduction_cm'])-float(row['oxygen_reduction_cm']))<1e-12
  independent=float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['rain_supplied_cm'])+float(row['runoff_cm'])+float(row['soil_evaporation_cm'])+float(row['pond_evaporation_cm'])+float(row['actual_transpiration_cm'])-float(row['bottom_up_cm'])+float(row['drainage_cm']);assert abs(independent)<1e-10
 assert sum(float(r['drainage_cm'])for r in budget)>0 and sum(float(r['actual_transpiration_cm'])for r in budget)>0
 result=dict(files={f:sha((folder/'full'/f).read_bytes())for f in files},budget=budget)
 if name=='boesten':
  pairs={label:list(map(float,re.search(r'SWAP5_COMMITTED_BOESTEN_PAIR=\s*([-+\d.Ee]+)\s+([-+\d.Ee]+)',(folder/label/'stdout').read_text()).groups()))for label in ['full','split','resumed']};assert pairs['full']==pairs['resumed']and min(pairs['full']+pairs['split'])>=0;result['committed_pairs']=pairs
 results[name]=result;bbc=case/'swap.bbc';old=bbc.read_bytes();bbc.write_bytes(old.replace(b'1998-12-31',b'1998-12-30'));target=folder/'foreign-bbc';run(common+['--restart',folder/'split','--output',target],name+'-foreign-bbc',False);assert not target.exists();bbc.write_bytes(old)
for name,text in [('analytic',source.replace('SWCALT=2','SWCALT=1')),('snow',source.replace('SWSNOW=0','SWSNOW=1')),('macro',source.replace('SWMACRO=0','SWMACRO=1')),('bad-cofred',source.replace('COFREDBO=0.79','COFREDBO=0.')),('extended-drainage',source.replace('SWDRA=1','SWDRA=2')),('wrong-heat',source.replace('SWHEA=1','SWHEA=0'))]:
 (case/'project.swp').write_text(text);target=out/('forbidden-'+name);run(common+['--output',target],name,False);assert not target.exists()
inputs=dict(meta['input_sha256'])
for path in [test,Path(__file__),ROOT/'tools/solute/run_project.py',ROOT/'tools/solute/run_column.py',ROOT/'app/solute_crop/read_swp_project.f90']:inputs[str(path.relative_to(ROOT))]=sha(path.read_bytes())
record=dict(status='COMPOSED_BOESTEN_DRAIN_HEAT481_RESTART_PASS',events=events,results=results,input_sha256=inputs,typed_pair_controls=7,typed_pair_roundtrip_exact=True,coupled_cases=2,fresh_process_restarts=2,complete_days=481,rejected_processes=8,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
