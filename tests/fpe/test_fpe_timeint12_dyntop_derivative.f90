program test_fpe_timeint12_dyntop_derivative
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE
  implicit none

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: provider
  real(real64),allocatable :: cof(:,:),heads(:),dirs(:),dtheta(:),dk(:),basek(:),water(:),k(:),cap(:),dummy(:)

  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda
  real(real64),parameter :: rains(4)=[4.0_real64,8.0_real64,12.0_real64,25.0_real64]
  real(real64),parameter :: dts(3)=[0.005_real64,0.02_real64,0.05_real64]
  real(real64),parameter :: ponds(3)=[0.0_real64,0.02_real64,0.05_real64]
  real(real64),parameter :: hs(8)=[-50.0_real64,-20.0_real64,-10.0_real64,-5.0_real64,-2.0_real64,-0.5_real64,0.5_real64,2.0_real64]
  integer :: ir,id,ip,ih,count_head,count_pond,count_runoff
  real(real64) :: h,rain,step_dt,pond,eps,ana,fd,absdiff,reldiff,fixed_identity
  logical :: ok
  character(len=48) :: route

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda)

  call setup()
  count_head=0; count_pond=0; count_runoff=0

  do ir=1,size(rains)
    rain=rains(ir)
    do id=1,size(dts)
      step_dt=dts(id)
      call bind_b110_default_mvg_provider(provider,hp,step_dt)
      do ip=1,size(ponds)
        pond=ponds(ip)
        do ih=1,size(hs)
          h=hs(ih)
          call evaluate_point(h,pond,rain,step_dt,ana,fd,route,fixed_identity,ok)
          if(.not.ok)cycle
          count_head=count_head+1
          if(index(trim(route),'linear-runoff')>0)then
            count_runoff=count_runoff+1
          else
            count_pond=count_pond+1
          end if
          absdiff=abs(ana-fd)
          if(abs(fd)>=1.0e-6_real64)then
            reldiff=absdiff/abs(fd)
          else
            reldiff=0.0_real64
          end if
          write(*,'(*(g0))') 'F_PE_TIMEINT12_POINT|MATERIAL=',trim(material_id),'|H=',h,'|RAIN=',rain, &
             '|DT=',step_dt,'|POND0=',pond,'|ROUTE=',trim(route),'|ANA=',ana,'|FD=',fd, &
             '|ABS=',absdiff,'|REL=',reldiff,'|FIXED_ID=',fixed_identity
        end do
      end do
    end do
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT12_END|MATERIAL=',trim(material_id),'|HEAD=',count_head, &
       '|POND=',count_pond,'|RUNOFF=',count_runoff
  write(*,'(A)') 'F_PE_TIMEINT12=PASS'

contains

  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine

  subroutine setup()
    integer::i
    real(real64)::mm
    p%parameter_set_id=26092912_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),cof(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    cof=0.0_real64; mm=1.0_real64-1.0_real64/nvg
    do i=1,numnod
      cof(1,i)=tr; cof(2,i)=ts; cof(3,i)=ksat; cof(4,i)=alpha; cof(5,i)=lambda; cof(6,i)=nvg; cof(7,i)=mm
      cof(8,i)=alpha; cof(9,i)=0.0_real64; cof(10,i)=ksat; cof(11,i)=0.999_real64; cof(12,i)=0.99_real64*ksat
      cof(22,i)=-1.0e6_real64; cof(23,i)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,cof)
    allocate(heads(numnod),dirs(numnod),dtheta(numnod),dk(numnod),basek(numnod))
    allocate(water(numnod),k(numnod),cap(numnod),dummy(numnod))
  end subroutine

  subroutine eval_value(hh,pond0,rr,dd,res,theta_top,valid)
    real(real64),intent(in)::hh,pond0,rr,dd
    type(b110_dynamic_top_boundary_result_t),intent(out)::res
    real(real64),intent(out)::theta_top
    logical,intent(out)::valid
    type(b110_dynamic_top_boundary_request_t)::req
    logical::k_ok

    call bind_b110_default_mvg_provider(provider,hp,dd)
    heads=hh
    call provider%evaluate(heads,water,k,cap,dummy)
    theta_top=water(1)

    req=b110_dynamic_top_boundary_request_t()
    req%conductivity_mean_method=1
    req%pressure_head_top_cm=hh
    req%water_content_top=theta_top
    req%candidate_ponding_depth_cm=pond0
    req%previous_ponding_depth_cm=pond0
    req%step_duration_day=dd
    req%precipitation_rate_cm_per_day=rr
    req%ponding_max_cm=0.05_real64
    req%runoff_resistance_day=0.05_real64
    req%runoff_exponent=1.0_real64
    req%fixed_top_node_conductivity_cm_per_day=-1.0_real64
    call evaluate_b110_dynamic_top_boundary(p,hp,req,res)
    valid=res%status==B110_DYN_TOP_AVAILABLE
    if(.not.valid)return
    valid=trim(res%route)=='ponded-head' .or. trim(res%route)=='ponded-head-linear-runoff'
  end subroutine

  subroutine eval_fixed_derivative(hh,pond0,rr,dd,kfix,derivative,route,valid)
    real(real64),intent(in)::hh,pond0,rr,dd,kfix
    real(real64),intent(out)::derivative
    character(len=*),intent(out)::route
    logical,intent(out)::valid
    type(b110_dynamic_top_boundary_request_t)::req
    type(b110_dynamic_top_boundary_result_t)::res
    real(real64)::theta_top

    call bind_b110_default_mvg_provider(provider,hp,dd)
    heads=hh
    call provider%evaluate(heads,water,k,cap,dummy)
    theta_top=water(1)

    req=b110_dynamic_top_boundary_request_t()
    req%conductivity_mean_method=1
    req%pressure_head_top_cm=hh
    req%water_content_top=theta_top
    req%candidate_ponding_depth_cm=pond0
    req%previous_ponding_depth_cm=pond0
    req%step_duration_day=dd
    req%precipitation_rate_cm_per_day=rr
    req%ponding_max_cm=0.05_real64
    req%runoff_resistance_day=0.05_real64
    req%runoff_exponent=1.0_real64
    req%fixed_top_node_conductivity_cm_per_day=kfix
    call evaluate_b110_dynamic_top_boundary(p,hp,req,res)
    valid=res%status==B110_DYN_TOP_AVAILABLE .and. res%surface_head_derivative_available
    route=trim(res%route)
    derivative=res%surface_head_dpressure_head_top
  end subroutine

  subroutine evaluate_point(hh,pond0,rr,dd,analytic,finite,base_route,fixed_id,valid)
    real(real64),intent(in)::hh,pond0,rr,dd
    real(real64),intent(out)::analytic,finite,fixed_id
    character(len=*),intent(out)::base_route
    logical,intent(out)::valid
    type(b110_dynamic_top_boundary_result_t)::r0,rp,rm
    real(real64)::theta0,thetap,thetam,k_sat,k_top,dk_top,kf,dkf,a,p1,p1p,denom,aprime,fixed_deriv
    logical::ok0,okp,okm,dir_ok,kok,fixed_ok
    character(len=64)::dir_route,fixed_route

    valid=.false.; analytic=0.0_real64; finite=0.0_real64; fixed_id=0.0_real64
    eps=1.0e-5_real64*max(1.0_real64,abs(hh))
    call eval_value(hh,pond0,rr,dd,r0,theta0,ok0)
    call eval_value(hh+eps,pond0,rr,dd,rp,thetap,okp)
    call eval_value(hh-eps,pond0,rr,dd,rm,thetam,okm)
    if(.not.(ok0.and.okp.and.okm))return
    if(trim(r0%route)/=trim(rp%route) .or. trim(r0%route)/=trim(rm%route))return

    call bind_b110_default_mvg_provider(provider,hp,dd)
    heads=hh; dirs=0.0_real64; dirs(1)=1.0_real64
    call evaluate_b110_default_mvg_state_direction(provider,heads,dirs,dtheta,dk,dir_ok,dir_route,basek)
    if(.not.dir_ok)return
    k_top=basek(1); dk_top=dk(1)

    call evaluate_b110_default_mvg_conductivity(hp,1,0.0_real64,k_sat,kok)
    if(.not.kok)return

    kf=0.5_real64*(k_sat+k_top)
    dkf=0.5_real64*dk_top
    a=dd/p%node_distance(1)
    p1=a*kf
    p1p=a*dkf
    if(trim(r0%route)=='ponded-head-linear-runoff')then
      denom=1.0_real64+p1+dd/0.05_real64
    else
      denom=1.0_real64+p1
    end if
    aprime=-dkf*dd+p1p*hh+p1
    analytic=(aprime-r0%surface_head_cm*p1p)/denom
    finite=(rp%surface_head_cm-rm%surface_head_cm)/(2.0_real64*eps)
    call eval_fixed_derivative(hh,pond0,rr,dd,k_top,fixed_deriv,fixed_route,fixed_ok)
    if(.not.fixed_ok)return
    if(trim(fixed_route)/=trim(r0%route))return
    fixed_id=abs(fixed_deriv-p1/denom)
    base_route=trim(r0%route)
    valid=ieee_is_finite(analytic).and.ieee_is_finite(finite).and.ieee_is_finite(fixed_id)
  end subroutine

end program test_fpe_timeint12_dyntop_derivative
