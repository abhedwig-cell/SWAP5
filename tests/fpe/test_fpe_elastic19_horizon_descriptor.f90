program test_fpe_elastic19_horizon_descriptor
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_elastic_storage_prior_policy, only: &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT, &
       FMR_ELAS_REGIME_PEAT, FMR_ELAS_REGIME_UNKNOWN
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, fmr_elastic_storage_mapping_diagnostics_t, &
       fmr_map_elastic_storage_horizons_to_nodes, FMR_ELAS_MAP_OK
  use mod_fmr_elastic_storage_descriptor_assembly, only: &
       fmr_elastic_storage_descriptor_t, fmr_elastic_storage_assembly_diagnostics_t, &
       fmr_assemble_generated_elastic_storage, FMR_ELAS_ASSEMBLY_OK, FMR_ELAS_ASSEMBLY_PRIOR_REJECTED
  use mod_fmr_elastic_storage_horizon_descriptor_materializer, only: &
       fmr_elastic_storage_source_horizon_t, fmr_elastic_storage_horizon_materialization_diagnostics_t, &
       fmr_materialize_elastic_storage_horizon_descriptor, &
       FMR_ELAS_HORIZON_OK, FMR_ELAS_HORIZON_INVALID_GEOMETRY, &
       FMR_ELAS_HORIZON_INVALID_DESCRIPTOR, FMR_ELAS_HORIZON_INVALID_RETENTION
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  implicit none

  type(fmr_elastic_storage_source_horizon_t) :: src
  type(fmr_elastic_storage_horizon_t) :: h, horizons(2)
  type(fmr_elastic_storage_horizon_materialization_diagnostics_t) :: diag
  type(fmr_elastic_storage_mapping_diagnostics_t) :: mdiag
  type(fmr_elastic_storage_descriptor_t), allocatable :: desc(:)
  type(fmr_elastic_storage_assembly_diagnostics_t) :: adiag
  type(fmr_b110_physical_parameters_t) :: base, bound
  integer, allocatable :: owner(:)
  integer :: u, ios, year, unit_id, count
  character(len=256) :: line
  character(len=8) :: name
  real(real64) :: wcr,wcs,alpha,npar,lambda,ksfit,expected,mpar,nanv

  nanv=ieee_value(0.0_real64,ieee_quiet_nan)
  call base_source(src)

  src%organic_matter_available=.true.; src%organic_matter_pct=15.0_real64; src%peat_type_present=.false.
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(diag%status==FMR_ELAS_HORIZON_OK.and.h%regime==FMR_ELAS_REGIME_MINERAL,'A1 15 mineral')
  src%organic_matter_pct=15.0001_real64
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(h%regime==FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT,'A1 organic rich')
  src%peat_type_present=.true.
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(h%regime==FMR_ELAS_REGIME_PEAT,'A1 peat')
  src%peat_type_present=.false.; src%organic_matter_available=.false.; src%organic_matter_pct=nanv
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(h%regime==FMR_ELAS_REGIME_UNKNOWN,'A1 unknown')
  write(*,'(A)')'F_PE_ELASTIC19_A1_REGIME_BOUNDARY=PASS'

  open(newunit=u,file='tests/fpe/data/fpe_elastic05_staringreeks_2018.csv',status='old',action='read',iostat=ios)
  call req(ios==0,'A2 open CSV')
  read(u,'(A)',iostat=ios) line
  call req(ios==0,'A2 header')
  count=0
  do
    read(u,'(A)',iostat=ios) line
    if(ios<0) exit
    call req(ios==0,'A2 read')
    read(line,*,iostat=ios) year,unit_id,name,wcr,wcs,alpha,npar,lambda,ksfit
    call req(ios==0,'A2 parse')
    call base_source(src)
    src%wcr=wcr; src%wcs=wcs; src%alpha_cm_inv=alpha; src%npar=npar
    call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
    call req(diag%status==FMR_ELAS_HORIZON_OK.and.diag%theta_materialized,'A2 materialize')
    mpar=1.0_real64-1.0_real64/npar
    expected=wcr+(wcs-wcr)/(1.0_real64+(alpha*100.0_real64)**npar)**mpar
    call req(abs(h%theta_ref_cm3_cm3-expected)<=2.0e-15_real64,'A2 theta identity')
    call req(h%theta_ref_cm3_cm3>=wcr.and.h%theta_ref_cm3_cm3<=wcs,'A3 theta bounds')
    count=count+1
  end do
  close(u)
  call req(count==36,'A3 material count')
  write(*,'(A)')'F_PE_ELASTIC19_A2_REFERENCE_THETA=PASS'
  write(*,'(A)')'F_PE_ELASTIC19_A3_ALL_36=PASS'

  call base_source(src)
  src%top_depth_m=0.25_real64; src%bottom_depth_m=0.75_real64; src%rho_dry_g_cm3=1.456789012345_real64
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(transfer(h%top_depth_m,0_8)==transfer(src%top_depth_m,0_8),'A4 top bits')
  call req(transfer(h%bottom_depth_m,0_8)==transfer(src%bottom_depth_m,0_8),'A4 bottom bits')
  call req(transfer(h%rho_dry_g_cm3,0_8)==transfer(src%rho_dry_g_cm3,0_8),'A4 rho bits')
  write(*,'(A)')'F_PE_ELASTIC19_A4_SOURCE_IDENTITY=PASS'

  call base_source(src); src%bottom_depth_m=0.0_real64
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(diag%status==FMR_ELAS_HORIZON_INVALID_GEOMETRY,'A5 geometry')
  call base_source(src); src%rho_dry_g_cm3=-1.0_real64
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(diag%status==FMR_ELAS_HORIZON_INVALID_DESCRIPTOR,'A5 density')
  call base_source(src); src%organic_matter_pct=101.0_real64
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(diag%status==FMR_ELAS_HORIZON_INVALID_DESCRIPTOR,'A5 OM')
  call base_source(src); src%npar=1.0_real64
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(diag%status==FMR_ELAS_HORIZON_INVALID_RETENTION,'A5 n')
  call base_source(src); src%alpha_cm_inv=nanv
  call fmr_materialize_elastic_storage_horizon_descriptor(src,h,diag)
  call req(diag%status==FMR_ELAS_HORIZON_INVALID_RETENTION,'A5 nan')
  write(*,'(A)')'F_PE_ELASTIC19_A5_FAIL_CLOSED=PASS'

  call base_source(src)
  src%top_depth_m=0.0_real64; src%bottom_depth_m=0.5_real64; src%rho_dry_g_cm3=1.5_real64
  call fmr_materialize_elastic_storage_horizon_descriptor(src,horizons(1),diag)
  src%top_depth_m=0.5_real64; src%bottom_depth_m=1.0_real64; src%rho_dry_g_cm3=1.3_real64
  call fmr_materialize_elastic_storage_horizon_descriptor(src,horizons(2),diag)
  call fmr_map_elastic_storage_horizons_to_nodes(horizons,[0.25_real64,0.75_real64], &
       [0.5_real64,0.5_real64],desc,owner,mdiag)
  call req(mdiag%status==FMR_ELAS_MAP_OK.and.all(owner==[1,2]),'A6 map')
  call req(desc(1)%rho_dry_g_cm3==horizons(1)%rho_dry_g_cm3.and. &
       desc(2)%theta_ref_cm3_cm3==horizons(2)%theta_ref_cm3_cm3,'A6 descriptors')
  write(*,'(A)')'F_PE_ELASTIC19_A6_ELASTIC17_COMPOSITION=PASS'

  call init_base(base,2)
  call fmr_assemble_generated_elastic_storage(base,.true.,desc,bound,adiag)
  call req(adiag%status==FMR_ELAS_ASSEMBLY_OK,'A7 mineral downstream')
  horizons(2)%regime=FMR_ELAS_REGIME_PEAT
  call fmr_map_elastic_storage_horizons_to_nodes(horizons,[0.25_real64,0.75_real64], &
       [0.5_real64,0.5_real64],desc,owner,mdiag)
  call fmr_assemble_generated_elastic_storage(base,.true.,desc,bound,adiag)
  call req(adiag%status==FMR_ELAS_ASSEMBLY_PRIOR_REJECTED.and.adiag%failed_node==2,'A7 peat downstream')
  write(*,'(A)')'F_PE_ELASTIC19_A7_DOWNSTREAM_POLICY=PASS'

  write(*,'(A)')'F_PE_ELASTIC19=PASS'

contains
  subroutine base_source(s)
    type(fmr_elastic_storage_source_horizon_t),intent(out)::s
    s=fmr_elastic_storage_source_horizon_t()
    s%top_depth_m=0.0_real64
    s%bottom_depth_m=0.5_real64
    s%rho_dry_g_cm3=1.45_real64
    s%organic_matter_available=.true.
    s%organic_matter_pct=5.0_real64
    s%peat_type_present=.false.
    s%wcr=0.02_real64
    s%wcs=0.43_real64
    s%alpha_cm_inv=0.02_real64
    s%npar=1.5_real64
  end subroutine base_source

  subroutine init_base(p,n)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::n
    p%active_nodes=n
    allocate(p%cofgen(24,n))
    p%cofgen=0.0_real64
    p%cofgen(1,:)=0.05_real64
    p%cofgen(2,:)=0.45_real64
    p%elasticity_active=.false.
    p%prepared_default_mvg_available=.false.
  end subroutine init_base

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC19_FAIL',trim(msg)
      error stop 1
    endif
  end subroutine req
end program test_fpe_elastic19_horizon_descriptor
