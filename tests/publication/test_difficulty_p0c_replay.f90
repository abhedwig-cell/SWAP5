program test_difficulty_p0c_replay
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_soil_water_solver, only: rossfast_d3r_soil_water_solver_t, rossfast_d3r_soil_water_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_difficulty_trial_record, only: difficulty_trial_record_t, DIFF_METHOD_REFERENCE_NEWTON, &
       DIFF_METHOD_ROSSFAST_D3R, DIFF_METHOD_CLASS_ITERATIVE_NONLINEAR, DIFF_METHOD_CLASS_ALTERNATIVE_FORMULATION
  use mod_difficulty_counterfactual_replay, only: difficulty_replay_one
  implicit none
  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  type(soil_water_parameter_set_t),target::p
  type(soil_water_solve_request_t)::req
  type(reference_richards_legacy_solver_t)::rs
  type(reference_richards_legacy_workspace_t)::rw
  type(rossfast_d3r_soil_water_solver_t)::as
  type(rossfast_d3r_soil_water_workspace_t)::aw
  type(soil_water_solve_result_t)::r1,r2,a1,a2
  type(difficulty_trial_record_t)::tmpl_r,tmpl_a,rr1,rr2,aa1,aa2
  type(rossfast_d3r_material_t)::mat
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::constitutive
  type(b110_source_sink_provider_t),target::ss
  type(fixed_flux_top_boundary_provider_t),target::tb
  real(real64),target::drainage(1,n),irrigation(n),root_sink(n)
  real(real64)::cofgen(24,n),heads(n),theta(n),k(n),c(n),dk(n),source_h(n),source_t(n)
  logical::found,initialized
  integer::status

  call rossfast_d3r_material_from_id('B01',mat,found); call require(found,'material')
  call init_parameters(p,cofgen,mat)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(constitutive,hp,ROSSFAST_D3R_OUTER_HORIZON_DAY)
  heads=-101.0_real64; call constitutive%evaluate(heads,theta,k,c,dk)
  drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(ss,drainage,irrigation,root_sink)
  call init_request(req,p,constitutive,ss,tb,theta,k(1))
  source_h=req%base_state%pressure_head; source_t=req%base_state%water_content
  call as%initialize('assets/rossfast/d3r','B01',initialized,status); call require(initialized,'ross initial init')

  tmpl_r%identity%checkpoint_id='cp'; tmpl_r%identity%counterfactual_group_id='group'
  tmpl_r%identity%method_id=DIFF_METHOD_REFERENCE_NEWTON; tmpl_r%identity%method_class=DIFF_METHOD_CLASS_ITERATIVE_NONLINEAR
  tmpl_a=tmpl_r; tmpl_a%identity%method_id=DIFF_METHOD_ROSSFAST_D3R
  tmpl_a%identity%method_class=DIFF_METHOD_CLASS_ALTERNATIVE_FORMULATION

  ! Establish direct-solver authority before testing the observation seam.
  call rs%solve(req,rw,r1)
  call require(r1%status==SW_SOLVE_CONVERGED,'direct reference converged')
  call as%solve(req,aw,a1)
  call require(a1%status==SW_SOLVE_CONVERGED,'direct alternative converged')
  call as%initialize('assets/rossfast/d3r','B01',initialized,status); call require(initialized,'ross reset after direct control')

  ! A then B.
  call difficulty_replay_one(rs,rw,req,tmpl_r,rr1,r1)
  write(*,'(A,I0,1X,A)') 'DIFFICULTY_P0C_REFERENCE_AB_STATUS=',r1%status,trim(r1%diagnostics%route)
  call require(r1%status==SW_SOLVE_CONVERGED,'reference A-B converged')
  call difficulty_replay_one(as,aw,req,tmpl_a,aa1,a1)
  write(*,'(A,I0,1X,A)') 'DIFFICULTY_P0C_ALTERNATIVE_AB_STATUS=',a1%status,trim(a1%diagnostics%route)
  call require(a1%status==SW_SOLVE_CONVERGED,'alternative A-B converged')
  call require(all(req%base_state%pressure_head==source_h).and.all(req%base_state%water_content==source_t),'source immutable A-B')

  ! Reinitialize solver-owned alternative workspace/solver, then B then A.
  call as%initialize('assets/rossfast/d3r','B01',initialized,status); call require(initialized,'ross init')
  call difficulty_replay_one(as,aw,req,tmpl_a,aa2,a2)
  call require(a2%status==SW_SOLVE_CONVERGED,'alternative B-A converged')
  call difficulty_replay_one(rs,rw,req,tmpl_r,rr2,r2)
  call require(r2%status==SW_SOLVE_CONVERGED,'reference B-A converged')

  call require(all(req%base_state%pressure_head==source_h).and.all(req%base_state%water_content==source_t),'source immutable B-A')
  call require(all(rr1%pre%pressure_head==rr2%pre%pressure_head).and.all(aa1%pre%pressure_head==aa2%pre%pressure_head),'identical pretrial records')
  call require(r1%status==r2%status,'reference status deterministic')
  call require(r1%candidate_state%active_nodes==r2%candidate_state%active_nodes,'reference candidate shape deterministic')
  if (r1%candidate_state%active_nodes>0) call require(all(r1%candidate_state%pressure_head==r2%candidate_state%pressure_head),'reference order independent')
  call require(a1%status==a2%status,'alternative status deterministic')
  call require(a1%candidate_state%active_nodes==a2%candidate_state%active_nodes,'alternative candidate shape deterministic')
  if (a1%candidate_state%active_nodes>0) call require(all(a1%candidate_state%pressure_head==a2%candidate_state%pressure_head),'alternative order independent')
  call require(r1%diagnostics%nonlinear_iterations==r2%diagnostics%nonlinear_iterations,'reference diagnostics deterministic')
  call require(trim(a1%diagnostics%route)==trim(a2%diagnostics%route),'alternative route deterministic')
  call require(.not.rr1%outcome%reliably_solvable.and..not.aa1%outcome%reliably_solvable,'solver seam cannot self-admit solvability')
  write(*,'(A)') 'DIFFICULTY_P0C_SOURCE_IMMUTABILITY=PASS'
  write(*,'(A)') 'DIFFICULTY_P0C_ORDER_INDEPENDENCE=PASS'
  write(*,'(A)') 'DIFFICULTY_P0C_DETERMINISTIC_REPLAY=PASS'
contains
  subroutine init_parameters(ps,cf,m)
    type(soil_water_parameter_set_t),target,intent(out)::ps
    real(real64),intent(out)::cf(24,n); type(rossfast_d3r_material_t),intent(in)::m
    real(real64)::vgm; integer::i
    vgm=1.0_real64-1.0_real64/m%n; ps%parameter_set_id=220012; ps%active_nodes=n
    allocate(ps%z(n),ps%dz(n),ps%node_distance(n)); ps%dz=ROSSFAST_D3R_DZ_CM; ps%node_distance=ROSSFAST_D3R_DZ_CM
    do i=1,n; ps%z(i)=-(real(i,real64)-0.5_real64)*ROSSFAST_D3R_DZ_CM; end do
    cf=0.0_real64
    do i=1,n
      cf(1,i)=m%theta_r; cf(2,i)=m%theta_s; cf(3,i)=m%ksatfit_cm_per_day; cf(4,i)=m%alpha_per_cm
      cf(5,i)=m%lambda; cf(6,i)=m%n; cf(7,i)=vgm; cf(8,i)=m%alpha_per_cm
      cf(9,i)=m%h_enpr_cm; cf(10,i)=m%ksatfit_cm_per_day; cf(11,i)=0.999_real64
      cf(12,i)=0.99_real64*m%ksatfit_cm_per_day; cf(22,i)=-1.0e6_real64; cf(23,i)=1.0e-12_real64
    end do
  end subroutine
  subroutine init_request(q,ps,ch,sp,tp,th,k0)
    use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t
    type(soil_water_solve_request_t),intent(out)::q; type(soil_water_parameter_set_t),target,intent(in)::ps
    class(constitutive_hydraulics_provider_t),target,intent(in)::ch
    class(source_sink_provider_t),target,intent(in)::sp
    type(fixed_flux_top_boundary_provider_t),target,intent(inout)::tp
    real(real64),intent(in)::th(n),k0
    q%parameters=>ps; q%evaluation%constitutive=>ch; q%evaluation%source_sink=>sp; q%evaluation%top_boundary=>tp
    q%base_state%active_nodes=n; allocate(q%base_state%pressure_head(n),q%base_state%water_content(n))
    q%base_state%pressure_head=-101.0_real64; q%base_state%water_content=th; q%base_state%ponding_depth=0.0_real64
    q%base_state%groundwater_level=-999.0_real64
    q%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; q%boundary%top_flux=0.01_real64*k0; q%boundary%top_head=-101.0_real64
    q%boundary%bottom_mode=2; q%boundary%bottom_flux=-0.004_real64*k0; q%boundary%bottom_head=-999999.0_real64
    q%step_duration=ROSSFAST_D3R_OUTER_HORIZON_DAY
    q%numerical%max_iterations=16; q%numerical%max_backtracking=8; q%numerical%conductivity_implicit_mode=0
    q%numerical%conductivity_mean_method=1; q%numerical%min_step_duration=1e-8_real64
    q%numerical%head_abs_tolerance=1e-12_real64; q%numerical%head_rel_tolerance=1e-12_real64
    q%numerical%compartment_balance_tolerance=1e-12_real64; q%numerical%total_balance_tolerance=1e-12_real64
    q%numerical%ponding_tolerance=1e-12_real64; q%request_interface_sensitivity=.false.
    tp%prescribed_flux=0.0_real64; tp%surface_conductivity=max(k0,tiny(1.0_real64))
  end subroutine
  subroutine require(x,label)
    logical,intent(in)::x; character(len=*),intent(in)::label
    if(.not.x) then; write(*,'(A,1X,A)') 'DIFFICULTY_P0C_FAIL',trim(label); error stop 1; end if
  end subroutine
end program test_difficulty_p0c_replay
