"""Actual original compiled startup refusals on the identical reader payload."""
import argparse,json,struct,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_runtime import m
from explicit_bottom9_history_science import native
from analytical_hydraulic_archives import SHA


def main():
 p=argparse.ArgumentParser()
 for key in ('profile','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();profile=json.loads((a.profile/'RESULT.json').read_text());build=Path(profile['build_root']);meta=json.loads((build/'BUILD.json').read_text())
 project=m.e.load(profile['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1');case=Path(project.input_directory);s=m.e.switches((case/'swap.swp').read_text(encoding='cp1252'))
 selected=dict(meta['identity']['original_output'],swdra=s['SWDRA']);assert selected['paired_boundary']==9
 for name,digest in meta['inputs'].items():assert SHA((case/name).read_bytes())==digest
 for name,digest in meta['identity']['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for role,digest in meta['executable_sha256'].items():assert SHA(m.h.executable(build,'day_'+role).read_bytes())==digest
 rows=[json.loads(line) for line in (a.profile/'trajectory/daily.jsonl').read_text().splitlines()];row=rows[3];source=a.profile/'trajectory/accepted-column-1-day-4.zip';before=SHA(source.read_bytes())
 with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
 import re
 text=(case/'swap.swp').read_text(encoding='cp1252');table=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert table;dz=[]
 for line in table[1].splitlines():
  _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
 observed=native(good,meta,row,selected,dz);domain=observed['actual_domain_offset'];hydraulic=observed['hydraulic_state_offset'];n=project.nodes
 attacks={}
 def mutate(label,position,fmt,value):
  bad=bytearray(good);struct.pack_into(fmt,bad,position,value);attacks[label]=bytes(bad)
 attacks.update(parent_codec=b'S5NHS007'+good[8:],truncated=good[:-1],trailing=good+b'\0')
 for label,offset in [('domain',domain),('witness',domain+28)]:
  for i in range(7):mutate(label+'-'+str(i),offset+4*i,'<i',struct.unpack_from('<i',good,offset+4*i)[0]+1)
 for label,index,value in [('foreign-bottom',6,6),('foreign-drainage',5,1-s['SWDRA']),('foreign-hysteresis',3,3-s['SWHYST'])]:
  bad=bytearray(good)
  for offset in (domain,domain+28):struct.pack_into('<i',bad,offset+4*index,value)
  attacks[label]=bytes(bad)
 for label,index,value in [('head-nan',0,float('nan')),('negative-theta',n,-1.),('negative-K',2*n,-1.),('negative-Kmean',3*n+1,-1.),('negative-capacity',4*n+2,-1.),('negative-volume',5*n+3,-1.),('unbalanced-volume',5*n+3,row['stock_end_cm'][0]+1.)]:mutate(label,hydraulic+8*index,'<d',value)
 mutate('foreign-clock',12,'<d',struct.unpack_from('<d',good,12)[0]+1.)
 assert len(attacks)==28
 q=dict(status='RUNNING',actual_observer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_compiler_producer=profile['source'],actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),original_checkpoint_sha256=before,compiler_executions=0,model_periods=0,accepted_model_days=0,refusals=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def worker(label,raw):
  target=a.output/label;target.mkdir();origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);(origin/'macro.bin').write_bytes(raw);directory=target/'original'
  m.h.prepare_column(case,directory,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
  assert (directory/'macro-origin.bin').read_bytes()==raw
  r=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,input=b'0 0\n',capture_output=True,timeout=20)
  (directory/'donor.stdout').write_bytes(r.stdout);(directory/'donor.stderr').write_bytes(r.stderr)
  return r
 save()
 try:
  positive=worker('positive-startup',good);assert positive.returncode in (0,100) and not positive.stderr and b'HYBRID_READY' in positive.stdout and b'HYBRID_DAY_RETURN' not in positive.stdout
  q['positive_original_startup']=dict(returncode=positive.returncode,accepted_model_days=0)
  for label,raw in attacks.items():
   result=worker(label,raw);assert result.returncode not in (0,100) and b'ERROR STOP' in result.stderr and b'HYBRID_READY' not in result.stdout and b'HYBRID_DAY_RETURN' not in result.stdout,label
   try:native(raw,meta,row,selected,dz)
   except (AssertionError,ValueError,struct.error):pass
   else:raise AssertionError('Independent reader accepted identical malformed history payload: '+label)
   q['refusals'].append(dict(label=label,actual_payload_sha256=SHA(raw),actual_native_returncode=result.returncode,actual_compiled_stderr=result.stderr.decode('utf8',errors='replace'),identical_payload_independent_reader_refused=True));assert SHA(source.read_bytes())==before;save()
  q.update(status='ALL28_ACTUAL_COMPILED_HISTORY9_NATIVE_AND_IDENTICAL_PAYLOAD_INDEPENDENT_REFUSALS_PASS',compiled_refusals=28,independent_refusals=28)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],profile['kind'],profile['hysteresis'],profile['optimization'])


if __name__=='__main__':main()
