program fsi09_b110_oracle_fingerprint
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod
  use MOD_swap_base, only: swhyst, swfrost, swmacro
  use variables, only: dt, indeks, fluseksatexm
  use MOD_MvG, only: cofgen, iHWCKmodel, swsophy, sw_use_elas, fl_use_tables, fl_use_kh_power, &
       set_cofgen_pointers, calc_cofgen_extra, watcon, moiscap, hconduc
  implicit none
  real(real64) :: input(24,numnod), hs(15), dts(2)
  real(real64) :: theta, cap, kval
  integer :: i, j, k

  hs = [0.1_real64, 0.0_real64, -0.001_real64, -0.005_real64, -0.01_real64, -0.5_real64, -1.0_real64, &
        -9.9_real64, -10.0_real64, -10.5_real64, -11.0_real64, -100.0_real64, -1000.0_real64, &
        -1.0e8_real64, -1.0e15_real64]
  dts = [0.25_real64, 2.5_real64]
  input = 0.0_real64
  do i = 1, numnod
     input(1,i) = 0.03_real64 + 0.005_real64*real(i,real64)
     input(2,i) = 0.42_real64 + 0.004_real64*real(i,real64)
     input(3,i) = 5.0_real64 + 2.0_real64*real(i,real64)
     input(4,i) = 0.015_real64 + 0.004_real64*real(i,real64)
     input(5,i) = 0.35_real64 + 0.03_real64*real(i,real64)
     input(6,i) = 1.45_real64 + 0.08_real64*real(i,real64)
     input(7,i) = 1.0_real64 - 1.0_real64/input(6,i)
     input(8,i) = input(4,i)
     if (mod(i,2) == 0) then
        input(9,i) = -10.0_real64 - 2.0_real64*real(i,real64)
     else
        input(9,i) = 0.0_real64
     end if
     input(10,i) = input(3,i)
     input(11,i) = 0.999_real64
     input(12,i) = 0.99_real64*input(3,i)
     input(22,i) = -1.0e6_real64
     input(23,i) = 1.0e-12_real64
  end do

  swsophy = 0
  sw_use_elas = 0
  fl_use_tables = .false.
  fl_use_kh_power = .false.
  swhyst = 0
  swfrost = 0
  swmacro = 0
  indeks = -1
  fluseksatexm = .false.
  iHWCKmodel = 1
  cofgen = 0.0_real64
  cofgen(1:24,1:numnod) = input
  call set_cofgen_pointers()
  call calc_cofgen_extra(numnod)

  do i = 1, numnod
     do j = 25, 42
        write(*,'(A,I0,A,I0,A,Z16.16)') 'D:', i, ':', j, ':', transfer(cofgen(j,i), 0_int64)
     end do
  end do

  do k = 1, size(dts)
     dt = dts(k)
     do j = 1, size(hs)
        do i = 1, numnod
           theta = watcon(i, hs(j))
           cap = moiscap(i, hs(j))
           kval = hconduc(i, hs(j), theta, 1.0_real64)
           write(*,'(A,I0,A,I0,A,I0,A,Z16.16,A,Z16.16,A,Z16.16)') 'V:', k, ':', j, ':', i, ':', &
                transfer(theta,0_int64), ':', transfer(cap,0_int64), ':', transfer(kval,0_int64)
        end do
     end do
  end do
end program fsi09_b110_oracle_fingerprint
