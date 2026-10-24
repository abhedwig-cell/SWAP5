"""Real MIGMAC10 owners with the original BBC, before native application widening.

Build only a private guarded backend counterfactual, reusing verified checked
provider objects. Every driver executes. No canonical source or guard is edited.
"""
import argparse,datetime,gzip,hashlib,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BACKEND='src/runtime/mod_fmr_serialized_reference_backend.f90'
sha=lambda b:hashlib.sha256(b).hexdigest()
OLD='(parameters%bottom_mode /= 2 .and. parameters%bottom_mode /= 7) .or. &'
NEW='''(parameters%bottom_mode /= 2 .and. parameters%bottom_mode /= 7 .and. &
           .not.(composed_rutter_boesten_macro.and.parameters%bottom_mode==3.and. &
             .not.parameters%swbotb3_explicit_active)) .or. &'''
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();bundle=json.loads((a.bundle/'bundle.json').read_text());meta=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text())
 for path,h in meta['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
 for path,h in meta['reused_artifact_sha256'].items():assert sha(Path(path).read_bytes())==h,path
 physical=meta['source_build'];objects=[e['command'][-1]for e in physical['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')]
 backend_object=[e['command'][-1]for e in physical['events']if e['category']=='compile'and e['command'][-3].endswith('/'+BACKEND)];assert len(backend_object)==1 and len(objects)==193
 archive=[x for x in meta['reused_artifact_sha256']if x.endswith('/libttutil.a')];assert len(archive)==1
 bbc=gzip.decompress((ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.bbc.gz').read_bytes())
 assert sha(bbc)=='ed83fe31870676cef7a57a27ce2372abc53cc0755b0f4ea6b0b6248e152480ff'
 data=re.findall(rb'^\s*(1998-\d\d-\d\d)\s+(-?[\d.]+)\s*$',bbc,re.M);assert len(data)==365
 dates=[(datetime.date.fromisoformat(d.decode())-datetime.date(1900,1,1)).days for d,h in data]
 origin=dates[0];dates=','.join(str(v)+'.0_real64'for v in dates);heads=','.join(h.decode()+'_real64'for d,h in data)
 def control(name):return f'''\n    allocate({name}%legacy_swbotb3_implicit_control)
    call {name}%legacy_swbotb3_implicit_control%initialize_table(0.0_real64,{origin}.0_real64, &
      [{dates}], &
      [{heads}],10.0_real64,.true.,rutter_status)
    if(rutter_status/=0)error stop 'original BBC control initialization'
'''
 events=[];r=dict(status='RUNNING',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=bundle['optimization'],bbc_sha256=sha(bbc),events=events,source_sha256={BACKEND:sha((ROOT/BACKEND).read_bytes())},production_activated=False)
 def save():(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
 def run(cmd,stage,label,env=None):
  cmd=list(map(str,cmd));t=time.perf_counter();cp=subprocess.run(cmd,cwd=stage,capture_output=True,timeout=180,env=env)
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(label=label,command=cmd,returncode=cp.returncode,seconds=time.perf_counter()-t));save();return cp
 flags=[f for f in meta['flags']if not f.startswith('-J')];fc=meta['compiler_command']
 source=(ROOT/BACKEND).read_text();assert source.count(OLD)==1
 private=out/'candidate_backend.f90';private.write_text(source.replace(OLD,NEW));r['candidate_backend_sha256']=sha(private.read_bytes())
 cp=run(fc+flags+['-J'+str(out),'-c',private,'-o',out/'candidate_backend.o'],out,'backend_compile');assert cp.returncode==0,cp.stderr.decode()
 candidate_objects=[str(out/'candidate_backend.o')if x==backend_object[0]else x for x in objects]
 env={**os.environ,'WU05_MIGMAC10':'1','WU05_MIGMAC10_RUTTER':'1','WU05_MIGMAC02_DYNAMIC':'2'}
 results={}
 for name in ['trial','replay']:
  path='tests/fpm/test_ppa_wu05a9_fmr_top_input_'+name+'.f90';text=(ROOT/path).read_text();r['source_sha256'][path]=sha(text.encode())
  if name=='trial':
   assert text.count('p%bottom_mode=7')==1;text=text.replace('p%bottom_mode=7','p%bottom_mode=3')
   assert text.count('f%bottom_head=-100.0_real64')==1;text=text.replace('f%bottom_head=-100.0_real64','f%bottom_head=-100.0_real64'+control('f'))
  else:
   assert text.count('fparams%bottom_mode=7')==1;text=text.replace('fparams%bottom_mode=7','fparams%bottom_mode=3')
   assert text.count('forcing%bottom_head=-100.0_real64')==1;text=text.replace('forcing%bottom_head=-100.0_real64','forcing%bottom_head=-100.0_real64'+control('forcing'))
  driver=out/(name+'.f90');driver.write_text(text)
  for variant,providers in [('canonical',objects),('candidate',candidate_objects)]:
   stage=out/(name+'-'+variant);stage.mkdir();exe=stage/'driver'
   cp=run(fc+['-I'+str(out),*flags,'-J'+str(stage),driver,*providers,*archive,'-o',exe],stage,name+'-'+variant+'-link');assert cp.returncode==0,cp.stderr.decode()
   cp=run([exe],stage,name+'-'+variant,env);results[name+'-'+variant]=cp.returncode
   if variant=='canonical':assert cp.returncode!=0,'preflight boundary unexpectedly changed'
 r.update(status='PROBE_COMPLETE',results=results,candidate_physical_pass=all(v==0 for k,v in results.items()if k.endswith('-candidate')),qualified=False,full_original_Andelst=False);save();print(json.dumps(r['results']))
if __name__=='__main__':main()
