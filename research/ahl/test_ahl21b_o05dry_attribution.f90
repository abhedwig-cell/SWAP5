program test_ahl21b_o05dry_attribution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t,soil_water_physical_state_t,soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t,bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_ahl11_decoupled_provider, only: ahl11_decoupled_provider_t,bind_ahl11_decoupled_provider
  use mod_ahl12b_exact_retention_klookup_provider, only: ahl12b_exact_retention_klookup_provider_t,bind_ahl12b_exact_retention_klookup_provider
  implicit none
  real(real64),parameter::dt=0.25_real64,mass_gate=1e-12_real64,h0=-500.0_real64,factor=0.99_real64
  type(soil_water_parameter_set_t),target::p
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::exact
  type(ahl11_decoupled_provider_t),target::exactk
  type(ahl12b_exact_retention_klookup_provider_t),target::exactret
  type(b110_source_sink_provider_t),target::sink
  type(fmr04_fixed_flux_top_provider_t),target::top
  type(soil_water_physical_state_t)::s
  type(soil_water_solve_request_t)::req
  type(soil_water_solve_result_t)::r0,rk,rr
  type(reference_richards_legacy_solver_t)::sol0,solk,solr
  type(reference_richards_legacy_workspace_t)::w0,wk,wr
  real(real64),allocatable,target::dr(:,:),sub(:),root(:)
  real(real64),allocatable::cof(:,:)
  real(real64)::heads(numnod),th(numnod),kk(numnod),cc(numnod),dd(numnod),k0,qb
  character(len=512)::rp,kp
  logical::ok
  integer::i
  if(command_argument_count()/=2)error stop 'usage RET K'
  call get_command_argument(1,rp);call get_command_argument(2,kp)
  p%parameter_set_id=421001_int64;p%active_nodes=numnod
  allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod));p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod)
  allocate(cof(24,numnod));cof=0
  do i=1,numnod
    cof(1,i)=.01;cof(2,i)=.336701;cof(3,i)=17.418504;cof(4,i)=.030304;cof(5,i)=.0736;cof(6,i)=2.887502
    cof(7,i)=1.0_real64-1.0_real64/cof(6,i);cof(8,i)=cof(4,i);cof(9,i)=0;cof(10,i)=cof(3,i);cof(11,i)=.999
    cof(12,i)=.99*cof(3,i);cof(22,i)=-1e6;cof(23,i)=1e-12
  end do
  call initialize_b110_default_mvg_parameters(hp,cof);call bind_b110_default_mvg_provider(exact,hp,dt)
  heads=h0;call exact%evaluate(heads,th,kk,cc,dd);k0=kk(1);qb=-factor*k0
  s%active_nodes=numnod;allocate(s%pressure_head(numnod),s%water_content(numnod));s%pressure_head=heads;s%water_content=th
  s%ponding_depth=0;s%groundwater_level=-2
  allocate(dr(1,numnod),sub(numnod),root(numnod));dr=0;sub=0;root=0;call bind_b110_source_sink_provider(sink,dr,sub,root)
  req=soil_water_solve_request_t();req%parameters=>p;req%base_state=s;req%step_duration=dt
  req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;req%boundary%bottom_mode=2;req%boundary%top_flux=-k0;req%boundary%top_head=h0;req%boundary%bottom_flux=qb
  req%physical%macropore_active=.false.;req%numerical%max_iterations=8;req%numerical%max_backtracking=4
  req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1;req%numerical%min_step_duration=1e-6
  req%numerical%compartment_balance_tolerance=mass_gate;req%numerical%total_balance_tolerance=mass_gate
  req%numerical%head_abs_tolerance=1e-12;req%numerical%head_rel_tolerance=1e-12;req%numerical%ponding_tolerance=1e-12
  req%evaluation%source_sink=>sink;req%evaluation%top_boundary=>top
  req%evaluation%constitutive=>exact;call sol0%solve(req,w0,r0);call require(r0%status==SW_SOLVE_CONVERGED,'reference')
  call bind_ahl11_decoupled_provider(exactk,hp,dt,trim(rp),trim(kp),ok,exact_k=.true.);call require(ok,'exactK bind')
  req%base_state=s;req%evaluation%constitutive=>exactk;call solk%solve(req,wk,rk);call require(rk%status==SW_SOLVE_CONVERGED,'exactK solve')
  call bind_ahl12b_exact_retention_klookup_provider(exactret,hp,dt,trim(kp),ok);call require(ok,'exactRetention bind')
  req%base_state=s;req%evaluation%constitutive=>exactret;call solr%solve(req,wr,rr);call require(rr%status==SW_SOLVE_CONVERGED,'exactRetention solve')
  call report('REFERENCE',r0,r0);call report('EXACT_K',r0,rk);call report('EXACT_RETENTION',r0,rr)
contains
  subroutine report(label,ref,cand)
    character(len=*),intent(in)::label
    type(soil_water_solve_result_t),intent(in)::ref,cand
    write(*,'(A,1X,A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,ES14.6,1X,A,ES14.6)') 'AHL21B',trim(label), &
      'REF_ITER=',ref%diagnostics%nonlinear_iterations,'CAND_ITER=',cand%diagnostics%nonlinear_iterations, &
      'REF_BACKTRACK=',ref%diagnostics%backtracking_attempts,'CAND_BACKTRACK=',cand%diagnostics%backtracking_attempts, &
      'MAX_DH=',maxval(abs(cand%candidate_state%pressure_head-ref%candidate_state%pressure_head)), &
      'BOTTOM_DH=',abs(cand%candidate_state%pressure_head(numnod)-ref%candidate_state%pressure_head(numnod))
  end subroutine
  subroutine require(x,m)
    logical,intent(in)::x;character(len=*),intent(in)::m
    if(.not.x)then;write(*,*)'AHL21B_FAIL ',trim(m);error stop 1;end if
  end subroutine
end program
