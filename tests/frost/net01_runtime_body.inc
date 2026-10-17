  ! B19 helper routines are reused unchanged by run_net01_runtime.py.
  integer::levels,vector_case,j,policy_count,rejected_count
  real(real64)::saved_net
  case_count=0;policy_count=0;rejected_count=0;duration=1.e-6_real64
  do levels=2,3
  do air=1,2
  do separate=0,1
  do blocking=0,1
  do bsign=-1,1,2
  do vector_case=1,4
    call configure_case(p,f,initial,air,1,separate,0)
    allocate(p%frost_divdra_levels(levels),f%frost_divdra_scalars_cm_per_day(levels))
    do j=1,levels
      p%frost_divdra_levels(j)=p%frost_divdra
      p%frost_divdra_levels(j)%distribution%drain_spacing=4._real64*real(j,real64)
      p%frost_divdra_levels(j)%drain_bottom_cm=-2._real64-.2_real64*real(j-1,real64)
    end do
    if(blocking==1)p%frost_divdra_levels(1)%drain_bottom_cm=-.5_real64
    f%frost_divdra_scalar_cm_per_day=0._real64
    f%frost_divdra_scalars_cm_per_day=0._real64
    f%frost_divdra_scalars_cm_per_day(1)=.01_real64
    select case(vector_case)
    case(1);f%frost_divdra_scalars_cm_per_day(2)=-.01_real64
    case(2);f%frost_divdra_scalars_cm_per_day(2)=-.0099995_real64
    case(3);f%frost_divdra_scalars_cm_per_day(2)=-.0099985_real64
    case(4);f%frost_divdra_scalars_cm_per_day(2)=.005_real64
    end select
    if(levels==3)f%frost_divdra_scalars_cm_per_day(3)=.002_real64
    f%bottom_flux=.001_real64*real(bsign,real64)
    call run(p,f,initial,0._real64,duration,out,obs,final,captured)
    call require(out%completed.and.out%committed,'multilevel actual runtime commits')
    call require(obs%frost_multilevel_divdra%available,'actual trial multilevel execution')
    call require(obs%frost_multilevel_divdra%low_air.eqv.(air==2),'physical low-air selection')
    call require(out%mass%complete.and.abs(out%mass%residual)<=hard_mass_gate,'hard column mass')
    call require(obs%frost_divdra_mass_accounted_in_trial,'existing sole trial ledger')
    if(obs%frost_multilevel_divdra%net_policy_applied)then
      saved_net=sum(obs%frost_multilevel_divdra%retained_scalar)
      call require(abs(obs%bottom_flux-sum(obs%frost_multilevel_divdra%final_nodal_sink)+saved_net)<1.e-14_real64, &
           'signed physical net preserved')
      policy_count=policy_count+1
    end if
    call run(p,f,initial,0._real64,duration,repeated,obs,again)
    call require(repeated%committed.and.all(final%pressure_head==again%pressure_head),'fresh worker A/B/A replay')
    call require(out%mass%storage_change==repeated%mass%storage_change,'one-time replay mass')
    case_count=case_count+1
    print '(A,I0,A,ES24.16)','NET01_CASE_',case_count,' MASS=',out%mass%residual
    if(vector_case==1.and.bsign==1.and.blocking==0)then
      call identities(columns(1),templates(1));registry(1)=captured
      call fmr_export_committed_restart(p%parameter_set_id,columns,templates,registry,bundle,ok,status)
      call require(ok.and.status==FMR_RESTART_OK,'export existing committed restart')
      call fmr_restore_committed_restart(bundle,p%parameter_set_id,columns,templates,restored,ok,status)
      call require(ok.and.status==FMR_RESTART_OK,'restore into empty registry')
      call run(p,f,final,duration,duration,out,obs,restart_a,resumed=captured)
      call run(p,f,final,duration,duration,repeated,obs,restart_b,resumed=restored(1))
      call require(out%committed.and.repeated%committed,'both continuations commit')
      call require(all(restart_a%pressure_head==restart_b%pressure_head),'restart exact pressure')
      call require(all(restart_a%water_content==restart_b%water_content),'restart exact storage')
      call require(out%mass%storage_change==repeated%mass%storage_change,'restart exact accounting')
      ! Invalid forcing must not reach the solver or alter accepted state.
      do invalid=1,6
        badp=p;badf=f
        select case(invalid)
        case(1);badf%frost_divdra_scalars_cm_per_day(1)=ieee_value(0._real64,ieee_quiet_nan)
        case(2);badf%frost_divdra_scalar_cm_per_day=.01_real64
        case(3);badp%frost_divdra_levels(1)%distribution%dz(1)=1._real64
        case(4);deallocate(badf%frost_divdra_scalars_cm_per_day)
        case(5);allocate(badf%drainage_flux_by_level(1,4));badf%drainage_flux_by_level=0._real64
        case(6);badf%frost_divdra_scalars_cm_per_day(1)=1.e-10_real64
        end select
        call run(badp,badf,initial,0._real64,duration,out,obs,again)
        call require(.not.out%committed.and..not.obs%solver_executed,'invalid ownership rejects before solver')
        call require(all(again%pressure_head==initial%pressure_head),'rejected trial nonmutation')
        rejected_count=rejected_count+1
      end do
    end if
  end do
  end do
  end do
  end do
  end do
  end do
  call require(case_count==256.and.policy_count>0.and.rejected_count==48,'complete physical matrix')
  print '(A,I0)','NET01_POLICY_CASES=',policy_count
  print '(A)','NET01_ACTUAL_RUNTIME=PASS'
