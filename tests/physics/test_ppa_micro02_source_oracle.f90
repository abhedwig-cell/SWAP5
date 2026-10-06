program test_ppa_micro02_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: dz
  use mod_RWU_micro, only: RWU_micro, UpwPot, swDoSatRel, swHydrLift, swO2ECT, swTypeTred, &
       RootRadius, Kroot, Lstem_A0, Lstem_A1, PLhalf, CampA, Tol_2, myTolX, TolConv, factor, Ntrial
  use mod_root_micro_matric_flux_table
  use mod_root_micro_de_willigen_process
  implicit none
  type(micro_matric_flux_table_t) :: tables(2)
  type(micro_de_willigen_parameters_t) :: parameters
  type(micro_de_willigen_result_t) :: typed
  real(real64) :: samples(MICRO_TABLE_POINTS), head(2), density(2), stress(2)
  real(real64) :: source_flux(2), alpha, tact, tact1, tact2
  logical :: check(3)
  integer :: j, status, case_no

  samples=.01_real64
  do j=1,2
    call build_micro_matric_flux_table(samples,.01_real64,.01_real64,tables(j),status)
    if(status/=MICRO_TABLE_OK) error stop 1
  end do
  allocate(UpwPot(2))
  parameters%root_radius_cm=.01_real64
  parameters%root_conductance_cm_per_day=.001_real64
  parameters%stem_a0_per_day=.01_real64
  parameters%stem_a1_per_cm=.001_real64
  parameters%half_leaf_pressure_cm=10000.0_real64
  parameters%campbell_exponent=2.0_real64
  parameters%residual_tolerance_cm_per_day=1.0e-6_real64
  RootRadius=parameters%root_radius_cm
  Kroot=parameters%root_conductance_cm_per_day
  Lstem_A0=parameters%stem_a0_per_day
  Lstem_A1=parameters%stem_a1_per_cm
  PLhalf=1.0_real64/parameters%half_leaf_pressure_cm
  CampA=parameters%campbell_exponent
  Tol_2=1.0e-6_real64
  myTolX=1.0e-7_real64
  TolConv=1.0e-4_real64
  factor=1.25_real64
  Ntrial=500
  swDoSatRel=0
  swHydrLift=0
  head=[-100.0_real64,-100.0_real64]
  density=.5_real64

  do case_no=1,4
    swO2ECT=0
    swTypeTred=1
    stress=1.0_real64
    select case(case_no)
    case(2)
      swO2ECT=1
      stress=[.75_real64,.5_real64]
    case(3)
      swO2ECT=2
      stress=[.75_real64,.5_real64]
    case(4)
      swTypeTred=2
    end select
    parameters%oxygen_mode=swO2ECT
    parameters%reduction_mode=swTypeTred
    call RWU_micro(1,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
    call RWU_micro(2,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
    print '(A,I0,A,3L2,A,5ES17.8)', 'SOURCE_DIAGNOSTIC=',case_no,' CHECK=',check, &
         ' TACT/T1/T2/U1/U2=',tact,tact1,tact2,source_flux
    if(.not.all(check)) error stop 2
    call evaluate_micro_de_willigen(parameters,head,dz,density,stress,2,.1_real64,tables,typed)
    if(typed%status/=MICRO_DW_OK) error stop 3
    if(any(abs(typed%root_extraction_sink-source_flux)>2.0e-5_real64)) then
      print *,case_no,source_flux,typed%root_extraction_sink
      error stop 4
    end if
    print '(A,I0,A,2F12.8)', 'SOURCE_CASE=',case_no,' UPTAKE=',source_flux
  end do
  ! The unchanged nonlinear source may publish a signed layer sink even when
  ! hydraulic lift is disabled. Keep this as explicit negative evidence.
  head=[-100.0_real64,-200.0_real64]
  swO2ECT=0
  swTypeTred=1
  stress=1.0_real64
  call RWU_micro(1,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
  call RWU_micro(2,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
  if(check(3).or.source_flux(2)>=0.0_real64) error stop 5
  parameters%oxygen_mode=0
  parameters%reduction_mode=1
  call evaluate_micro_de_willigen(parameters,head,dz,density,stress,2,.1_real64,tables,typed)
  if(typed%status/=MICRO_DW_OK.or.any(typed%root_extraction_sink<0.0_real64)) error stop 6
  print '(A,2F12.8,A,3L2)', 'SOURCE_NO_LIFT_SIGNED_ANOMALY=',source_flux,' CHECK=',check
  print '(A)', 'MICRO02_CORRECTED_LITERAL_COMPARISON_PASS'
end program
