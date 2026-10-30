"""Original grass input, original compiled biomass oracle, current crop owners."""
import argparse
import hashlib,json,re,subprocess,time,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--hupsel',action='store_true');p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False)
ref=Path('/workspace/scratch/f29d9f3066a3/dq13-reference431/providers');original=(ref/'selected/wofost.f90').read_text();oracle=out/'original_wofost.f90';oracle.write_text(original.replace('   private\n','   private\n   public :: read_wofost,initialize_wofost,initialize_grass,update_dvs_rate,update_wofost,r_act\n',1))
input_file=ROOT/('reference/swap-4.3.1/projects/1.hupselbrook/grass.crp'if a.hupsel else'reference/swap-4.3.1/projects/2.grassgrowth/grass.crp');shutil.copyfile(input_file,out/'grass.crp')
# Compile the exact production selection block; only bind private fields to explicit arguments.
production=ROOT/'src/runtime/mod_fmr_wofost_crop_transaction.f90';text=production.read_text();block=text.split('  subroutine complete_threshold_grass_day(',1)[1].split('    if(cut)then',1)[0];block='    cut=.false.'+block.split('    cut=.false.',1)[1]
block=block.replace('self%grass_parameters','config').replace('self%event_forcing%crop_forcing%calendar_day_of_year','doy')
selection=out/'production_threshold.f90';selection.write_text('module production_threshold\n use iso_fortran_env,only:real64\n use mod_wofost_grass_development\n use mod_wofost_crop_owner_state\n implicit none\n contains\n subroutine select_production_cut(config,base,development,doy,cut_age,cut_index,cut,code)\n type(grass_management_parameters_t),intent(in)::config\n type(wofost_crop_owner_state_t),intent(in)::base\n type(grass_development_candidate_t),intent(in)::development\n integer,intent(in)::doy,cut_index\n integer,intent(inout)::cut_age\n integer,intent(out)::code\n logical,intent(out)::cut\n real(real64)::aerial,threshold\n code=0\n'+block+' end subroutine\nend module\n')
driver=ROOT/'tests/dataqual15_hupsel/mowing_oracle.f90';mapping={}
for p in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
  if name.lower()in mapping and mapping[name.lower()]!=p:visit(mapping[name.lower()])
 ordered.append(p)
visit(driver);ordered.remove(driver);events=[];binaries={}
source_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in ordered+[driver]}
def run(cmd,**kw):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),capture_output=True,**kw);events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode));(out/(str(len(events))+'.stderr')).write_bytes(r.stderr);(out/'EVENTS.json').write_text(json.dumps(events,indent=2))
 if r.returncode:raise RuntimeError(r.stderr.decode()+r.stdout.decode())
 return r.stdout
fc=str(a.compiler.resolve())
for opt in ['O0','O2']:
 f=out/opt;f.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-I'+str(f),'-J'+str(f),'-I'+str(ref/'swobj'),'-I'+str(ref/'ttobj')];objs=[]
 for i,p in enumerate(ordered+[selection,oracle]):
  obj=f/(str(i)+'.o');run([fc,*flags,'-c',p,'-o',obj]);assert obj.stat().st_size>0;objs.append(obj)
 original_objects=[p for p in(ref/'swobj').glob('*.o')if p.name.lower()!='wofost.o']
 run([fc,*flags,driver,*objs,*original_objects,ref/'ttobj/libttutil.a','-o',f/'test'])
 stdout=run([f/'test']+(['hupsel']if a.hupsel else[]),cwd=out);(f/'stdout').write_bytes(stdout);binaries[opt]=dict(executable_sha256=hashlib.sha256((f/'test').read_bytes()).hexdigest(),stdout=stdout.decode());assert b'ORIGINAL_GRASS_BIOMASS_CANDIDATE_PASS'in stdout;print(opt,stdout.decode(),flush=True)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in source_hashes.items())
(out/'RESULT.json').write_text(json.dumps(dict(status='GRASS_BODY_COMPONENT_PASS_NOT_HYDRAULIC_MODEL',events=events,source_sha256=source_hashes,production_sha256=hashlib.sha256(production.read_bytes()).hexdigest(),input_sha256=hashlib.sha256(input_file.read_bytes()).hexdigest(),selection_sha256=hashlib.sha256(selection.read_bytes()).hexdigest(),input_project='Hupsel'if a.hupsel else'Grassgrowth',binaries=binaries,compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],donor_original_sha256=hashlib.sha256((ref/'selected/wofost.f90').read_bytes()).hexdigest(),donor_exposed_sha256=hashlib.sha256(oracle.read_bytes()).hexdigest(),donor_objects_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest()for p in original_objects+[ref/'ttobj/libttutil.a']}),indent=2))
