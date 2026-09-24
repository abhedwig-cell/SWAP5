program test_ahl25e_attribution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_ahl25d_model3_analytical, only: model3_parameters_t, model3_analytical_provider_t, bind_model3_analytical_provider
  use mod_ahl25d_model3_lookup, only: model3_lookup_provider_t, bind_model3_lookup_provider
  implicit none
  real(real64),parameter::dt=0.25_real64,mass_gate=1.0e-12_real64
  type(soil_water_parameter_set_t),target::parameters
  type(model3_parameters_t)::p
  type(model3_analytical_provider_t),target::analytical
  type(model3_lookup_provider_t),target::candidate
  type(b110_source_sink_provider_t),target::source_sink
  type(fmr04_fixed_flux_top_provider_t),target::top_provider
  type(soil_water_physical_state_t)::initial_state
  type(soil_water_solve_request_t)::request
  type(soil_water_solve_result_t)::ref_result,cand_result
  type(reference_richards_legacy_solver_t)::solver_ref,solver_cand
  type(reference_richards_legacy_workspace_t)::ws_ref,ws_cand
  real(real64),allocatable,target::drainage(:,:),subsurface(:),root_sink(:)
  real(real64)::heads(numnod),theta(numnod),kval(numnod),cap(numnod),dkdh(numnod)
  real(real64)::h0,hbot,k0,dh,dw,dbf,mass
  character(len=512)::table_path,material,regime,mode,arg
  logical::ok,er,ek
  if(command_argument_count()/=6)error stop 'usage TABLE MATERIAL REGIME H0 HBOT MODE'
  call get_command_argument(1,table_path);call get_command_argument(2,material);call get_command_argument(3,regime)
  call get_command_argument(4,arg);read(arg,*)h0;call get_command_argument(5,arg);read(arg,*)hbot;call get_command_argument(6,mode)
  call set_material(trim(material),p);call bind_model3_analytical_provider(analytical,p)
  er=trim(mode)=='exact_ret';ek=trim(mode)=='exact_k'
  call bind_model3_lookup_provider(candidate,trim(table_path),ok,exact_retention=er,exact_k=ek)
  call require(ok,'candidate bound')
  parameters%parameter_set_id=425002_int64;parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z;parameters%dz=dz;parameters%node_distance=disnod(1:numnod)
  heads=h0;call analytical%evaluate(heads,theta,kval,cap,dkdh);k0=kval(1)
  initial_state%active_nodes=numnod;allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
  initial_state%pressure_head=heads;initial_state%water_content=theta;initial_state%ponding_depth=0;initial_state%groundwater_level=-2
  allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod));drainage=0;subsurface=0;root_sink=0
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)
  request=soil_water_solve_request_t();request%parameters=>parameters;request%base_state=initial_state;request%step_duration=dt
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;request%boundary%bottom_mode=5;request%boundary%top_flux=-k0
  request%boundary%top_head=h0;request%boundary%bottom_flux=0;request%boundary%bottom_head=hbot
  request%physical%macropore_active=.false.;request%numerical%max_iterations=8;request%numerical%max_backtracking=4
  request%numerical%conductivity_implicit_mode=0;request%numerical%conductivity_mean_method=1;request%numerical%min_step_duration=1e-6
  request%numerical%compartment_balance_tolerance=mass_gate;request%numerical%total_balance_tolerance=mass_gate
  request%numerical%head_abs_tolerance=1e-12;request%numerical%head_rel_tolerance=1e-12;request%numerical%ponding_tolerance=1e-12
  request%evaluation%source_sink=>source_sink;request%evaluation%top_boundary=>top_provider
  request%evaluation%constitutive=>analytical;call solver_ref%solve(request,ws_ref,ref_result);call require(ref_result%status==SW_SOLVE_CONVERGED,'ref')
  request%base_state=initial_state;request%evaluation%constitutive=>candidate;call solver_cand%solve(request,ws_cand,cand_result);call require(cand_result%status==SW_SOLVE_CONVERGED,'cand')
  dh=maxval(abs(cand_result%candidate_state%pressure_head-ref_result%candidate_state%pressure_head))
  dw=maxval(abs(cand_result%candidate_state%water_content-ref_result%candidate_state%water_content))
  dbf=abs(cand_result%bottom_flux-ref_result%bottom_flux)
  if(cand_result%integrated_mass_balance_residual_available)then;mass=abs(cand_result%integrated_mass_balance_residual_cm);else;mass=abs(cand_result%unrounded_mass_balance_residual);end if
  write(*,'(A,1X,A,1X,A,1X,A,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,I0,1X,A,I0)') &
   'AHL25E',trim(material),trim(regime),trim(mode),'MAX_DH=',dh,'MAX_DTHETA=',dw,'DBOTTOM=',dbf,'MASS=',mass, &
   'ITER=',cand_result%diagnostics%nonlinear_iterations,'BACKTRACK=',cand_result%diagnostics%backtracking_attempts
contains
  subroutine set_material(id,p)
    character(len=*),intent(in)::id;type(model3_parameters_t),intent(out)::p
    select case(id)
    case('M3_SEPARATED');p=model3_parameters_t(0.02_real64,0.44_real64,0.06_real64,2.2_real64,0.5454545454545454_real64,0.001_real64,1.45_real64,0.31034482758620685_real64,0.35_real64,40.0_real64,-0.5_real64)
    case('M3_DOMINANT_SECOND');p=model3_parameters_t(0.04_real64,0.50_real64,0.03_real64,1.7_real64,0.4117647058823529_real64,0.004_real64,2.4_real64,0.5833333333333333_real64,0.15_real64,10.0_real64,1.0_real64)
    case default;error stop 'unknown'
    end select
  end subroutine
  subroutine require(x,msg);logical,intent(in)::x;character(len=*),intent(in)::msg;if(.not.x)then;write(*,*)'FAIL',trim(msg);error stop 1;end if;end subroutine
end program
