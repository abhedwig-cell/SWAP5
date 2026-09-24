program test_ahl26i_pdi_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t,soil_water_physical_state_t,soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t,bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_ahl26f_pdi_analytical, only: pdi_params_t,pdi_analytical_provider_t,bind_pdi_analytical_provider
  use mod_ahl26f_pdi_lookup, only: pdi_lookup_provider_t,bind_pdi_lookup_provider
  implicit none
  integer,parameter::NREPLAY=16384,NT=7
  real(real64),parameter::mass_gate=1e-12_real64
  real(real64)::dt
  type(soil_water_parameter_set_t),target::parameters
  type(pdi_params_t)::p
  type(pdi_analytical_provider_t),target::analytical
  type(pdi_lookup_provider_t),target::candidate
  type(b110_source_sink_provider_t),target::source_sink
  type(fmr04_fixed_flux_top_provider_t),target::top_provider
  type(soil_water_physical_state_t)::initial_state
  type(soil_water_solve_request_t)::request
  type(soil_water_solve_result_t)::ref_result,cand_result
  type(reference_richards_legacy_solver_t)::solver_ref,solver_cand
  type(reference_richards_legacy_workspace_t)::ws_ref,ws_cand
  real(real64),allocatable,target::drainage(:,:),subsurface(:),root_sink(:)
  real(real64)::heads(numnod),theta(numnod),kval(numnod),cap(numnod),dkdh(numnod)
  real(real64)::h0,hbot,k0,rt(NT),ct(NT),rat(NT),a,b
  character(len=512)::path,material,regime,arg
  logical::ok
  integer::q,r
  if(command_argument_count()/=6)error stop 'usage TABLE MATERIAL REGIME H0 HBOT DT'
  call get_command_argument(1,path);call get_command_argument(2,material);call get_command_argument(3,regime)
  call get_command_argument(4,arg);read(arg,*)h0;call get_command_argument(5,arg);read(arg,*)hbot;call get_command_argument(6,arg);read(arg,*)dt
  call set_material(trim(material),p);call bind_pdi_analytical_provider(analytical,p);call bind_pdi_lookup_provider(candidate,trim(path),ok);call req(ok,'bind')
  parameters%parameter_set_id=426030_int64;parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod));parameters%z=z;parameters%dz=dz;parameters%node_distance=disnod(1:numnod)
  heads=h0;call analytical%evaluate(heads,theta,kval,cap,dkdh);k0=kval(1)
  initial_state%active_nodes=numnod;allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
  initial_state%pressure_head=heads;initial_state%water_content=theta;initial_state%ponding_depth=0;initial_state%groundwater_level=-2
  allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod));drainage=0;subsurface=0;root_sink=0
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)
  call build_request(request)
  request%evaluation%constitutive=>analytical;call solver_ref%solve(request,ws_ref,ref_result);call req(ref_result%status==SW_SOLVE_CONVERGED,'ref')
  request%base_state=initial_state;request%evaluation%constitutive=>candidate;call solver_cand%solve(request,ws_cand,cand_result);call req(cand_result%status==SW_SOLVE_CONVERGED,'cand')
  call req(maxval(abs(cand_result%candidate_state%pressure_head-ref_result%candidate_state%pressure_head))<=0.05_real64,'head')
  call req(abs(cand_result%bottom_flux-ref_result%bottom_flux)<=1e-5_real64,'bottom')
  call req(cand_result%diagnostics%nonlinear_iterations==ref_result%diagnostics%nonlinear_iterations,'iter')
  call req(cand_result%diagnostics%backtracking_attempts==ref_result%diagnostics%backtracking_attempts,'backtrack')
  do r=1,NT
    if(mod(r,2)==1)then
      call cpu_time(a);do q=1,NREPLAY;request%base_state=initial_state;request%evaluation%constitutive=>analytical;call solver_ref%solve(request,ws_ref,ref_result);end do;call cpu_time(b);rt(r)=(b-a)/NREPLAY
      call cpu_time(a);do q=1,NREPLAY;request%base_state=initial_state;request%evaluation%constitutive=>candidate;call solver_cand%solve(request,ws_cand,cand_result);end do;call cpu_time(b);ct(r)=(b-a)/NREPLAY
    else
      call cpu_time(a);do q=1,NREPLAY;request%base_state=initial_state;request%evaluation%constitutive=>candidate;call solver_cand%solve(request,ws_cand,cand_result);end do;call cpu_time(b);ct(r)=(b-a)/NREPLAY
      call cpu_time(a);do q=1,NREPLAY;request%base_state=initial_state;request%evaluation%constitutive=>analytical;call solver_ref%solve(request,ws_ref,ref_result);end do;call cpu_time(b);rt(r)=(b-a)/NREPLAY
    end if
    rat(r)=ct(r)/rt(r);write(*,'(A,1X,A,1X,A,1X,I0,1X,F10.6)')'AHL26I_PAIR',trim(material),trim(regime),r,rat(r)
  end do
  call sort7(rat);write(*,'(A,1X,A,1X,A,1X,F10.6)')'AHL26I_MEDIAN_RATIO',trim(material),trim(regime),rat(4)
  write(*,'(A,1X,A,1X,A,1X,F10.6)')'AHL26I_REDUCTION',trim(material),trim(regime),1-rat(4)
contains
  subroutine build_request(req)
    type(soil_water_solve_request_t),intent(out)::req
    req=soil_water_solve_request_t();req%parameters=>parameters;req%base_state=initial_state;req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;req%boundary%bottom_mode=5;req%boundary%top_flux=-k0;req%boundary%top_head=h0;req%boundary%bottom_flux=0;req%boundary%bottom_head=hbot
    req%physical%macropore_active=.false.;req%numerical%max_iterations=8;req%numerical%max_backtracking=4;req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1e-6;req%numerical%compartment_balance_tolerance=mass_gate;req%numerical%total_balance_tolerance=mass_gate
    req%numerical%head_abs_tolerance=1e-12;req%numerical%head_rel_tolerance=1e-12;req%numerical%ponding_tolerance=1e-12;req%evaluation%source_sink=>source_sink;req%evaluation%top_boundary=>top_provider
  end subroutine
  subroutine set_material(id,p)
    character(len=*),intent(in)::id;type(pdi_params_t),intent(out)::p
    if(id=='PDI8_REFERENCE')then;p=pdi_params_t(8,0.05,0.45,0.02,1.6,0.375,0,0,0,1,0,1e7,1e4,-1.5,0.01,50.0,0.5)
    else;p=pdi_params_t(10,0.04,0.46,0.03,1.8,0.4444444444444444,0.003,1.6,0.375,0.6,0.4,1e7,1e4,-1.2,0.02,50.0,0.5);end if
  end subroutine
  subroutine sort7(v);real(real64),intent(inout)::v(7);real(real64)::t;integer::i,j;do i=1,6;do j=i+1,7;if(v(j)<v(i))then;t=v(i);v(i)=v(j);v(j)=t;end if;end do;end do;end subroutine
  subroutine req(x,msg);logical,intent(in)::x;character(len=*),intent(in)::msg;if(.not.x)then;write(*,*)'AHL26I_FAIL',trim(msg);error stop 1;end if;end subroutine
end program
