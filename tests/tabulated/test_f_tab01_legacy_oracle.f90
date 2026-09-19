program f_tab01_legacy_oracle_characterization
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use swap_array_dimensions, only: MACP, MATAB, MATABENTRIES
  use doTSPACK, only: IER
  implicit none

  integer, parameter :: n_cases = 5
  integer, parameter :: n_query = 4000
  integer :: sizes(n_cases)
  integer :: icase, n, failures
  real(real64), parameter :: THETA_R = 0.05_real64
  real(real64), parameter :: THETA_S = 0.43_real64
  real(real64), parameter :: KSAT    = 50.0_real64
  real(real64), parameter :: ALPHA   = 0.02_real64
  real(real64), parameter :: NPAR    = 1.6_real64
  real(real64), parameter :: MPAR    = 1.0_real64 - 1.0_real64/NPAR
  real(real64), parameter :: LAMBDA  = 0.5_real64
  real(real64), parameter :: H_CRIT  = -1.0e-2_real64

  real(real64), allocatable :: sptab(:,:,:)
  integer, allocatable :: ientrytab(:,:)

  sizes = [25, 50, 100, 200, 400]
  failures = 0

  allocate(sptab(7,MACP,MATAB))
  allocate(ientrytab(MACP,0:MATABENTRIES))

  write(*,'(A)') 'F-TAB01 legacy TSPACK oracle characterization'
  write(*,'(A)') 'Source lineage: SWAP-model/SWAP c22bd832, blob 62a4df82'
  write(*,'(A)') 'Table knots uniform in transformed x=-log(1-h); K interpolated in log(K).'

  do icase = 1, n_cases
     n = sizes(icase)
     call characterize_table(n, sptab, ientrytab, failures)
  end do

  if (failures /= 0) then
     write(*,'(A,I0)') 'F_TAB01_STRUCTURAL_FAILURES=', failures
     error stop 1
  end if

  write(*,'(A)') 'F_TAB01_STRUCTURAL_STATUS=PASS'

contains

  subroutine characterize_table(n, sptab, ientrytab, failures)
    integer, intent(in) :: n
    real(real64), intent(inout) :: sptab(7,MACP,MATAB)
    integer, intent(inout) :: ientrytab(MACP,0:MATABENTRIES)
    integer, intent(inout) :: failures

    real(real64) :: xtab(MATAB), ytab(MATAB), dydx(MATAB), sigma(MATAB)
    real(real64) :: htab(MATAB)
    real(real64) :: x_min, xq, hq, theta_q, k_q, c_q, dkdh_q, dummy
    real(real64) :: theta_ref_q, k_ref_q, c_ref_q
    real(real64) :: theta_max_abs, theta_max_range_norm
    real(real64) :: k_max_log10, c_max_rel_smooth
    real(real64) :: theta_self_max_rel, k_self_max_rel
    real(real64) :: hp, hm, tp, tm, kp, km, c_fd, dk_fd, eps
    real(real64) :: denom
    integer :: i, q, j, node

    node = 1
    sptab = 0.0_real64
    ientrytab = 0
    xtab = 0.0_real64
    ytab = 0.0_real64
    dydx = 0.0_real64
    sigma = 0.0_real64
    htab = 0.0_real64

    x_min = -log(1.0_real64 - (-1.0e6_real64))

    do i = 1, n
       xtab(i) = x_min + real(i-1,real64) / real(n-1,real64) * (0.0_real64 - x_min)
       htab(i) = 1.0_real64 - exp(-xtab(i))
       if (i == n) htab(i) = 0.0_real64
       ytab(i) = theta_reference(htab(i))
       sptab(1,node,i) = xtab(i)
       sptab(2,node,i) = ytab(i)
       sptab(3,node,i) = log(k_reference(htab(i), ytab(i)))
    end do

    call PreProcTabulatedFunction(1, n, xtab, ytab, dydx, sigma)
    if (IER /= 0) then
       write(*,'(A,I0,A,I0)') 'F_TAB01_PREPROC_THETA_ERROR n=',n,' IER=',IER
       failures = failures + 1
       return
    end if
    do i = 1, n
       sptab(4,node,i) = dydx(i)
       sptab(6,node,i) = sigma(i)
    end do

    ytab = 0.0_real64
    dydx = 0.0_real64
    sigma = 0.0_real64
    do i = 1, n
       ytab(i) = sptab(3,node,i)
    end do
    call PreProcTabulatedFunction(2, n, xtab, ytab, dydx, sigma)
    if (IER /= 0) then
       write(*,'(A,I0,A,I0)') 'F_TAB01_PREPROC_K_ERROR n=',n,' IER=',IER
       failures = failures + 1
       return
    end if
    do i = 1, n
       sptab(5,node,i) = dydx(i)
       sptab(7,node,i) = sigma(i)
    end do

    call build_entry_index(n, htab, ientrytab(node,:))

    theta_max_abs = 0.0_real64
    theta_max_range_norm = 0.0_real64
    k_max_log10 = 0.0_real64
    c_max_rel_smooth = 0.0_real64
    theta_self_max_rel = 0.0_real64
    k_self_max_rel = 0.0_real64

    do q = 1, n_query
       xq = x_min + (real(q,real64)-0.5_real64) / real(n_query,real64) * (0.0_real64-x_min)
       hq = 1.0_real64 - exp(-xq)

       call EvalTabulatedFunction(0,n,1,2,4,node,sptab,ientrytab,hq,theta_q,dummy,1)
       call EvalTabulatedFunction(0,n,1,2,4,node,sptab,ientrytab,hq,dummy,c_q,3)
       call EvalTabulatedFunction(0,n,1,3,5,node,sptab,ientrytab,hq,k_q,dummy,2)
       call EvalTabulatedFunction(0,n,1,3,5,node,sptab,ientrytab,hq,dummy,dkdh_q,4)

       theta_ref_q = theta_reference(hq)
       k_ref_q = k_reference(hq,theta_ref_q)
       c_ref_q = capacity_reference_raw(hq)

       if (.not. ieee_is_finite(theta_q) .or. .not. ieee_is_finite(k_q) .or. &
           .not. ieee_is_finite(c_q) .or. .not. ieee_is_finite(dkdh_q)) then
          failures = failures + 1
          cycle
       end if
       if (theta_q < THETA_R-1.0e-12_real64 .or. theta_q > THETA_S+1.0e-12_real64) failures = failures + 1
       if (k_q <= 0.0_real64) failures = failures + 1

       theta_max_abs = max(theta_max_abs, abs(theta_q-theta_ref_q))
       theta_max_range_norm = max(theta_max_range_norm, abs(theta_q-theta_ref_q)/(THETA_S-THETA_R))
       k_max_log10 = max(k_max_log10, abs(log10(k_q)-log10(k_ref_q)))

       if (hq <= H_CRIT .and. c_ref_q > 1.0e-14_real64) then
          c_max_rel_smooth = max(c_max_rel_smooth, abs(c_q-c_ref_q)/c_ref_q)
       end if

       eps = max(1.0e-8_real64, abs(hq)*2.0e-6_real64)
       hp = min(hq + eps, -1.1e-9_real64)
       hm = hq - eps
       call EvalTabulatedFunction(0,n,1,2,4,node,sptab,ientrytab,hp,tp,dummy,1)
       call EvalTabulatedFunction(0,n,1,2,4,node,sptab,ientrytab,hm,tm,dummy,1)
       c_fd = (tp-tm)/(hp-hm)
       denom = max(abs(c_q),abs(c_fd),1.0e-10_real64)
       theta_self_max_rel = max(theta_self_max_rel,abs(c_q-c_fd)/denom)

       call EvalTabulatedFunction(0,n,1,3,5,node,sptab,ientrytab,hp,kp,dummy,2)
       call EvalTabulatedFunction(0,n,1,3,5,node,sptab,ientrytab,hm,km,dummy,2)
       dk_fd = (kp-km)/(hp-hm)
       denom = max(abs(dkdh_q),abs(dk_fd),1.0e-12_real64)
       k_self_max_rel = max(k_self_max_rel,abs(dkdh_q-dk_fd)/denom)
    end do

    write(*,'(A,I0,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6,A,ES14.6)') &
      'F_TAB01_METRICS n=',n, &
      ' theta_max_abs=',theta_max_abs, &
      ' theta_range_norm=',theta_max_range_norm, &
      ' K_max_log10_decades=',k_max_log10, &
      ' C_max_rel_h_le_hcrit=',c_max_rel_smooth, &
      ' theta_derivative_self_rel=',theta_self_max_rel, &
      ' K_derivative_self_rel=',k_self_max_rel
  end subroutine characterize_table

  subroutine build_entry_index(n, htab, index_row)
    integer, intent(in) :: n
    real(real64), intent(in) :: htab(MATAB)
    integer, intent(out) :: index_row(0:MATABENTRIES)
    integer :: i, j

    index_row = 0
    index_row(0) = n

    do i = 1, n
       if (htab(i) > -1.0e-5_real64) then
          j = 0
       else
          j = int(1000.0_real64*(log10(-htab(i))+1.0_real64)) + 4001
       end if
       if (j < 0 .or. j > MATABENTRIES) then
          write(*,'(A,I0,A,ES14.6)') 'F_TAB01_INDEX_OUT_OF_RANGE j=',j,' h=',htab(i)
          error stop 2
       end if
       index_row(j) = i
    end do

    index_row(1) = 0
    do j = MATABENTRIES-1, 1, -1
       if (index_row(j) == 0) index_row(j) = index_row(j+1)
    end do
  end subroutine build_entry_index

  pure real(real64) function theta_reference(h) result(theta)
    real(real64), intent(in) :: h
    real(real64) :: u, theta_hcrit, slope

    if (h >= 0.0_real64) then
       theta = THETA_S
    else if (h > H_CRIT) then
       u = abs(ALPHA*H_CRIT)
       theta_hcrit = THETA_R + (THETA_S-THETA_R)/(1.0_real64+u**NPAR)**MPAR
       slope = (THETA_S-theta_hcrit)/(-H_CRIT)
       theta = theta_hcrit + slope*(h-H_CRIT)
       theta = min(theta,THETA_S)
    else
       u = abs(ALPHA*h)
       theta = THETA_R + (THETA_S-THETA_R)/(1.0_real64+u**NPAR)**MPAR
    end if
  end function theta_reference

  pure real(real64) function capacity_reference_raw(h) result(c)
    real(real64), intent(in) :: h
    real(real64) :: u, theta_hcrit, slope, term1, term2

    if (h >= 0.0_real64) then
       c = 0.0_real64
    else if (h > H_CRIT) then
       u = abs(ALPHA*H_CRIT)
       theta_hcrit = THETA_R + (THETA_S-THETA_R)/(1.0_real64+u**NPAR)**MPAR
       slope = (THETA_S-theta_hcrit)/(-H_CRIT)
       c = slope
    else
       u = abs(ALPHA*h)
       term1 = u**(NPAR-1.0_real64)
       term2 = (THETA_S-THETA_R)/(1.0_real64+u**NPAR)**(MPAR+1.0_real64)
       c = NPAR*MPAR*ALPHA*term2*term1
    end if
  end function capacity_reference_raw

  pure real(real64) function k_reference(h,theta) result(k)
    real(real64), intent(in) :: h, theta
    real(real64) :: se, term1

    se = (theta-THETA_R)/(THETA_S-THETA_R)
    se = max(0.0_real64,min(1.0_real64,se))
    if (h < -1.0e14_real64) then
       k = 1.0e-10_real64
    else if (se > 1.0_real64-1.0e-6_real64) then
       k = KSAT
    else
       term1 = (1.0_real64-se**(1.0_real64/MPAR))**MPAR
       k = KSAT*se**LAMBDA*(1.0_real64-term1)**2
    end if
    k = min(k,KSAT)
  end function k_reference

end program f_tab01_legacy_oracle_characterization
