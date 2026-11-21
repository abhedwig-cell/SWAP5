"""Actual native4 and Snow-domain reader refusals, with zero accepted days."""
import argparse,json,struct,subprocess,sys,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import original_output_matrix as thermal
m=thermal.m


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();profile=json.loads((a.profile/'RESULT.json').read_text());build=Path(profile['build_root'])
 project=m.e.load(profile['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
 meta,case=m.validate_bundle(build,a.reference_work,project);vapor=meta['identity']['hydraulic_vapor']
 source=a.profile/'trajectory/accepted-column-1-day-4.zip';digest=m.sha(source)
 with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
 assert good[:8]==m.e.auxiliary_magic(project)==vapor['native_codec'].encode()
 values=[4,project.nodes,vapor['numlay'],0,int(project.solute),0,0,1,0,0,1,2,1,6]+vapor['models']+[f if model>=8 else 0 for model,f in zip(vapor['models'],vapor['SWVAPOR'])]
 header=struct.pack('<'+str(len(values))+'i',*values);assert good.count(header+header)==1
 snow=[1,project.nodes,0,int(project.solute),0,1,0,1,1,2];thermal_header=struct.pack('<10i',*snow);assert good.count(thermal_header+thermal_header)==1
 attacks=[]
 for role,record,expected in (('vapor',header,values),('snow',thermal_header,snow)):
  offset=good.index(record+record)
  for witness_only in (False,True):
   for i,value in enumerate(expected):
    edits=[(offset+4*i,struct.pack('<i',value+1))]
    if not witness_only:edits.append((offset+len(record)+4*i,struct.pack('<i',value+1)))
    attacks.append((role+('-witness-' if witness_only else '-domain-')+str(i),edits))
 for magic in (b'S5HVW003',b'S5HVC003',b'S5ITW001',b'S5ITC001',b'S5HSW003',b'S5HSC003'):
  attacks.append((magic.decode(),[(0,magic)]))
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_BUILD_sha256=m.sha(build/'BUILD.json'),checkpoint_sha256=digest,accepted_model_days=0,compiler_executions=0,refusals=[],public_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def worker(label,raw):
  out=a.output/label;out.mkdir();origin=out/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);(origin/'macro.bin').write_bytes(raw)
  directory=out/'original';m.h.prepare_column(case,directory,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
  run=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,input=b'0 0\n',capture_output=True,timeout=20)
  (directory/'donor.stdout').write_bytes(run.stdout);(directory/'donor.stderr').write_bytes(run.stderr)
  return run
 save()
 try:
  positive=worker('positive',good)
  assert positive.returncode in (0,100) and not positive.stderr and b'HYBRID_READY' in positive.stdout and b'HYBRID_DAY_RETURN' not in positive.stdout
  q['positive_original_native_startup']=True;save()
  for label,edits in attacks:
   raw=bytearray(good)
   for offset,value in edits:raw[offset:offset+len(value)]=value
   run=worker(label,raw);diagnostic=run.stderr.decode(errors='replace')
   assert run.returncode!=0 and 'ERROR STOP' in diagnostic and b'HYBRID_READY' not in run.stdout and b'HYBRID_DAY_RETURN' not in run.stdout,(label,diagnostic)
   q['refusals'].append(dict(label=label,returncode=run.returncode,diagnostic=diagnostic));assert m.sha(source)==digest;save()
  for size in (0,48,48+2*len(header)-1,len(good)-1):
   run=worker('truncated-'+str(size),good[:size]);diagnostic=run.stderr.decode(errors='replace')
   assert run.returncode!=0 and b'HYBRID_READY' not in run.stdout and b'HYBRID_DAY_RETURN' not in run.stdout
   q['refusals'].append(dict(label='truncated-'+str(size),returncode=run.returncode,diagnostic=diagnostic));assert m.sha(source)==digest;save()
  q['status']='ACTUAL_SNOW_VAPOR_NATIVE4_AND_LITERAL_SNOW_DOMAIN_STARTUP_REFUSALS_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],len(q['refusals']),flush=True)


if __name__=='__main__':main()
