program test_fpe_elastic05_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
       CONSTITUTIVE_DEMAND_CAPACITY, CONSTITUTIVE_DEMAND_DKDH
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction, &
       evaluate_b110_default_mvg_water_content_direction
  implicit none

  type(b110_default_mvg_parameters_t), target :: p_old,p_off,p_on,p_het
  type(b110_default_mvg_provider_t) :: old,off,on,het
  real(real64),allocatable :: c(:,:),ss(:),sshet(:),h(:)
  real(real64),allocatable :: to(:),ko(:),co(:),do(:),tf(:),kf(:),cf(:),df(:),tn(:),kn(:),cn(:),dn(:)
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,mm
  real(real64),allocatable :: dh_in(:),dtheta_old(:),dtheta_off(:),dtheta_on(:),dk_on(:),basek(:)
  character(len=32) :: mode,route_old,route_off,route_on
  logical :: available_old,available_off,available_on
  integer :: i,mask

  call get_command_argument(1,mode)
  call rr(2,tr);call rr(3,ts);call rr(4,alpha);call rr(5,nvg);call rr(6,ksat);call rr(7,lambda)
  allocate(c(24,numnod),ss(numnod),sshet(numnod),h(numnod))
  allocate(to(numnod),ko(numnod),co(numnod),do(numnod),tf(numnod),kf(numnod),cf(numnod),df(numnod))
  allocate(tn(numnod),kn(numnod),cn(numnod),dn(numnod))
  allocate(dh_in(numnod),dtheta_old(numnod),dtheta_off(numnod),dtheta_on(numnod),dk_on(numnod),basek(numnod))
  c=0.0_real64; mm=1.0_real64-1.0_real64/nvg
  do i=1,numnod
    c(1,i)=tr;c(2,i)=ts;c(3,i)=ksat;c(4,i)=alpha;c(5,i)=lambda;c(6,i)=nvg;c(7,i)=mm
    c(8,i)=alpha;c(9,i)=0.0_real64;c(10,i)=ksat;c(11,i)=0.999_real64;c(12,i)=0.99_real64*ksat
    c(22,i)=-1.0e6_real64;c(23,i)=1.0e-12_real64
  end do
  ss=1.0e-6_real64

  select case(trim(mode))
  case('invalid-missing')
    call initialize_b110_default_mvg_parameters(p_on,c,enable_elastic_storage=.true.)
    error stop 'ELASTIC05 expected missing-value failure'
  case('invalid-inactive-values')
    call initialize_b110_default_mvg_parameters(p_off,c,enable_elastic_storage=.false.,specific_elastic_storage_input=ss)
    error stop 'ELASTIC05 expected inactive-values failure'
  case('invalid-negative')
    ss(1)=-1.0e-6_real64
    call initialize_b110_default_mvg_parameters(p_on,c,enable_elastic_storage=.true.,specific_elastic_storage_input=ss)
    error stop 'ELASTIC05 expected negative-value failure'
  case('invalid-ksatexm')
    call initialize_b110_default_mvg_parameters(p_on,c,enable_ksatexm_extension=.true., &
         enable_elastic_storage=.true.,specific_elastic_storage_input=ss)
    error stop 'ELASTIC05 expected ELAS+KSATEXM failure'
  case('invalid-nan')
    ss(1)=ieee_value(ss(1),ieee_quiet_nan)
    call initialize_b110_default_mvg_parameters(p_on,c,enable_elastic_storage=.true.,specific_elastic_storage_input=ss)
    error stop 'ELASTIC05 expected NaN-value failure'
  case('invalid-shape')
    block
      real(real64) :: short_ss(numnod-1)
      short_ss=1.0e-6_real64
      call initialize_b110_default_mvg_parameters(p_on,c,enable_elastic_storage=.true., &
           specific_elastic_storage_input=short_ss)
    end block
    error stop 'ELASTIC05 expected shape failure'
  case('check')
    continue
  case default
    error stop 'ELASTIC05 unknown mode'
  end select

  call initialize_b110_default_mvg_parameters(p_old,c)
  call initialize_b110_default_mvg_parameters(p_off,c,enable_elastic_storage=.false.)
  call initialize_b110_default_mvg_parameters(p_on,c,enable_elastic_storage=.true.,specific_elastic_storage_input=ss)
  call bind_b110_default_mvg_provider(old,p_old,0.01_real64)
  call bind_b110_default_mvg_provider(off,p_off,0.01_real64)
  call bind_b110_default_mvg_provider(on,p_on,0.01_real64)

  do i=1,numnod
    select case(mod(i-1,8))
    case(0);h(i)=-20.0_real64
    case(1);h(i)=-1.0_real64
    case(2);h(i)=-0.01_real64
    case(3);h(i)=-0.001_real64
    case(4);h(i)=0.0_real64
    case(5);h(i)=0.1_real64
    case(6);h(i)=1.0_real64
    case default;h(i)=100.0_real64
    end select
  end do

  call old%evaluate(h,to,ko,co,do)
  call off%evaluate(h,tf,kf,cf,df)
  call req(all(to==tf).and.all(ko==kf).and.all(co==cf).and.all(do==df),'inactive full evaluate drift')

  call on%evaluate(h,tn,kn,cn,dn)
  do i=1,numnod
    if(h(i)>=0.0_real64)then
      call req(abs(tn(i)-(ts+h(i)*ss(i)))<=1.0e-14_real64,'active theta')
      call req(cn(i)==ss(i),'active capacity')
      call req(abs(kn(i)-ksat)<=1.0e-14_real64*max(1.0_real64,abs(ksat)),'active conductivity')
    else
      call req(tn(i)==to(i),'negative-head theta drift')
      call req(cn(i)==co(i),'negative-head capacity drift')
      call req(kn(i)==ko(i),'negative-head conductivity drift')
    end if
  end do

  do mask=1,15
    if(iand(mask,15)==0)cycle
    to=-777.0_real64;ko=-777.0_real64;co=-777.0_real64;do=-777.0_real64
    tn=-888.0_real64;kn=-888.0_real64;cn=-888.0_real64;dn=-888.0_real64
    call old%evaluate_demand(h,mask,to,ko,co,do)
    call on%evaluate_demand(h,mask,tn,kn,cn,dn)
    do i=1,numnod
      if(iand(mask,CONSTITUTIVE_DEMAND_WATER_CONTENT)/=0)then
        if(h(i)>=0.0_real64)then
          call req(abs(tn(i)-(ts+h(i)*ss(i)))<=1.0e-14_real64,'demand theta')
        else
          call req(tn(i)==to(i),'demand negative theta')
        end if
      end if
      if(iand(mask,CONSTITUTIVE_DEMAND_CAPACITY)/=0)then
        if(h(i)>=0.0_real64)then
          call req(cn(i)==ss(i),'demand capacity')
        else
          call req(cn(i)==co(i),'demand negative capacity')
        end if
      end if
      if(iand(mask,CONSTITUTIVE_DEMAND_CONDUCTIVITY)/=0)then
        if(h(i)>=0.0_real64)then
          call req(abs(kn(i)-ksat)<=1.0e-14_real64*max(1.0_real64,abs(ksat)),'demand conductivity')
        else
          call req(kn(i)==ko(i),'demand negative conductivity')
        end if
      end if
      if(iand(mask,CONSTITUTIVE_DEMAND_DKDH)/=0)call req(dn(i)==0.0_real64,'demand dkdh')
    end do
  end do

  ! P0A: directional closure. Default/off remain identical. Active smooth
  ! saturated heads use dtheta/dh=ELAS; h=0 remains an unavailable switch.
  dh_in=1.25_real64
  h=2.0_real64
  call evaluate_b110_default_mvg_water_content_direction(old,h,dh_in,dtheta_old,available_old,route_old)
  call evaluate_b110_default_mvg_water_content_direction(off,h,dh_in,dtheta_off,available_off,route_off)
  call req(available_old.eqv.available_off,'directional default/off availability')
  call req(trim(route_old)==trim(route_off),'directional default/off route')
  call req(all(dtheta_old==dtheta_off),'directional default/off values')
  call evaluate_b110_default_mvg_state_direction(on,h,dh_in,dtheta_on,dk_on,available_on,route_on,basek)
  call req(available_on,'active saturated directional unavailable')
  do i=1,numnod
    call req(abs(dtheta_on(i)-ss(i)*dh_in(i))<=1.0e-15_real64,'active saturated dtheta')
    call req(dk_on(i)==0.0_real64,'active saturated dK')
    call req(abs(basek(i)-ksat)<=1.0e-14_real64*max(1.0_real64,abs(ksat)),'active saturated base K')
  end do
  h=0.0_real64
  call evaluate_b110_default_mvg_water_content_direction(on,h,dh_in,dtheta_on,available_on,route_on)
  call req(.not.available_on,'h=0 directional switch must remain unavailable')

  do i=1,numnod
    sshet(i)=1.0e-7_real64*real(i,real64)
  end do
  call initialize_b110_default_mvg_parameters(p_het,c,enable_elastic_storage=.true.,specific_elastic_storage_input=sshet)
  call bind_b110_default_mvg_provider(het,p_het,0.01_real64)
  h=2.0_real64
  call het%evaluate(h,tn,kn,cn,dn)
  do i=1,numnod
    call req(abs(tn(i)-(ts+2.0_real64*sshet(i)))<=1.0e-14_real64,'heterogeneous theta')
    call req(cn(i)==sshet(i),'heterogeneous capacity')
  end do

  write(*,'(A)')'F_PE_ELASTIC05_PROVIDER=PASS'
contains
  subroutine rr(k,x)
    integer,intent(in)::k
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(k,s);read(s,*)x
  end subroutine
  subroutine req(ok,msg)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    if(.not.ok)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC05_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_elastic05_provider
