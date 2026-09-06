program model7_capacity_gate
  use WC_K_models_04_11, only: functionvalue_04_11, bimodal, novap
  use MOD_grid, only: layer
  implicit none
  integer :: imod(1), ip, ih, n, fails
  real(8) :: cof(21,1), h, hp, hm, dh, c, cp, cm, cfd, rel, maxrel
  real(8) :: f, logh0, logh

  layer = 1
  imod(1) = 7
  bimodal = .false.
  novap = .true.
  bimodal(1) = .true.
  n = 0
  fails = 0
  maxrel = 0.0d0

  do ip = 1, 50
     cof = 0.0d0
     cof(1,1) = 0.01d0 + 0.001d0*mod(ip,10)
     cof(2,1) = 0.35d0 + 0.005d0*mod(ip,12)
     cof(3,1) = 25.0d0
     cof(4,1) = 10.0d0**(-3.0d0 + 0.04d0*mod(ip,25))
     cof(5,1) = 0.5d0
     cof(6,1) = 1.15d0 + 0.035d0*mod(ip,20)
     cof(7,1) = 1.0d0 - 1.0d0/cof(6,1)
     cof(13,1) = 10.0d0**(-2.7d0 + 0.05d0*mod(3*ip,20))
     cof(14,1) = 1.2d0 + 0.04d0*mod(7*ip,18)
     cof(15,1) = 1.0d0 - 1.0d0/cof(14,1)
     cof(16,1) = 0.1d0 + 0.8d0*dble(mod(11*ip,47))/46.0d0
     cof(17,1) = 1.0d0 - cof(16,1)
     cof(18,1) = 10.0d0**(5.0d0 + 0.04d0*mod(13*ip,45))
     logh0 = log10(cof(18,1))

     do ih = 1, 20
        f = (dble(ih)-0.5d0)/20.0d0
        logh = 1.0d0 + f*(log10(0.8d0*cof(18,1))-1.0d0)
        h = -10.0d0**logh
        dh = max(1.0d-5, abs(h)*1.0d-6)
        hp = h + dh
        hm = h - dh
        cp = functionvalue_04_11(1,1,imod,cof,hp)
        cm = functionvalue_04_11(1,1,imod,cof,hm)
        cfd = (cp-cm)/(2.0d0*dh)
        c = functionvalue_04_11(3,1,imod,cof,h)
        rel = abs(c-cfd)/max(abs(cfd),1.0d-14)
        n = n + 1
        if (rel > 1.0d-3) fails = fails + 1
        if (rel > maxrel) maxrel = rel
     end do
  end do

  write(*,'(A,I0)') 'POINTS=', n
  write(*,'(A,I0)') 'FAIL_GT_1E-3=', fails
  write(*,'(A,ES24.16)') 'FAIL_FRACTION=', dble(fails)/dble(n)
  write(*,'(A,ES24.16)') 'MAX_REL_ERROR=', maxrel
end program model7_capacity_gate
