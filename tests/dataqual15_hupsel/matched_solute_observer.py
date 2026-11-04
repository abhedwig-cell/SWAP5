"""Literal original transport replay on copies of actual native trial inputs."""
import argparse,hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
import solute_route_observer as owner
ROOT=owner.ROOT
GENERATOR=ROOT/'tests/nut-sol/run_nonlinear_pond.py'
INVERSE=ROOT/'tests/nut-sol/matrix_nonlinear_oracle.f90'
sha=owner.sha

SHADOW='''
    block
      integer,save::matched_unit=0
      real(real64)::original_c(n),original_mass(n),original_surface,original_decay,original_in,original_out
      original_c=mobile%concentration_mg_cm3
      original_mass=mobile%mass_mg_cm2+amount%sorbed_matrix_mass
      original_surface=amount%pond_mass
      call literal_step(f,original_c,original_mass,original_surface,original_decay,original_in,original_out)
      if(matched_unit==0)open(newunit=matched_unit,file='solute_matched.dat',status='replace',action='write')
      write(matched_unit,'(*(es25.17e3,1x))')t%t0,t%t1,r%mass_before_mg_cm2,r%mass_after_mg_cm2, &
        r%external_input_mg_cm2+pond_receipt%dry_input,r%external_output_mg_cm2, &
        maxval(abs(next_mobile%concentration_mg_cm3-original_c)), &
        maxval(abs(next_mobile%mass_mg_cm2+next_amount%sorbed_matrix_mass-original_mass)), &
        abs(next_amount%pond_mass-original_surface),abs(r%decay_output_mg_cm2-original_decay), &
        abs((r%external_output_mg_cm2-r%external_input_mg_cm2)-(original_out-original_in)), &
        f%frexp,maxval(abs(f%kf))
    end block
'''

def instrument(route,main):
 route,main=owner.instrument(route,main)
 assert route.count(' implicit none\n')==1
 route=route.replace(' implicit none\n',' use b111_literal_oracle,only:literal_step\n implicit none\n')
 assert route.count(owner.RAW)==1
 route=route.replace(owner.RAW,owner.RAW+SHADOW)
 return route,main

def literal(out):
 # Reuse the accepted independent original-source collector, including its
 # hard source SHA and literal line-slice assertions. No model is executed.
 keys=('DYNAMIC_POND_RESULT_DIR','POND_EXPONENT','POND_REUSE_BUILD')
 previous={n:os.environ.get(n) for n in keys}
 os.environ['DYNAMIC_POND_RESULT_DIR']=str(out/'literal-generator');os.environ['POND_EXPONENT']='1';os.environ.pop('POND_REUSE_BUILD',None)
 try:
  scope={'__file__':str(GENERATOR)}
  exec(compile(GENERATOR.read_text().split('\nresults = dict')[0],str(GENERATOR),'exec'),scope)
 finally:
  for n,v in previous.items():
   if v is None:os.environ.pop(n,None)
   else:os.environ[n]=v
 assert scope['hashlib'].sha256(scope['raw']).hexdigest()=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
 return scope['oracle']

def build(bundle,out,fc):
 out.mkdir();bundle=bundle.resolve();base=json.loads((bundle/'BUILD.json').read_text())
 assert subprocess.check_output([fc,'--version'],text=True).splitlines()[0]==base['compiler']
 assert all(sha(Path(n))==h for n,h in base['source_sha256'].items())
 assert all(sha(Path(n))==h for n,h in base['object_sha256'].items())
 assert sha(Path(base['ttutil_archive']))==base['archive_sha256']
 pub=base['publication_provider'];assert sha(Path(pub['source']))==pub['source_sha256'] and sha(Path(pub['object']))==pub['object_sha256']
 for p in bundle.glob('*.mod'):shutil.copyfile(p,out/p.name)
 flags=[f for f in base['flags'] if not f.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
 events=[]
 def run(cmd):
  begin=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=180);i=len(events)
  (out/f'{i}.stdout').write_bytes(cp.stdout);(out/f'{i}.stderr').write_bytes(cp.stderr)
  events.append(dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-begin))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,cp.stderr
 source=out/'b111_literal_oracle.f90';source.write_text(literal(out),encoding='utf-8',newline='\n')
 inverse=out/INVERSE.name;shutil.copyfile(INVERSE,inverse)
 for p in (inverse,source):run([fc,*flags,'-c',p,'-o',out/(p.stem+'.o')])
 changed=instrument((ROOT/owner.ROUTE).read_text(),(ROOT/owner.MAIN).read_text())
 objects=list(map(Path,base['object_sha256']));assert len(objects)==len(base['source_sha256']);patches={}
 for i,n in enumerate(base['source_sha256']):
  p=Path(n)
  if p.is_relative_to(ROOT) and p.relative_to(ROOT).as_posix() in (owner.ROUTE,owner.MAIN):
   relative=p.relative_to(ROOT).as_posix();post=out/p.name;post.write_text(changed[0 if relative==owner.ROUTE else 1],encoding='utf-8',newline='\n')
   obj=out/(str(i)+'.o');run([fc,*flags,'-c',post,'-o',obj]);objects[i]=obj
   patches[relative]=dict(before=base['source_sha256'][n],after=sha(post),postimage=post.name)
 assert set(patches)=={owner.ROUTE,owner.MAIN}
 extras=[out/'matrix_nonlinear_oracle.o',out/'b111_literal_oracle.o'];exe=out/'observed.exe'
 arguments=['-fopenmp','-Wl,--stack,16777216',*objects,*extras,pub['object'],base['ttutil_archive'],'-o',exe]
 # Preserve the exact link inputs while avoiding the Windows argv limit.
 response=out/'link.args';response.write_text('\n'.join('"'+str(x).replace('\\','/')+'"' for x in arguments),encoding='utf-8',newline='\n')
 (out/'LINK.json').write_text(json.dumps(dict(arguments=list(map(str,arguments)),response_sha256=sha(response)),indent=2)+'\n')
 run([fc,'@'+str(response)])
 record=dict(baseline_build=base,source_patches=patches,executable_sha256=sha(exe),
             object_sha256={str(p):sha(p) for p in objects+extras},events=events,
             literal_source_sha256=sha(source),inverse_source_sha256=sha(inverse),generator_sha256=sha(GENERATOR),
             original_solute_source_sha256='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2')
 (out/'BUILD.json').write_text(json.dumps(record,indent=2)+'\n');return exe

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in ('o0','o2','case','o0-tail','output','compiler'):p.add_argument('--'+n,type=Path,required=True)
 a=p.parse_args();out=a.output.resolve();out.mkdir()
 # This isolated orchestration adapter changes no versioned helper or model:
 # the incumbent qualifier retains all exact endpoint and strict restart tests.
 owner.build=build
 for opt,bundle,seed,baseline in [('O2',a.o2,a.case/'checkpoint-1077.bin',a.case),
                                 ('O0',a.o0,a.o0_tail/'checkpoint-1077.bin',a.o0_tail)]:
  folder=out/opt;folder.mkdir();owner.qualify(opt,bundle.resolve(),seed.resolve(),a.case.resolve(),baseline.resolve(),folder,a.compiler.resolve())
