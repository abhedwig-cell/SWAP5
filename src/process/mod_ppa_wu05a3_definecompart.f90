! PPA-WU05-A3 isolated source oracle for B1.11 MACROPORE/DEFINECOMPART.
! This module is not a production macropore owner or runtime route.
module mod_ppa_wu05a3_definecompart
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_DEFINECOMPART_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_DEFINECOMPART_INVALID = 1_int32
  public :: ppa_wu05a3_definecompart

contains

  subroutine ppa_wu05a3_definecompart(num_nodes, zbot, ztop, z_ah, z_ic, z_st, &
      spoint, powm, swpowm, num_extra, idnx, z_sp, status)
    integer(int32), intent(in) :: num_nodes
    real(real64), intent(inout) :: zbot(:), ztop(:)
    real(real64), intent(inout) :: z_ah, z_ic, z_st, spoint
    real(real64), intent(in) :: powm
    integer(int32), intent(in) :: swpowm
    integer(int32), intent(out) :: num_extra, idnx(:), status
    real(real64), intent(out) :: z_sp
    integer(int32) :: ic, ix, jx
    real(real64) :: zhlp, zz(4)
    logical :: flag_extra(4)
    integer(int32) :: capacity

    status = PPA_WU05A3_DEFINECOMPART_INVALID
    num_extra = 0_int32
    z_sp = 0.0_real64
    idnx = 0_int32
    capacity = min(size(zbot), size(ztop), size(idnx))
    if (num_nodes < 1 .or. num_nodes + 4 > capacity) return
    if (.not. ieee_is_finite(z_ah) .or. .not. ieee_is_finite(z_ic) .or. &
        .not. ieee_is_finite(z_st) .or. .not. ieee_is_finite(spoint) .or. &
        .not. ieee_is_finite(powm)) return
    if (powm <= 0.0_real64 .or. (swpowm /= 0 .and. swpowm /= 1)) return
    if (any(.not. ieee_is_finite(zbot(1:num_nodes))) .or. &
        any(.not. ieee_is_finite(ztop(1:num_nodes)))) return
    if (any(ztop(1:num_nodes) <= zbot(1:num_nodes))) return
    if (num_nodes > 1) then
      if (any(abs(zbot(1:num_nodes-1)-ztop(2:num_nodes)) > 1.0e-12_real64)) return
    end if

    ! B1.11 DEFINECOMPART: source-ordered breakpoint merging, grid alignment,
    ! insertion, and original-compartment identity mapping.
    num_extra = 4_int32
    flag_extra = .false.
    z_ah = min(z_ah, zbot(1))
    z_ic = min(z_ah, z_ic)
    z_st = min(z_ah, z_st)
    z_sp = z_ah - spoint * (z_ah - z_ic)

    if (abs(z_ah-z_ic) < 0.1_real64) then
      z_ic = z_ah
      z_sp = z_ah
      num_extra = 2_int32
      flag_extra(2:3) = .true.
    else if (abs(z_ah-z_sp) < 0.1_real64) then
      z_sp = z_ah
      num_extra = 3_int32
      flag_extra(2) = .true.
    else if (abs(z_ic-z_sp) < 0.1_real64) then
      z_sp = z_ic
      num_extra = 3_int32
      flag_extra(2) = .true.
    end if

    if (abs(z_st-z_ah) < 0.1_real64 .or. abs(z_st-z_sp) < 0.1_real64 .or. &
        abs(z_st-z_ic) < 0.1_real64) then
      if (abs(z_st-z_ah) < 0.1_real64) z_st = z_ah
      if (abs(z_st-z_sp) < 0.1_real64) z_st = z_sp
      if (abs(z_st-z_ic) < 0.1_real64) z_st = z_ic
      num_extra = num_extra - 1_int32
      flag_extra(4) = .true.
    end if

    zz = [z_ah, z_sp, z_ic, z_st]
    ic = 1_int32
    zhlp = min(z_ic, z_st)
    do while (ic <= num_nodes)
      if (ztop(ic)-1.0e-6_real64 <= zhlp) exit
      do ix = 1_int32, 4_int32
        if (abs(zbot(ic)-zz(ix)) < 0.1_real64) then
          select case (ix)
          case (1)
            z_ah = zbot(ic)
          case (2)
            z_sp = zbot(ic)
          case (3)
            z_ic = zbot(ic)
          case (4)
            z_st = zbot(ic)
          end select
          zz(ix) = -1.0e6_real64
          if (.not. flag_extra(ix)) num_extra = num_extra - 1_int32
        end if
      end do
      ic = ic + 1_int32
    end do

    do ix = 1_int32, 3_int32
      do jx = ix+1_int32, 4_int32
        if (zz(ix) < zz(jx)) then
          zhlp = zz(ix)
          zz(ix) = zz(jx)
          zz(jx) = zhlp
        else if (abs(zz(ix)-zz(jx)) < 0.1_real64) then
          zz(jx) = -1.0e6_real64
        end if
      end do
    end do

    ic = num_nodes
    do ix = num_extra, 1_int32, -1_int32
      do while (ic >= 1)
        if (ztop(ic) >= zz(ix)) exit
        zbot(ic+ix) = zbot(ic)
        ztop(ic+ix) = ztop(ic)
        idnx(ic+ix) = ic
        ic = ic - 1_int32
      end do
      if (ic < 1) return
      zbot(ic+ix) = zbot(ic)
      ztop(ic+ix) = zz(ix)
      zbot(ic) = zz(ix)
      idnx(ic+ix) = ic
    end do
    do ix = 1_int32, ic
      idnx(ix) = ix
    end do

    if ((z_ah-z_ic) > 1.0_real64) then
      spoint = (z_ah-z_sp)/(z_ah-z_ic)
    else
      spoint = 1.0_real64
    end if
    status = PPA_WU05A3_DEFINECOMPART_OK
  end subroutine ppa_wu05a3_definecompart

end module mod_ppa_wu05a3_definecompart
