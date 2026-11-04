"""Actual copied-source integral refinement receipts; production remains unchanged."""
import argparse,base64,gzip,io,json,os,subprocess,tarfile,time
from pathlib import Path
import mpmath as mp
import film_accuracy as f
import film_accuracy_evidence as evidence
SOURCE='src/physics/oxygen/mod_bartholomeus_waterfilm_independent.f90'
STEP='         integral = trapezoid_refine(1.0e-10_real64,matric_potential_pa,p,level,previous)\n'

def load():
 scope=json.loads((f.BASE/'ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text())
 assert scope['archive_sha256']=='99adab40cc703f4533abc89befa5d16d76d6a36d1b7a09ef3e463becf997c1db'
 files=f.parent.unpack(scope);raw=files['micro/case/original_factor_inputs.dat'];assert f.sha(raw)=='70232a44072f546f2abde62bda2db52faeaff4df04b72a9442a49afb9fcd8148'
 corpus=f.frames(raw)
 record=json.loads((f.BASE/'FILM_ACCURACY_WINDOWS_20261104.json').read_text());packet=(f.BASE/record['archive']).read_bytes();assert f.sha(packet)==record['archive_sha256']
 with tarfile.open(fileobj=io.BytesIO(packet))as t:prior={n:t.extractfile(n).read()for n in t.getnames()}
 evidence.audit(prior)
 table=[[mp.mpf(x)for x in line.split()[2:]]for line in prior['certified-film.dat'].decode().splitlines()]
 return scope,raw,corpus,table

def selected(corpus):
 result=[]
 for record,node in [(1248,13),(115,6)]:
  fields=corpus[record-1][node-1];upper=-100*float(fields[11]);sigma=.07275*(1-.002*(float(fields[13])+273-291))
  with mp.workdps(80):
   film=f.film(fields,80,True);sig=mp.mpf('.07275')*(1-mp.mpf('.002')*(mp.mpf(fields[13])+273-291));p=-100*mp.mpf(fields[11])
   integral=1/(mp.pi*(film/2+2*sig/p)**2)
   condition=mp.mpf('.5')+2*sig/(p*film)
   result.append(dict(record=record,node=node,upper_pa=upper,sigma=sigma,film80_m=mp.nstr(film,45),integral80=mp.nstr(integral,45),relative_subtraction_condition=mp.nstr(condition,25)))
 return result

def observed(source,cases):
 assert source.count('   use iso_fortran_env, only : real64\n')==1 and source.count(STEP)==1
 tests=[]
 for c in cases:
  p=format(c['upper_pa'],'.17e')+'_real64';s=format(c['sigma'],'.17e')+'_real64'
  tests.append('(abs(matric_potential_pa-'+p+')<=4*epsilon(1d0)*abs(matric_potential_pa).and. &\n'+
               '             abs(p%surface_tension_water-'+s+')<=4*epsilon(1d0)*abs(p%surface_tension_water))')
 trace='         if('+'.or. &\n            '.join(tests)+') &\n'+"           write(error_unit,'(a,1x,i0,5(1x,es25.17e3))')'FILM_STEP',level,matric_potential_pa, &\n"+'             p%surface_tension_water,previous,integral,abs(integral-previous)/max(abs(integral),tiny(1d0))\n'
 use='   use iso_fortran_env, only : real64,error_unit\n'
 result=source.replace('   use iso_fortran_env, only : real64\n',use).replace(STEP,STEP+trace)
 assert result.replace(use,'   use iso_fortran_env, only : real64\n').replace(trace,'')==source
 return result

def build(out,source,scope,compiler,opt):
 out.mkdir();original=json.loads((f.ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text());literal=gzip.decompress(base64.b64decode(original['gzip_base64']));assert f.sha(literal)=='8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87'
 (out/'fixture.f90').write_text(f.MODULE,encoding='utf-8');(out/'oxygen.f90').write_text(f.adapted_source(literal.decode()),encoding='utf-8');(out/'driver.f90').write_text(f.adapted_driver((f.ROOT/'tests/dataqual15_hupsel/original_factor_comparison.f90').read_text()),encoding='utf-8')
 module=out/'waterfilm.f90';module.write_text(source,encoding='utf-8')
 order=[module if n==SOURCE else f.ROOT/n for n in scope['factor_repository_order']];assert order.count(module)==1
 inputs=[out/'fixture.f90',f.ROOT/'tests/dataqual15_hupsel/matched_oxygen_owners.f90',out/'oxygen.f90',*order,out/'driver.f90'];exe=out/'compare.exe'
 flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-I'+str(out),'-J'+str(out)]
 cmd=[compiler,*flags,*map(str,inputs),'-o',str(exe)];r=subprocess.run(cmd,cwd=out,capture_output=True,timeout=180);(out/'compile.stderr').write_bytes(r.stderr);assert r.returncode==0,r.stderr.decode(errors='replace')[-2000:]
 (out/'BUILD.json').write_text(json.dumps(dict(command=cmd,compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],source_sha256={p.name if p.parent==out else p.relative_to(f.ROOT).as_posix():f.sha(p.read_bytes())for p in inputs},executable_sha256=f.sha(exe.read_bytes())),indent=2)+'\n')
 return exe

def run(exe,frame,out):
 start=time.monotonic();r=subprocess.run([str(exe),str(frame)],cwd=out,capture_output=True,timeout=300)
 (out/'comparison.stdout').write_bytes(r.stdout);(out/'comparison.stderr').write_bytes(r.stderr);assert r.returncode==0,r.stderr.decode(errors='replace')[-1000:]
 rows=[list(map(float,line.split()))for line in r.stdout.decode().splitlines()];assert len(rows)==41678
 assert max(abs(x[4]-x[6])for x in rows)<1e-9
 return r.stdout,r.stderr,rows,time.monotonic()-start

def receipts(raw,cases):
 lines=raw.decode().splitlines();assert lines and all(line.startswith('FILM_STEP ')for line in lines)
 records=[list(map(float,line.split()[1:]))for line in lines];result=[]
 for c in cases:
  rows=[r for r in records if abs(r[1]-c['upper_pa'])<=4e-15*abs(c['upper_pa'])and abs(r[2]-c['sigma'])<=4e-15*abs(c['sigma'])]
  sessions=[]
  for row in rows:
   if int(row[0])==2:sessions.append([])
   assert sessions;sessions[-1].append(row)
  assert len(sessions)==2 and sessions[0]==sessions[1],(c['record'],len(sessions))
  last=sessions[0][-1];true_error=abs(last[4]-float(c['integral80']))/float(c['integral80'])
  result.append(dict(**c,refinements=sessions[0],exit_level=int(last[0]),accepted_successive_relative_change=last[5],independent_relative_integral_error=true_error,exceeds_unchanged_integral_criterion=true_error>1e-5))
 return result

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',default=os.environ.get('FC','gfortran'));a=p.parse_args()
 out=a.output.resolve();out.mkdir();scope,raw,corpus,table=load();cases=selected(corpus);frame=out/'original_factor_inputs.dat';frame.write_bytes(raw)
 source=(f.ROOT/SOURCE).read_text();trace=observed(source,cases);report=dict(status='ACTUAL_REFINEMENT_OBSERVATION_PENDING',source_sha256=f.sha(source.encode()),input_sha256=f.sha(raw),production_admission=False,whole_scientific_admission=False,builds={})
 for opt in ('O0','O2'):
  plain=out/(opt+'-plain');watched=out/(opt+'-observed');p_exe=build(plain,source,scope,a.compiler,opt);t_exe=build(watched,trace,scope,a.compiler,opt)
  expected,stderr,rows,seconds=run(p_exe,frame,plain);assert not stderr
  actual,trace_raw,_,trace_seconds=run(t_exe,frame,watched);assert actual==expected,'observer altered actual numerical output'
  report['builds'][opt]=dict(exact_unobserved_stdout_sha256=f.sha(expected),actual_observed_stdout_exact=True,observations=receipts(trace_raw,cases),seconds=[seconds,trace_seconds])
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 report['status']='ACTUAL_O0_O2_REFINEMENT_OBSERVATION_AND_EXACT_FULL_CORPUS_CONTROLS_PASS'
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({opt:[(x['record'],x['node'],x['exit_level'],x['accepted_successive_relative_change'],x['independent_relative_integral_error'])for x in r['observations']]for opt,r in report['builds'].items()}))
if __name__=='__main__':main()
