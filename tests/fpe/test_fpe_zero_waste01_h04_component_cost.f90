program test_fpe_zero_waste01_h04_component_cost
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  implicit none

  real(real64), parameter :: H_CRIT=-1.0e-2_real64, HCON_VSMALL=1.0e-10_real64
  real(real64), parameter :: DT=0.25_real64
  type(b110_default_mvg_parameters_t), target :: hydraulic
  type(b110_default_mvg_provider_t) :: provider
  real(real64), allocatable :: raw(:,:), head(:), theta(:), kval(:), cap(:), dkdh(:)
  real(real64), allocatable :: theta_m(:), kval_m(:), cap_m(:), theta_only(:)
  integer :: n, reps, r, i
  integer(int64) :: c0,c1,rate
  real(real64) :: checksum, bottom_k, point_k
  logical :: point_available
  character(len=32) :: arg

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) reps
  if (n <= 0 .or. reps <= 0) error stop 'H04 component-cost invalid request'

  allocate(raw(24,n),head(n),theta(n),kval(n),cap(n),dkdh(n),theta_m(n),kval_m(n),cap_m(n),theta_only(n))
  call initialize_fixture(raw)
  call initialize_b110_default_mvg_parameters(hydraulic,raw)
  call bind_b110_default_mvg_provider(provider,hydraulic,DT)

  do i=1,n
    head(i)=-75.0_real64 - 0.025_real64*real(mod(i-1,17),real64)
  end do

  call provider%evaluate(head,theta,kval,cap,dkdh)
  if (.not. provider%supports_point_conductivity()) error stop 'H04 B110 point conductivity capability unavailable'
  call provider%evaluate_point_conductivity(n,head(n),theta(n),point_k,point_available)
  if (.not. point_available) error stop 'H04 B110 point conductivity evaluation unavailable'
  if (transfer(point_k,0_int64) /= transfer(kval(n),0_int64)) error stop 'H04 point K not bit-identical to full K(NN)'
  theta_only = -huge(0.0_real64)
  cap_m = -huge(0.0_real64)
  call provider%evaluate_demand(head,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta_only,kval_m,cap_m,dkdh)
  if (.not. same_vector_bits(theta,theta_only)) error stop 'H04 demand theta not bit-identical'
  call provider%evaluate_demand(head,CONSTITUTIVE_DEMAND_CAPACITY,theta_only,kval_m,cap_m,dkdh)
  if (.not. same_vector_bits(cap,cap_m)) error stop 'H04 demand capacity not bit-identical'
  call mirror_theta_k(hydraulic%cofgen,head,theta_m,kval_m)
  call mirror_capacity(hydraulic%cofgen,head,cap_m)
  if (.not. same_vector_bits(theta,theta_m)) error stop 'H04 theta mirror not bit-identical'
  if (.not. same_vector_bits(kval,kval_m)) error stop 'H04 K mirror not bit-identical'
  if (.not. same_vector_bits(cap,cap_m)) error stop 'H04 C mirror not bit-identical'
  write(*,'(A,I0,A)') 'H04_COMPONENT_IDENTITY,n=',n,',PASS'

  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call provider%evaluate(head,theta,kval,cap,dkdh)
    checksum=checksum+theta(1)+kval(n)+cap(1)
  end do
  call system_clock(c1)
  call emit('full_provider',n,reps,c0,c1,rate,checksum)

  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call provider%evaluate_demand(head,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta_only,kval_m,cap_m,dkdh)
    checksum=checksum+theta_only(1)
  end do
  call system_clock(c1)
  call emit('theta_only',n,reps,c0,c1,rate,checksum)

  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call provider%evaluate_point_conductivity(n,head(n),theta(n),bottom_k,point_available)
    if (.not. point_available) error stop 'H04 timed point conductivity unavailable'
    checksum=checksum+bottom_k
  end do
  call system_clock(c1)
  call emit('bottom_k_only',n,reps,c0,c1,rate,checksum)

  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call mirror_theta_k(hydraulic%cofgen,head,theta_m,kval_m)
    checksum=checksum+theta_m(1)+kval_m(n)
  end do
  call system_clock(c1)
  call emit('theta_k',n,reps,c0,c1,rate,checksum)

  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call provider%evaluate_demand(head,CONSTITUTIVE_DEMAND_CAPACITY,theta_only,kval_m,cap_m,dkdh)
    checksum=checksum+cap_m(1)
  end do
  call system_clock(c1)
  call emit('capacity',n,reps,c0,c1,rate,checksum)

contains

  subroutine initialize_fixture(c)
    real(real64), intent(out) :: c(:,:)
    integer :: j
    c=0.0_real64
    do j=1,size(c,2)
      c(1,j)=0.032_real64
      c(2,j)=0.423_real64
      c(3,j)=4.75_real64
      c(4,j)=0.0135_real64
      c(5,j)=0.365_real64
      c(6,j)=1.455_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j)
      c(8,j)=c(4,j)
      c(9,j)=0.0_real64
      c(10,j)=c(3,j)
      c(11,j)=0.999_real64
      c(12,j)=0.99_real64*c(3,j)
      c(22,j)=-1.0e6_real64
      c(23,j)=1.0e-12_real64
    end do
  end subroutine initialize_fixture

  subroutine mirror_theta(c,h,t)
    real(real64), intent(in) :: c(:,:),h(:)
    real(real64), intent(out) :: t(:)
    integer :: j
    do j=1,size(h)
      t(j)=watcon(c(:,j),h(j))
    end do
  end subroutine mirror_theta

  subroutine mirror_bottom_k(c,h,kbottom)
    real(real64), intent(in) :: c(:,:),h(:)
    real(real64), intent(out) :: kbottom
    real(real64) :: theta_bottom
    integer :: j
    j=size(h)
    theta_bottom=watcon(c(:,j),h(j))
    kbottom=hconduc(c(:,j),h(j),theta_bottom)
  end subroutine mirror_bottom_k

  subroutine mirror_theta_k(c,h,t,k)
    real(real64), intent(in) :: c(:,:),h(:)
    real(real64), intent(out) :: t(:),k(:)
    integer :: j
    do j=1,size(h)
      t(j)=watcon(c(:,j),h(j))
      k(j)=hconduc(c(:,j),h(j),t(j))
    end do
  end subroutine mirror_theta_k

  subroutine mirror_capacity(c,h,capacity)
    real(real64), intent(in) :: c(:,:),h(:)
    real(real64), intent(out) :: capacity(:)
    integer :: j
    do j=1,size(h)
      capacity(j)=moiscap(c(:,j),h(j))
    end do
  end subroutine mirror_capacity

  pure real(real64) function watcon(c,headv) result(v)
    real(real64), intent(in) :: c(:),headv
    real(real64) :: help,h105,alfa
    alfa=c(4)
    if (headv >= 0.0_real64) then
      v=c(2)
    else
      if (c(9) > H_CRIT) then
        if (headv > H_CRIT) then
          v=c(26)+c(27)*(headv-H_CRIT)
          v=min(v,c(2))
        else
          help=abs(alfa*headv)**c(6)
          help=(1.0_real64+help)**c(7)
          v=c(1)+c(25)/help
        end if
      else
        h105=1.05_real64*c(9)
        if (headv >= h105) then
          v=c(2)+c(42)*headv/(1.0_real64+c(41)*headv)
        else
          help=abs(alfa*headv)**c(6)
          help=(1.0_real64+help)**c(7)
          v=c(1)+c(25)/(help*c(28))
        end if
      end if
    end if
  end function watcon

  pure real(real64) function moiscap(c,headv) result(v)
    real(real64), intent(in) :: c(:),headv
    real(real64) :: alphah,h105,term1,term2
    if (headv >= 0.0_real64) then
      v=DT*1.0e-7_real64
    else
      alphah=abs(c(4)*headv)
      if (c(9) > H_CRIT) then
        if (headv > H_CRIT) then
          v=c(27)
        else
          term1=alphah**c(30)
          term2=c(25)/((1.0_real64+term1*alphah)**c(31))
          v=c(29)*term2*term1
        end if
      else
        h105=1.05_real64*c(9)
        if (headv >= h105) then
          v=c(42)/((1.0_real64+c(41)*headv)**2)
        else
          term1=alphah**c(30)
          term2=(1.0_real64+term1*alphah)**c(31)
          term2=c(25)/term2
          v=c(29)*term2*term1/c(28)
        end if
      end if
      if (headv > -1.0_real64 .and. v < DT*1.0e-7_real64) v=DT*1.0e-7_real64
    end if
  end function moiscap

  pure real(real64) function hconduc(c,headv,theta) result(v)
    real(real64), intent(in) :: c(:),headv,theta
    real(real64) :: relsat,term1,term2,se
    relsat=(theta-c(1))/c(25)
    if (c(9) > H_CRIT) then
      if (headv < -1.0e14_real64) then
        v=HCON_VSMALL
      else if (relsat > (1.0_real64-1.0e-6_real64)) then
        v=c(3)
      else
        term1=(1.0_real64-relsat**c(32))**c(7)
        v=c(3)*(relsat**c(5))*(1.0_real64-term1)**2
      end if
    else
      if (headv < -1.0e14_real64) then
        v=HCON_VSMALL
      else
        if (headv >= c(9)) then
          v=c(3)
        else
          se=((1.0_real64+abs(c(4)*headv)**c(6))**(-c(7)))/c(28)
          term1=(1.0_real64-(se*c(28))**c(32))**c(7)
          term2=(1.0_real64-c(28)**c(32))**c(7)
          v=c(3)*se**c(5)*((1.0_real64-term1)/(1.0_real64-term2))**2
        end if
      end if
    end if
    v=min(v,c(3))
  end function hconduc

  logical function same_vector_bits(a,b) result(same)
    real(real64), intent(in) :: a(:),b(:)
    integer(int64), allocatable :: ia(:),ib(:)
    same=.false.
    if(size(a)/=size(b)) return
    allocate(ia(size(a)),ib(size(b)))
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    same=all(ia==ib)
  end function same_vector_bits

  subroutine emit(metric,nvalue,repetitions,start_clock,end_clock,clock_rate,sumv)
    character(len=*), intent(in) :: metric
    integer, intent(in) :: nvalue,repetitions
    integer(int64), intent(in) :: start_clock,end_clock,clock_rate
    real(real64), intent(in) :: sumv
    real(real64) :: seconds,ns_per_call
    seconds=real(end_clock-start_clock,real64)/real(clock_rate,real64)
    ns_per_call=1.0e9_real64*seconds/real(repetitions,real64)
    write(*,'(A,A,A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
      'H04_COMPONENT,metric=',trim(metric),',n=',nvalue,',reps=',repetitions,',seconds=',seconds, &
      ',ns_per_call=',ns_per_call,',checksum=',sumv
  end subroutine emit
end program test_fpe_zero_waste01_h04_component_cost
