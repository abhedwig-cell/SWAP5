! Research only: integrate the actual stationary Darcy law, including K's jump.
module mod_top03_continuous_contact
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters, evaluate_b110_default_mvg_conductivity
  use mod_soil_water_solver_contract, only: dynamic_top_boundary_provider_t, soil_water_parameter_set_t, &
       soil_water_boundary_conditions_t, soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE, &
       SW_TOP_BOUNDARY_UNAVAILABLE, SW_TOP_BOUNDARY_REGIME_HEAD
  implicit none
  private
  integer,parameter,public :: CONTACT_AVAILABLE=1,CONTACT_INVALID=2,CONTACT_UNCONVERGED=3,CONTACT_BRANCH_UNAVAILABLE=4
  type,public :: top03_continuous_result_t
    integer :: status=CONTACT_INVALID,iterations=0
    real(real64) :: q=0,interface_head=0,dq_dsoil_head=0,dinterface_dsoil_head=0,soil_k=0
    real(real64) :: length_residual=huge(1.0_real64),flux_identity_error=huge(1.0_real64)
    real(real64) :: seed_head_difference=0,seed_flux_difference=0
  end type
  type,extends(dynamic_top_boundary_provider_t),public :: top03_continuous_contact_t
    type(soil_water_parameter_set_t),pointer :: geometry=>null()
    type(b110_default_mvg_parameters_t),pointer :: soil=>null()
    type(b110_default_mvg_parameters_t) :: layer
    real(real64) :: stage=0,thickness=0,resistance=0,cut_head=0
    integer :: layer_nodes=0
  contains
    procedure :: evaluate => evaluate_boundary
    procedure :: solve => solve_contact
  end type
  public :: bind_top03_continuous_contact
contains
  subroutine bind_top03_continuous_contact(self,geometry,soil,stage,thickness,resistance,nodes)
    type(top03_continuous_contact_t),intent(out) :: self
    type(soil_water_parameter_set_t),target,intent(in) :: geometry
    type(b110_default_mvg_parameters_t),target,intent(in) :: soil
    real(real64),intent(in) :: stage,thickness,resistance
    integer,intent(in) :: nodes
    real(real64),allocatable :: c(:,:)
    real(real64) :: lo,hi,mid,k
    integer :: i
    logical :: ok
    self%geometry=>geometry;self%soil=>soil;self%stage=stage
    self%thickness=thickness;self%resistance=resistance;self%layer_nodes=nodes
    if(nodes<1.or.thickness<=0.or.resistance<=0)return
    c=spread(soil%cofgen(1:24,1),2,nodes)
    c(3,:)=thickness/resistance;c(10,:)=c(3,:);c(12,:)=0.99_real64*c(3,:)
    call initialize_b110_default_mvg_parameters(self%layer,c)
    ! Locate the actual public evaluator's saturation switch; no smoothed K.
    lo=-1.0_real64;hi=0.0_real64
    do i=1,80
      mid=0.5_real64*(lo+hi)
      if(mid==lo.or.mid==hi)exit
      call evaluate_b110_default_mvg_conductivity(self%layer,1,mid,k,ok)
      if(.not.ok)return
      if(k==self%layer%cofgen(3,1))then
        hi=mid
      else
        lo=mid
      end if
    end do
    self%cut_head=hi
  end subroutine

  subroutine soil_k_slope(self,h,k,dk,ok)
    class(top03_continuous_contact_t),intent(in) :: self
    real(real64),intent(in) :: h
    real(real64),intent(out) :: k,dk
    logical,intent(out) :: ok
    real(real64) :: eps,plus,minus,ks
    integer :: i
    logical :: p,m
    call evaluate_b110_default_mvg_conductivity(self%soil,1,h,k,ok)
    dk=0
    if(.not.ok.or.k<=0)return
    ks=self%soil%cofgen(3,1);eps=1e-6_real64*max(1.0_real64,abs(h))
    do i=1,20
      call evaluate_b110_default_mvg_conductivity(self%soil,1,h+eps,plus,p)
      call evaluate_b110_default_mvg_conductivity(self%soil,1,h-eps,minus,m)
      if(.not.p.or..not.m)then
        ok=.false.;return
      end if
      if(((plus==ks).eqv.(k==ks)).and.((minus==ks).eqv.(k==ks)))then
        dk=(plus-minus)/(2*eps);return
      end if
      eps=0.5_real64*eps
    end do
    ok=.false.
  end subroutine

  subroutine gauss(self,j,a,b,v8,v16,ok)
    class(top03_continuous_contact_t),intent(in) :: self
    real(real64),intent(in) :: j,a,b
    real(real64),intent(out) :: v8(2),v16(2)
    logical,intent(out) :: ok
    real(real64),parameter :: x8(4)=[0.183434642495649805_real64,0.525532409916328986_real64, &
         0.796666477413626740_real64,0.960289856497536232_real64]
    real(real64),parameter :: w8(4)=[0.362683783378361983_real64,0.313706645877887287_real64, &
         0.222381034453374471_real64,0.101228536290376259_real64]
    real(real64),parameter :: x16(8)=[0.095012509837637440_real64,0.281603550779258913_real64, &
         0.458016777657227386_real64,0.617876244402643748_real64,0.755404408355003034_real64, &
         0.865631202387831744_real64,0.944575023073232576_real64,0.989400934991649933_real64]
    real(real64),parameter :: w16(8)=[0.189450610455068496_real64,0.182603415044923589_real64, &
         0.169156519395002538_real64,0.149595988816576733_real64,0.124628971255533872_real64, &
         0.095158511682492785_real64,0.062253523938647893_real64,0.027152459411754095_real64]
    real(real64) :: mid,half,h,k,f
    integer :: n,s
    logical :: good
    mid=0.5_real64*(a+b);half=0.5_real64*(b-a);v8=0;v16=0;ok=.false.
    do n=1,4
      do s=-1,1,2
        h=mid+real(s,real64)*half*x8(n)
        call evaluate_b110_default_mvg_conductivity(self%layer,1,h,k,good)
        if(.not.good.or.j<=k)return
        f=k/(j-k);v8=v8+w8(n)*[f,f/(j-k)]
      end do
    end do
    do n=1,8
      do s=-1,1,2
        h=mid+real(s,real64)*half*x16(n)
        call evaluate_b110_default_mvg_conductivity(self%layer,1,h,k,good)
        if(.not.good.or.j<=k)return
        f=k/(j-k);v16=v16+w16(n)*[f,f/(j-k)]
      end do
    end do
    v8=v8*half;v16=v16*half;ok=.true.
  end subroutine

  recursive subroutine adaptive_integral(self,j,a,b,depth,value,ok)
    class(top03_continuous_contact_t),intent(in) :: self
    real(real64),intent(in) :: j,a,b
    integer,intent(in) :: depth
    real(real64),intent(out) :: value(2)
    logical,intent(out) :: ok
    real(real64) :: v8(2),v16(2),left(2),right(2),mid
    logical :: good
    call gauss(self,j,a,b,v8,v16,ok)
    if(.not.ok)return
    if(abs(v16(1)-v8(1))<=1e-13_real64*(1+abs(v16(1))).and. &
         abs(v16(2)-v8(2))<=1e-12_real64*(1+abs(v16(2))))then
      value=v16;return
    end if
    if(depth>=20)then
      ok=.false.;return
    end if
    mid=0.5_real64*(a+b)
    call adaptive_integral(self,j,a,mid,depth+1,left,ok)
    if(.not.ok)return
    call adaptive_integral(self,j,mid,b,depth+1,right,good)
    ok=good
    if(ok)value=left+right
  end subroutine

  subroutine length_integral(self,j,interface,value,ok)
    class(top03_continuous_contact_t),intent(in) :: self
    real(real64),intent(in) :: j,interface
    real(real64),intent(out) :: value(2)
    logical,intent(out) :: ok
    real(real64) :: ks,v(2),end_unsat,start_sat
    ks=self%layer%cofgen(3,1);value=0;ok=.false.
    if(j<=ks.or.interface>self%stage)return
    if(interface<self%cut_head)then
      end_unsat=min(self%cut_head,self%stage)
      call adaptive_integral(self,j,interface,end_unsat,0,v,ok)
      if(.not.ok)return
      value=value+v
    end if
    start_sat=max(interface,self%cut_head)
    if(self%stage>start_sat)then
      value=value+(self%stage-start_sat)*[ks/(j-ks),ks/((j-ks)**2)]
    end if
    ok=all(ieee_is_finite(value))
  end subroutine

  subroutine solve_one(self,hs,seed,result)
    class(top03_continuous_contact_t),intent(in) :: self
    real(real64),intent(in) :: hs
    integer,intent(in) :: seed
    type(top03_continuous_result_t),intent(out) :: result
    real(real64) :: ks,ksoil,dks,d,rsoil,drsoil,es,jsat,j,lo,hi,next,iface,v(2),f,df,fi,ki,dj
    integer :: it
    logical :: ok
    result=top03_continuous_result_t()
    if(.not.associated(self%soil).or..not.associated(self%geometry))return
    if(self%stage<=0.or.self%thickness<=0.or.self%resistance<=0.or..not.ieee_is_finite(hs))return
    d=self%geometry%node_distance(1)
    if(d<=0.or.abs(self%geometry%z(1)+d)>1e-12_real64)return
    call soil_k_slope(self,hs,ksoil,dks,ok)
    if(.not.ok.or.ksoil<=0)then
      result%status=CONTACT_BRANCH_UNAVAILABLE;return
    end if
    ks=self%layer%cofgen(3,1);es=hs-d;rsoil=d/ksoil;drsoil=-d*dks/(ksoil*ksoil)
    jsat=(self%stage+self%thickness-es)/(self%resistance+rsoil)
    iface=es+jsat*rsoil
    if(iface>=self%cut_head)then
      j=jsat;dj=(-1.0_real64-j*drsoil)/(self%resistance+rsoil)
      result%length_residual=0;result%iterations=0
    else
      if(jsat<=ks)then
        result%status=CONTACT_UNCONVERGED;return
      end if
      lo=ks*(1+1e-12_real64);hi=jsat;j=0.5_real64*(lo+hi)
      if(seed==1)j=lo+0.9_real64*(hi-lo)
      if(seed==2)j=lo+0.1_real64*(hi-lo)
      result%status=CONTACT_UNCONVERGED
      do it=1,60
        iface=es+j*rsoil
        call length_integral(self,j,iface,v,ok)
        if(.not.ok)return
        f=v(1)-self%thickness
        call evaluate_b110_default_mvg_conductivity(self%layer,1,iface,ki,ok)
        if(.not.ok.or.j<=ki)return
        fi=ki/(j-ki);df=-rsoil*fi-v(2)
        if(abs(f)<=1e-12_real64)exit
        if(f>0)then
          lo=j
        else
          hi=j
        end if
        next=j-f/df
        if(next<=lo.or.next>=hi)next=0.5_real64*(lo+hi)
        j=next
      end do
      if(it>60)return
      result%iterations=it;result%length_residual=abs(f)
      dj=fi*(1+j*drsoil)/df
    end if
    result%q=-j;result%soil_k=ksoil;result%interface_head=es+j*rsoil
    result%dq_dsoil_head=-dj;result%dinterface_dsoil_head=1+dj*rsoil+j*drsoil
    result%flux_identity_error=abs(result%q+ksoil*((result%interface_head-hs)/d+1))
    if(.not.all(ieee_is_finite([result%q,result%interface_head,result%dq_dsoil_head, &
         result%dinterface_dsoil_head,result%length_residual])))return
    result%status=CONTACT_AVAILABLE
  end subroutine

  subroutine solve_contact(self,hs,result,seed)
    class(top03_continuous_contact_t),intent(in) :: self
    real(real64),intent(in) :: hs
    type(top03_continuous_result_t),intent(out) :: result
    integer,intent(in),optional :: seed
    type(top03_continuous_result_t) :: other
    integer :: i
    if(present(seed))then
      call solve_one(self,hs,seed,result);return
    end if
    call solve_one(self,hs,0,result)
    if(result%status/=CONTACT_AVAILABLE)return
    do i=1,2
      call solve_one(self,hs,i,other)
      if(other%status/=CONTACT_AVAILABLE)then
        result%status=CONTACT_UNCONVERGED;return
      end if
      result%seed_flux_difference=max(result%seed_flux_difference,abs(result%q-other%q))
      result%seed_head_difference=max(result%seed_head_difference,abs(result%interface_head-other%interface_head))
    end do
    if(result%seed_flux_difference>1e-9_real64.or.result%seed_head_difference>1e-7_real64)result%status=CONTACT_UNCONVERGED
  end subroutine

  subroutine evaluate_boundary(self,pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    class(top03_continuous_contact_t),intent(in) :: self
    real(real64),intent(in) :: pressure_head_top,water_content_top,candidate_ponding_depth
    type(soil_water_boundary_conditions_t),intent(in) :: requested
    type(soil_water_top_boundary_result_t),intent(out) :: result
    type(top03_continuous_result_t) :: local
    result=soil_water_top_boundary_result_t();result%status=SW_TOP_BOUNDARY_UNAVAILABLE
    result%route='top03-continuous-contact-unavailable'
    if(.not.all(ieee_is_finite([pressure_head_top,water_content_top,candidate_ponding_depth])))return
    call self%solve(pressure_head_top,local)
    if(local%status/=CONTACT_AVAILABLE)then
      write(*,'(A,2(1X,ES24.16),1X,I0)')'CONTACT_UNAVAILABLE',self%stage,pressure_head_top,local%status
      return
    end if
    result%status=SW_TOP_BOUNDARY_AVAILABLE;result%regime=SW_TOP_BOUNDARY_REGIME_HEAD
    result%surface_head=local%interface_head;result%surface_face_conductivity=local%soil_k
    result%actual_top_flux=local%q;result%candidate_ponding_depth=self%stage
    result%surface_head_derivative_available=.true.;result%surface_head_dpressure_head_top=local%dinterface_dsoil_head
    result%external_surface_head_imposed=.true.;result%carries_surface_mass_terms=.true.
    result%runoff_resolved=.true.;result%route='top03-continuous-layer-contact'
  end subroutine
end module
