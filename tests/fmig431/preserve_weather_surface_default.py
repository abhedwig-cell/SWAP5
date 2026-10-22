"""Compare two unmodified production solver contracts in their original geometry."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='95a3bd5721a4dfb4c0c38823c475ff55b95bee57'
SOURCES=subprocess.check_output(['python',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all','tests/fsi/fsi04_real_headcalc_stubs.f90','src/adapter/mod_reference_richards_legacy_binding.f90'],cwd=ROOT,text=True).splitlines()+['src/legacy/b1_10_port/headcalc.f90']
DRIVERS=['test_fsi25_reference_indicator_production_seam','test_fsi38_prescribed_qbot_temporal_certificate']
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
b=json.loads((a.build/'BUILD.json').read_text());assert b['status']=='BUILT';fc=b['compiler_command'];events=[];outputs={};identities={}
def run(command,label):
 t=time.monotonic();p=subprocess.run(command,cwd=out,capture_output=True,timeout=90)
 for stream in ('stdout','stderr'):(out/(label+'.'+stream)).write_bytes(getattr(p,stream))
 events.append(dict(command=command,label=label,returncode=p.returncode,seconds=time.monotonic()-t));(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');p.check_returncode();return p.stdout
for label in ('before','after'):
 dest=out/label;dest.mkdir();flags=[x for x in b['flags'] if not x.startswith(('-I','-J'))]+['-I'+str(dest),'-J'+str(dest)];objects=[]
 for i,source in enumerate(SOURCES):
  raw=subprocess.check_output(['git','show',BASE+':'+source],cwd=ROOT) if label=='before' else (ROOT/source).read_bytes();src=dest/(f'{i:02d}-'+Path(source).name);src.write_bytes(raw);identities[label+':'+source]=hashlib.sha256(raw).hexdigest();obj=dest/f'{i:02d}.o';objects.append(str(obj));run(fc+flags+['-c',str(src),'-o',str(obj)],label+'-compile-'+str(i))
 for driver in DRIVERS:
  exe=dest/driver;run(fc+flags+[str(ROOT/'tests/fsi'/(driver+'.f90')),*objects,'-o',str(exe)],label+'-'+driver+'-link');outputs[label,driver]=run([str(exe)]+(['-75','.01'] if 'fsi25' in driver else []),label+'-'+driver+'-native');assert b'PASS' in outputs[label,driver]
for driver in DRIVERS:assert outputs['before',driver]==outputs['after',driver]
(out/'RESULT.json').write_text(json.dumps(dict(status='DEFAULT_REAL_SOLVER_BEFORE_AFTER_BYTE_EXACT',baseline=BASE,compiler_build=str(a.build),contracts=2,input_sha256=identities,events=events),indent=2)+'\n');print('DEFAULT_REAL_SOLVER_BEFORE_AFTER_BYTE_EXACT')
