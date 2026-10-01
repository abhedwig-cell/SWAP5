module ppa_wu05a18_providers
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t, &
       top_boundary_provider_t, soil_water_boundary_conditions_t
  use mod_b110_default_mvg_provider, only: prepared_b110_default_mvg_provider_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: area_scaled_mvg_t
    type(prepared_b110_default_mvg_provider_t) :: base
    real(real64), allocatable :: area_fraction(:), reference_theta(:), reference_base_theta(:)
  contains
    procedure :: evaluate => area_scaled_evaluate
  end type area_scaled_mvg_t

  type, extends(source_sink_provider_t), public :: fixed_snapshot_source_sink_t
    real(real64), allocatable :: sink_rate(:)
  contains
    procedure :: evaluate => fixed_source_sink_evaluate
  end type fixed_snapshot_source_sink_t

  type, extends(top_boundary_provider_t), public :: fixed_snapshot_top_t
  contains
    procedure :: evaluate => fixed_top_evaluate
  end type fixed_snapshot_top_t

contains

  subroutine area_scaled_evaluate(self,h,theta,k,c,dkdh)
    class(area_scaled_mvg_t),intent(in)::self
    real(real64),intent(in)::h(:)
    real(real64),intent(out)::theta(:),k(:),c(:),dkdh(:)
    real(real64),allocatable::raw_theta(:),raw_k(:),raw_c(:),raw_dkdh(:)
    integer::n
    n=size(h)
    allocate(raw_theta(n),raw_k(n),raw_c(n),raw_dkdh(n))
    call self%base%evaluate(h,raw_theta,raw_k,raw_c,raw_dkdh)
    theta=self%reference_theta+self%area_fraction*(raw_theta-self%reference_base_theta)
    k=self%area_fraction*raw_k
    c=self%area_fraction*raw_c
    dkdh=self%area_fraction*raw_dkdh
  end subroutine area_scaled_evaluate

  subroutine fixed_source_sink_evaluate(self,h,theta,source,sink)
    class(fixed_snapshot_source_sink_t),intent(in)::self
    real(real64),intent(in)::h(:),theta(:)
    real(real64),intent(out)::source(:),sink(:)
    if(size(self%sink_rate)/=size(h) .or. size(theta)/=size(h))error stop 'A18 source shape'
    source=0.0_real64
    sink=self%sink_rate
  end subroutine fixed_source_sink_evaluate

  subroutine fixed_top_evaluate(self,h_top,theta_top,requested,actual_top_flux,surface_head,runoff_flux)
    class(fixed_snapshot_top_t),intent(in)::self
    real(real64),intent(in)::h_top,theta_top
    type(soil_water_boundary_conditions_t),intent(in)::requested
    real(real64),intent(out)::actual_top_flux,surface_head,runoff_flux
    actual_top_flux=requested%top_flux
    surface_head=0.0_real64
    runoff_flux=0.0_real64
    if(h_top>huge(h_top) .or. theta_top>huge(theta_top))error stop 'A18 impossible top'
    if(.not.same_type_as(self,self))error stop 'A18 impossible top type'
  end subroutine fixed_top_evaluate

end module ppa_wu05a18_providers

program test_ppa_wu05a18_andelst_baseline
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use MOD_grid, only: numnod,z,dz,disnod
  use ppa_wu05a18_snapshot
  use ppa_wu05a18_providers
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t,soil_water_solve_request_t, &
       soil_water_solve_result_t,SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,initialize_b110_default_mvg_parameters, &
       bind_b110_default_mvg_provider
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t,matrix_perched_zone_view_t, &
       derive_matrix_saturated_zone_view,derive_matrix_perched_zone_view
  implicit none

  type(soil_water_parameter_set_t),target::parameters
  type(b110_default_mvg_parameters_t),target::hp
  type(area_scaled_mvg_t),target::hyd
  type(fixed_snapshot_source_sink_t),target::sources
  type(fixed_snapshot_top_t),target::top
  type(reference_richards_legacy_solver_t)::solver
  type(reference_richards_legacy_workspace_t)::workspace
  type(soil_water_solve_request_t)::request
  type(soil_water_solve_result_t)::result
  type(matrix_saturated_zone_view_t)::matrix_view
  type(matrix_perched_zone_view_t)::perched
  real(real64)::raw_theta(n),raw_k(n),raw_c(n),raw_dkdh(n),theta_s(n)
  integer::i,ordinary_top
  real(real64)::gwl_endpoint

  call require(numnod==n,'fixture node count')

  parameters%parameter_set_id=1801_int64
  parameters%active_nodes=n
  allocate(parameters%z(n),parameters%dz(n),parameters%node_distance(n))
  parameters%z=z
  parameters%dz=dz
  parameters%node_distance=disnod(1:n)

  call initialize_b110_default_mvg_parameters(hp,snapshot_cofgen)
  call bind_b110_default_mvg_provider(hyd%base,hp,snapshot_dt)
  allocate(hyd%area_fraction(n),hyd%reference_theta(n),hyd%reference_base_theta(n))
  hyd%area_fraction=snapshot_frarmtrx
  hyd%reference_theta=snapshot_theta
  call hyd%base%evaluate(snapshot_h,hyd%reference_base_theta,raw_k,raw_c,raw_dkdh)
  call hyd%evaluate(snapshot_h,raw_theta,raw_k,raw_c,raw_dkdh)
  call require(maxval(abs(raw_theta-snapshot_theta))<2.0e-13_real64,'initial effective theta exact')

  allocate(sources%sink_rate(n))
  sources%sink_rate=snapshot_qdra+snapshot_qrot

  request%parameters=>parameters
  request%base_state%active_nodes=n
  allocate(request%base_state%pressure_head(n),request%base_state%water_content(n))
  request%base_state%pressure_head=snapshot_h
  request%base_state%water_content=snapshot_theta
  request%base_state%ponding_depth=0.0_real64
  request%base_state%groundwater_level=snapshot_gwl
  request%step_duration=snapshot_dt
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%top_flux=snapshot_qtop
  request%boundary%bottom_mode=2
  request%boundary%bottom_flux=snapshot_qbot
  request%numerical%max_iterations=30
  request%numerical%max_backtracking=4
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-5_real64
  request%numerical%compartment_balance_tolerance=1.0e-6_real64
  request%numerical%total_balance_tolerance=1.0e-5_real64
  request%numerical%head_abs_tolerance=1.0e-2_real64
  request%numerical%head_rel_tolerance=1.0e-3_real64
  request%numerical%ponding_tolerance=1.0e-4_real64
  request%physical%macropore_active=.false.
  request%evaluation%constitutive=>hyd
  request%evaluation%source_sink=>sources
  request%evaluation%top_boundary=>top

  call solver%solve(request,workspace,result)
  write(*,'(*(g0))') 'PPA_WU05A18_BASELINE|STATUS=',result%status,'|RETRY=',result%retry_advised, &
       '|IT=',result%diagnostics%nonlinear_iterations,'|MASS=',result%integrated_mass_balance_residual_cm
  call require(result%status==SW_SOLVE_CONVERGED,'source-backed baseline converged')
  call require(result%integrated_mass_balance_residual_available,'baseline mass available')
  call require(abs(result%integrated_mass_balance_residual_cm)<1.0e-7_real64,'baseline mass gate')

  ordinary_top=0
  do i=n-1,1,-1
    if(result%candidate_state%pressure_head(i)<0.0_real64 .and. &
       result%candidate_state%pressure_head(i+1)>=0.0_real64)then
      ordinary_top=i+1
      gwl_endpoint=z(i+1)+result%candidate_state%pressure_head(i+1) / &
           (result%candidate_state%pressure_head(i+1)-result%candidate_state%pressure_head(i))*disnod(i+1)
      exit
    end if
  end do
  call require(ordinary_top>0,'ordinary groundwater endpoint')
  result%candidate_state%groundwater_level=gwl_endpoint

  theta_s=snapshot_cofgen(2,:)
  call derive_matrix_saturated_zone_view(result%candidate_state,z,dz,matrix_view)
  call derive_matrix_perched_zone_view(result%candidate_state,theta_s,z,dz,matrix_view,0.1_real64,perched)

  write(*,'(*(g0))') 'PPA_WU05A18_ENDPOINT|GWL=',gwl_endpoint,'|MAIN_TOP=',ordinary_top, &
       '|PERCHED_ACTIVE=',perched%active,'|PERCHED_TOP=',perched%top_node, &
       '|PERCHED_BOTTOM=',perched%bottom_node,'|PERCHED_LEVEL=',perched%water_level_cm
  call require(perched%valid .and. perched%active,'perched endpoint retained')
  call require(perched%bottom_node<ordinary_top-1,'perched endpoint separated')
  call require(perched%top_node>=15 .and. perched%top_node<=25,'perched top source neighborhood')
  call require(perched%bottom_node>=25 .and. perched%bottom_node<=35,'perched bottom source neighborhood')

  print '(a)', 'PPA_WU05A18_SOURCE_SNAPSHOT=PASS'
  print '(a)', 'PPA_WU05A18_REFERENCE_BASELINE=PASS'
  print '(a)', 'PPA_WU05A18_PERCHED_ENDPOINT=PASS'
  print '(a)', 'PPA_WU05A18_AUTHORITY_GATE=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05A18_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu05a18_andelst_baseline
