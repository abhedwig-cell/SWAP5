"""Compile real original/current owners and replay the retained accepted batch."""
import argparse,csv,hashlib,io,json,math,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/dataqual15'))
from original_sources import build_original
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--observations',type=Path);p.add_argument('--compile-only',action='store_true');p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--original-O0',type=Path);p.add_argument('--original-O2',type=Path);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=str(a.compiler.resolve())
 report=dict(status='IN_PROGRESS',events=[],scientific_equivalence=False,production_changed=False)
 if not a.compile_only:
  assert a.observations is not None;obs=a.observations.resolve();prior=json.loads((obs/'RESULT.json').read_text());batch=obs/'accepted-inputs.dat';assert prior['status']=='ACTUAL_ACCEPTED_UPTAKE_INPUTS_CAPTURED'and sha(batch)==prior['selection']['batch_sha256']
  report.update(observation_result_sha256=sha(obs/'RESULT.json'),input_batch_sha256=sha(batch))
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 def run(cmd,label,cwd=out,timeout=240):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout);i=len(report['events']);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);report['events'].append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start));save();assert r.returncode==0,(label,r.stderr.decode(errors='replace')[-2000:],r.stdout.decode(errors='replace')[-1000:]);return r.stdout
 driver=ROOT/'tests/dataqual15_hupsel/paired_uptake.f90';mapping={}
 for path in (ROOT/'src').rglob('*.f90'):
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',path.read_text(),re.M|re.I):mapping[name.lower()]=path
 ordered=[];seen=set()
 def visit(path):
  if path in seen:return
  seen.add(path)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',path.read_text(),re.M|re.I):
   if name.lower()in mapping and mapping[name.lower()]!=path:visit(mapping[name.lower()])
  ordered.append(path)
 visit(driver);ordered.remove(driver)
 report['source_sha256']={str(path.relative_to(ROOT)):sha(path)for path in [*ordered,driver,Path(__file__)]};report['compiler']=subprocess.check_output([fc,'--version'],text=True).splitlines()[0];report['paired']={}
 for opt in ['O0','O2']:
  original=getattr(a,'original_'+opt,None)
  if original is None:original=build_original(out/('original-'+opt),fc,opt)
  else:
   original=original.resolve();meta=json.loads((original/'BUILD.json').read_text());assert meta['compiler']==report['compiler']and '-'+opt in meta['flags']
   assert all(sha(original/path)==digest for path,digest in meta['object_sha256'].items())
  folder=out/opt;folder.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fbacktrace','-I'+str(folder),'-J'+str(folder),'-I'+str(original/'swobj'),'-I'+str(original/'ttobj')]
  raw=(original/'selected/RWU_micro.f90').read_text();anchor='public :: do_RWU_micro, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table';assert raw.count(anchor)==1
  source=folder/'visible_original_rwu.f90';source.write_text(raw.replace(anchor,anchor+', RWU_micro, get_MFLP_K'),newline='\n')
  visible=folder/'visible_original_rwu.o';run([fc,*flags,'-c',source,'-o',visible],'original-visibility-'+opt,folder)
  objects=[]
  for i,path in enumerate(ordered):
   obj=folder/f'{i}.o';run([fc,*flags,'-c',path,'-o',obj],'typed-compile-'+opt,folder);objects.append(obj)
  exe=folder/('paired.exe'if sys.platform=='win32'else'paired');args=folder/'link.args';args.write_text('\n'.join('"'+str(v).replace('\\','/')+'"'for v in [*flags,driver,*objects,visible,*[p for p in sorted((original/'swobj').glob('*.o'))if p.name.lower()!='rwu_micro.o'],original/'ttobj/libttutil.a','-o',exe]),newline='\n');run([fc,'@'+str(args)],'paired-link-'+opt,folder)
  if a.compile_only:
   report['paired'][opt]=dict(binary_sha256=sha(exe),native_execution=False);save();continue
  stdout=run([exe,batch],'paired-native-'+opt,folder,timeout=600);(folder/'paired.stdout').write_bytes(stdout)
  lines=stdout.decode().splitlines();header=next(line for line in lines if line.startswith('case,t0,'));data=list(csv.DictReader([header,*[line for line in lines if re.match(r'^\d+,',line)]]));assert len(data)==prior['selection']['accepted_cases']
  numbers=[{k:float(v)for k,v in row.items()}for row in data];by_day={}
  for day in [583,584,585]:
   selected=[r for r in numbers if int(r['t0'])==day-1];assert selected and abs(math.fsum(r['t1']-r['t0']for r in selected)-1)<1e-10
   by_day[str(day)]={key:math.fsum(r[key]*(r['t1']-r['t0'])for r in selected)for key in ['observed_uptake','source_uptake','tight_uptake','source_current_total_error','source_tight_total_error']}
  result=dict(cases=len(data),binary_sha256=sha(exe),visibility_only_source_sha256=sha(source),raw_stdout_sha256=sha(folder/'paired.stdout'),maxima={k:max(r[k]for r in numbers)for k in ['oxygen_max_error','current_replay_error','source_current_nodal_error','source_tight_nodal_error']},source_checks_all_three=all(r['source_checks']==3 for r in numbers),tight_status_all_zero=all(r['tight_status']==0 for r in numbers),daily=by_day)
  result['existing_oxygen_gate_pass']=result['maxima']['oxygen_max_error']<=1e-4;result['existing_micro_gate_pass']=result['maxima']['source_current_nodal_error']<=2e-5
  report['paired'][opt]=result;save()
 report['status']='COMPONENTS_COMPILED_NO_EXECUTION'if a.compile_only else'ACTUAL_ACCEPTED_IDENTICAL_INPUT_OWNERS_MEASURED';save();print(json.dumps({k:v for k,v in report.items()if k not in ['events','source_sha256']},indent=2))
if __name__=='__main__':main()
