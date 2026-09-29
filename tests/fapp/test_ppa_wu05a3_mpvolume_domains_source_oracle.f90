program test_ppa_wu05a3_mpvolume_domains_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_ppa_wu05a3_mpvolume_domains
  implicit none
  real(real64)::dz(4),diam(4),dyn(4),stat(4),pp(3,4),cells(4),dcell(3,4),dtot(3),total,dynpos(4)
  integer(int32)::pot(3),bottom(3),status

  call check_minimum_pore_cutoff_and_domain_partition()
  call check_potential_bottom_floor()
  call check_negative_dynamic_candidate_clamp()
  call check_invalid_geometry()
  call check_inactive_top_input_is_ignored()
  call check_short_output_extent_is_invalid()
  print '(A)','PPA_WU05A3_MPVOLUME_DOMAINS_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_MINIMUM_PORE_WIDTH_CUTOFF=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_DEEPEST_ACTIVE_BOTTOM_AND_DOMAIN_LIMITS=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_DOMAIN_CELL_AND_TOTAL_VOLUME_SUM=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_NEGATIVE_DYNAMIC_CANDIDATE_CLAMP=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_INVALID_GEOMETRY_FAIL_CLOSED=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_INACTIVE_TOP_INPUT_IGNORED=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_SHORT_OUTPUT_EXTENT_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MPVOLUME_DOMAINS_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine invoke(n,nd,top)
    integer(int32),intent(in)::n,nd,top
    call ppa_wu05a3_mpvolume_domains(n,nd,top,pot,dz,diam,dyn,stat,pp,cells, &
        bottom,dcell,dtot,total,dynpos,status)
  end subroutine

  subroutine invoke_short_output()
    real(real64) :: short_cells(2),short_domain_cells(3,4),short_domain_total(3),short_dynamic(4)
    integer(int32) :: short_bottom(2),short_status
    call ppa_wu05a3_mpvolume_domains(3_int32,3_int32,1_int32,pot,dz,diam,dyn,stat,pp, &
        short_cells,short_bottom,short_domain_cells,short_domain_total,total,short_dynamic,short_status)
    call require(short_status==PPA_WU05A3_MPVOLUME_DOMAINS_INVALID,17)
    call require(abs(total)<1.0e-12_real64 .and. all(short_bottom==0),18)
  end subroutine

  subroutine check_minimum_pore_cutoff_and_domain_partition()
    dz=10.0_real64; diam=1.0_real64; stat=0.0_real64
    dyn=[0.01_real64,0.0_real64,0.02_real64,0.0_real64]
    pp=0.0_real64
    pp(1,1:4)=1.0_real64
    pp(2,1:4)=0.5_real64
    pp(3,1:4)=0.5_real64
    pot=[0_int32,2_int32,1_int32]
    call invoke(3_int32,3_int32,1_int32)
    call require(status==PPA_WU05A3_MPVOLUME_DOMAINS_OK,1)
    call require(abs(cells(1)-0.01_real64)<1.0e-12_real64 .and. &
        abs(cells(3)-0.02_real64)<1.0e-12_real64,2)
    call require(bottom(1)==3 .and. bottom(2)==2 .and. bottom(3)==1,3)
    call require(abs(dtot(1)-0.03_real64)<1.0e-12_real64 .and. &
        abs(dtot(2)-0.005_real64)<1.0e-12_real64 .and. &
        abs(dtot(3)-0.005_real64)<1.0e-12_real64,4)
    call require(abs(total-0.04_real64)<1.0e-12_real64,5)
  end subroutine

  subroutine check_potential_bottom_floor()
    dz=10.0_real64; diam=1.0_real64; stat=0.0_real64; dyn=0.0_real64
    dyn(1)=1.0_real64; pp=0.0_real64; pp(1,1:4)=1.0_real64
    pp(2,1:4)=0.5_real64; pp(3,1:4)=0.5_real64
    pot=[0_int32,2_int32,1_int32]
    call invoke(4_int32,3_int32,1_int32)
    call require(status==PPA_WU05A3_MPVOLUME_DOMAINS_OK,6)
    call require(bottom(1)==2 .and. bottom(2)==2 .and. bottom(3)==1,7)
    call require(abs(total-2.0_real64)<1.0e-12_real64,8)
  end subroutine

  subroutine check_negative_dynamic_candidate_clamp()
    dz=10.0_real64; diam=1.0_real64; stat=0.0_real64; dyn=0.0_real64
    dyn(1)=-0.5_real64; stat(1)=0.6_real64; dyn(2)=0.4_real64
    pp=0.0_real64; pp(1,1:4)=1.0_real64; pot=[0_int32,2_int32,0_int32]
    call invoke(2_int32,1_int32,1_int32)
    call require(status==PPA_WU05A3_MPVOLUME_DOMAINS_OK,9)
    call require(abs(cells(1)-0.1_real64)<1.0e-12_real64 .and. &
        abs(dtot(1)-0.5_real64)<1.0e-12_real64,10)
    call require(abs(dynpos(1))<1.0e-12_real64 .and. &
        abs(dynpos(2)-0.4_real64)<1.0e-12_real64,11)
  end subroutine

  subroutine check_invalid_geometry()
    dz=10.0_real64; diam=0.0_real64; stat=0.0_real64; dyn=0.1_real64
    pp=0.0_real64; pot=[0_int32,2_int32,1_int32]
    call invoke(3_int32,3_int32,1_int32)
    call require(status==PPA_WU05A3_MPVOLUME_DOMAINS_INVALID,12)
    call require(abs(total)<1.0e-12_real64 .and. all(bottom==0),13)
  end subroutine

  subroutine check_inactive_top_input_is_ignored()
    dz=10.0_real64; diam=1.0_real64; stat=0.0_real64; dyn=0.0_real64
    dz(1)=ieee_value(0.0_real64,ieee_quiet_nan)
    diam(1)=ieee_value(0.0_real64,ieee_quiet_nan)
    stat(1)=ieee_value(0.0_real64,ieee_quiet_nan)
    dyn(1)=ieee_value(0.0_real64,ieee_quiet_nan)
    pp=0.0_real64; pp(1,1:4)=1.0_real64; pot=[0_int32,2_int32,1_int32]
    ! The legacy loop computes VlMpCp above IcTopMp, but it does not read
    ! geometry or dynamic inputs there. Static volume still participates.
    call invoke(3_int32,1_int32,2_int32)
    call require(status==PPA_WU05A3_MPVOLUME_DOMAINS_OK,14)
    call require(abs(cells(1))<1.0e-12_real64 .and. &
        abs(cells(2)-stat(2))<1.0e-12_real64,15)
    call require(bottom(1)==2 .and. abs(total-cells(2))<1.0e-12_real64,16)
  end subroutine

  subroutine check_short_output_extent_is_invalid()
    dz=10.0_real64; diam=1.0_real64; stat=0.0_real64; dyn=0.1_real64
    pp=0.0_real64; pot=[0_int32,2_int32,1_int32]
    call invoke_short_output()
  end subroutine

end program test_ppa_wu05a3_mpvolume_domains_source_oracle
