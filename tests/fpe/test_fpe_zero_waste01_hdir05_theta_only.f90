program test_fpe_zero_waste01_hdir05_theta_only
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction, &
       evaluate_b110_default_mvg_water_content_direction
  implicit none

  integer, parameter :: n=60
  real(real64), parameter :: HCRIT=-1.0e-2_real64, HDRY=-1.0e14_real64
  real(real64), parameter :: KSW=1.0_real64-1.0e-6_real64
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: provider
  real(real64) :: raw(24,n), h(n), dh(n), old_theta(n), old_k(n), new_theta(n)
  real(real64) :: heads(18), dirs(4)
  integer :: branch, ih, id, cases, mismatches, reps, r
  logical :: old_ok,new_ok
  character(len=64) :: old_route,new_route
  integer(int64) :: c0,c1,rate,checksum
  real(real64) :: sec, full_ns, theta_ns

  dirs=[0.0_real64,0.37_real64,1.0e40_real64,1.0e200_real64]
  cases=0; mismatches=0

  do branch=1,2
    call make_raw(raw,branch)
    call initialize_b110_default_mvg_parameters(hp,raw)
    call bind_b110_default_mvg_provider(provider,hp,0.2_real64)
    call make_heads(branch,heads)
    do ih=1,size(heads)
      h=heads(ih)
      do id=1,size(dirs)
        dh=dirs(id)
        call evaluate_b110_default_mvg_state_direction(provider,h,dh,old_theta,old_k,old_ok,old_route)
        call evaluate_b110_default_mvg_water_content_direction(provider,h,dh,new_theta,new_ok,new_route)
        cases=cases+1
        if (old_ok .neqv. new_ok) then
          mismatches=mismatches+1
          write(*,'(A,2I4,3(1X,ES24.16),2(1X,L1),2(1X,A))') 'HDIR05_MISMATCH',branch,ih,heads(ih),dirs(id), &
               maxval(abs(old_theta-new_theta)),old_ok,new_ok,trim(old_route),trim(new_route)
        else if (old_ok) then
          if (.not. same_bits(old_theta,new_theta)) then
            mismatches=mismatches+1
            write(*,'(A,2I4,3(1X,ES24.16))') 'HDIR05_BITS_MISMATCH',branch,ih,heads(ih),dirs(id), &
                 maxval(abs(old_theta-new_theta))
          end if
        end if
      end do
    end do
  end do

  write(*,'(A,I0,A,I0)') 'HDIR05_DIFFERENTIAL,cases=',cases,',mismatches=',mismatches
  if (mismatches /= 0) error stop 'HDIR05 theta-only prototype differs from full directional oracle'
  write(*,'(A)') 'FPE_ZERO_WASTE01_HDIR05_DIFFERENTIAL=PASS'

  call make_raw(raw,1)
  call initialize_b110_default_mvg_parameters(hp,raw)
  call bind_b110_default_mvg_provider(provider,hp,0.2_real64)
  do r=1,n
    h(r)=-135.0_real64+0.25_real64*real(r-1,real64)
    dh(r)=0.025_real64
  end do
  reps=100000
  checksum=0_int64
  call system_clock(c0,rate)
  do r=1,reps
    call evaluate_b110_default_mvg_state_direction(provider,h,dh,old_theta,old_k,old_ok,old_route)
    if (old_ok) checksum=checksum+transfer(old_theta(1),0_int64)
  end do
  call system_clock(c1)
  sec=real(c1-c0,real64)/real(rate,real64)
  full_ns=1.0e9_real64*sec/real(reps,real64)

  checksum=0_int64
  call system_clock(c0)
  do r=1,reps
    call evaluate_b110_default_mvg_water_content_direction(provider,h,dh,new_theta,new_ok,new_route)
    if (new_ok) checksum=checksum+transfer(new_theta(1),0_int64)
  end do
  call system_clock(c1)
  sec=real(c1-c0,real64)/real(rate,real64)
  theta_ns=1.0e9_real64*sec/real(reps,real64)

  write(*,'(A,ES24.16,A,ES24.16,A,ES24.16)') 'HDIR05_COST,full_ns=',full_ns,',theta_only_ns=',theta_ns, &
       ',ratio=',theta_ns/full_ns
  write(*,'(A)') 'FPE_ZERO_WASTE01_HDIR05_PROTOTYPE=PASS'

contains

  subroutine make_raw(c,branch)
    real(real64),intent(out)::c(:,:)
    integer,intent(in)::branch
    integer::i
    c=0.0_real64
    do i=1,size(c,2)
      c(1,i)=0.032_real64; c(2,i)=0.423_real64; c(3,i)=4.75_real64
      c(4,i)=0.0135_real64; c(5,i)=0.365_real64; c(6,i)=1.455_real64
      c(7,i)=1.0_real64-1.0_real64/c(6,i); c(8,i)=c(4,i)
      if(branch==1) then
        c(9,i)=0.0_real64
      else
        c(9,i)=-100.0_real64
      end if
      c(10,i)=c(3,i); c(11,i)=0.999_real64; c(12,i)=0.99_real64*c(3,i)
      c(22,i)=-1.0e6_real64; c(23,i)=1.0e-12_real64
    end do
  end subroutine

  subroutine make_heads(branch,v)
    integer,intent(in)::branch
    real(real64),intent(out)::v(:)
    if(branch==1) then
      v=[1.0_real64,nearest(0.0_real64,1.0_real64),0.0_real64,nearest(0.0_real64,-1.0_real64), &
         -1.0e-6_real64,nearest(HCRIT,1.0_real64),HCRIT,nearest(HCRIT,-1.0_real64),-0.1_real64,-1.0_real64, &
         -10.0_real64,-100.0_real64,-1.0e4_real64,nearest(HDRY,1.0_real64),HDRY,nearest(HDRY,-1.0_real64), &
         -1.0e15_real64,-1.0e100_real64]
    else
      v=[1.0_real64,0.0_real64,-1.0e-6_real64,-1.0_real64,-50.0_real64,-99.0_real64, &
         nearest(-100.0_real64,1.0_real64),-100.0_real64,nearest(-100.0_real64,-1.0_real64),-101.0_real64, &
         nearest(-105.0_real64,1.0_real64),-105.0_real64,nearest(-105.0_real64,-1.0_real64),-110.0_real64, &
         -1.0e4_real64,HDRY,nearest(HDRY,-1.0_real64),-1.0e15_real64]
    end if
  end subroutine

  subroutine theta_only_mirror(parameters,head,head_dir,theta_dir,available,route)
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    real(real64),intent(in)::head(:),head_dir(:)
    real(real64),intent(out)::theta_dir(:)
    logical,intent(out)::available
    character(len=*),intent(out)::route
    integer::i,n
    real(real64)::dtheta,theta
    logical::ok
    available=.false.; route='b110-mvg-direction-unavailable'; theta_dir=0.0_real64
    n=parameters%active_nodes
    if(n<=0 .or. .not. allocated(parameters%cofgen)) then
      route='b110-mvg-parameters-invalid'; return
    end if
    if(size(head)/=n .or. size(head_dir)/=n .or. size(theta_dir)/=n) then
      route='b110-mvg-direction-shape-invalid'; return
    end if
    if(any(.not. ieee_is_finite(head)) .or. any(.not. ieee_is_finite(head_dir))) then
      route='b110-mvg-direction-nonfinite'; return
    end if
    do i=1,n
      call theta_and_k_smooth(parameters%cofgen(:,i),head(i),theta,dtheta,ok)
      if(.not.ok) then
        route='b110-mvg-nonsmooth-constitutive-branch'; theta_dir=0.0_real64; return
      end if
      theta_dir(i)=dtheta*head_dir(i)
    end do
    if(any(.not. ieee_is_finite(theta_dir))) then
      route='b110-mvg-state-direction-nonfinite'; theta_dir=0.0_real64; return
    end if
    available=.true.; route='b110-mvg-analytic-smooth-direction'
  end subroutine

  subroutine theta_and_k_smooth(c,head,theta,dtheta,ok)
    real(real64),intent(in)::c(:),head
    real(real64),intent(out)::theta,dtheta
    logical,intent(out)::ok
    real(real64)::alpha,u,raw_theta,h105,relsat,invm,a,x,se,r,denom,term2
    ok=.false.; theta=0.0_real64; dtheta=0.0_real64
    if(size(c)<42 .or. .not. ieee_is_finite(head)) return
    if(c(25)<=0.0_real64 .or. c(3)<0.0_real64 .or. c(7)<=0.0_real64) return
    alpha=c(4); if(alpha<=0.0_real64) return
    if(head>0.0_real64) then
      theta=c(2); dtheta=0.0_real64
    else if(head==0.0_real64) then
      return
    else if(c(9)>HCRIT) then
      if(head>HCRIT) then
        raw_theta=c(26)+c(27)*(head-HCRIT)
        if(raw_theta>c(2)) then
          theta=c(2); dtheta=0.0_real64
        else if(raw_theta==c(2)) then
          return
        else
          theta=raw_theta; dtheta=c(27)
        end if
      else if(head==HCRIT) then
        return
      else
        u=abs(alpha*head)
        theta=c(1)+c(25)/(1.0_real64+u**c(6))**c(7)
        dtheta=c(6)*c(7)*alpha*c(25)*u**(c(6)-1.0_real64)/(1.0_real64+u**c(6))**(c(7)+1.0_real64)
      end if
    else
      h105=1.05_real64*c(9)
      if(head>h105) then
        theta=c(2)+c(42)*head/(1.0_real64+c(41)*head)
        dtheta=c(42)/(1.0_real64+c(41)*head)**2
      else if(head==h105) then
        return
      else
        u=abs(alpha*head)
        theta=c(1)+c(25)/((1.0_real64+u**c(6))**c(7)*c(28))
        dtheta=c(6)*c(7)*alpha*c(25)*u**(c(6)-1.0_real64)/((1.0_real64+u**c(6))**(c(7)+1.0_real64)*c(28))
      end if
    end if
    if(.not.ieee_is_finite(theta) .or. .not.ieee_is_finite(dtheta)) return

    if(c(9)>HCRIT) then
      if(head<HDRY) then
        ok=.true.; return
      else if(head==HDRY) then
        return
      end if
      relsat=(theta-c(1))/c(25)
      if(.not.ieee_is_finite(relsat)) return
      if(relsat>KSW) then
        ok=.true.; return
      else if(relsat==KSW) then
        return
      end if
      if(relsat<=0.0_real64 .or. relsat>=1.0_real64) return
      invm=c(32); a=1.0_real64-relsat**invm
      if(a<=0.0_real64) return
      ! For common finite MvG coefficients this is the exact branch domain.
      ! Extreme arithmetic is deliberately falsified by the differential test.
      ok=.true.
    else
      if(head>c(9)) then
        ok=.true.; return
      else if(head==c(9)) then
        return
      end if
      u=abs(alpha*head); if(u<=0.0_real64) return
      x=(1.0_real64+u**c(6))**(-c(7))
      se=x/c(28); r=x; invm=c(32); a=1.0_real64-r**invm
      if(se<=0.0_real64 .or. a<=0.0_real64) return
      term2=(1.0_real64-c(28)**invm)**c(7); denom=1.0_real64-term2
      if(denom==0.0_real64) return
      ok=.true.
    end if
  end subroutine

  logical function same_bits(a,b)
    real(real64),intent(in)::a(:),b(:)
    integer::i
    same_bits=size(a)==size(b)
    if(.not.same_bits)return
    do i=1,size(a)
      if(transfer(a(i),0_int64)/=transfer(b(i),0_int64)) then
        same_bits=.false.; return
      end if
    end do
  end function
end program
