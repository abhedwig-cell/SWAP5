program pdi_harness
  use MOD_grid, only: layer
  use WC_K_models_04_11, only: functionvalue_04_11, BiModal, NoVap
  implicit none

  integer :: imod(1), j
  real(8) :: c(24,1), hvals(3), h, wc, k_with, k_without, kvap

  layer(1) = 1
  imod(1) = 8
  BiModal(1) = .false.
  NoVap(1) = .false.
  c = 0.0d0

  ! Representative valid PDI parameters within the SWAP 4.3.1 input ranges.
  ! The Kelvin old/corrected vapor ratio itself is independent of this choice.
  c(1,1)  = 0.05d0       ! theta_r
  c(2,1)  = 0.45d0       ! theta_s
  c(3,1)  = 50.0d0       ! Ksat [cm/d]
  c(4,1)  = 0.02d0       ! alpha [1/cm]
  c(5,1)  = 0.5d0        ! L
  c(6,1)  = 1.6d0        ! n
  c(7,1)  = 1.0d0 - 1.0d0/c(6,1)
  c(18,1) = 1.0d7        ! |h0| [cm]
  c(19,1) = 1.0d4        ! |ha| [cm]
  c(20,1) = -1.5d0       ! PDI a
  c(21,1) = 0.01d0       ! omega_K

  hvals = (/ -1.0d5, -1.0d6, -1.0d7 /)

  write(*,'(a)') 'h_cm,wc,k_total,k_no_vap,kvap'
  do j = 1, 3
    h = hvals(j)

    NoVap(1) = .false.
    wc = functionvalue_04_11(1,1,imod,c,h)
    k_with = functionvalue_04_11(2,1,imod,c,h,wc,20.0d0)

    NoVap(1) = .true.
    k_without = functionvalue_04_11(2,1,imod,c,h,wc,20.0d0)

    kvap = k_with - k_without
    write(*,'(es24.16,a,es24.16,a,es24.16,a,es24.16,a,es24.16)') &
      h, ',', wc, ',', k_with, ',', k_without, ',', kvap
  end do
end program pdi_harness
