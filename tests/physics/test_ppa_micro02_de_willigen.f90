program test_ppa_micro02_de_willigen
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_root_micro_matric_flux_table
  use mod_root_micro_de_willigen_process
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_fmr_micro_mvg_table_binding
  implicit none
  type(micro_matric_flux_table_t) :: synthetic(2)
  type(micro_matric_flux_table_t), allocatable :: real_tables(:)
  type(micro_de_willigen_parameters_t) :: parameters
  type(micro_de_willigen_result_t) :: result, repeat_result
  type(b110_default_mvg_parameters_t) :: hydraulics
  real(real64) :: samples(MICRO_TABLE_POINTS), cofgen(24,2), m, k
  real(real64) :: head(2), thickness(2), density(2), stress(2)
  logical :: ok
  integer :: i, status

  samples=0.01_real64
  do i=1,2
    call build_micro_matric_flux_table(samples,0.01_real64,0.01_real64,synthetic(i),status)
    if(status/=MICRO_TABLE_OK) error stop 1
  end do
  parameters%root_radius_cm=0.01_real64
  parameters%root_conductance_cm_per_day=0.001_real64
  parameters%stem_a0_per_day=0.01_real64
  parameters%stem_a1_per_cm=0.001_real64
  parameters%half_leaf_pressure_cm=10000.0_real64
  parameters%campbell_exponent=2.0_real64
  head=[-100.0_real64,-200.0_real64]
  thickness=10.0_real64
  density=0.5_real64
  stress=1.0_real64
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,2,0.1_real64,synthetic,result)
  if(result%status/=MICRO_DW_OK) error stop 2
  if(any(result%root_extraction_sink<0.0_real64)) error stop 3
  if(abs(result%actual_uptake_total-sum(result%root_extraction_sink))>1.0e-12_real64) error stop 4
  if(result%actual_uptake_total>0.1_real64+1.0e-12_real64) error stop 5
  if(result%actual_uptake_total<=0.0_real64) error stop 6
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,2,0.1_real64,synthetic,repeat_result)
  if(repeat_result%status/=MICRO_DW_OK) error stop 7
  if(any(result%root_extraction_sink/=repeat_result%root_extraction_sink)) error stop 8
  print '(A,3ES22.13)', 'SYNTHETIC ',result%actual_uptake_total,result%root_pressure_cm,result%leaf_pressure_cm

  stress(2)=0.0_real64
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,2,0.1_real64,synthetic,result)
  if(result%status/=MICRO_DW_OK.or.result%root_extraction_sink(2)/=0.0_real64) error stop 9
  parameters%oxygen_mode=1
  stress=[0.75_real64,0.5_real64]
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,2,0.1_real64,synthetic,result)
  if(result%status/=MICRO_DW_OK) error stop 10
  parameters%oxygen_mode=2
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,2,0.1_real64,synthetic,result)
  if(result%status/=MICRO_DW_OK) error stop 11
  parameters%oxygen_mode=0
  parameters%reduction_mode=2
  stress=1.0_real64
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,2,0.1_real64,synthetic,result)
  if(result%status/=MICRO_DW_OK) error stop 12
  parameters%reduction_mode=1
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,0,0.1_real64,synthetic,result)
  if(result%status/=MICRO_DW_OK.or.result%actual_uptake_total/=0.0_real64) error stop 13
  parameters%root_radius_cm=-1.0_real64
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,2,0.1_real64,synthetic,result)
  if(result%status/=MICRO_DW_INVALID.or.allocated(result%root_extraction_sink)) error stop 14

  cofgen=0.0_real64
  do i=1,2
    cofgen(1,i)=0.032_real64
    cofgen(2,i)=0.423_real64
    cofgen(3,i)=4.75_real64
    cofgen(4,i)=0.0135_real64
    cofgen(5,i)=0.365_real64
    cofgen(6,i)=1.455_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
    cofgen(8,i)=cofgen(4,i)
    cofgen(10,i)=cofgen(3,i)
    cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.0e6_real64
    cofgen(23,i)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hydraulics,cofgen)
  call fmr_build_micro_mvg_tables(hydraulics,real_tables,ok)
  if(.not.ok.or..not.allocated(real_tables)) error stop 15
  if(size(real_tables)/=2) error stop 16
  call evaluate_micro_matric_flux_table(real_tables(1),-100.0_real64,m,k,status)
  if(status/=MICRO_TABLE_OK.or.m<=0.0_real64.or.k<=0.0_real64) error stop 17
  parameters%root_radius_cm=0.01_real64
  call evaluate_micro_de_willigen(parameters,head,thickness,density,stress,2,0.1_real64,real_tables,result)
  if(result%status/=MICRO_DW_OK) error stop 18
  print '(A,3ES22.13)', 'REAL_MVG ',result%actual_uptake_total,result%root_pressure_cm,k
  print '(A)', 'MICRO02_STANDALONE_SMOKE_PASS'
end program
