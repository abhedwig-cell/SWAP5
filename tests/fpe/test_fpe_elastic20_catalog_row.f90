program test_fpe_elastic20_catalog_row
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t
  use mod_fmr_elastic_storage_horizon_descriptor_builder, only: &
       fmr_elastic_storage_retention_t, fmr_build_elastic_storage_horizon_descriptor, &
       FMR_ELAS_DESCRIPTOR_OK
  implicit none

  type(fmr_elastic_storage_retention_t) :: retention
  type(fmr_elastic_storage_horizon_t) :: horizon
  real(real64) :: top_depth, bottom_depth, density, om_pct, expected_theta
  integer :: om_available_i, peat_present_i, expected_regime, status
  integer(int64) :: actual_bits, expected_bits

  call read_real(1,top_depth)
  call read_real(2,bottom_depth)
  call read_real(3,density)
  call read_int(4,om_available_i)
  call read_real(5,om_pct)
  call read_int(6,peat_present_i)
  call read_real(7,retention%wcr)
  call read_real(8,retention%wcs)
  call read_real(9,retention%alpha_cm_inv)
  call read_real(10,retention%npar)
  call read_real(11,expected_theta)
  call read_int(12,expected_regime)

  call fmr_build_elastic_storage_horizon_descriptor(top_depth,bottom_depth,density, &
       om_available_i /= 0,om_pct,peat_present_i /= 0,retention,horizon,status)

  if (status /= FMR_ELAS_DESCRIPTOR_OK) then
    write(*,'(A,I0)') 'F_PE_ELASTIC20_ROW_FAIL_STATUS=',status
    error stop 1
  end if

  actual_bits=transfer(horizon%theta_ref_cm3_cm3,actual_bits)
  expected_bits=transfer(expected_theta,expected_bits)
  if (actual_bits /= expected_bits) then
    write(*,'(A,Z16.16,1X,Z16.16)') 'F_PE_ELASTIC20_ROW_FAIL_THETA_BITS=',actual_bits,expected_bits
    error stop 1
  end if
  if (horizon%regime /= expected_regime) then
    write(*,'(A,I0,1X,I0)') 'F_PE_ELASTIC20_ROW_FAIL_REGIME=',horizon%regime,expected_regime
    error stop 1
  end if
  if (transfer(horizon%top_depth_m,actual_bits) /= transfer(top_depth,expected_bits)) error stop 'top identity'
  if (transfer(horizon%bottom_depth_m,actual_bits) /= transfer(bottom_depth,expected_bits)) error stop 'bottom identity'
  if (transfer(horizon%rho_dry_g_cm3,actual_bits) /= transfer(density,expected_bits)) error stop 'density identity'

  write(*,'(A)') 'F_PE_ELASTIC20_ROW=PASS'

contains

  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=128)::s
    call get_command_argument(i,s)
    read(s,*)x
  end subroutine read_real

  subroutine read_int(i,x)
    integer,intent(in)::i
    integer,intent(out)::x
    character(len=128)::s
    call get_command_argument(i,s)
    read(s,*)x
  end subroutine read_int

end program test_fpe_elastic20_catalog_row
