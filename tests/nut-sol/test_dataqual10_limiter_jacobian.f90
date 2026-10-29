program conservative_limiter_jacobian
 use iso_fortran_env,only:real64
 use mod_column_swp_macro_configuration
 use mod_column_swp_macro_initial
 use mod_fmr_macropore_configuration
 use mod_ppa_wu05a6_rate_bundle
 use mod_ppa_wu05a15_exchange_derivative
 implicit none
 type(native_macro_initial_t)::initial
 type(fmr_macropore_physical_config_t)::config
 type(macropore_rate_bundle_request_t)::q
 type(macropore_rate_bundle_result_t)::r,rp,rm
 type(macropore_exchange_derivative_result_t)::d
 real(real64),allocatable::capacity(:)
 real(real64)::fd,h,step,worst,err,tolerance,dt
 character(1024)::path,mode
 integer::n,nd,k,policy,orientation,capped,split,j,cases,defects
 logical::expect_defect
 call get_command_argument(1,path);call get_command_argument(2,mode)
 expect_defect=trim(mode)=='expect-defect'
 call import_column_macro_configuration(trim(path),initial,config,allow_variable_surface=.true.)
 n=initial%geometry%num_nodes;nd=initial%geometry%num_domains;k=20
 allocate(capacity(n));capacity=0d0;cases=0;defects=0;worst=0d0;h=2d0;step=1d-5
 do policy=0,1
 do orientation=1,2
 do capped=0,1
 do split=0,1
 do j=1,3
  dt=10d0**(j-3);q=config%rate_template
  q%unsaturated%sorptivity%step_duration=dt
  q%unsaturated%sorptivity%matrix_top_saturated_node=1
  q%unsaturated%sorptivity%flow_reduction=0d0
  q%interflow_sat%step_duration=dt;q%interflow_sat%matrix_bottom_saturated_node=0
  q%rapid%step_duration=dt;q%rapid%enabled=.false.
  q%matrix_sat%step_duration=dt;q%matrix_sat%matrix_top_saturated_node=k
  q%matrix_sat%matrix_bottom_saturated_node=k+split
  q%matrix_sat%matrix_partial_top_active=.false.;q%matrix_sat%bottom_domain=n
  q%matrix_sat%matrix_head=0d0;q%matrix_sat%matrix_head(k)=h;q%matrix_sat%matrix_head(k+1)=3d0
  q%matrix_sat%macro_reference_level=q%matrix_sat%z(k)-10d0
  if(orientation==2)q%matrix_sat%macro_reference_level=q%matrix_sat%z(k)+10d0
  q%matrix_sat%cdarcy=10d0;q%matrix_sat%flow_reduction=1d0
  q%limiter%conservative_storage_bounds=policy==1
  q%limiter%minimum_storage_cm=0d0
  q%limiter%accepted_storage_cm=1d5;q%limiter%maximum_storage_cm=2d5
  if(capped==1)then
   q%limiter%maximum_storage_cm=1d0;q%limiter%accepted_storage_cm=1d0-1d-6
   if(orientation==2)q%limiter%accepted_storage_cm=1d-6
  end if
  q%limiter%potential_top_vertical_cm=0d0;q%limiter%potential_top_lateral_cm=0d0
  q%limiter%redistribution_capacity_cm=0d0
  call evaluate_macropore_rate_bundle(q,r)
  if(.not.r%valid)error stop 'invalid real rate bundle'
  call evaluate_macropore_exchange_derivative(q,r,capacity,d,.true.)
  if(.not.d%valid)error stop 'invalid real Jacobian'
  q%matrix_sat%matrix_head(k)=h+step;call evaluate_macropore_rate_bundle(q,rp)
  q%matrix_sat%matrix_head(k)=h-step;call evaluate_macropore_rate_bundle(q,rm)
  q%matrix_sat%matrix_head(k)=h
  if(.not.rp%valid.or..not.rm%valid)error stop 'invalid perturbed real bundles'
  fd=sum(rp%qexc_to_matrix_rate(:,k)-rm%qexc_to_matrix_rate(:,k))/(2d0*step)
  err=abs(fd-d%total_dqdh_node(k));tolerance=max(5d-9,5d-6*abs(fd))
  if(policy==0)then
   write(*,'(a,4i3,3es25.17e3)')'LEGACY',orientation,capped,split,j,sum(r%qexc_to_matrix_rate(:,k)),d%total_dqdh_node(k),fd
  else
   worst=max(worst,err);cases=cases+1
   if(err>tolerance)then
    defects=defects+1
    if(.not.expect_defect)then
     print *, 'DERIVATIVE_MISMATCH',orientation,capped,split,j,d%total_dqdh_node(k),fd
     error stop 'conservative Jacobian differs from actual limited rate bundle'
    end if
   end if
  end if
 end do
 end do
 end do
 end do
 end do
 if(expect_defect)then
  if(defects==0)error stop 'expected baseline defect absent'
  print *, 'BASELINE_LIMITER_DERIVATIVE_DEFECTS',defects,cases,worst
 else
  print *, 'CONSERVATIVE_LIMITER_JACOBIAN_PASS',cases,defects,worst
 end if
end program
