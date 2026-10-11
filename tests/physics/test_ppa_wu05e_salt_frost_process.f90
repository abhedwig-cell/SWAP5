program salt_frost_process
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
 use mod_root_water_uptake_process
 use mod_root_uptake_compensation
 use mod_root_uptake_compensation_execution
 implicit none
 type(root_water_uptake_flux_result_t)::base,final
 type(root_water_uptake_diagnostics_t)::bd
 type(root_compensation_config_t)::cfg
 type(root_compensation_diagnostics_t)::diag
 type(root_walsum_geometry_t)::geometry
 real(real64)::potential(4),drought(4),oxygen(4),salt(4),frost(4),raw(4),losses(4),actual(4)
 real(real64)::alphas(4),effective(4),expected(4),expected_loss(4),uptake,qred,weight,node_loss,alpha,total
 integer::i,j,k,status,scenario,method
 ! Direct transcription of the independently pinned reference equations below.
 ! No production attribution/compositor helper computes an expected result.
 potential=[.4_real64,.4_real64,.2_real64,0._real64]
 geometry=root_walsum_geometry_t(.5_real64,5._real64,1.5_real64)
 allocate(base%root_extraction_sink(4))
 do scenario=1,6
   drought=[.5_real64,1._real64,.25_real64,1._real64]
   oxygen=[.75_real64,.5_real64,1._real64,1._real64]
   salt=[.8_real64,.6_real64,.4_real64,1._real64]
   frost=[0._real64,1._real64,0._real64,1._real64]
   select case(scenario)
   case(2);oxygen=1._real64
   case(3);drought=1._real64;oxygen=1._real64
   case(4);drought=1._real64;oxygen=1._real64;salt=1._real64;frost=1._real64
   case(5);frost=0._real64
   case(6);salt=1._real64;frost=1._real64
   end select
   raw=potential*drought*oxygen*salt*frost
   losses=0._real64
   do i=1,4
     node_loss=potential(i)-raw(i)
     weight=sum(1._real64-[drought(i),oxygen(i),salt(i),frost(i)])
     if(node_loss>1.e-14_real64)losses=losses+(1._real64-[drought(i),oxygen(i),salt(i),frost(i)])/weight*node_loss
   end do
   call attribute_root_stress_losses(potential,potential*drought,oxygen,actual(1),actual(2),status, &
        salt,actual(3),frost,actual(4))
   call req(status==ROOT_COMP_OK,'joint node attribution')
   call near(actual,losses,'independent four-factor node loss oracle')
   call req(abs(sum(losses)+sum(raw)-sum(potential))<2.e-14_real64,'precompensation closure')
   base%root_extraction_sink=raw;base%actual_uptake_total=sum(raw)
   bd%drought_reduction_total=actual(1)
   do method=1,2
     cfg%method=method
     alpha=.7_real64
     cfg%alpha_critical=alpha
     if(method==ROOT_COMP_WALSUM)cfg%alpha_critical=ieee_value(0._real64,ieee_quiet_nan)
     do k=1,5
       cfg%stressor=k
       uptake=sum(raw);expected=raw;expected_loss=losses;qred=1._real64-uptake
       if(uptake>=.05_real64.and.qred>1.e-14_real64)then
         alphas=uptake**(losses/qred);effective=alphas
         if(k==ROOT_COMP_ALL)then
           total=min(uptake/alpha,1._real64)
         else
           j=k-1
           effective(j)=min(alphas(j)/alpha,1._real64)
           total=product(effective)
         end if
         expected=raw*(total/uptake)
         weight=sum(1._real64-effective)
         expected_loss=0._real64
         if(1._real64-total>1.e-14_real64.and.weight>1.e-14_real64) &
              expected_loss=(1._real64-effective)/weight*(1._real64-total)
         ! ALL uses the unmodified effective per-stressor alphas for reporting.
       end if
       call apply_root_uptake_compensation(cfg,1._real64,base,bd,actual(2),final,diag,status, &
            geometry,[.5_real64,.5_real64,1._real64,1._real64],actual(3),actual(4))
       call req(status==ROOT_COMP_EXEC_OK,'Jarvis/Walsum joint compensation')
       call near(final%root_extraction_sink,expected,'independent selected compensation oracle')
       call near([diag%drought_reduction_total,diag%oxygen_reduction_total, &
            diag%salinity_reduction_total,diag%frost_reduction_total],expected_loss,'independent postcompensation loss oracle')
       call req(abs(final%actual_uptake_total+diag%drought_reduction_total+diag%oxygen_reduction_total+ &
            diag%salinity_reduction_total+diag%frost_reduction_total-1._real64)<2.e-14_real64,'postcompensation closure')
       call req(all(pack(final%root_extraction_sink,raw==0._real64)==0._real64),'zero/frozen sink cannot resurrect')
       call req(final%actual_uptake_total<=1._real64,'hard potential uptake bound')
     end do
   end do
 end do
 ! Joint invalid factors fail with deterministic empty loss outputs.
 do k=1,5
   salt=1._real64;frost=1._real64
   select case(k)
   case(1);frost(1)=ieee_value(0._real64,ieee_quiet_nan)
   case(2);salt(1)=ieee_value(0._real64,ieee_positive_inf)
   case(3);salt(1)=-.1_real64
   case(4);frost(1)=1.1_real64
   case(5);frost(1)=ieee_value(0._real64,ieee_positive_inf)
   end select
   call attribute_root_stress_losses(potential,potential,spread(1._real64,1,4),actual(1),actual(2),status, &
        salt,actual(3),frost,actual(4))
   call req(status==ROOT_COMP_INVALID,'invalid joint factors reject')
   call req(all(actual==0._real64),'invalid joint outputs empty')
 end do
 salt=1._real64;frost=1._real64
 call attribute_root_stress_losses(potential,potential,oxygen,actual(1),actual(2),status, &
      salt(:3),actual(3),frost,actual(4))
 call req(status==ROOT_COMP_INVALID,'joint salt shape rejects')
 call attribute_root_stress_losses(potential,potential,oxygen,actual(1),actual(2),status, &
      salt,actual(3),frost(:3),actual(4))
 call req(status==ROOT_COMP_INVALID,'joint frost shape rejects')
 call attribute_root_stress_losses(potential,potential,oxygen,actual(1),actual(2),status, &
      salinity_factor=salt,frost_factor=frost,frost_loss=actual(4))
 call req(status==ROOT_COMP_INVALID,'joint attribution requires both output channels')
 potential=0._real64
 call attribute_root_stress_losses(potential,potential,oxygen,actual(1),actual(2),status, &
      salt,actual(3),frost,actual(4))
 call req(status==ROOT_COMP_OK.and.all(actual==0._real64),'zero potential joint identity')
 print '(a)','PPA_SALFRO01_INDEPENDENT_PROCESS_ORACLE=PASS'
contains
 subroutine near(a,b,message)
 real(real64),intent(in)::a(:),b(:)
 character(*),intent(in)::message
 call req(all(abs(a-b)<2.e-14_real64),message)
 end subroutine
 subroutine req(ok,message)
 logical,intent(in)::ok
 character(*),intent(in)::message
 if(.not.ok)then
   print *,message
   error stop 1
 end if
 end subroutine
end program
