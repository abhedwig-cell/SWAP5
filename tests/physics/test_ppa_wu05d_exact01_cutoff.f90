program exact_cutoff
 use iso_fortran_env,only:real64
 use mod_root_water_uptake_process
 use mod_root_uptake_compensation
 use mod_root_uptake_compensation_execution
 use exact_reference_compensation,only:legacy_compensation
 implicit none
 type(root_water_uptake_flux_result_t)::base,final
 type(root_water_uptake_diagnostics_t)::bd
 type(root_compensation_config_t)::cfg
 type(root_compensation_diagnostics_t)::diag
 type(root_walsum_geometry_t)::geometry
 real(real64),parameter::ratios(11)=[0._real64,5.e-15_real64,1.e-14_real64,2.e-14_real64, &
       .01_real64,.042_real64,.049_real64,.05_real64,.051_real64,.5_real64,1._real64]
 real(real64)::refq(4),losses(4),refloss(4),alpha,weights(4),qred,ratio,tol
 integer::m,k,j,l,status,cases
 logical::eligible
 allocate(base%root_extraction_sink(4))
 geometry=root_walsum_geometry_t(.5_real64,5._real64,1.5_real64)
 cases=0
 do m=1,2
  cfg%method=m;cfg%alpha_critical=.7_real64
  do k=1,5
   cfg%stressor=k
   do l=1,3
    select case(l)
    case(1);weights=[1._real64,0._real64,0._real64,0._real64]
    case(2);weights=[.5_real64,.25_real64,.125_real64,.125_real64]
    case(3);weights=[0._real64,0._real64,.5_real64,.5_real64]
    end select
    do j=1,size(ratios)
     ratio=ratios(j);qred=1._real64-ratio;losses=weights*qred
     base%root_extraction_sink=[ratio*.5_real64,ratio*.5_real64,0._real64,0._real64]
     base%actual_uptake_total=sum(base%root_extraction_sink)
     bd%drought_reduction_total=losses(1)
     refq=base%root_extraction_sink;refloss=losses;alpha=.7_real64
     call legacy_compensation(refq,1._real64,refloss,m,k,alpha)
     call apply_root_uptake_compensation(cfg,1._real64,base,bd,losses(2),final,diag,status, &
          geometry,[.5_real64,.5_real64,1._real64,1._real64],losses(3),losses(4))
     call req(status==ROOT_COMP_EXEC_OK,'exact source valid input')
     eligible=qred>1.e-14_real64.and.ratio>=1.e-14_real64
     call req(diag%applied.eqv.eligible,'exact executable cutoff eligibility')
     tol=max(1.e-28_real64,maxval(abs(refq))*1.e-12_real64)
     call req(all(abs(final%root_extraction_sink-refq)<=tol),'literal B1.11 compensation block node oracle')
     call req(all(abs([diag%drought_reduction_total,diag%oxygen_reduction_total, &
          diag%salinity_reduction_total,diag%frost_reduction_total]-refloss)<2.e-14_real64), &
          'literal B1.11 compensation block reporting oracle')
     call req(final%actual_uptake_total<=1._real64,'hard PTRA bound')
     call req(all(final%root_extraction_sink(3:)==0._real64),'zero nodes never resurrect')
     call req(abs(final%actual_uptake_total+diag%drought_reduction_total+diag%oxygen_reduction_total+ &
          diag%salinity_reduction_total+diag%frost_reduction_total-1._real64)<2.e-14_real64,'source loss closure')
     cases=cases+1
    end do
   end do
  end do
 end do
 call req(cases==330,'declared cases all execute')
 print '(a,i0)','PPA_EXACT01_LITERAL_COMPENSATION_CASES=',cases
 print '(a)','PPA_EXACT01_CUTOFF_SOURCE_ORACLE=PASS'
contains
 subroutine req(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then
  print *,label,' METHOD=',m,' SELECTOR=',k,' WEIGHTS=',l,' RATIO=',ratio
  error stop 1
 end if
 end subroutine
end program
