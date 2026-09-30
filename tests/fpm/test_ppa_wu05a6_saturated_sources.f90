program test_ppa_wu05a6_saturated_sources
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
  use mod_ppa_wu05a6_saturated_sources, only: saturated_sources_result_t, evaluate_saturated_sources
  implicit none

  type(saturated_exchange_request_t)::interflow,matrix
  type(saturated_sources_result_t)::result

  call setup(interflow)
  matrix=interflow

  interflow%matrix_head=[20.0_real64]
  matrix%matrix_head=[2.0_real64]

  call evaluate_saturated_sources(interflow,matrix,result)
  if(.not.result%valid)error stop 'A6 R3 sources invalid'
  if(abs(result%qin_interflow_rate(1,1)-0.10_real64)>1.0e-12_real64) &
       error stop 'A6 R3 interflow rate'
  if(abs(result%qout_matrix_sat_rate(1,1)-0.08_real64)>1.0e-12_real64) &
       error stop 'A6 R3 matrix out rate'
  if(abs(result%qexc_sat_to_matrix_rate(1,1)+0.02_real64)>1.0e-12_real64) &
       error stop 'A6 R3 qexc composition'

  print '(a)', 'PPA_WU05A6_SATURATED_SOURCES=PASS'

contains

  subroutine setup(request)
    type(saturated_exchange_request_t),intent(out)::request
    request%num_domains=1
    request%num_nodes=1
    request%matrix_top_saturated_node=1
    request%matrix_bottom_saturated_node=1
    request%swsep=0
    request%matrix_level=5.0_real64
    request%step_duration=0.1_real64
    request%flow_reduction=1.0_real64
    request%shape_factor=1.0_real64
    allocate(request%bottom_domain(1),request%top_macro_saturated_node(1), &
         request%macro_saturated_fraction(1),request%macro_reference_level(1),request%z(1), &
         request%dz(1),request%matrix_head(1),request%ksat_horizontal(1),request%diameter(1), &
         request%domain_fraction(1,1),request%cdarcy(1,1))
    request%bottom_domain=1
    request%top_macro_saturated_node=1
    request%macro_saturated_fraction=1.0_real64
    request%macro_reference_level=10.0_real64
    request%z=0.0_real64
    request%dz=10.0_real64
    request%ksat_horizontal=0.1_real64
    request%diameter=4.0_real64
    request%domain_fraction=0.2_real64
    request%cdarcy=0.01_real64
  end subroutine setup

end program test_ppa_wu05a6_saturated_sources
