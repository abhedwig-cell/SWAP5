program test_fpe_timeint17d_provider_fd
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_boundary_conditions_t, soil_water_top_boundary_result_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters, evaluate_b110_default_mvg_conductivity
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, bind_b110_dynamic_top_boundary_solver_provider
  implicit none
  integer, parameter :: neps=4
  real(real64), parameter :: epss(neps)=[1.0e-4_real64,3.0e-5_real64,1.0e-5_real64,3.0e-6_real64]
  type(soil_water_parameter_set_t),target :: geom
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_dynamic_top_boundary_solver_provider_t) :: top
  type(soil_water_boundary_conditions_t) :: bc
  type(soil_water_top_boundary_result_t) :: r0,rp,rm
  real(real64)::cof(24,1),tr,ts,alpha,nvg,ksat,lambda,h,pd,rain,dt,pmax,rsro,ktop,theta
  real(real64)::fd_h,fd_q,fd_p,fd_run,err,rel,best_err,best_rel
  integer::i,eligible
  character(len=32)::mid,route
  call get_command_argument(1,mid); call get_command_argument(2,route)
  call rr(3,tr);call rr(4,ts);call rr(5,alpha);call rr(6,nvg);call rr(7,ksat);call rr(8,lambda)
  call rr(9,h);call rr(10,pd);call rr(11,rain);call rr(12,dt);call rr(13,pmax);call rr(14,rsro);call rr(15,ktop)
  geom%active_nodes=1; allocate(geom%z(1),geom%dz(1),geom%node_distance(1))
  geom%z=-5.0_real64; geom%dz=10.0_real64; geom%node_distance=10.0_real64
  cof=0.0_real64
  cof(1,1)=tr;cof(2,1)=ts;cof(3,1)=ksat;cof(4,1)=alpha;cof(5,1)=lambda;cof(6,1)=nvg;cof(7,1)=1.0_real64-1.0_real64/nvg
  cof(8,1)=alpha;cof(9,1)=0.0_real64;cof(10,1)=ksat;cof(11,1)=0.999_real64;cof(12,1)=0.99_real64*ksat
  cof(22,1)=-1.0e6_real64;cof(23,1)=1.0e-12_real64
  call initialize_b110_default_mvg_parameters(hp,cof)
  call bind_b110_dynamic_top_boundary_solver_provider(top,geom,hp,1,pd,dt,rain,0d0,0d0,0d0,0d0,0d0,pmax,rsro,1d0,ktop)
  theta=watcon(h)
  call top%evaluate(h,theta,pd,bc,r0)
  if(r0%status<=0) error stop 'base provider unavailable'
  best_err=huge(1d0);best_rel=huge(1d0);eligible=0
  do i=1,neps
    call top%evaluate(h+epss(i),watcon(h+epss(i)),pd,bc,rp)
    call top%evaluate(h-epss(i),watcon(h-epss(i)),pd,bc,rm)
    if(rp%status<=0.or.rm%status<=0) cycle
    if(route_code(rp%route)/=route_code(r0%route).or.route_code(rm%route)/=route_code(r0%route)) cycle
    eligible=eligible+1
    fd_h=(rp%surface_head-rm%surface_head)/(2d0*epss(i))
    fd_q=(rp%actual_top_flux-rm%actual_top_flux)/(2d0*epss(i))
    fd_p=(rp%candidate_ponding_depth-rm%candidate_ponding_depth)/(2d0*epss(i))
    fd_run=(rp%runoff_depth-rm%runoff_depth)/(2d0*epss(i))
    if(r0%surface_head_derivative_available)then
      err=abs(r0%surface_head_dpressure_head_top-fd_h)
      rel=err/max(1d-30,abs(fd_h))
      if(err<best_err)then;best_err=err;best_rel=rel;end if
    end if
    write(*,'(*(g0))') 'F_PE_TIMEINT17D_OBS|MATERIAL=',trim(mid),'|ROUTE=',trim(route),'|DT=',dt,'|EPS=',epss(i), &
      '|PROVIDER_ROUTE=',route_code(r0%route),'|AN_DHSURF=',r0%surface_head_dpressure_head_top,'|FD_DHSURF=',fd_h, &
      '|FD_DQTOP=',fd_q,'|FD_DPOND=',fd_p,'|FD_DRUNOFF=',fd_run
  end do
  write(*,'(*(g0))') 'F_PE_TIMEINT17D_RESULT|MATERIAL=',trim(mid),'|ROUTE=',trim(route),'|DT=',dt, &
    '|ELIGIBLE=',eligible,'|DERIV_AVAILABLE=',merge(1,0,r0%surface_head_derivative_available), &
    '|BEST_ABS_ERR=',best_err,'|BEST_REL_ERR=',best_rel,'|BASE_ROUTE=',route_code(r0%route)
contains
  subroutine rr(i,x);integer,intent(in)::i;real(real64),intent(out)::x;character(len=64)::s;call get_command_argument(i,s);read(s,*)x;end subroutine
  integer function route_code(s) result(r);character(len=*),intent(in)::s
    if(index(s,'surface-flux')>0)then;r=1
    else if(index(s,'linear-runoff')>0)then;r=3
    else if(index(s,'ponded-head')>0)then;r=2
    else if(index(s,'atmospheric-head')>0)then;r=4
    else;r=0;end if
  end function
  real(real64) function watcon(head) result(t)
    real(real64),intent(in)::head;real(real64)::se,m
    m=1d0-1d0/nvg
    if(head>=0d0)then;t=ts
    else;se=(1d0+(abs(alpha*head))**nvg)**(-m);t=tr+(ts-tr)*se;end if
  end function
end program
