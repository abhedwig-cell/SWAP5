program test_ppa_wu05e_real_water_face_closure
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_solute_water_face_flux_reconstruction, only: reconstruct_interval_water_face_flux, WATER_FACE_FLUX_OK
  implicit none

  real(real64), parameter :: dt=1.0e-3_real64, tol=1.0e-10_real64
  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(b110_source_sink_provider_t), target :: base
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  real(real64), allocatable, target :: qdra(:,:), qssdi(:), qrot(:), cofgen(:,:)
  real(real64), allocatable :: faces(:)
  real(real64) :: heads(numnod), water0(numnod), cond(numnod), cap(numnod), dkdh(numnod), closure
  integer :: i, status

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=5058_int64
  params%active_nodes=numnod
  params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)
  cofgen=0.0_real64
  do i=1,numnod
    cofgen(1,i)=0.02_real64; cofgen(2,i)=0.427494_real64; cofgen(3,i)=31.225016_real64
    cofgen(4,i)=0.021659_real64; cofgen(5,i)=0.98087_real64; cofgen(6,i)=1.734737_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
    cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64; cofgen(12,i)=0.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  heads=-100.0_real64
  call hyd%evaluate(heads,water0,cond,cap,dkdh)
  allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
  qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
  call bind_b110_source_sink_provider(base,qdra,qssdi,qrot)

  request%parameters=>params
  request%base_state%active_nodes=numnod
  allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
  request%base_state%pressure_head=heads; request%base_state%water_content=water0
  request%base_state%ponding_depth=0.0_real64; request%base_state%groundwater_level=-200.0_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=7
  request%boundary%top_flux=0.0_real64
  request%boundary%bottom_head=-100.0_real64
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=64; request%numerical%max_backtracking=24
  request%numerical%conductivity_implicit_mode=0; request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-12_real64
  request%numerical%compartment_balance_tolerance=tol; request%numerical%total_balance_tolerance=tol
  request%numerical%head_abs_tolerance=tol; request%numerical%head_rel_tolerance=tol
  request%numerical%ponding_tolerance=tol
  request%evaluation%constitutive=>hyd; request%evaluation%source_sink=>base; request%evaluation%top_boundary=>top
  request%step_duration=dt

  call solver%solve(request,workspace,result)
  if(result%status/=SW_SOLVE_CONVERGED) error stop 'real Reference Richards solve failed'
  call reconstruct_interval_water_face_flux(dz(1:numnod),water0,result%candidate_state%water_content, &
       0.0_real64*water0,-result%top_flux,-result%bottom_flux,dt,tol,faces,closure,status)
  if(status/=WATER_FACE_FLUX_OK) error stop 'real Richards water continuity closure failed'
  if(size(faces)/=numnod+1) error stop 'real Richards face count failed'
  if(abs(closure)>tol) error stop 'real Richards bottom closure residual failed'
  write(*,'(a)') 'PPA_WU05E_REAL_RICHARDS_WATER_FACE_CLOSURE=PASS'
end program test_ppa_wu05e_real_water_face_closure
