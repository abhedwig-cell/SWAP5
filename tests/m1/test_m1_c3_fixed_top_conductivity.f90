program test_m1c3_fixed_top
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters, &
       evaluate_b110_default_mvg_conductivity
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE
  implicit none
  type(soil_water_parameter_set_t) :: g
  type(b110_default_mvg_parameters_t) :: hp
  type(b110_dynamic_top_boundary_request_t) :: r
  type(b110_dynamic_top_boundary_result_t) :: a,b,c,d
  real(real64) :: cof(24,1), kfixed, ka, kb, kc, kd
  logical :: ok
  real(real64), parameter :: tol=1.0e-12_real64

  g%parameter_set_id=1_int64; g%active_nodes=1
  allocate(g%z(1),g%dz(1),g%node_distance(1))
  g%z=-1.0_real64; g%dz=2.0_real64; g%node_distance=1.0_real64
  cof=0.0_real64
  cof(1,1)=0.032_real64; cof(2,1)=0.423_real64; cof(3,1)=4.75_real64
  cof(4,1)=0.0135_real64; cof(5,1)=0.365_real64; cof(6,1)=1.455_real64
  cof(7,1)=1.0_real64-1.0_real64/cof(6,1); cof(8,1)=cof(4,1)
  cof(9,1)=0.0_real64; cof(10,1)=cof(3,1); cof(11,1)=0.999_real64; cof(12,1)=0.99_real64*cof(3,1)
  call initialize_b110_default_mvg_parameters(hp,cof)
  call evaluate_b110_default_mvg_conductivity(hp,1,-75.0_real64,kfixed,ok)
  call require(ok,1)

  r%conductivity_mean_method=1
  r%water_content_top=0.2_real64
  r%candidate_ponding_depth_cm=0.0_real64; r%previous_ponding_depth_cm=0.0_real64
  r%step_duration_day=0.04_real64
  r%precipitation_rate_cm_per_day=20.0_real64
  r%irrigation_rate_cm_per_day=0.0_real64; r%snowmelt_rate_cm_per_day=0.0_real64; r%runon_rate_cm_per_day=0.0_real64
  r%potential_bare_soil_evaporation_cm_per_day=0.0_real64; r%potential_pond_evaporation_cm_per_day=0.0_real64
  r%ponding_max_cm=1.0_real64; r%runoff_resistance_day=0.1_real64; r%runoff_exponent=1.0_real64

  r%pressure_head_top_cm=-75.0_real64
  call evaluate_b110_dynamic_top_boundary(g,hp,r,a)
  call require(a%status==B110_DYN_TOP_AVAILABLE,2)
  r%pressure_head_top_cm=-25.0_real64
  call evaluate_b110_dynamic_top_boundary(g,hp,r,b)
  call require(b%status==B110_DYN_TOP_AVAILABLE,3)
  ka = -a%evaporation_capacity_cm_per_day / ((-2.75e5_real64-(-75.0_real64))/g%node_distance(1)+1.0_real64)
  kb = -b%evaporation_capacity_cm_per_day / ((-2.75e5_real64-(-25.0_real64))/g%node_distance(1)+1.0_real64)
  call require(abs(ka-kb)>tol,4)

  r%fixed_top_node_conductivity_cm_per_day=kfixed
  r%pressure_head_top_cm=-75.0_real64
  call evaluate_b110_dynamic_top_boundary(g,hp,r,c)
  call require(c%status==B110_DYN_TOP_AVAILABLE,5)
  r%pressure_head_top_cm=-25.0_real64
  call evaluate_b110_dynamic_top_boundary(g,hp,r,d)
  call require(d%status==B110_DYN_TOP_AVAILABLE,6)
  kc = -c%evaporation_capacity_cm_per_day / ((-2.75e5_real64-(-75.0_real64))/g%node_distance(1)+1.0_real64)
  kd = -d%evaporation_capacity_cm_per_day / ((-2.75e5_real64-(-25.0_real64))/g%node_distance(1)+1.0_real64)
  call require(abs(kc-kd)<tol,7)
  call require(abs(kc-ka)<tol,8)
  print '(A)','M1_C3_FIXED_TOP_DEFAULT_DYNAMIC=PASS'
  print '(A)','M1_C3_FIXED_TOP_OVERRIDE_STABLE=PASS'
  print '(A)','M1_C3_FIXED_TOP_ORIGIN_IDENTITY=PASS'
contains
  subroutine require(x,n)
    logical,intent(in)::x; integer,intent(in)::n
    if(.not.x) then; write(*,'(A,I0)') 'M1_C3_FIXED_TOP_FAIL=',n; error stop 1; end if
  end subroutine
end program
