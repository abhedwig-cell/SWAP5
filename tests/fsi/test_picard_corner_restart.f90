program test_picard_corner_restart
 use iso_fortran_env,only:real64
 use mod_soil_water_solver_contract
 use mod_b110_default_mvg_provider
 use mod_b110_source_sink_provider
 use mod_b110_root_sink_provider
 use mod_b110_dynamic_top_boundary_solver_adapter
 use mod_reference_richards_legacy_binding
 implicit none
 type(soil_water_parameter_set_t),target::p
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::source
 type(b110_root_sink_provider_t),target::root
 type(b110_dynamic_top_boundary_solver_provider_t),target::top
 type(reference_richards_legacy_solver_t)::solver
 type(reference_richards_legacy_workspace_t)::workspace,fresh
 type(soil_water_solve_request_t)::r
 type(soil_water_solve_result_t)::v,replay,first_result
 type(soil_water_boundary_conditions_t)::saved_boundary
 type(soil_water_numerical_config_t)::saved_numerical
 real(real64),allocatable::cof(:,:),kk(:),cc(:),dk(:),heads(:),theta(:),faces(:),cell(:)
 real(real64),allocatable,target::drain(:,:),irrigation(:),qroot(:)
 real(real64)::step,pond,gwl,rain,irr,snow,runon,ebare,epond,pmax,rsro,exponent,kfixed,residual
 integer::n,u,i,j,mode,expected,divisor
 logical::implicit_k
 character(len=1024)::path,arg
 call get_command_argument(1,path);call get_command_argument(2,arg);read(arg,*)expected
 open(newunit=u,file=trim(path),status='old')
 read(u,*)n
 p%active_nodes=n
 allocate(p%z(n),p%dz(n),p%node_distance(n),cof(24,n),kk(n),cc(n),dk(n),heads(n),theta(n), &
          faces(n+1),cell(n),drain(1,n),irrigation(n),qroot(n))
 read(u,*)p%z,p%dz,p%node_distance
 read(u,*)cof
 r%parameters=>p;r%base_state%active_nodes=n
 allocate(r%base_state%pressure_head(n),r%base_state%water_content(n))
 read(u,*)heads,theta,pond,gwl
 read(u,*)drain,irrigation,qroot
 read(u,*)r%boundary
 read(u,*)r%numerical
 read(u,*)step
 read(u,*)pond,rain,irr,snow,runon,ebare,epond,pmax,rsro,exponent,kfixed,implicit_k
 close(u)
 call get_command_argument(3,arg);read(arg,*)divisor
 step=step/real(divisor,real64)
 r%base_state%pressure_head=heads;r%base_state%water_content=theta
 r%base_state%ponding_depth=pond;r%base_state%groundwater_level=gwl
 call initialize_b110_default_mvg_parameters(hp,cof)
 hp%continuous_saturation_conductivity=.true.
 call bind_b110_default_mvg_provider(hyd,hp,step)
 saved_boundary=r%boundary;saved_numerical=r%numerical
 block
 real(real64),target::zero(n)
 zero=0d0
 call bind_b110_source_sink_provider(source,drain,irrigation,zero)
 call bind_b110_root_sink_provider(root,qroot)
 call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,pond,step,rain,irr,snow,runon, &
      ebare,epond,pmax,rsro,exponent,kfixed,implicit_conductivity=implicit_k)
 r%step_duration=step
 r%evaluation%constitutive=>hyd;r%evaluation%source_sink=>source
 r%evaluation%root_sink=>root;r%evaluation%dynamic_top_boundary=>top
 do mode=1,4
  hp%continuous_saturation_conductivity=mode/=2
  r%numerical%picard_conductivity_iteration=mode/=3
  if(mode==4)then
   r%boundary%bottom_mode=3
   r%boundary%bottom_external_resistance_days=100d0
   r%boundary%bottom_head=-100d0
  end if
  call solver%solve(r,workspace,v)
  if(any(r%base_state%pressure_head/=heads).or.any(r%base_state%water_content/=theta).or. &
     r%base_state%ponding_depth/=pond.or.r%base_state%groundwater_level/=gwl)error stop 'physical origin mutated'
  if(r%numerical%consistent_provider_conductivity)error stop 'caller numerical policy mutated'
  if(mode==1)then
   if(v%status/=expected)then
    print *, 'ACTUAL_STATUS',v%status,'EXPECTED',expected,'DT',step
    error stop 'predecessor discriminator'
   end if
   if(expected==SW_SOLVE_CONVERGED.and.v%diagnostics%internal_retries<1)error stop 'retry not exercised'
   first_result=v
  end if
  if(v%status==SW_SOLVE_CONVERGED)then
   faces(1)=v%top_flux;faces(n+1)=v%bottom_flux
   do i=2,n
    faces(i)=-workspace%state_binding%kmean(i)* &
      ((v%candidate_state%pressure_head(i-1)-v%candidate_state%pressure_head(i))/p%node_distance(i)+1d0)
   end do
   cell=(v%candidate_state%water_content-theta)*p%dz- &
      step*(faces(2:n+1)-faces(1:n)-drain(1,:)+irrigation-qroot)
   if(maxval(abs(cell))>1d-10.or.abs(sum(cell))>1d-10)error stop 'independent finite volume mass'
   if(.not.v%integrated_mass_balance_residual_available)error stop 'missing mass certificate'
   if(abs(v%integrated_mass_balance_residual_cm)>1d-10)error stop 'hard mass'
   call solver%solve(r,fresh,replay)
   if(replay%status/=v%status)error stop 'fresh replay status'
   if(any(replay%candidate_state%pressure_head/=v%candidate_state%pressure_head).or. &
      any(replay%candidate_state%water_content/=v%candidate_state%water_content).or. &
      replay%top_flux/=v%top_flux.or.replay%bottom_flux/=v%bottom_flux)error stop 'A B A scratch replay'
  end if
  write(*,*)'CORNER_CASE',mode,v%status,v%diagnostics%internal_retries
  if(v%status==SW_SOLVE_CONVERGED)then
   write(*,*)'HEAD',v%candidate_state%pressure_head
   write(*,*)'MASS',maxval(abs(cell)),sum(cell),v%integrated_mass_balance_residual_cm
  end if
 end do
 if(expected==SW_SOLVE_CONVERGED)then
  hp%continuous_saturation_conductivity=.true.
  r%boundary=saved_boundary;r%numerical=saved_numerical
  r%numerical%max_iterations=0
  call solver%solve(r,workspace,v)
  if(v%status==SW_SOLVE_CONVERGED)error stop 'invalid policy accepted'
  if(any(r%base_state%pressure_head/=heads).or.any(r%base_state%water_content/=theta))error stop 'reject mutated origin'
  r%numerical=saved_numerical
  call solver%solve(r,workspace,v)
  if(v%status/=SW_SOLVE_CONVERGED)error stop 'A after rejected B failed'
  if(any(v%candidate_state%pressure_head/=first_result%candidate_state%pressure_head).or. &
     any(v%candidate_state%water_content/=first_result%candidate_state%water_content))error stop 'rejected scratch leaked'
 end if
 end block
 print *, 'PICARD_CORNER_RESTART_REAL_PROVIDER_PASS'
end program
