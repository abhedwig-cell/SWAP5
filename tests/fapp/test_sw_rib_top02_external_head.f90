program test_sw_rib_top02_external_head
  use, intrinsic :: iso_fortran_env, only:int64,real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only:b110_default_mvg_parameters_t,initialize_b110_default_mvg_parameters
  use mod_b110_dynamic_top_boundary_provider
  implicit none
  integer,parameter::N=2
  type(soil_water_parameter_set_t)::g
  type(b110_default_mvg_parameters_t)::hp
  type(b110_dynamic_top_boundary_request_t)::base,r
  type(b110_dynamic_top_boundary_result_t)::a,b
  real(real64)::c(24,N)
  call init
  call make(base)
  call evaluate_b110_dynamic_top_boundary(g,hp,base,a)
  r=base;r%external_surface_water_head_supplied=.false.;r%external_surface_water_head_cm=99.;r%external_flooding_sill_head_cm=98.
  call evaluate_b110_dynamic_top_boundary(g,hp,r,b)
  call req(same(a,b),'supplied false preservation')

  r=base;r%external_surface_water_head_supplied=.true.;r%external_flooding_sill_head_cm=0.20_real64
  r%external_surface_water_head_cm=0.20_real64
  call evaluate_b110_dynamic_top_boundary(g,hp,r,b)
  call req(trim(b%route)==trim(a%route),'equality sill inactive')

  r%external_surface_water_head_cm=0.50_real64
  call evaluate_b110_dynamic_top_boundary(g,hp,r,b)
  call req(b%status==B110_DYN_TOP_AVAILABLE,'flood available')
  call req(trim(b%route)=='external-surface-water-head','flood route')
  call req(abs(b%surface_head_cm-0.50_real64)<1e-14_real64,'external head exact')
  call req(abs(b%candidate_ponding_depth_cm-0.50_real64)<1e-14_real64,'external pond exact')
  call req(b%runoff_depth_cm==0.0_real64,'no simultaneous runoff')
  call req(b%actual_top_flux_cm_per_day<0.0_real64,'fixture infiltrates')
  write(*,'(A)')'SW_RIB_TOP02_EXTERNAL_HEAD=PASS'
contains
  subroutine init
    integer::i
    g%parameter_set_id=1_int64;g%active_nodes=N
    allocate(g%z(N),g%dz(N),g%node_distance(N));g%z=[-5._real64,-15._real64];g%dz=10.;g%node_distance=10.
    c=0.
    do i=1,N
      c(1,i)=0.05;c(2,i)=0.45;c(3,i)=10.;c(4,i)=0.02;c(5,i)=0.5;c(6,i)=1.6
      c(7,i)=0.375;c(8,i)=0.02;c(10,i)=10.;c(11,i)=0.999;c(12,i)=9.9;c(22,i)=-1e6;c(23,i)=1e-12
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
  end subroutine
  subroutine make(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t();x%conductivity_mean_method=1;x%pressure_head_top_cm=-10.
    x%water_content_top=.25;x%step_duration_day=.1;x%ponding_max_cm=.1;x%runoff_resistance_day=.01;x%runoff_exponent=1.
  end subroutine
  pure logical function same(x,y)
    type(b110_dynamic_top_boundary_result_t),intent(in)::x,y
    same=x%status==y%status.and.x%regime==y%regime.and.x%route==y%route.and. &
      x%actual_top_flux_cm_per_day==y%actual_top_flux_cm_per_day.and.x%surface_head_cm==y%surface_head_cm.and. &
      x%candidate_ponding_depth_cm==y%candidate_ponding_depth_cm.and.x%runoff_depth_cm==y%runoff_depth_cm
  end function
  subroutine req(x,m)
    logical,intent(in)::x
    character(*),intent(in)::m
    if(.not.x)then
      write(*,'(A,1X,A)')'SW_RIB_TOP02_FAIL',trim(m)
      error stop 1
    end if
  end subroutine
end program
