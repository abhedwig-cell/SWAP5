! Explicit research liquid-only thermal owner, independent of the legacy heat solve.
module mod_macro_liquid_thermal
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_reference_linear_solver,only:reference_tridag
 implicit none
 private
 type,public::macro_liquid_thermal_result_t
  logical::produced=.false.
  real(real64),allocatable::temperature_c(:,:),matrix_energy_j_cm2(:,:)
  real(real64)::external_net_into_j_cm2=0d0,stock_change_j_cm2=0d0,residual_j_cm2=0d0
 end type
 public::advance_macro_liquid_thermal
contains
 subroutine advance_macro_liquid_thermal(w0,w1,face,exchange,external_out,t_initial,initial_available, &
    matrix_t0,matrix_t1,matrix_available,top_t0,top_t1,top_available,bottom_t0,bottom_t1,bottom_available, &
    dt,substeps,capacity,result)
  real(real64),intent(in)::w0(:,:),w1(:,:),face(:,:),exchange(:,:),external_out(:,:),t_initial(:,:)
  logical,intent(in)::initial_available(:,:),matrix_available(:),top_available(:),bottom_available(:)
  real(real64),intent(in)::matrix_t0(:),matrix_t1(:),top_t0(:),top_t1(:),bottom_t0(:),bottom_t1(:)
  real(real64),intent(in)::dt,capacity
  integer,intent(in)::substeps
  type(macro_liquid_thermal_result_t),intent(out)::result
  real(real64),allocatable::temperature(:,:),before(:),after(:),old(:),new(:),lower(:),diagonal(:),upper(:),rhs(:),gamma(:),qenergy(:),matrix_energy(:,:)
  real(real64)::h,s0,s1,tm,tt,tb,external_energy,stock0,stock1,from_matrix,boundary,ledger,source_scale
  integer::nd,n,id,node,k,error
  result=macro_liquid_thermal_result_t();nd=size(w0,1);n=size(w0,2)
  if(nd<=0.or.n<=0.or.substeps<=0)return
  if(.not.all(ieee_is_finite([dt,capacity])))return
  if(dt<=0d0.or.capacity<=0d0)return
  if(any(shape(w1)/=[nd,n]).or.any(shape(face)/=[nd,n+1]).or.any(shape(exchange)/=[nd,n]).or. &
     any(shape(external_out)/=[nd,n]).or.any(shape(t_initial)/=[nd,n]).or.any(shape(initial_available)/=[nd,n]))return
  if(size(matrix_t0)/=n.or.size(matrix_t1)/=n.or.size(matrix_available)/=n)return
  if(size(top_t0)/=nd.or.size(top_t1)/=nd.or.size(top_available)/=nd)return
  if(size(bottom_t0)/=nd.or.size(bottom_t1)/=nd.or.size(bottom_available)/=nd)return
  if(any(.not.ieee_is_finite(w0)).or.any(.not.ieee_is_finite(w1)).or.any(.not.ieee_is_finite(face)).or. &
     any(.not.ieee_is_finite(exchange)).or.any(.not.ieee_is_finite(external_out)))return
  if(any(w0<0d0).or.any(w1<0d0).or.any(external_out<0d0))return
  do id=1,nd
   do node=1,n
    if(w0(id,node)>0d0)then
     if(.not.initial_available(id,node))return
     if(.not.ieee_is_finite(t_initial(id,node)))return
    end if
    ledger=w1(id,node)-w0(id,node)-dt*(face(id,node)-face(id,node+1)-exchange(id,node)-external_out(id,node))
    source_scale=max(1d0,w0(id,node),w1(id,node),dt*abs(face(id,node)),dt*abs(face(id,node+1)))
    if(abs(ledger)>1d-12*source_scale)return
    if(exchange(id,node)<0d0)then
     if(.not.matrix_available(node))return
     if(.not.all(ieee_is_finite([matrix_t0(node),matrix_t1(node)])))return
    end if
   end do
   if(face(id,1)>0d0)then
    if(.not.top_available(id))return
    if(.not.all(ieee_is_finite([top_t0(id),top_t1(id)])))return
   end if
   if(face(id,n+1)<0d0)then
    if(.not.bottom_available(id))return
    if(.not.all(ieee_is_finite([bottom_t0(id),bottom_t1(id)])))return
   end if
  end do
  allocate(temperature(nd,n),matrix_energy(nd,n),before(n),after(n),old(n),new(n),lower(n),diagonal(n),upper(n),rhs(n),gamma(n),qenergy(n+1))
  temperature=0d0;matrix_energy=0d0
  where(w0>0d0)temperature=t_initial
  stock0=capacity*sum(w0*temperature);external_energy=0d0;h=dt/real(substeps,real64)
  do k=1,substeps
   s0=real(k-1,real64)/substeps;s1=real(k,real64)/substeps
   do id=1,nd
    before=(1d0-s0)*w0(id,:)+s0*w1(id,:);after=(1d0-s1)*w0(id,:)+s1*w1(id,:);old=temperature(id,:)
    lower=0d0;diagonal=after;upper=0d0;rhs=before*old
    do node=1,n
     diagonal(node)=diagonal(node)+h*(max(0d0,-face(id,node))+max(0d0,face(id,node+1))+max(0d0,exchange(id,node))+external_out(id,node))
     if(node>1)lower(node)=-h*max(0d0,face(id,node))
     if(node<n)upper(node)=-h*max(0d0,-face(id,node+1))
     if(exchange(id,node)<0d0)then
      tm=(1d0-s1)*matrix_t0(node)+s1*matrix_t1(node);rhs(node)=rhs(node)-h*exchange(id,node)*tm
     end if
    end do
    if(face(id,1)>0d0)then
     tt=(1d0-s1)*top_t0(id)+s1*top_t1(id);rhs(1)=rhs(1)+h*face(id,1)*tt
    end if
    if(face(id,n+1)<0d0)then
     tb=(1d0-s1)*bottom_t0(id)+s1*bottom_t1(id);rhs(n)=rhs(n)-h*face(id,n+1)*tb
    end if
    do node=1,n
     if(diagonal(node)==0d0)then
      if(rhs(node)/=0d0.or.lower(node)/=0d0.or.upper(node)/=0d0)return
      diagonal(node)=1d0
     end if
    end do
    call reference_tridag(n,lower,diagonal,upper,rhs,new,gamma,error,capture_in_gamma_requested=.false.)
    if(error/=0.or.any(.not.ieee_is_finite(new)))return
    temperature(id,:)=new
    do node=1,n
     if(exchange(id,node)>=0d0)then
      matrix_energy(id,node)=matrix_energy(id,node)+capacity*h*exchange(id,node)*new(node)
     else
      tm=(1d0-s1)*matrix_t0(node)+s1*matrix_t1(node)
      matrix_energy(id,node)=matrix_energy(id,node)+capacity*h*exchange(id,node)*tm
     end if
     external_energy=external_energy-capacity*h*external_out(id,node)*new(node)
    end do
    if(face(id,1)>0d0)then
     external_energy=external_energy+capacity*h*face(id,1)*tt
    else
     external_energy=external_energy+capacity*h*face(id,1)*new(1)
    end if
    if(face(id,n+1)<0d0)then
     external_energy=external_energy-capacity*h*face(id,n+1)*tb
    else
     external_energy=external_energy-capacity*h*face(id,n+1)*new(n)
    end if
   end do
  end do
  stock1=capacity*sum(w1*temperature)
  result%stock_change_j_cm2=stock1-stock0;result%external_net_into_j_cm2=external_energy
  result%residual_j_cm2=stock1-stock0+sum(matrix_energy)-external_energy
  if(abs(result%residual_j_cm2)>1d-10*max(1d0,abs(stock0),abs(stock1),abs(external_energy)))return
  result%temperature_c=temperature;result%matrix_energy_j_cm2=matrix_energy;result%produced=.true.
 end subroutine
end module
