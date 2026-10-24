"""Source-bound downstream trace gap after bounded PR1431; no production edits."""
import hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent
sha=lambda b:hashlib.sha256(b).hexdigest()
results={}
for opt in ['O0','O2']:
 out=W/('andelst-trace-boundary-'+opt);out.mkdir();base=W/('andelst-macro-bbc6-'+opt);meta=json.loads((W/('fresh-build-'+opt)/'column/build-complete.json').read_text())
 source=(ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
 old='parameters%macropore_active.or.allocated(forcing%rutter)))'
 new='parameters%macropore_active.or.allocated(forcing%rutter)).and. &\n           .not.(template%optional_state_layout_id==FMR_OPTIONAL_STATE_LAYOUT_RUTTER_BOESTEN_MACROPORE.and. &\n             parameters%bottom_mode==3.and..not.parameters%swbotb3_explicit_active))'
 assert source.count(old)==1
 private=out/'trace_counterfactual.f90'
 metric='if(self%boesten_evaporation_active.and.self%accepted_water_flux_trace_enabled)then'
 assert source.count(metric)==1
 changed=source.replace(old,new).replace(metric,'if(self%boesten_evaporation_active.and.self%accepted_water_flux_trace_enabled.and..not.self%macropore_active)then')
 needle='    if (self%model%accepted_water_flux_trace_enabled .and. result%completed) then'
 assert changed.count(needle)==1
 observer="""    if(result%completed)then
      block
        class(transaction_state_t),allocatable::trace_physical
        logical::trace_available
        call candidate%snapshot(trace_physical,trace_available)
        if(.not.trace_available)error stop 'trace gap missing pre-publication candidate'
        select type(q=>trace_physical)
        type is(fmr_b110_boesten_macropore_state_t)
          write(*,'(*(g0,1x))')'TRACE_PHYSICS',result%mass%residual,q%pressure_head,q%water_content, &
            q%ponding_depth,q%macropore%water_domain_cp,q%boesten_evaporation%spev,q%boesten_evaporation%saev, &
            q%rutter%canopy_storage(),q%rutter%accepted_until()
        class default
          error stop 'trace gap unexpected physical state'
        end select
      end block
    end if
"""
 private.write_text(changed.replace(needle,observer+needle))
 flags=[f for f in meta['flags']if not f.startswith('-J')];fc=meta['compiler_command'];events=[]
 def run(cmd,label,cwd=out):
  cmd=list(map(str,cmd));start=time.perf_counter();cp=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=180,env={**os.environ,'PATH':str(W/'compiler/bin')+':'+os.environ['PATH'],'WU05_MIGMAC10':'1','WU05_MIGMAC10_RUTTER':'1','WU05_MIGMAC02_DYNAMIC':'2'})
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(label=label,command=cmd,returncode=cp.returncode,seconds=time.perf_counter()-start));(out/'events.json').write_text(json.dumps(events,indent=2));return cp
 cp=run(fc+flags+['-J'+str(out),'-c',private,'-o',out/'trace_counterfactual.o'],'compile');assert cp.returncode==0,cp.stderr.decode()
 objects=[]
 for e in meta['source_build']['events']:
  if e['category']!='compile'or e['command'][-3].endswith('/app/solute_crop/main.f90'):continue
  src,obj=e['command'][-3],e['command'][-1]
  if src.endswith('/src/runtime/mod_fmr_serialized_reference_backend.f90'):obj=str(base/'candidate_backend.o')
  if src.endswith('/src/adapter/mod_reference_richards_legacy_binding.f90'):obj=str(base/'candidate_binding.o')
  objects.append(obj)
 archive=[p for p in meta['reused_artifact_sha256']if p.endswith('/libttutil.a')]
 text=(base/'trial.f90').read_text();needle='result,candidate,diagnostics)';assert text.count(needle)==1
 text=text.replace(needle,'result,candidate,diagnostics,trace_accepted_water_flux_substeps=.true.)')
 text=text.replace('  observation=backend%observation()',"  observation=backend%observation()\n  write(*,'(A,L1,A,ES25.17E3)')'TRACE_DIAGNOSTIC=',observation%accepted_water_flux_trace_available, &\n    '|MACRO_ACCEPTED_TOP_CM=',observation%macropore_accepted_top_cm")
 driver=out/'trace_trial.f90';driver.write_text(text)
 for variant in ['canonical','counterfactual','control']:
  stage=out/variant;stage.mkdir();exe=stage/'driver'
  selected_driver=driver
  if variant=='control':
   selected_driver=out/'control_trial.f90';selected_driver.write_text(text.replace(',trace_accepted_water_flux_substeps=.true.',''))
  current=[str(out/'trace_counterfactual.o')if variant!='canonical'and p==str(base/'candidate_backend.o')else p for p in objects]
  cp=run(fc+['-I'+str(out),*flags,'-J'+str(stage),selected_driver,*current,*archive,'-o',exe],variant+'-link',stage);assert cp.returncode==0,cp.stderr.decode()
  cp=run([exe],variant,stage)
  if variant=='control':assert cp.returncode==0,cp.stderr.decode()[-1500:]
  else:assert cp.returncode!=0,'incomplete external-macro trace unexpectedly admitted'
 control=[l for l in (out/'control.stdout').read_bytes().splitlines()if l.startswith(b'TRACE_PHYSICS ')]
 traced=[l for l in (out/'counterfactual.stdout').read_bytes().splitlines()if l.startswith(b'TRACE_PHYSICS ')]
 assert len(control)==1 and control==traced,'pre-publication physical candidate changed'
 diag=(out/'counterfactual.stderr').read_bytes();assert b'COMPLETED=F'in diag and b'CANDIDATE_READY=F'in diag
 results[opt]=dict(status='PHYSICAL_CANDIDATE_EXACT_TRACE_PUBLICATION_REJECTS_ATOMICALLY',events=events,production_source_sha256=sha(source.encode()),counterfactual_source_sha256=sha(private.read_bytes()),driver_sha256=sha(driver.read_bytes()),production_edited=False)
 (out/'RESULT.json').write_text(json.dumps(results[opt],indent=2));print(opt,results[opt]['status'],flush=True)
