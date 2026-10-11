program test_fpe_timeint17d_toprow_fd
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_boundary_conditions_t, soil_water_top_boundary_result_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, bind_b110_dynamic_top_boundary_solver_provider
  implicit none
  integer, parameter :: neps=4
  real(real64), parameter :: epss(neps)=[1.0e-4_real64,3.0e-5_real64,1.0e-5_real64,3.0e-6_real64]
  type(soil_water_parameter_set_t),target :: geom
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: hyd
  type(b110_dynamic_top_boundary_solver_provider_t) :: top
  type(soil_water_boundary_conditions_t) :: bc
  type(soil_water_top_boundary_result_t) :: r0,rp,rm
  real(real64)::cof(24,1),tr,ts,alpha,nvg,ksat,lambda,h0,pd,rain,dt,pmax,rsro,ktop
  real(real64)::th(1),kk(1),cap(1),dk(1),j_an,j_fd,fp,fm,abs_err,rel_err,best_abs,best_rel
  integer::i,eligible
  character(len=32)::mid,route
  call get_command_argument(1,mid);call get_command_argument(2,route)
  call rr(3,tr);call rr(4,ts);call rr(5,alpha);call rr(6,nvg);call rr(7,ksat);call rr(8,lambda)
  call rr(9,h0);call rr(10,pd);call rr(11,rain);call rr(12,dt);call rr(13,pmax);call rr(14,rsro);call rr(15,ktop)
  geom%active_nodes=1;allocate(geom%z(1),geom%dz(1),geom%node_distance(1))
  geom%z=-5d0;geom%dz=10d0;geom%node_distance=10d0
  cof=0d0;cof(1,1)=tr;cof(2,1)=ts;cof(3,1)=ksat;cof(4,1)=alpha;cof(5,1)=lambda;cof(6,1)=nvg;cof(7,1)=1d0-1d0/nvg
  cof(8,1)=alpha;cof(9,1)=0d0;cof(10,1)=ksat;cof(11,1)=0.999d0;cof(12,1)=0.99d0*ksat;cof(22,1)=-1d6;cof(23,1)=1d-12
  call initialize_b110_default_mvg_parameters(hp,cof)
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  call bind_b110_dynamic_top_boundary_solver_provider(top,geom,hp,1,pd,dt,rain,0d0,0d0,0d0,0d0,0d0,pmax,rsro,1d0,ktop)
  call hyd%evaluate([h0],th,kk,cap,dk)
  call top%evaluate(h0,th(1),pd,bc,r0)
  if(r0%status<=0) error stop 'base unavailable'
  j_an=cap(1)*geom%dz(1)/dt + ktop/geom%node_distance(1)
  if(route_code(r0%route)==2 .or. route_code(r0%route)==3) then
    j_an=j_an+r0%surface_face_conductivity/geom%node_distance(1)*(1d0-r0%surface_head_dpressure_head_top)
  end if
  best_abs=huge(1d0);best_rel=huge(1d0);eligible=0
  do i=1,neps
    fp=resid(h0+epss(i),rp)
    fm=resid(h0-epss(i),rm)
    if(rp%status<=0.or.rm%status<=0) cycle
    if(route_code(rp%route)/=route_code(r0%route).or.route_code(rm%route)/=route_code(r0%route)) cycle
    eligible=eligible+1
    j_fd=(fp-fm)/(2d0*epss(i))
    abs_err=abs(j_an-j_fd);rel_err=abs_err/max(1d-30,abs(j_fd))
    if(abs_err<best_abs)then;best_abs=abs_err;best_rel=rel_err;end if
    write(*,'(*(g0))') 'F_PE_TIMEINT17D_ROW_OBS|MATERIAL=',trim(mid),'|ROUTE=',trim(route),'|DT=',dt,'|EPS=',epss(i), &
      '|J_AN=',j_an,'|J_FD=',j_fd,'|ABS_ERR=',abs_err,'|REL_ERR=',rel_err
  end do
  write(*,'(*(g0))') 'F_PE_TIMEINT17D_ROW_RESULT|MATERIAL=',trim(mid),'|ROUTE=',trim(route),'|DT=',dt, &
    '|ELIGIBLE=',eligible,'|J_AN=',j_an,'|BEST_ABS_ERR=',best_abs,'|BEST_REL_ERR=',best_rel,'|BASE_ROUTE=',route_code(r0%route)
contains
  subroutine rr(i,x);integer,intent(in)::i;real(real64),intent(out)::x;character(len=64)::s;call get_command_argument(i,s);read(s,*)x;end subroutine
  integer function route_code(s) result(r);character(len=*),intent(in)::s
    if(index(s,'surface-flux')>0)then;r=1
    else if(index(s,'linear-runoff')>0)then;r=3
    else if(index(s,'ponded-head')>0)then;r=2
    else if(index(s,'atmospheric-head')>0)then;r=4
    else;r=0;end if
  end function
  real(real64) function resid(h,res) result(f)
    real(real64),intent(in)::h
    type(soil_water_top_boundary_result_t),intent(out)::res
    real(real64)::t(1),k(1),c(1),d(1),grad
    call hyd%evaluate([h],t,k,c,d)
    call top%evaluate(h,t(1),pd,bc,res)
    f=(t(1)-th(1))*geom%dz(1)/dt + ktop*((h-h0)/geom%node_distance(1)+1d0)
    if(res%regime==1)then
      f=f+res%actual_top_flux
    else
      grad=(res%surface_head-h)/geom%node_distance(1)+1d0
      f=f-res%surface_face_conductivity*grad
    end if
  end function
end program
