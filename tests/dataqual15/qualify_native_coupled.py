"""Source-bound full-column contact experiment; original acceptance stays authoritative."""
import argparse,hashlib,json,os,subprocess,sys,tarfile,time,zlib,struct,shutil,re
from pathlib import Path
import qualify_nonlinear_native_contact as native
from research_native_build_cache import verified_objects
ROOT=native.ROOT

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--prior-build',type=Path);p.add_argument('--reuse-coupled-build',type=Path);a=p.parse_args()
 out=a.output.resolve();out.mkdir(exist_ok=False);build=out/'build';build.mkdir()
 prior=a.prior_build.resolve() if a.prior_build else None;old=json.loads((prior/'RESULT.json').read_text(encoding='utf-8')) if prior else None
 report=dict(baseline=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),optimization=a.optimization,events=[],scope='FULL_COLUMN_NONLINEAR_RESEARCH_NOT_COMMITTED',full_energy_balance_complete=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 def run(cmd,cwd,label,env=None,check=True):
  start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,env=env,capture_output=True,timeout=180)
  (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
  report['events'].append(dict(label=label,command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start));save()
  if check:assert cp.returncode==0,(label,cp.stderr.decode(errors='replace')[-3000:])
  return cp
 shadow=native.overlays(out/'overlay')
 provider=shadow[native.MACRO];s=provider.read_text(encoding='utf-8');s=s.replace('    procedure,public::research_contact_rates','    procedure,public::research_contact_lifecycle\n    procedure,public::research_contact_selector\n    procedure,public::research_contact_rates')
 imports='''  use mod_contact_action_memory,only:complete_contact_action_memory
  use mod_macropore_standard_storage,only:macropore_standard_candidate_receipt_t,build_macropore_standard_candidate
  use mod_ppa_wu05a5_top_partition,only:macropore_top_partition_result_t
  use mod_ppa_wu05a6_sorptivity_history,only:sorptivity_history_update_request_t,apply_sorptivity_history_update
  use mod_macropore_standard_rate_adapter,only:prepare_standard_sorptivity_history_request
  use mod_ppa_wu05a6_vertical_flux_reconstruction,only:vertical_flux_reconstruction_request_t,vertical_flux_reconstruction_result_t,reconstruct_vertical_flux
'''
 s=s.replace('  implicit none',imports+'  implicit none',1);s=s.replace('\ncontains\n','\ncontains\n'+(ROOT/(native.RESEARCH+'native_transaction_provider.inc')).read_text(encoding='utf-8'),1);provider.write_text(s,encoding='utf-8')
 backend_key='src/runtime/mod_fmr_serialized_reference_backend.f90'
 backend=(ROOT/backend_key).read_text(encoding='utf-8');backend=backend.replace('  implicit none','  use mod_native_feedback_context,only:capture_native_feedback_context\n  implicit none',1)
 anchor='''    if (self%macropore_active) then
      if (self%soil_water_selection%uses_rossfast() .or. trajectory_request_ok) return'''
 capture='''    if (self%macropore_active) then
      select type(research_physical=>state)
      class is(fmr_b110_physical_state_t)
        if(self%soil_temperature_active)call capture_native_feedback_context(self%soil_temperature_parameters, &
          self%soil_temperature_numerical,self%soil_temperature_forcing,research_physical%soil_temperature,t0,t1)
      end select
      if (self%soil_water_selection%uses_rossfast() .or. trajectory_request_ok) return'''
 assert backend.count(anchor)==1;backend=backend.replace(anchor,capture);path=out/'overlay'/backend_key;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(backend,encoding='utf-8');shadow[backend_key]=path
 head=shadow[native.HEAD];s=head.read_text(encoding='utf-8');s=s.replace((ROOT/(native.RESEARCH+'contact_headcalc_methods.inc')).read_text(encoding='utf-8'),(ROOT/(native.RESEARCH+'native_transaction_headcalc.inc')).read_text(encoding='utf-8').replace('research_coupled_contact()','research_nonlinear_contact()'));s=s.replace('   integer::research_branch=0','''   integer::research_branch=0,research_log_unit=0
   type(ppa_wu05a16_inner_macropore_provider_t)::research_macro,research_base_macro
   real(8),allocatable::research_current_exchange(:)
''')
 s=s.replace('   use mod_nonlinear_contact_pair','''   use mod_nonlinear_contact_pair
   use mod_native_feedback_context
   use mod_native_coupled_transaction
   use mod_transaction_reference
   use mod_macropore_standard_storage,only:derive_macropore_standard_storage_view
''',1);head.write_text(s,encoding='utf-8')
 driver=shadow[native.DRIVER];s=driver.read_text(encoding='utf-8');s=s.replace('integer::heat_unit,heat_node','integer::heat_unit,heat_node,domain_id,transport_unit')
 marker="            close(heat_unit)"
 export="""            open(newunit=transport_unit,file='actual-transport.csv',status='unknown',position='append')
            do heat_node=1,numnod
              write(transport_unit,'(a,2(a,es25.17e3),a,i0,8(a,es25.17e3))')'MATRIX',',',s%t0,',',s%t1,',',heat_node, &
               ',',s%matrix_area_fraction(heat_node),',',s%top_flux,',',s%bottom_flux,',',s%net_node_source(heat_node), &
               ',',s%root_sink(heat_node),',',s%drainage_sink(heat_node),',',s%subsurface_source(heat_node),',',s%macropore_matrix_exchange(heat_node)
              do domain_id=1,size(s%macropore_water_start,1)
                write(transport_unit,'(a,2(a,es25.17e3),2(a,i0),6(a,es25.17e3))')'MACRO',',',s%t0,',',s%t1,',',domain_id,',',heat_node, &
                  ',',s%macropore_water_start(domain_id,heat_node),',',s%macropore_water_end(domain_id,heat_node), &
                  ',',s%macropore_vertical_face_rate(domain_id,heat_node),',',s%macropore_vertical_face_rate(domain_id,heat_node+1), &
                  ',',s%macropore_matrix_exchange_domain(domain_id,heat_node),',',s%macropore_external_outflow_rate(domain_id,heat_node)
              end do
            end do
            close(transport_unit)
"""
 assert s.count(marker)==1;s=s.replace(marker,marker+'\n'+export);driver.write_text(s,encoding='utf-8')
 original,tt=native.materialize(ROOT,build)
 old_order=[Path(e['command'][-3]) for e in old['events'] if e['label'].startswith('compile-') and e['label'][8:].isdigit()] if old else []
 ordered=[ROOT/(native.RESEARCH+n) for n in ['mod_contact_action_memory.f90', 'mod_macro_liquid_thermal.f90', 'mod_native_macro_heat_feedback.f90', 'mod_native_coupled_transaction.f90', 'mod_native_feedback_context.f90']]
 if old:
  assert len(old_order)==202
  for source in old_order:
   selected=None
   for key in shadow:
    if source.as_posix().endswith('/'+key):selected=shadow[key];break
   if selected is None:selected=original if source.name=='legacy_swp_original.f90' else source
   ordered.append(selected)
 else:
  for source in [*ROOT.glob('src/**/*.f90'),*ROOT.glob('app/solute_column/*.f90'),original,ROOT/(native.RESEARCH+'mod_nonlinear_contact_pair.f90'),ROOT/(native.RESEARCH+'mod_contact_action_memory.f90'),*[ROOT/(native.RESEARCH+n) for n in ['mod_macro_liquid_thermal.f90', 'mod_native_macro_heat_feedback.f90', 'mod_native_coupled_transaction.f90', 'mod_native_feedback_context.f90']],ROOT/native.DRIVER]:
   key=source.relative_to(ROOT).as_posix() if source.is_relative_to(ROOT) else None;ordered.append(shadow.get(key,source))
 # Topological order follows the actual new imports; the complete202-provider closure stays present.
 providers={};uses={}
 for source in ordered:
  text=source.read_text(encoding='utf-8');uses[source]=re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',text,re.M|re.I)
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',text,re.M|re.I):providers[name.lower()]=source
 sorted_sources=[];seen=set()
 def visit(source):
  if source in seen:return
  seen.add(source)
  for name in uses[source]:
   if name.lower() in providers and providers[name.lower()]!=source:visit(providers[name.lower()])
  sorted_sources.append(source)
 if old:
  for source in ordered:visit(source)
 else:
  for source in [shadow[native.DRIVER],shadow[native.HEAD],original]:visit(source)
 ordered=sorted_sources;assert len(ordered)==207
 compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0];report['compiler']=compiler
 # Existing helper verifies every original compile input, object and TTUTIL authority.
 if prior:
  old_shadow={key:prior/'overlay'/key for key in shadow}
  verified_objects(prior,ROOT,old_order,old_shadow,a.optimization,compiler)
  utilities=prior/'original'
 else:utilities=native.build_original(out/'original',shutil.which('gfortran'),a.optimization,utilities_only=True)
 sources=[x.relative_to(ROOT).as_posix() for x in ordered if x.is_relative_to(ROOT) and not x.is_relative_to(out)]
 sources += list(shadow)+['app/support/restart_publish.c',native.RESEARCH+'native_contact_platform.c','tests/dataqual15/research_native_build_cache.py','tests/dataqual15/original_sources.py','tools/solute/legacy_reader_sources.py','tools/vq/b0_source_runner.py','tests/dataqual15/qualify_native_coupled.py',native.SELF,native.RESEARCH+'native_transaction_headcalc.inc',native.RESEARCH+'native_transaction_provider.inc',native.RESEARCH+'mod_contact_action_memory.f90',*[native.RESEARCH+n for n in ['mod_macro_liquid_thermal.f90', 'mod_native_macro_heat_feedback.f90', 'mod_native_coupled_transaction.f90', 'mod_native_feedback_context.f90']],'tests/dataqual15/qualify_contact_memory.py','tests/dataqual15/qualify_coupled_contact.py',native.RESEARCH+'contact_headcalc_methods.inc',native.RESEARCH+'contact_provider_methods.inc']
 assert not subprocess.check_output(['git','diff','HEAD','--',*sources]),'persist first'
 report['source_git_blob']={x:subprocess.check_output(['git','rev-parse','HEAD:'+x],text=True).strip() for x in set(sources)}
 report['rendered_sha256']={x:sha(y) for x,y in shadow.items()};report['generated_reader_sha256']=sha(original);save()
 flags=['-'+a.optimization,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build),'-I'+str(utilities/'ttobj')]
 objects=[];reuse={};dirty=set()
 if a.reuse_coupled_build:
  previous=a.reuse_coupled_build.resolve();rr=json.loads((previous/'RESULT.json').read_text(encoding='utf-8'));assert rr['compiler']==compiler and rr['optimization']==a.optimization
  cert=json.loads((previous/'COMPILED_INPUTS.json').read_text(encoding='utf-8'));assert len(cert)==202
  for entry in cert:
   assert sha(Path(entry['source']))==entry['source_sha256'] and sha(Path(entry['object']))==entry['object_sha256']
   reuse[Path(entry['source']).name]=entry
  for module in (previous/'build').glob('*.mod'):shutil.copy2(module,build/module.name)
 compiled=[]
 for i,source in enumerate(ordered):
  entry=reuse.get(source.name);affected=entry is None or sha(source)!=entry['source_sha256'] or any(name.lower() in dirty for name in uses[source])
  if affected:
   obj=build/(str(i)+'.o');run(['gfortran',*flags,'-c',source,'-o',obj],build,'compile-'+str(i))
   for name in re.findall(r'^\s*module\s+(\w+)\s*$',source.read_text(encoding='utf-8'),re.M|re.I):dirty.add(name.lower())
  else:obj=Path(entry['object'])
  objects.append(obj);compiled.append(dict(source=str(source),source_sha256=sha(source),object=str(obj),object_sha256=sha(obj),reused=not affected))
 (out/'COMPILED_INPUTS.json').write_text(json.dumps(compiled,indent=2)+'\n',encoding='utf-8');report['reused_objects']=sum(x['reused'] for x in compiled);save()
 for name,source in [('publish','app/support/restart_publish.c'),('platform',native.RESEARCH+'native_contact_platform.c')]:
  obj=build/(name+'.o');run(['gcc','-O2','-c',ROOT/source,'-o',obj],build,'compile-'+name);objects.append(obj)
 exe=build/'native.exe';run(['gfortran','-fopenmp',*objects,utilities/'ttobj/libttutil.a','-o',exe],build,'link');report['executable_sha256']=sha(exe);save()
 capsule=ROOT/'integration/dataqual15/ANDELST_CONTACT_DIAGNOSTIC.tar.xz';assert sha(capsule)=='0e0c5a80e4481e98a4e74632a06cbdc813e8514a76508716c4d131f445b470e4';report['source_capsule_sha256']=sha(capsule);save()
 def case(name):
  folder=out/name;folder.mkdir()
  with tarfile.open(ROOT/'integration/dataqual15/ANDELST_CONTACT_DIAGNOSTIC.tar.xz') as t:
   for n in ('input.nml','input.swp','input.bbc','input.dra','macro.nml','origin.bin'):(folder/n).write_bytes(t.extractfile('run/'+n).read())
  binding=hashlib.sha256((folder/'input.nml').read_bytes()+(folder/'input.swp').read_bytes()+(folder/'macro.nml').read_bytes()+report['executable_sha256'].encode()).hexdigest()
  raw=(folder/'origin.bin').read_bytes();assert zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
  raw=raw[:8]+binding.encode()+raw[72:-4];raw+=struct.pack('=I',zlib.crc32(raw));(folder/'origin.bin').write_bytes(raw)
  return folder,binding
 for enabled in (0,1):
  folder,binding=case('contact-'+str(enabled));cp=run([exe,'input.nml','origin.bin','5','input.swp','macro.nml',binding,'5.0','anchored-cauchy','0.0001','experimental','source-surface-demand','perched-jacobian','conservative-macro-storage'],folder,'contact-'+str(enabled),env=dict(os.environ,OMP_NUM_THREADS='1',SWAP5_RESEARCH_CONTACT=str(enabled)),check=False)
  assert cp.returncode!=0,'inspect unexpected full continuation'
 assert (out/'contact-0/origin.bin').read_bytes()==(out/'contact-0/diagnostic-rejected.bin').read_bytes()==(out/'contact-1/diagnostic-rejected.bin').read_bytes()
 report['contact_rows']=(out/'contact-1/coupled-contact.csv').read_text(encoding='utf-8').splitlines();report['native_rollback_exact']=True
 trials=[row.split(',') for row in report['contact_rows'] if row.startswith('COUPLED,')]
 assert len(trials)==5 and [r[2] for r in trials]==['T','T','T','F','F']
 assert max(float(r[-2]) for r in trials[:3])<=1e-10 and max(abs(float(r[-1])) for r in trials[:3])<=1e-11
 for tag in ('MACRO_STORAGE','MACRO_VERTICAL'):
  rows=[row.split(',') for row in report['contact_rows'] if row.startswith(tag+',')];assert len(rows)==3 and all(row[2]=='T' for row in rows),rows
 history=[row.split(',') for row in report['contact_rows'] if row.startswith('HISTORY_BRANCHES,')];assert len(history)==3 and all(row[2:4]==['T','T'] for row in history)
 assert all(row[4]=='F' and float(row[5])>0 for row in history)
 completed=[row.split(',') for row in report['contact_rows'] if row.startswith('ACTION_HISTORY,')];assert len(completed)==3 and all(row[2:4]==['T','T'] for row in completed)
 report['native_transaction_rows']=(out/'contact-1/native-coupled-transaction.csv').read_text(encoding='utf-8').splitlines()
 report['private_coupled_candidate_history_complete']=True;report['full_coupled_step_accepted']=False;report['contact_memory_closure_available']=True;report['policy']='EXPLICIT_CORRECTED_ACTION_CLOCK_NOT_ORIGINAL_BINARY_MODEL';save()
 folder,binding=case('actual-prefix');run([exe,'input.nml','-','1','input.swp','macro.nml',binding,'1.0','anchored-cauchy','0.0001','experimental','source-surface-demand','perched-jacobian','conservative-macro-storage'],folder,'actual-prefix',env=dict(os.environ,OMP_NUM_THREADS='1',SWAP5_RESEARCH_CONTACT='0'))
 report['status']='NATIVE_COUPLED_TRANSACTION_EXECUTED_INSPECT_ACCEPTANCE';save();print(report['status']);print('\n'.join(x for x in report['native_transaction_rows'] if x.startswith(('TRANSACTION','REVISION','WATER_TRIAL'))))
if __name__=='__main__':main()
