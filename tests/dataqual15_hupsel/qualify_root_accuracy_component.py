"""Current optional APIs versus frozen algorithms, using bounded original states."""
import argparse,hashlib,importlib.util,json,subprocess,time
from pathlib import Path
import film_accuracy as data
import film_refinement_candidate as historical
import micro_pressure_probe as pressure
ROOT=Path(__file__).resolve().parents[2];sha=lambda b:hashlib.sha256(b).hexdigest()
DRIVER='tests/dataqual15_hupsel/root_accuracy_component_driver.f90'
FILM='src/physics/oxygen/mod_bartholomeus_waterfilm_independent.f90'

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();compiler=a.compiler.resolve()
 record=json.loads((ROOT/'integration/dataqual15_hupsel/ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text())
 files=data.parent.unpack(record);raw=files['micro/case/original_factor_inputs.dat'];assert sha(raw)=='70232a44072f546f2abde62bda2db52faeaff4df04b72a9442a49afb9fcd8148'
 corpus=data.frames(raw);del files
 selected=[(1248,13),(115,6)]
 candidates=[(i+1,j+1)for i,g in enumerate(corpus)for j,f in enumerate(g)if float(f[11])<0 and float(f[22])-float(f[12])>=1e-4]
 selected += [candidates[i*(len(candidates)-1)//61]for i in range(62)]
 inputs=[]
 for i,j in selected:
  c=list(map(float,corpus[i-1][j-1]));alpha=.01*c[24];n=c[26];m=c[27];sigma=.07275*(1-.002*(c[13]+273-291))
  inputs.append([-100*c[11],(c[22]-c[21])*alpha*n*m,n-1,m+1,alpha,n,sigma])
 original=subprocess.check_output(['git','show','34b8adf88:'+FILM],cwd=ROOT).decode()
 refined=historical.candidate(original)
 def renamed(body,module,function):
  return body.replace('mod_bartholomeus_waterfilm_independent',module).replace('bartholomeus_waterfilm_mvg_independent',function)
 frozen={'legacy.f90':renamed(original,'frozen_legacy_film','legacy_film'),'refined.f90':renamed(refined,'frozen_refined_film','refined_film'),
  'capped.f90':renamed((ROOT/FILM).read_text().replace('do level = 2, 24','do level = 2, 2'),'capped_current_film','capped_film')}
 process=(ROOT/pressure.PROCESS).read_text();start=process.index('      if(refine_search)then\n');end=process.index('      end if\n',start)+len('      end if\n');block=process[start:end]
 assert pressure.OLD in block
 variants={'current':process,'legacy-reference':process.replace(block,pressure.OLD),'precise-reference':process.replace(block,pressure.NEW)}
 spec=importlib.util.spec_from_file_location('closure',ROOT/'tests/support/augment_bartholomeus_backend_sources.py');closure=importlib.util.module_from_spec(spec);spec.loader.exec_module(closure)
 order,_=closure.strict_closure(ROOT,[ROOT/pressure.PROCESS,ROOT/FILM]);results={};events=[]
 for opt in ('O0','O2'):
  for variant,body in variants.items():
   folder=out/(opt+'-'+variant);folder.mkdir();(folder/'film.dat').write_text('\n'.join(' '.join(format(v,'.17e')for v in x)for x in inputs)+'\n')
   source=folder/'micro.f90';source.write_text(body,newline='\n');locals=[]
   for name,text in frozen.items():f=folder/name;f.write_text(text,newline='\n');locals.append(f)
   sources=[source if path==ROOT/pressure.PROCESS else path for path in order]+locals+[ROOT/DRIVER]
   flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(folder),'-J'+str(folder)]
   exe=folder/('component.exe'if compiler.suffix=='.exe'else'component')
   command=[str(compiler),*flags,*map(str,sources),'-o',str(exe)];begin=time.monotonic();cp=subprocess.run(command,cwd=folder,capture_output=True,timeout=180)
   (folder/'compile.stdout').write_bytes(cp.stdout);(folder/'compile.stderr').write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode(errors='replace')
   modes=('legacy','refined')if variant=='current'else(('legacy',)if variant=='legacy-reference'else('refined',))
   for mode in modes:
    r=subprocess.run([str(exe),mode],cwd=folder,capture_output=True,timeout=90);(folder/(mode+'.stdout')).write_bytes(r.stdout);(folder/(mode+'.stderr')).write_bytes(r.stderr)
    assert r.returncode==0,r.stderr.decode(errors='replace');results[opt+'/'+variant+'/'+mode]=sha(r.stdout)
   events.append(dict(optimization=opt,variant=variant,command=command,seconds=time.monotonic()-begin,executable_sha256=sha(exe.read_bytes()),source_sha256={str(s):sha(s.read_bytes())for s in sources}))
  assert results[opt+'/current/legacy']==results[opt+'/legacy-reference/legacy']
  assert results[opt+'/current/refined']==results[opt+'/precise-reference/refined']
 report=dict(status='CURRENT_ROOT_API_DEFAULT_AND_REFINED_FROZEN_ALGORITHM_CONTRACTS_PASS',selected_original_nodes=selected,
  input_authority_sha256=record['archive_sha256'],input_sha256=sha(raw),results=results,events=events,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])

if __name__=='__main__':main()
