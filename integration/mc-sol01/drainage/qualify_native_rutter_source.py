"""Execute original prepared crop demand and detailed rain through the real owner."""
import argparse,csv,hashlib,json,math,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest();p=argparse.ArgumentParser();p.add_argument('--fc',required=True);p.add_argument('--reader-proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();proof=a.reader_proof.resolve();r=json.loads((proof/'RESULT.json').read_bytes());assert r['status']=='ORIGINAL_RUTTER_CROP_WEATHER481_O0_O2_PREPARATION_PASS';rows=lambda p:list(csv.DictReader(p.open()));plans=[];bindings={str(proof/'RESULT.json'):sha((proof/'RESULT.json').read_bytes())}
for index in sorted({k.split('period')[1] for k in r['results']}):
 d=proof/('O2-period'+index);crop=rows(d/'qualified-crop.csv');rutter=rows(d/'qualified-rutter.csv');assert len(crop)==len(rutter)==481;plans.append((crop,rutter))
 for name in ['qualified-crop.csv','qualified-rutter.csv']:bindings[str(d/name)]=sha((d/name).read_bytes())
combined=[]
for i in range(481):
 active=[(c[i],r[i])for c,r in plans if float(c[i]['active'])==1];assert len(active)<=1
 if active:combined.append(active[0])
 else:combined.append(next((c[i],r[i])for c,r in plans if float(c[i]['active'])==0))
rainfile=proof/'original-preparation/rain_events.csv';rain=rows(rainfile);bindings[str(rainfile)]=sha(rainfile.read_bytes());left=0.;segments=[]
for row in rain:
 right=float(row['end_day']);rate=float(row['rate_cm_day']);assert right>left
 while left<min(right,481.):
  day=min(int(math.floor(left)),480);end=min(right,float(day+1),481.);assert end>left
  c,r=combined[day];segments.append([len(segments)+1,left,end,rate*(end-left),float(c['cover']),float(r['capacity_cm']),float(r['dry_transpiration_cm_day']),float(r['wet_transpiration_cm_day']),float(r['interception_evaporation_cm_day'])]);left=end
 if left>=481:break
assert left==481. and len(segments)>481
source=out/'original-source.dat';source.write_text('\n'.join(' '.join(format(x,'.17g')if isinstance(x,float)else str(x)for x in row)for row in segments)+'\n')
sources=[ROOT/p for p in ['src/runtime/mod_interception_source_window_runtime.f90','src/process/mod_rutter_interception_process.f90','src/process/mod_rutter_event_integrator.f90','src/runtime/mod_rutter_source_window_processor.f90','tests/nut-sol/test_native_rutter_source.f90']];events=[];streams=[]
for opt in ['O0','O2']:
 d=out/opt;d.mkdir();exe=d/'source';flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(d),'-I'+str(d)]
 for label,cmd in [('link',[a.fc,*flags,*map(str,sources),'-o',str(exe)]),('plain',[str(exe),str(source),'plain']),('restart',[str(exe),str(source),'restart'])]:
  start=time.monotonic();cp=subprocess.run(cmd,cwd=d,capture_output=True)
  for stream in ['stdout','stderr']:(d/(label+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(label=opt+'/'+label,command=cmd,returncode=cp.returncode,seconds=time.monotonic()-start));(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,cp.stdout.decode()+cp.stderr.decode()
  if label!='link':streams.append(cp.stdout)
assert len(set(streams))==1
record=dict(status='ORIGINAL_RUTTER_SOURCE481_O0_O2_TYPED_RESTART_PASS',days=481,source_records=len(segments),input_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in [*sources,Path(__file__)]},reader_proof_root=str(proof),prepared_input_sha256=bindings,source_data_sha256=sha(source.read_bytes()),events=events,output=streams[0].decode(),full_original_Andelst=False,hydraulic_execution=False,file_restart=False,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
