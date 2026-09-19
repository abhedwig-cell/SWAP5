program tabulated_hydraulics_characterization
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use swap_array_dimensions, only: macp, matab, matabentries
  implicit none

  integer, parameter :: n = 241
  integer, parameter :: neval = 401
  real(8), parameter :: theta_r = 0.05d0
  real(8), parameter :: theta_s = 0.45d0
  real(8), parameter :: alpha = 0.02d0
  real(8), parameter :: nvg = 1.60d0
  real(8), parameter :: mvg = 1.0d0 - 1.0d0/nvg
  real(8), parameter :: lexp = 0.50d0
  real(8), parameter :: ksat = 50.0d0

  real(8) :: sptab(7,macp,matab)
  integer :: ientrytab(macp,0:matabentries)
  real(8) :: head_raw(matab), x(matab), theta_tab(matab), logk_tab(matab)
  real(8) :: dydx(matab), sigma(matab)
  real(8) :: frac, exponent, dummy, h, theta_ref, k_ref
  real(8) :: theta_eval, k_eval, c_eval, dkdh_eval
  real(8) :: scratch, max_theta_abs, max_log10k_abs, min_c, min_dkdh
  integer :: i, j, q

  sptab = 0.0d0
  ientrytab = 0
  head_raw = 0.0d0
  x = 0.0d0
  theta_tab = 0.0d0
  logk_tab = 0.0d0
  dydx = 0.0d0
  sigma = 0.0d0

  ! Construct a strictly monotone Mualem-van Genuchten reference table.
  ! Negative knots span 1e7 to 1e-5 cm on a logarithmic grid, followed by h=0.
  do i = 1, n-1
     frac = dble(i-1)/dble(n-2)
     exponent = 7.0d0 - 12.0d0*frac
     head_raw(i) = -10.0d0**exponent
     theta_tab(i) = vg_theta(head_raw(i))
     logk_tab(i) = dlog(vg_k(head_raw(i)))
  end do
  head_raw(n) = 0.0d0
  theta_tab(n) = theta_s
  logk_tab(n) = dlog(ksat)

  do i = 2, n
     if (head_raw(i) <= head_raw(i-1)) error stop 'reference head table is not strictly increasing'
     if (theta_tab(i) <= theta_tab(i-1)) error stop 'reference theta table is not strictly increasing'
     if (logk_tab(i) <= logk_tab(i-1)) error stop 'reference K table is not strictly increasing'
  end do

  ! Reproduce the complete current ReadSwap preprocessing, including the
  ! backward fill that follows ientrytab(1,1)=0.
  do i = 1, n
     x(i) = -dlog(-head_raw(i) + 1.0d0)
     dummy = head_raw(i)
     if (dummy > -1.0d-5) then
        j = 0
     else
        j = int(1000.0d0*(dlog10(-dummy)+1.0d0)) + 4001
     end if
     if (j < 0 .or. j > matabentries) error stop 'lookup-bin index outside allocated range'
     ientrytab(1,j) = i
     sptab(1,1,i) = x(i)
     sptab(2,1,i) = theta_tab(i)
     sptab(3,1,i) = logk_tab(i)
  end do

  ientrytab(1,1) = 0
  do j = matabentries-1, 1, -1
     if (ientrytab(1,j) == 0) ientrytab(1,j) = ientrytab(1,j+1)
  end do

  if (ientrytab(1,1) <= 0) error stop 'complete preprocessing left lookup bin 1 invalid'
  if (ientrytab(1,1) >= n) error stop 'lookup bin 1 does not bracket a negative-head interval'

  call PreProcTabulatedFunction(1, n, x, theta_tab, dydx, sigma)
  do i = 1, n
     sptab(4,1,i) = dydx(i)
     sptab(6,1,i) = sigma(i)
  end do

  call PreProcTabulatedFunction(2, n, x, logk_tab, dydx, sigma)
  do i = 1, n
     sptab(5,1,i) = dydx(i)
     sptab(7,1,i) = sigma(i)
  end do

  max_theta_abs = 0.0d0
  max_log10k_abs = 0.0d0
  min_c = huge(1.0d0)
  min_dkdh = huge(1.0d0)

  write(*,'(A)') 'h_cm,theta_ref,theta_table,k_ref,k_table,c_table,dkdh_table'
  do q = 1, neval
     frac = dble(q-1)/dble(neval-1)
     exponent = 7.0d0 - 15.9d0*frac
     h = -10.0d0**exponent

     theta_eval = -999.0d0
     scratch = 0.0d0
     call EvalTabulatedFunction(0, n, 1, 2, 4, 1, sptab, ientrytab, h, theta_eval, scratch, 1)

     k_eval = -999.0d0
     scratch = 0.0d0
     call EvalTabulatedFunction(0, n, 1, 3, 5, 1, sptab, ientrytab, h, k_eval, scratch, 2)

     c_eval = -999.0d0
     scratch = -999.0d0
     call EvalTabulatedFunction(0, n, 1, 2, 4, 1, sptab, ientrytab, h, c_eval, scratch, 3)
     c_eval = scratch

     dkdh_eval = -999.0d0
     scratch = -999.0d0
     call EvalTabulatedFunction(0, n, 1, 3, 5, 1, sptab, ientrytab, h, dkdh_eval, scratch, 4)
     dkdh_eval = scratch

     theta_ref = vg_theta(h)
     k_ref = vg_k(h)

     if (.not. ieee_is_finite(theta_eval) .or. .not. ieee_is_finite(k_eval) .or. &
         .not. ieee_is_finite(c_eval) .or. .not. ieee_is_finite(dkdh_eval)) then
        error stop 'non-finite tabulated hydraulic output'
     end if
     if (theta_eval < theta_r-1.0d-10 .or. theta_eval > theta_s+1.0d-10) &
        error stop 'theta outside physical reference bounds'
     if (k_eval <= 0.0d0 .or. k_eval > ksat*(1.0d0+1.0d-10)) &
        error stop 'K outside physical reference bounds'

     max_theta_abs = max(max_theta_abs, dabs(theta_eval-theta_ref))
     max_log10k_abs = max(max_log10k_abs, dabs(dlog10(k_eval)-dlog10(k_ref)))
     min_c = min(min_c, c_eval)
     min_dkdh = min(min_dkdh, dkdh_eval)

     write(*,'(ES24.16,",",ES24.16,",",ES24.16,",",ES24.16,",",ES24.16,",",ES24.16,",",ES24.16)') &
          h, theta_ref, theta_eval, k_ref, k_eval, c_eval, dkdh_eval
  end do

  write(*,'(A,I0)') 'SUMMARY ientry_bin_1=', ientrytab(1,1)
  write(*,'(A,ES24.16)') 'SUMMARY max_theta_abs=', max_theta_abs
  write(*,'(A,ES24.16)') 'SUMMARY max_log10K_abs=', max_log10k_abs
  write(*,'(A,ES24.16)') 'SUMMARY min_C=', min_c
  write(*,'(A,ES24.16)') 'SUMMARY min_dKdh=', min_dkdh
  write(*,'(A)') 'CHARACTERIZATION_COMPLETED'

contains

  pure real(8) function vg_theta(head) result(theta)
    real(8), intent(in) :: head
    real(8) :: se
    if (head >= 0.0d0) then
       theta = theta_s
    else
       se = (1.0d0 + (alpha*dabs(head))**nvg)**(-mvg)
       theta = theta_r + (theta_s-theta_r)*se
    end if
  end function vg_theta

  pure real(8) function vg_k(head) result(kval)
    real(8), intent(in) :: head
    real(8) :: se, bracket
    if (head >= 0.0d0) then
       kval = ksat
    else
       se = (1.0d0 + (alpha*dabs(head))**nvg)**(-mvg)
       bracket = 1.0d0 - (1.0d0-se**(1.0d0/mvg))**mvg
       kval = ksat * se**lexp * bracket**2
    end if
  end function vg_k

end program tabulated_hydraulics_characterization
