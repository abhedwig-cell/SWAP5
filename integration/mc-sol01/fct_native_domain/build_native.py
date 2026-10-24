"""Build a bounded native caller with source-generated FCT pond composition."""
import argparse,hashlib,importlib.util,json,os,runpy,subprocess,sys,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--optimization',choices=['O0','O2'],required=True);ap.add_argument('--reader-build',type=Path);ap.add_argument('--reference',action='store_true');a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 g=runpy.run_path(str(HERE/'generate.py'));parts=g['sources']();rep=g['rep']
 route=(ROOT/'src/runtime/mod_fmr_b111_pond_solute_route.f90').read_text().replace('mod_fmr_b111_pond_solute_route','mod_research_native_pond_route')
 route=rep(route,' use mod_b111_reactive_solute_substep',' use mod_research_native_fct\n use mod_b111_reactive_solute_substep')
 route=rep(route,'call advance_b111_reactive_solute_substep(mobile,amount,f,next_mobile,next_amount,r, &\n      exact_empty_pond_limit=supply%implicit_pond_evaporation.or.supply%exact_empty_pool_chemistry)',
  'call advance_research_native_fct(mobile,amount,f,.true.,next_mobile,next_amount,r)')
 route=rep(route,'    if(r%status/=B111_REACTIVE_OK)return', '''    if(r%status/=B111_REACTIVE_OK)then
      write(*,*)'FCT_NATIVE_DOMAIN',minval(f%q_face_up_cm_day),maxval(f%q_face_up_cm_day), &
       minval(f%kf),maxval(f%kf),minval(f%bulk_density),maxval(f%bulk_density),f%frexp
      write(*,*)'FCT_NATIVE_CARRIER',maxval(abs((f%theta-f%theta_previous)*f%dz_cm-f%dt_day* &
       (-f%q_face_up_cm_day(:n)+f%q_face_up_cm_day(2:)-f%root_sink_cm_day-sum(f%qdra_cm_day,dim=1))))
      return
    end if''')
 joint=(ROOT/'src/runtime/mod_fmr_b111_pond_joint_application.f90').read_text().replace('mod_fmr_b111_pond_joint_application','mod_research_native_pond_joint').replace('mod_fmr_b111_pond_solute_route','mod_research_native_pond_route')
 driver=(ROOT/'app/solute_project/main.f90').read_text().replace('use mod_fmr_b111_pond_joint_application','use mod_research_native_pond_joint')
 driver=rep(driver,'  water_flux_policy%enabled=water_flux_temporal', '''  call require(.not.dynamic_temperature,'FCT native heat combination not qualified')
  call require(solute_transport_scheme==1,'FCT native caller requires implicit transport parameters')
  ! Distinct physical configuration identity rejects cross-policy restarts.
  p%parameter_set_id=p%parameter_set_id+1000000_int64
  water_flux_policy%enabled=water_flux_temporal''')
 driver=rep(driver,'supply%exact_empty_pool_chemistry=any(soil_evaporation_cm_day>0d0)', 'supply%exact_empty_pool_chemistry=.true.')
 route=rep(route,'    if(pond_receipt%status/=POND_OK)return', '''    if(pond_receipt%status/=POND_OK)then
      write(*,*)'NATIVE_POND_REJECTION',k,pond_receipt%status,pond_receipt%water_residual, &
       pond_step%depth_begin,pond_step%depth_end,pond_step%qtop,pond_step%t0,pond_step%t1
      return
    end if''')
 route=rep(route,'if(supply%runon_rate>0d0.and..not.t%converged_gross_sources_available)return', '''if(supply%runon_rate>0d0.and..not.t%converged_gross_sources_available)then
     write(*,*)'NATIVE_GROSS_SOURCE_MISSING',k
     return
    end if''')
 if a.reference:
  driver=(ROOT/'app/solute_project/main.f90').read_text().replace('use mod_fmr_b111_pond_joint_application','use mod_research_native_pond_joint')
  route=rep(route,'call advance_research_native_fct(mobile,amount,f,.true.,next_mobile,next_amount,r)', '''call advance_b111_reactive_solute_substep(mobile,amount,f,next_mobile,next_amount,r, &
      exact_empty_pond_limit=supply%implicit_pond_evaporation.or.supply%exact_empty_pool_chemistry)''')
 parts.update({'native_pond_route.f90':route.encode(),'native_pond_joint.f90':joint.encode(),'native_driver.f90':driver.encode()})
 sys.path.insert(0,str(ROOT/'tools/solute'));from legacy_reader_sources import materialize
 original,tt=materialize(ROOT,out);parts[original.name]=original.read_bytes()
 for name,b in parts.items():(out/name).write_bytes(b)
 dep=ROOT/'tests/support/augment_bartholomeus_backend_sources.py';spec=importlib.util.spec_from_file_location('deps',dep);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
 with tempfile.TemporaryDirectory(dir=ROOT,prefix='.fct-native-')as tmp:
  lookup={}
  for name,b in parts.items():
   p=Path(tmp)/name;p.write_bytes(b);lookup[p]=out/name
  extra=[*map(str,lookup),'app/solute_column/link_context.f90','app/solute_column/read_swp_water.f90','app/solute_column/read_swp_chemistry.f90',str(HERE.parent/'fct_reactive/mod_research_composed_fct.f90')]
  sources,_=deps.strict_closure(ROOT,[str(Path(tmp)/'native_driver.f90')],extra)
  sources=[lookup.get(p,p) for p in sources];sources.insert(-1,ROOT/'src/legacy/b1_10_port/headcalc.f90')
 # Rebuild original TTUTIL from immutable materialized source, no object cache.
 fc=os.environ['FC'];flags=['-'+a.optimization,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(out),'-I'+str(out)]
 r=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),events=[],inputs={str(p.relative_to(ROOT)):sha(p) for p in sources if p.is_relative_to(ROOT)},generated={p.name:sha(p) for p in [out/n for n in parts]},closure=list(map(str,sources)))
 def run(cmd):
  t=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=180);i=len(r['events'])
  for s in ['stdout','stderr']:(out/f'{i:03d}.{s}').write_bytes(getattr(cp,s))
  r['events'].append(dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-t));(out/'build.json').write_text(json.dumps(r,indent=2)+'\n');assert cp.returncode==0,cp.stderr[-2500:]
 objects=[]
 if a.reader_build:
  previous=json.loads((a.reader_build/'build.json').read_text());assert previous['status']=='BUILT_RESEARCH_NATIVE'
  legacy=[e for e in previous['events'] if '-std=legacy' in e['command']];assert len(legacy)==len(tt) and all(e['returncode']==0 for e in legacy)
  for p,e in zip(tt,legacy):
   assert e['command'][0]==fc and '-'+a.optimization in e['command']
   assert p.read_bytes()==Path(e['command'][-3]).read_bytes()
  archive=a.reader_build/'libttutil.a';r['reused_immutable_reader_archive']=dict(path=str(archive),sha256=sha(archive),providers=len(tt))
  (out/'libttutil.a').write_bytes(archive.read_bytes())
 else:
  for i,p in enumerate(tt):
   obj=out/f'tt-{i:03d}.o';run([fc,*flags,'-std=legacy','-fallow-argument-mismatch','-c',p,'-o',obj]);objects.append(obj)
  run(['ar','rcs',out/'libttutil.a',*objects])
 run([fc,*flags,*sources,out/'libttutil.a','-o',out/'native_fct'])
 r['status']='BUILT_RESEARCH_NATIVE';r['executable_sha256']=sha(out/'native_fct');(out/'build.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(dict(status=r['status'],providers=len(sources),original_readers=len(tt))))
if __name__=='__main__':main()
