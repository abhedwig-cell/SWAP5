program test_ppa_micro05_literal_mvg
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_MvG, only: source_cofgen=>cofgen, iHWCKmodel, swsophy, sw_use_elas, &
       fl_use_tables, fl_use_kh_power, set_cofgen_pointers, calc_cofgen_extra, watcon, hconduc
  use MOD_grid, only: numnod, layer, dz
  use variables, only: ksatfit
  use mod_RWU_micro, only: get_MFLP_K, RWU_micro, UpwPot, swDoSatRel, swHydrLift, swO2ECT, swTypeTred, &
       RootRadius, Kroot, Lstem_A0, Lstem_A1, PLhalf, CampA, Tol_2, myTolX, TolConv, factor, Ntrial, iMicro
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters, evaluate_b110_default_mvg_conductivity
  use mod_root_micro_matric_flux_table, only: micro_matric_flux_table_t, &
       evaluate_micro_matric_flux_table, MICRO_TABLE_OK
  use mod_fmr_micro_mvg_table_binding, only: fmr_build_micro_mvg_tables
  use mod_root_micro_de_willigen_process, only: micro_de_willigen_parameters_t, &
       micro_de_willigen_result_t, evaluate_micro_de_willigen, MICRO_DW_OK
  implicit none
  type(b110_default_mvg_parameters_t) :: typed_hydraulics
  type(micro_matric_flux_table_t), allocatable :: typed_tables(:)
  type(micro_de_willigen_parameters_t) :: parameters
  type(micro_de_willigen_result_t) :: uptake
  real(real64) :: input(24,numnod), heads(7), source_m, source_k, typed_m, typed_k, theta
  real(real64) :: point_k, maximum_m_error, maximum_k_error
  real(real64) :: pressure(numnod), density(numnod), stress(numnod), source_flux(numnod)
  real(real64) :: source_alpha, tact, tact1, tact2
  logical :: check(3)
  integer :: node, head_index, status
  logical :: ok

  input=0.0_real64
  do node=1,numnod
    input(1,node)=0.032_real64
    input(2,node)=0.423_real64
    input(3,node)=4.75_real64+0.4_real64*real(node-1,real64)
    input(4,node)=0.0135_real64+0.001_real64*real(node-1,real64)
    input(5,node)=0.365_real64
    input(6,node)=1.455_real64
    input(7,node)=1.0_real64-1.0_real64/input(6,node)
    input(8,node)=input(4,node)
    input(10,node)=input(3,node)
    input(11,node)=0.999_real64
    input(12,node)=0.99_real64*input(3,node)
    input(22,node)=-1.0e6_real64
    input(23,node)=1.0e-12_real64
  end do
  source_cofgen(1:24,1:numnod)=input
  iHWCKmodel=1
  swsophy=0
  sw_use_elas=0
  fl_use_tables=.false.
  fl_use_kh_power=.false.
  ksatfit=[input(3,1),input(3,3)]
  call set_cofgen_pointers
  call calc_cofgen_extra(numnod)
  call initialize_b110_default_mvg_parameters(typed_hydraulics,input)
  call fmr_build_micro_mvg_tables(typed_hydraulics,typed_tables,ok,[1,1,3,3])
  if(.not.ok.or..not.allocated(typed_tables)) error stop 1
  call get_MFLP_K(1)

  heads=[-20000.0_real64,-19999.0_real64,-10000.0_real64,-100.0_real64, &
         -2.0_real64,-0.5_real64,0.0_real64]
  maximum_m_error=0.0_real64
  maximum_k_error=0.0_real64
  do node=1,numnod
    do head_index=1,size(heads)
      call get_MFLP_K(2,heads(head_index),node,source_m,source_k)
      call evaluate_micro_matric_flux_table(typed_tables(node),heads(head_index),typed_m,typed_k,status)
      if(status/=MICRO_TABLE_OK) error stop 2
      maximum_m_error=max(maximum_m_error,abs(source_m-typed_m))
      maximum_k_error=max(maximum_k_error,abs(source_k-typed_k))
      if(abs(source_m-typed_m)>2.0e-12_real64*max(1.0_real64,abs(source_m))) error stop 3
      if(abs(source_k-typed_k)>2.0e-12_real64*max(1.0_real64,abs(source_k))) error stop 4
    end do
  end do
  do node=1,numnod,2
    theta=watcon(node,-100.0_real64)
    source_k=hconduc(node,-100.0_real64,theta,10.0_real64)
    call evaluate_b110_default_mvg_conductivity(typed_hydraulics,node,-100.0_real64,point_k,ok)
    if(.not.ok.or.abs(source_k-point_k)>2.0e-12_real64*max(1.0_real64,abs(source_k))) error stop 5
  end do
  parameters%root_radius_cm=0.01_real64
  parameters%root_conductance_cm_per_day=0.001_real64
  parameters%stem_a0_per_day=0.01_real64
  parameters%stem_a1_per_cm=0.001_real64
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
  iMicro=1
  swDoSatRel=0
  swHydrLift=0
  swO2ECT=0
  swTypeTred=1
  allocate(UpwPot(numnod))
  pressure=-100.0_real64
  density=0.5_real64
  stress=1.0_real64
  call RWU_micro(1,1,numnod,dz,pressure,density,stress,.false.,0.1_real64, &
       tact,source_flux,source_alpha,tact1,tact2,check)
  call RWU_micro(2,1,numnod,dz,pressure,density,stress,.false.,0.1_real64, &
       tact,source_flux,source_alpha,tact1,tact2,check)
  if(.not.all(check)) error stop 6
  call evaluate_micro_de_willigen(parameters,pressure,dz,density,stress,numnod,0.1_real64,typed_tables,uptake)
  if(uptake%status/=MICRO_DW_OK) error stop 7
  if(any(abs(source_flux-uptake%root_extraction_sink)>2.0e-5_real64)) error stop 8
  if(sum(source_flux(1:2))<=0.0_real64.or.sum(source_flux(3:4))<=0.0_real64) error stop 9
  print '(a,2es24.16)', 'MICRO05_MAX_M_K_ABS_ERROR=',maximum_m_error,maximum_k_error
  print '(a,4es17.8)', 'MICRO05_SOURCE_NORMAL_SINK=',source_flux
  pressure=[-100.0_real64,-100.01_real64,-100.02_real64,-100.03_real64]
  call RWU_micro(1,1,numnod,dz,pressure,density,stress,.false.,0.1_real64, &
       tact,source_flux,source_alpha,tact1,tact2,check)
  call RWU_micro(2,1,numnod,dz,pressure,density,stress,.false.,0.1_real64, &
       tact,source_flux,source_alpha,tact1,tact2,check)
  if(.not.all(check)) error stop 10
  call evaluate_micro_de_willigen(parameters,pressure,dz,density,stress,numnod,0.1_real64,typed_tables,uptake)
  if(uptake%status/=MICRO_DW_OK) error stop 11
  if(any(abs(source_flux-uptake%root_extraction_sink)>2.0e-5_real64)) error stop 12
  if(sum(source_flux(1:2))<=0.0_real64.or.sum(source_flux(3:4))<=0.0_real64) error stop 13
  print '(a,4es17.8)', 'MICRO05_SOURCE_HETEROGENEOUS_HEAD_SINK=',source_flux
  print '(a)', 'MICRO05_LITERAL_MVG_HORIZON_AND_KSATFIT=PASS'
end program
