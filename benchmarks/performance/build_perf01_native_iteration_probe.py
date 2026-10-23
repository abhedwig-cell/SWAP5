"""Research-only relink with an explicit iteration limit; never edits production."""
import argparse,copy,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--base',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--iterations',type=int,required=True)
    ap.add_argument('--min-step',type=float)
    ap.add_argument('--head-tolerance',type=float)
    ap.add_argument('--balance-tolerance',type=float)
    ap.add_argument('--observe-solver',action='store_true')
    ap.add_argument('--saturated-restart',action='store_true')
    a=ap.parse_args();assert 8<=a.iterations<=100
    assert a.min_step is None or 1e-12<=a.min_step<=1e-6
    assert a.head_tolerance is None or 1e-12<=a.head_tolerance<=1e-6
    assert a.balance_tolerance is None or 1e-12<=a.balance_tolerance<=1e-10
    base=a.base.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    bundle=json.loads((base/'bundle.json').read_text());meta=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text())
    assert all(sha(ROOT/p)==h for p,h in meta['input_sha256'].items())
    assert all(sha(Path(p))==h for p,h in meta['reused_artifact_sha256'].items())
    source=ROOT/'app/solute_project/main.f90';raw=source.read_text()
    anchor='p%max_iterations=8;p%max_backtracking=4';assert raw.count(anchor)==1
    raw=raw.replace(anchor,f'p%max_iterations={a.iterations};p%max_backtracking=4'+
        (f';p%min_step_duration={a.min_step:.17e}_real64'if a.min_step is not None else'')+
        (f';p%head_abs_tolerance={a.head_tolerance:.17e}_real64;p%head_rel_tolerance={a.head_tolerance:.17e}_real64'if a.head_tolerance is not None else'')+
        (f';p%compartment_balance_tolerance={a.balance_tolerance:.17e}_real64;p%total_balance_tolerance={a.balance_tolerance:.17e}_real64'if a.balance_tolerance is not None else''))
    failure="      write(*,*)'joint status/water/chemical: ',result%status,result%water%status,result%chemical%status\n"
    assert raw.count(failure)==1
    raw=raw.replace(failure,failure+"      observation=backend%observation()\n"+
        "      write(*,*) 'PROBE_REJECTIONS',result%diagnostics%solver_rejections, &\n"+
        "        result%diagnostics%temporal_rejections,result%diagnostics%mass_rejections\n"+
        "      write(*,*) 'PROBE_SOLVER',observation%solver_status,observation%solver_diagnostics%nonlinear_iterations, &\n"+
        "        observation%solver_diagnostics%headcalc_calls,observation%solver_diagnostics%backtracking_attempts\n")
    driver=out/'iteration_probe.f90';driver.write_text(raw)
    shared=meta['source_build'];objects=[e['command'][-1]for e in shared['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')]
    assert len(objects)==193
    flags=[f for f in meta['flags']if not f.startswith('-J')];exe=out/'swap5_iteration_probe'
    observed=None
    if a.observe_solver or a.saturated_restart:
        head=ROOT/'src/legacy/b1_10_port/headcalc.f90';headraw=head.read_text()
        if a.saturated_restart:
            anchor='   logical :: corner_retry_available, corner_retry_active\n';assert headraw.count(anchor)==1
            headraw=headraw.replace(anchor,anchor+'   logical :: saturated_probe_active, saturated_probe_seed, saturated_probe_available\n'+
                '   type(reference_richards_state_binding_t) :: saturated_probe_entry\n'+
                '   real(8) :: saturated_probe_target, saturated_probe_left, saturated_probe_right, saturated_probe_mid, saturated_probe_loss\n'+
                '   integer :: saturated_probe_i\n')
            anchor='900 continue\n';assert headraw.count(anchor)==1
            headraw=headraw.replace(anchor,'   saturated_probe_active=.false.;saturated_probe_seed=.false.\n'+
                '   saturated_probe_available=provider_constitutive_active.and.provider_dynamic_top_active.and. &\n'+
                '      swmacro==0.and.swbotb==2.and.swkimpl==0.and..not.consistent_provider_conductivity.and. &\n'+
                '      .not.picard_conductivity_iteration.and.all(state%hm1(1:NN)>=0d0)\n'+
                '   if(saturated_probe_available)saturated_probe_entry=state\n'+anchor)
            anchor='!  calculate vector fsi_ws%residual (first time)\n';assert headraw.count(anchor)==1
            headraw=headraw.replace(anchor,
                '   if(saturated_probe_seed)then\n'+
                '      saturated_probe_seed=.false.\n'+
                '      saturated_probe_left=minval(state%hm1(1:NN));saturated_probe_right=saturated_probe_left+1d0\n'+
                '      do saturated_probe_i=1,20\n'+
                '         call evaluate_saturated_probe_shift(saturated_probe_right,saturated_probe_loss)\n'+
                '         if(saturated_probe_loss>=saturated_probe_target)exit\n'+
                '         saturated_probe_right=saturated_probe_left+2d0*(saturated_probe_right-saturated_probe_left)\n'+
                '      end do\n'+
                '      do saturated_probe_i=1,40\n'+
                '         saturated_probe_mid=0.5d0*(saturated_probe_left+saturated_probe_right)\n'+
                '         call evaluate_saturated_probe_shift(saturated_probe_mid,saturated_probe_loss)\n'+
                '         if(saturated_probe_loss<saturated_probe_target)then\n'+
                '            saturated_probe_left=saturated_probe_mid\n'+
                '         else\n'+
                '            saturated_probe_right=saturated_probe_mid\n'+
                '         end if\n'+
                '      end do\n'+
                '      provider_tuple_valid=.true.;provider_tuple_from_candidate=.true.\n'+
                '      do i=2,NN\n'+
                '         fsi_ws%head_gradient(i)=(state%h(i-1)-state%h(i))/grid_disnod(i)+1d0\n'+
                '      end do\n'+
                "      write(*,*) 'PROBE_SATURATED_SEED',dt,minval(state%hm1(1:NN))\n"+
                '   end if\n'+anchor)
            anchor='   if (.NOT.fldtmin) then\n';assert headraw.count(anchor)==1
            headraw=headraw.replace(anchor,
                '   if(saturated_probe_available.and..not.saturated_probe_active.and..not.state%ftoph.and. &\n'+
                '      all(state%h(1:NN)>=0d0).and.all(state%theta(1:NN)==state%thetm1(1:NN)).and.sum1>CritDevBalTot)then\n'+
                '      saturated_probe_target=sum1*dt\n'+
                '      state=saturated_probe_entry;saturated_probe_active=.true.;saturated_probe_seed=.true.\n'+
                '      iBackTr=0\n'+
                '      goto 900\n'+
                '   end if\n'+anchor)
            old=('   if(saturated_probe_available.and..not.saturated_probe_active.and..not.state%ftoph.and. &\n'+
                '      all(state%h(1:NN)>=0d0).and.all(state%theta(1:NN)==state%thetm1(1:NN)).and.sum1>CritDevBalTot)then\n'+
                '      saturated_probe_target=sum1*dt\n')
            assert headraw.count(old)==1
            headraw=headraw.replace(old,'   if(saturated_probe_available.and..not.saturated_probe_active)then\n')
            anchor='   call vector_F(1)\n';assert headraw.count(anchor)==1
            headraw=headraw.replace(anchor,anchor+
                '   if(saturated_probe_available.and..not.saturated_probe_active)then\n'+
                '      saturated_probe_target=dt*sum(fsi_ws%residual(1:NN))\n'+
                '      saturated_probe_available=.not.state%ftoph.and.saturated_probe_target>0d0.and. &\n'+
                '         all(state%theta(1:NN)==state%thetm1(1:NN))\n'+
                '   end if\n')
            anchor='\ncontains\n';assert headraw.count(anchor)==1
            headraw=headraw.replace(anchor,anchor+'''
subroutine evaluate_saturated_probe_shift(shift,storage_loss)
   real(8),intent(in)::shift
   real(8),intent(out)::storage_loss
   integer::probe_node
   state%h(1:NN)=state%hm1(1:NN)-shift
   ctx%diagnostics%constitutive_evaluations=ctx%diagnostics%constitutive_evaluations+1
   call evaluation_context%constitutive%evaluate(state%h(1:numnod),fsi_ws%provider_theta, &
        fsi_ws%provider_k,fsi_ws%provider_capacity,fsi_ws%provider_dkdh)
   state%theta(1:NN)=fsi_ws%provider_theta(1:NN)
   call evaluation_context%constitutive%evaluate_water_content_increment(state%h(1:numnod),state%hm1(1:numnod), &
        state%theta(1:numnod),state%thetm1(1:numnod),fsi_ws%provider_water_content_increment(1:numnod))
   storage_loss=0d0
   do probe_node=1,NN
      storage_loss=storage_loss-fsi_ws%provider_water_content_increment(probe_node)*grid_dz(probe_node)
   end do
end subroutine
''')
        anchor='!  Convergence could not been reached\n';assert headraw.count(anchor)==1
        headraw=headraw.replace(anchor,anchor+
          "   write(*,*) 'PROBE_HEAD_FAILURE',dt,Fmax,sum1,state%ftoph,state%pondm1,state%pond,state%qtop\n"+
          "   write(*,*) 'PROBE_HEAD_ORIGIN',state%hm1(1:NN)\n"+
          "   write(*,*) 'PROBE_HEAD_CANDIDATE',state%h(1:NN)\n")
        observed=out/'observed_headcalc.f90';observed.write_text(headraw)
        headobj=next(e['command'][-1]for e in shared['events']if e['category']=='compile'and e['command'][-3]==str(head))
        objects.remove(headobj)
        observed_object=out/'observed_headcalc.o'
        r=subprocess.run(meta['compiler_command']+flags+['-J'+str(out),'-c',str(observed),'-o',str(observed_object)],cwd=out,capture_output=True)
        (out/'headcalc.stdout').write_bytes(r.stdout);(out/'headcalc.stderr').write_bytes(r.stderr);r.check_returncode()
        objects.append(str(observed_object))
    archive=next(p for p in meta['reused_artifact_sha256']if p.endswith('/libttutil.a'))
    command=meta['compiler_command']+flags+['-J'+str(out),str(driver),*objects,archive,'-o',str(exe)]
    t=time.perf_counter();r=subprocess.run(command,cwd=out,capture_output=True)
    (out/'stdout').write_bytes(r.stdout);(out/'stderr').write_bytes(r.stderr);r.check_returncode()
    record=copy.deepcopy(meta);record.update(executable_sha256=sha(exe),
        research_only=dict(iteration_limit=a.iterations,min_step_duration=a.min_step,head_tolerance=a.head_tolerance,
          balance_tolerance=a.balance_tolerance,production_source_sha256=sha(source),
          generated_driver_sha256=sha(driver),compile_link_seconds=time.perf_counter()-t,command=command),
        generated_input_sha256={driver.name:sha(driver)})
    if observed:
        record['generated_input_sha256'][observed.name]=sha(observed)
        record['research_only']['diagnostic_headcalc_source_sha256']=sha(observed)
        record['research_only']['saturated_neumann_restart']=a.saturated_restart
    (out/'build-complete.json').write_text(json.dumps(record,indent=2)+'\n')
    old=bundle['exe'];bundle['exe']=str(exe);bundle['executable_sha256'].pop(old)
    bundle['executable_sha256'][str(exe)]=sha(exe);bundle['research_only']=record['research_only']
    (out/'bundle.json').write_text(json.dumps(bundle,indent=2)+'\n')
    print('RESEARCH_ITERATION_PROBE_BUILT',a.iterations)
if __name__=='__main__':main()
