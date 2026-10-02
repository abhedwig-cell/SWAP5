! Test-only distributed layer. Evaluation reads an immutable physical origin.
module mod_top03_stateful_contact
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters, evaluate_b110_default_mvg_conductivity, &
       b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_soil_water_solver_contract, only: dynamic_top_boundary_provider_t, soil_water_parameter_set_t, &
       soil_water_boundary_conditions_t, soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE, &
       SW_TOP_BOUNDARY_UNAVAILABLE, SW_TOP_BOUNDARY_REGIME_HEAD
  implicit none
  private
  integer,parameter,public :: CONTACT_AVAILABLE=1,CONTACT_INVALID=2,CONTACT_NO_ROOT=3, &
       CONTACT_BRANCH_UNAVAILABLE=4,CONTACT_SEED_DISAGREEMENT=5
  real(real64),parameter :: ROOT_TOL=1e-11_real64
  type,public :: top03_stateful_result_t
    integer :: status=CONTACT_INVALID,iterations=0
    real(real64) :: q=0,interface_head=0,interface_head_other=0,dq_dsoil_head=0,dinterface_dsoil_head=0
    real(real64) :: max_face_residual=huge(1.0_real64),soil_k=0,seed_head_difference=0,seed_flux_difference=0
    real(real64) :: bound_stage=0,bound_hs=0,bound_dt=0
    integer :: bound_policy=-1
    real(real64) :: external_input=0,matrix_input=0,storage_change=0,mass_error=0
    real(real64),allocatable :: head(:),theta(:),k(:),flux(:),origin_head(:)
  end type
  type,extends(dynamic_top_boundary_provider_t),public :: top03_stateful_contact_t
    type(soil_water_parameter_set_t),pointer :: geometry=>null()
    type(b110_default_mvg_parameters_t),pointer :: soil=>null()
    type(b110_default_mvg_parameters_t) :: layer
    real(real64),allocatable :: origin_head(:),origin_theta(:),origin_k(:)
    real(real64) :: dt=0,origin_soil_k=0
    integer :: conductivity_policy=0
    real(real64) :: stage=0,thickness=0,resistance=0
    integer :: layer_nodes=0
  contains
    procedure :: evaluate => evaluate_contact_boundary
    procedure :: solve => solve_contact
  end type
  public :: bind_top03_stateful_contact, bind_top03_layer_origin, validate_top03_layer_candidate
contains
  subroutine bind_top03_stateful_contact(self,geometry,soil,stage,thickness,resistance,nodes)
    type(top03_stateful_contact_t),intent(out) :: self
    type(soil_water_parameter_set_t),target,intent(in) :: geometry
    type(b110_default_mvg_parameters_t),target,intent(in) :: soil
    real(real64),intent(in) :: stage,thickness,resistance
    integer,intent(in) :: nodes
    real(real64),allocatable :: c(:,:)
    self%geometry=>geometry;self%soil=>soil;self%stage=stage
    self%thickness=thickness;self%resistance=resistance;self%layer_nodes=nodes
    if(nodes<1.or.thickness<=0.or.resistance<=0) return
    c=spread(soil%cofgen(1:24,1),2,nodes)
    c(3,:)=thickness/resistance;c(10,:)=c(3,:);c(12,:)=0.99_real64*c(3,:)
    call initialize_b110_default_mvg_parameters(self%layer,c)
  end subroutine

  subroutine bind_top03_layer_origin(self,head,soil_head,dt,policy)
    type(top03_stateful_contact_t),intent(inout) :: self
    real(real64),intent(in) :: head(:),soil_head,dt
    integer,intent(in) :: policy
    real(real64) :: cap(size(head)),dk(size(head))
    logical :: ok
    if(size(head)/=self%layer_nodes.or.dt<=0.or.policy<0.or.policy>1)error stop 'invalid layer origin'
    self%origin_head=head;self%dt=dt;self%conductivity_policy=policy
    self%origin_theta=head;self%origin_k=head
    call storage(self,head,self%origin_theta,cap)
    block
      integer :: j
      do j=1,size(head)
        call evaluate_b110_default_mvg_conductivity(self%layer,j,head(j),self%origin_k(j),ok)
        if(.not.ok)error stop 'invalid layer K'
      end do
    end block
    call evaluate_b110_default_mvg_conductivity(self%soil,1,soil_head,self%origin_soil_k,ok)
    if(.not.ok)error stop 'invalid soil origin conductivity'
  end subroutine

  subroutine storage(self,h,theta,capacity)
    class(top03_stateful_contact_t),intent(in) :: self
    real(real64),intent(in) :: h(:)
    real(real64),intent(out) :: theta(:),capacity(:)
    type(b110_default_mvg_parameters_t),target :: parameters
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: k(size(h)),dk(size(h))
    parameters=self%layer
    call bind_b110_default_mvg_provider(provider,parameters,self%dt)
    call provider%evaluate(h,theta,k,capacity,dk)
  end subroutine

  subroutine k_and_slope(p,node,h,k,dk,ok)
    type(b110_default_mvg_parameters_t),intent(in) :: p
    integer,intent(in) :: node
    real(real64),intent(in) :: h
    real(real64),intent(out) :: k,dk
    logical,intent(out) :: ok
    real(real64) :: eps,kp,km,ks
    logical :: plus_ok,minus_ok,same_plus,same_minus
    integer :: j
    call evaluate_b110_default_mvg_conductivity(p,node,h,k,ok)
    dk=0
    if(.not.ok.or.k<=0)return
    ks=p%cofgen(3,node);eps=max(1e-6_real64,1e-6_real64*abs(h))
    do j=1,20
      call evaluate_b110_default_mvg_conductivity(p,node,h+eps,kp,plus_ok)
      call evaluate_b110_default_mvg_conductivity(p,node,h-eps,km,minus_ok)
      if(.not.plus_ok.or..not.minus_ok)then
        ok=.false.;return
      end if
      same_plus=(kp==ks).eqv.(k==ks);same_minus=(km==ks).eqv.(k==ks)
      if(same_plus.and.same_minus)then
        dk=(kp-km)/(2*eps);return
      end if
      eps=0.5_real64*eps
    end do
    ! Never differentiate across the actual B1.10 conductivity discontinuity.
    ok=.false.
  end subroutine

  subroutine faces(self,hs,h,k,dk,q,left,right,ok,slopes)
    class(top03_stateful_contact_t),intent(in) :: self
    real(real64),intent(in) :: hs,h(:)
    real(real64),intent(out) :: k(:),dk(:),q(:),left(:),right(:)
    logical,intent(out) :: ok
    logical,intent(in) :: slopes
    real(real64) :: dz,d,ks,dks,g,delta,zup,zdown,up,down,aup,adown
    integer :: i,n
    logical :: good
    n=self%layer_nodes;dz=self%thickness/real(n,real64);d=self%geometry%node_distance(1)
    ok=.false.;left=0;right=0;dk=0
    do i=1,n
      if(slopes.and.(self%conductivity_policy==1.or.i==1))then
        call k_and_slope(self%layer,i,h(i),k(i),dk(i),good)
      else
        call evaluate_b110_default_mvg_conductivity(self%layer,i,h(i),k(i),good)
      end if
      if(.not.good.or.k(i)<=0)return
    end do
    dks=0
    if(slopes.and.self%conductivity_policy==1)then
      call k_and_slope(self%soil,1,hs,ks,dks,good)
    else
      call evaluate_b110_default_mvg_conductivity(self%soil,1,hs,ks,good)
    end if
    if(.not.good.or.ks<=0)return
    g=(self%layer%cofgen(3,1)+k(1))/dz
    delta=h(1)+self%thickness-0.5_real64*dz-(self%stage+self%thickness)
    q(1)=g*delta;right(1)=g+delta*dk(1)/dz
    if(self%conductivity_policy==0)then
      k=self%origin_k;dk=0;ks=self%origin_soil_k;dks=0
    end if
    do i=2,n+1
      up=k(i-1);aup=0.5_real64*dz;zup=self%thickness-(real(i,real64)-1.5_real64)*dz
      if(i<=n)then
        down=k(i);adown=0.5_real64*dz;zdown=zup-dz
        delta=h(i)+zdown-h(i-1)-zup
      else
        down=ks;adown=d
        delta=hs+self%geometry%z(1)-h(n)-zup
      end if
      g=1.0_real64/(aup/up+adown/down)
      q(i)=g*delta
      left(i)=-g+delta*g*g*aup*dk(i-1)/(up*up)
      if(i<=n)then
        right(i)=g+delta*g*g*adown*dk(i)/(down*down)
      else
        right(i)=g+delta*g*g*adown*dks/(down*down)
      end if
    end do
    ok=all(ieee_is_finite(q)).and.all(ieee_is_finite(left)).and.all(ieee_is_finite(right))
  end subroutine

  subroutine tridiagonal(upper,diagonal,lower,rhs,x,ok)
    real(real64),intent(in) :: upper(:),diagonal(:),lower(:),rhs(:)
    real(real64),intent(out) :: x(:)
    logical,intent(out) :: ok
    real(real64) :: c(size(rhs)),b(size(rhs)),v(size(rhs)),f
    integer :: i,n
    n=size(rhs);b=diagonal;c=lower;v=rhs;ok=.false.
    do i=2,n
      if(abs(b(i-1))<1e-20_real64)return
      f=upper(i)/b(i-1);b(i)=b(i)-f*c(i-1);v(i)=v(i)-f*v(i-1)
    end do
    if(abs(b(n))<1e-20_real64)return
    x(n)=v(n)/b(n)
    do i=n-1,1,-1
      x(i)=(v(i)-c(i)*x(i+1))/b(i)
    end do
    ok=all(ieee_is_finite(x))
  end subroutine

  subroutine solve_one(self,hs,seed,result)
    class(top03_stateful_contact_t),intent(in) :: self
    real(real64),intent(in) :: hs
    integer,intent(in) :: seed
    type(top03_stateful_result_t),intent(out) :: result
    real(real64),allocatable :: h(:),k(:),dk(:),q(:),left(:),right(:),f(:),upper(:),diagonal(:),lower(:), &
         rhs(:),step(:),trial(:),sensitivity(:),lo(:),hi(:),theta(:),cap(:),tt(:),cc(:)
    real(real64) :: dz,d,es,et,z,ks,dks,totalr,partial,lambda,norm,newnorm
    integer :: i,n,it,bt,polish
    logical :: ok,good,accepted
    result=top03_stateful_result_t();n=self%layer_nodes
    if(.not.associated(self%soil).or..not.associated(self%geometry))return
    if(.not.allocated(self%origin_head).or.self%dt<=0)return
    if(n<1.or.self%stage<=0.or.self%thickness<=0.or.self%resistance<=0.or..not.ieee_is_finite(hs))return
    d=self%geometry%node_distance(1)
    if(d<=0.or.abs(self%geometry%z(1)+d)>1e-12_real64)return
    call k_and_slope(self%soil,1,hs,ks,dks,ok)
    if(.not.ok.or.ks<=0)then
      result%status=CONTACT_BRANCH_UNAVAILABLE;return
    end if
    if(self%conductivity_policy==0)then
      ks=self%origin_soil_k;dks=0
    end if
    allocate(h(n),k(n),dk(n),q(n+1),left(n+1),right(n+1),f(n),upper(n),diagonal(n),lower(n), &
         rhs(n),step(n),trial(n),sensitivity(n),lo(n),hi(n),theta(n),cap(n),tt(n),cc(n))
    dz=self%thickness/real(n,real64);es=hs-d;et=self%stage+self%thickness
    totalr=self%resistance+d/ks
    do i=1,n
      z=self%thickness-(real(i,real64)-0.5_real64)*dz
      partial=(self%thickness-z)/(self%thickness/self%resistance)
      lo(i)=min(es,et,minval(self%origin_head))-self%thickness;hi(i)=max(es,et,maxval(self%origin_head))+self%thickness
      h(i)=self%origin_head(i)
      if(seed==1)h(i)=max(lo(i),min(hi(i),-123.0_real64))
      if(seed==2)h(i)=max(lo(i),min(hi(i),0.0_real64))
    end do
    result%status=CONTACT_NO_ROOT;polish=0
    do it=1,100
      result%iterations=it
      call faces(self,hs,h,k,dk,q,left,right,ok,.true.)
      if(.not.ok)then
        result%status=CONTACT_BRANCH_UNAVAILABLE;return
      end if
      call storage(self,h,theta,cap)
      f=dz*(theta-self%origin_theta)/self%dt+q(1:n)-q(2:n+1);norm=maxval(abs(f))
      if(norm<=ROOT_TOL)then
        polish=polish+1
        if(polish>=4)exit
      else
        polish=0
      end if
      upper=0;lower=0
      do i=1,n
        diagonal(i)=dz*cap(i)/self%dt+right(i)-left(i+1)
        if(i>1)upper(i)=left(i)
        if(i<n)lower(i)=-right(i+1)
      end do
      call tridiagonal(upper,diagonal,lower,-f,step,ok)
      if(.not.ok)return
      lambda=1;accepted=.false.
      do bt=1,40
        trial=h+lambda*step
        if(all(trial>=lo).and.all(trial<=hi))then
          call faces(self,hs,trial,k,dk,q,left,right,good,.false.)
          if(good)then
            call storage(self,trial,tt,cc)
            newnorm=maxval(abs(dz*(tt-self%origin_theta)/self%dt+q(1:n)-q(2:n+1)))
            if(newnorm<=ROOT_TOL.or.newnorm<(1.0_real64-1e-4_real64*lambda)*norm)then
              h=trial;accepted=.true.;exit
            end if
          end if
        end if
        lambda=0.5_real64*lambda
      end do
      if(.not.accepted)return
    end do
    if(it>100)return
    ! Rebuild the candidate-K Jacobian and condense its pressure response.
    call faces(self,hs,h,k,dk,q,left,right,ok,.true.)
    if(.not.ok)then
      result%status=CONTACT_BRANCH_UNAVAILABLE;return
    end if
    upper=0;lower=0;rhs=0
    do i=1,n
      diagonal(i)=dz*cap(i)/self%dt+right(i)-left(i+1)
      if(i>1)upper(i)=left(i)
      if(i<n)lower(i)=-right(i+1)
    end do
    rhs(n)=right(n+1)
    call tridiagonal(upper,diagonal,lower,rhs,sensitivity,ok)
    if(.not.ok)return
    result%q=q(n+1);result%soil_k=ks
    result%dq_dsoil_head=left(n+1)*sensitivity(n)+right(n+1)
    result%interface_head=es-result%q*d/ks
    result%interface_head_other=h(n)+0.5_real64*dz+result%q*0.5_real64*dz/k(n)
    result%dinterface_dsoil_head=1.0_real64-result%dq_dsoil_head*d/ks+result%q*d*dks/(ks*ks)
    call storage(self,h,theta,cap)
    result%origin_head=self%origin_head;result%bound_stage=self%stage;result%bound_hs=hs
    result%bound_dt=self%dt;result%bound_policy=self%conductivity_policy
    result%head=h;result%theta=theta;result%k=k;result%flux=q
    result%max_face_residual=maxval(abs(dz*(theta-self%origin_theta)/self%dt+q(1:n)-q(2:n+1)))
    result%external_input=-self%dt*q(1);result%matrix_input=-self%dt*q(n+1)
    result%storage_change=sum(dz*(theta-self%origin_theta))
    result%mass_error=result%storage_change-result%external_input+result%matrix_input
    result%status=CONTACT_AVAILABLE
  end subroutine

  subroutine solve_contact(self,hs,result,seed)
    class(top03_stateful_contact_t),intent(in) :: self
    real(real64),intent(in) :: hs
    type(top03_stateful_result_t),intent(out) :: result
    integer,intent(in),optional :: seed
    integer :: j
    type(top03_stateful_result_t) :: alternate
    if(present(seed))then
      call solve_one(self,hs,seed,result);return
    end if
    call solve_one(self,hs,0,result)
  end subroutine

  logical function validate_top03_layer_candidate(self,hs,candidate) result(valid)
    class(top03_stateful_contact_t),intent(in) :: self
    real(real64),intent(in) :: hs
    type(top03_stateful_result_t),intent(in) :: candidate
    real(real64) :: k(self%layer_nodes),dk(self%layer_nodes),q(self%layer_nodes+1), &
         left(self%layer_nodes+1),right(self%layer_nodes+1),theta(self%layer_nodes),cap(self%layer_nodes),dz
    logical :: ok
    integer :: n
    valid=.false.;n=self%layer_nodes
    if(candidate%status/=CONTACT_AVAILABLE)return
    if(.not.allocated(candidate%head).or..not.allocated(candidate%theta).or. &
         .not.allocated(candidate%origin_head).or..not.allocated(candidate%flux))return
    if(size(candidate%head)/=n.or.size(candidate%theta)/=n.or.size(candidate%origin_head)/=n.or.size(candidate%flux)/=n+1)return
    if(any(candidate%origin_head/=self%origin_head).or.candidate%bound_stage/=self%stage.or. &
         candidate%bound_hs/=hs.or.candidate%bound_dt/=self%dt.or.candidate%bound_policy/=self%conductivity_policy)return
    if(.not.all(ieee_is_finite([candidate%q,candidate%external_input,candidate%matrix_input,candidate%storage_change])))return
    if(.not.all(ieee_is_finite(candidate%head)).or..not.all(ieee_is_finite(candidate%flux)).or. &
         .not.all(ieee_is_finite(candidate%theta)))return
    call faces(self,hs,candidate%head,k,dk,q,left,right,ok,.false.)
    if(.not.ok)return
    call storage(self,candidate%head,theta,cap);dz=self%thickness/real(n,real64)
    if(maxval(abs(dz*(theta-self%origin_theta)/self%dt+q(1:n)-q(2:n+1)))>ROOT_TOL)return
    if(maxval(abs(q-candidate%flux))>1e-10_real64.or.maxval(abs(theta-candidate%theta))>1e-12_real64)return
    if(abs(candidate%q-q(n+1))>1e-10_real64)return
    if(abs(candidate%external_input+self%dt*q(1))>1e-11_real64.or. &
         abs(candidate%matrix_input+self%dt*q(n+1))>1e-11_real64.or. &
         abs(candidate%storage_change-sum(dz*(theta-self%origin_theta)))>1e-11_real64)return
    valid=abs(candidate%external_input-candidate%matrix_input-candidate%storage_change)<=1e-11_real64
  end function

  subroutine evaluate_contact_boundary(self,pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    class(top03_stateful_contact_t),intent(in) :: self
    real(real64),intent(in) :: pressure_head_top,water_content_top,candidate_ponding_depth
    type(soil_water_boundary_conditions_t),intent(in) :: requested
    type(soil_water_top_boundary_result_t),intent(out) :: result
    type(top03_stateful_result_t) :: local
    result=soil_water_top_boundary_result_t();result%status=SW_TOP_BOUNDARY_UNAVAILABLE
    result%route='top03-nonlinear-contact-unavailable'
    if(.not.all(ieee_is_finite([pressure_head_top,water_content_top,candidate_ponding_depth])))return
    call self%solve(pressure_head_top,local)
    if(local%status/=CONTACT_AVAILABLE)then
      write(*,'(A,2(1X,ES24.16),1X,I0)')'CONTACT_UNAVAILABLE',self%stage,pressure_head_top,local%status
      return
    end if
    result%status=SW_TOP_BOUNDARY_AVAILABLE;result%regime=SW_TOP_BOUNDARY_REGIME_HEAD
    result%surface_head=local%interface_head;result%surface_face_conductivity=local%soil_k
    result%actual_top_flux=local%q;result%candidate_ponding_depth=self%stage
    result%surface_head_derivative_available=.true.
    result%surface_head_dpressure_head_top=local%dinterface_dsoil_head
    result%external_surface_head_imposed=.true.;result%carries_surface_mass_terms=.true.
    result%runoff_resolved=.true.;result%route='top03-nonlinear-layer-contact'
    ! HeadCalc's SWKIMPL=0 Jacobian treats K_face as fixed. The true interface
    ! head derivative is supplied; no fictitious derivative or production edit.
  end subroutine
end module
