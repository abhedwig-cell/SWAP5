"""Declared original-only precision controls; never relax the failed literal gate."""
import argparse,csv,hashlib,json,math,shlex,subprocess,sys,time
from pathlib import Path
from inspect_uptake_case import detailed_source
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--observations',type=Path,required=True);p.add_argument('--components',type=Path);p.add_argument('--only-qromb',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=a.compiler.resolve();obs=a.observations.resolve();batch=obs/'accepted-inputs.dat';report=dict(status='IN_PROGRESS',events=[],controls={},unchanged_literal_gate_pass=False,production_changed=False,input_sha256=sha(batch))
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 def run(cmd,label,cwd=out,timeout=600):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout);i=len(report['events']);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);report['events'].append(dict(label=label,command=list(map(str,cmd)),seconds=time.monotonic()-start,returncode=r.returncode));save();assert r.returncode==0,(label,r.stderr.decode(errors='replace')[-3000:]);return r.stdout
 if a.components:base=a.components.resolve()
 else:
  base=out/'components';run([sys.executable,'-B',ROOT/'tests/dataqual15_hupsel/replay_uptake.py','--compile-only','--compiler',fc,'--output',base],'clean-components')
 m=json.loads((base/'RESULT.json').read_text());assert m['status']=='COMPONENTS_COMPILED_NO_EXECUTION'
 assert m['compiler']==subprocess.check_output([fc,'--version'],text=True).splitlines()[0]
 for name,pin in m['source_sha256'].items():assert sha(ROOT/name)==pin,name
 source=out/'detailed.f90';source.write_text(detailed_source(False),newline='\n');report['detail_source_sha256']=sha(source)
 report['source_sha256']={str(p.relative_to(ROOT)):sha(p)for p in [Path(__file__),ROOT/'tests/dataqual15_hupsel/inspect_uptake_case.py',ROOT/'tests/dataqual15_hupsel/paired_uptake.f90',ROOT/'integration/dataqual15_hupsel/UPTAKE_DIAGNOSIS_STATUS.json']}
 for opt in ['O0','O2']:
  old=base/opt;exename='paired.exe'if sys.platform=='win32'else'paired';assert sha(old/exename)==m['paired'][opt]['binary_sha256']
  args=shlex.split((old/'link.args').read_text());oxygen=next(Path(v)for v in args if v.replace('\\','/').endswith('/swobj/oxygenstress.o'));original=oxygen.parent.parent;manifest=json.loads((original/'BUILD.json').read_text());raw=(original/'selected/oxygenstress.f90').read_text();selected={k.replace('\\','/'):v for k,v in manifest['selected_sha256'].items()};assert sha(original/'selected/oxygenstress.f90')==selected['selected/oxygenstress.f90']
  assert all(sha(original/path)==pin for path,pin in manifest['object_sha256'].items())
  variants=[('1.d-4',False,None),('1.d-6',False,None),('1.d-8',False,None),('1.d-10',False,None),('1.d-4',True,None),('1.d-10',True,None),('1.d-10',True,'1.d-8'),('1.d-10',True,'1.d-10')]
  if a.only_qromb:variants=[v for v in variants if v[2]is not None]
  for accuracy,fresh,quadrature in variants:
   name=opt+'-'+accuracy+('-fresh'if fresh else'')+('-qromb'+quadrature if quadrature else'');folder=out/name;folder.mkdir();anchor='        accuracy = 1.d-4';assert raw.count(anchor)==1;modified=raw.replace(anchor,'        accuracy = '+accuracy)
   if fresh:
    anchor='            SOLVE = ZBREND (myFUNC,a,b,Dif_a,Dif_b,accuracy)';assert modified.count(anchor)==1
    modified=modified.replace(anchor,anchor+'\n            fxi = myfunc(SOLVE) ! observe concentration at the published root')
   if quadrature:
    anchor='      real(8), parameter         :: EPS   = 1.0d-5            ! 1.0D-8';assert modified.count(anchor)==1
    modified=modified.replace(anchor,'      real(8), parameter         :: EPS   = '+quadrature+'            ! declared standard-MvG quadrature precision control')
   provider=folder/'oxygenstress.f90';provider.write_text(modified,newline='\n');obj=folder/'oxygenstress.o';flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-I'+str(old),'-I'+str(original/'swobj'),'-I'+str(original/'ttobj'),'-J'+str(folder)]
   run([fc,*flags,'-c',provider,'-o',obj],'precision-provider-'+opt+'-'+accuracy,folder)
   new=[];exe=folder/exename
   for v in args:
    if v.startswith('-J'):new.append('-J'+str(folder))
    elif v.replace('\\','/')==str(ROOT/'tests/dataqual15_hupsel/paired_uptake.f90').replace('\\','/'):new.append(str(source))
    elif Path(v)==oxygen:new.append(str(obj))
    elif Path(v)==old/exename:new.append(str(exe))
    else:new.append(v)
   link=folder/'link.args';link.write_text('\n'.join('"'+v.replace('\\','/')+'"'for v in new),newline='\n');run([fc,'@'+str(link)],'precision-link-'+opt+'-'+accuracy,folder)
   output=run([exe,batch],'precision-native-'+opt+'-'+accuracy,folder);(folder/'paired.stdout').write_bytes(output);lines=output.decode().splitlines();header=next(l for l in lines if l.startswith('case,t0,'));primary=list(csv.DictReader([header,*[l for l in lines if l[:1].isdigit()and','in l]]));chains=[l.split(',')for l in lines if l.startswith('CHAIN,')];assert len(primary)==len(chains)>0
   day={}
   for r,c in zip(primary,chains):
    assert int(r['case'])==int(c[1])and float(r['current_replay_error'])<=1e-12 and float(c[5])<=1e-12
    d=str(int(float(c[2]))+1);duration=float(c[3])-float(c[2]);x=day.setdefault(d,dict(duration=0.,observed_uptake=0.,original_micro_current_oxygen=0.,original_whole_chain=0.));x['duration']+=duration;x['observed_uptake']+=float(r['observed_uptake'])*duration;x['original_micro_current_oxygen']+=float(r['source_uptake'])*duration;x['original_whole_chain']+=float(c[6])*duration
   report['controls'][name]=dict(cases=len(primary),refresh_published_macro=fresh,quadrature_precision=quadrature,provider_sha256=sha(provider),executable_sha256=sha(exe),stdout_sha256=sha(folder/'paired.stdout'),max_original_current_oxygen=max(float(c[4])for c in chains),max_current_observed_oxygen=max(float(c[5])for c in chains),max_original_chain_nodal_uptake_error=max(float(c[7])for c in chains),all_original_chain_checks=all(int(c[8])==3 for c in chains),daily=day);save()
 report['status']='DECLARED_OXYGEN_PRECISION_CONTROLS_COMPLETE';save();print(json.dumps({k:v for k,v in report.items()if k not in ['events','source_sha256']},indent=2))
if __name__=='__main__':main()
