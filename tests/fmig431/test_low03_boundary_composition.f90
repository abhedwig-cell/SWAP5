program test_low03_boundary_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use frozen_low03_oracle
  use mod_soil_water_solver_contract
  implicit none
  real(real64), parameter :: hs(5)=[-1000._real64,-100._real64,-10._real64,0._real64,10._real64]
  real(real64), parameter :: aquifers(3)=[-400._real64,-100._real64,20._real64]
  real(real64), parameter :: ks(5)=[1.e-6_real64,.01_real64,.1_real64,1._real64,100._real64]
  real(real64), parameter :: ds(3)=[.5_real64,5._real64,50._real64]
  real(real64), parameter :: rs(5)=[0._real64,.01_real64,1._real64,100._real64,10000._real64]
  real(real64), parameter :: extras(3)=[-1._real64,0._real64,1._real64]
  integer :: ih,ia,ik,id,ir,flag,ie,cases,limits,differences
  real(real64) :: h,a,k,d,r,q,j,conductance,expected,q5,z
  real(real64) :: typed_q,typed_j
  logical :: valid
  type(soil_water_boundary_conditions_t) :: boundary
  cases=0;limits=0;differences=0;z=-195._real64
  do ih=1,size(hs)
  do ia=1,size(aquifers)
  do ik=1,size(ks)
  do id=1,size(ds)
  do ir=1,size(rs)
  do flag=0,1
  do ie=1,size(extras)
    h=hs(ih);a=aquifers(ia);k=ks(ik);d=ds(id);r=rs(ir)
    if(flag==1.and.r==0._real64)cycle
    if(flag==0)then
      conductance=1._real64/(d/k+r)
    else
      conductance=1._real64/r
    end if
    q=b111_q3(h,z,a,k,d,r,flag)+extras(ie)
    j=b111_j3(h,z,a,k,d,r,flag)
    boundary%bottom_mode=3;boundary%bottom_head=a;boundary%bottom_flux=extras(ie)
    boundary%bottom_external_resistance_days=r;boundary%bottom_include_half_cell=flag==0
    call evaluate_resistive_bottom_boundary(boundary,h,z,d,k,typed_q,typed_j,valid)
    if(.not.valid)error stop 'typed boundary unexpectedly rejected'
    if(abs(typed_q-q)>64*epsilon(q)*max(1._real64,abs(q)))error stop 'typed flux versus frozen B111'
    if(abs(typed_j-j)>64*epsilon(j)*max(1._real64,abs(j)))error stop 'typed Jacobian versus frozen B111'
    expected=conductance*(a-(h+z))+extras(ie)
    if(abs(q-expected)>64*epsilon(q)*max(1._real64,abs(q),abs(expected)))error stop 'Robin source mismatch'
    if(abs(j-conductance)>64*epsilon(j)*max(1._real64,abs(j)))error stop 'Jacobian source mismatch'
    cases=cases+1
    q5=b111_q5(h,z,a,k,d)
    if(flag==0.and.r==0._real64.and.extras(ie)==0._real64)then
      if(abs(q-q5)>128*epsilon(q)*max(1._real64,abs(q),abs(q5)))error stop 'zero-R head limit mismatch'
      limits=limits+1
    end if
    if(flag==0.and.r>0._real64.and.extras(ie)==0._real64)then
      if(abs(q-q5)>1.e-10_real64*max(1._real64,abs(q),abs(q5)))differences=differences+1
    end if
  end do
  end do
  end do
  end do
  end do
  end do
  end do
  if(limits==0.or.differences==0)error stop 'missing discriminatory cases'
  print '(a,i0,a,i0,a,i0)', 'LOW03_COMPOSITION_PASS cases=',cases,' zero_R_limits=',limits,' nonzero_R_nonaliases=',differences
end program
