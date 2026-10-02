program top03_stateful_contact_probe
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_top03_microrelief_top_provider, only: bind_top03_microrelief_provider
  use mod_top03_explicit_layer_provider, only: top03_layer_contact_provider_t
  use mod_top03_stateful_contact, only: top03_nonlinear_contact_t=>top03_stateful_contact_t, &
       top03_contact_result_t=>top03_stateful_result_t,bind_top03_nonlinear_contact=>bind_top03_stateful_contact, &
       bind_top03_layer_origin,validate_top03_layer_candidate,CONTACT_AVAILABLE
  implicit none
  type(soil_water_parameter_set_t),target :: params
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: hyd
  type(b110_source_sink_provider_t),target :: source
  type(top03_layer_contact_provider_t),target :: top
  type(top03_nonlinear_contact_t),target :: contact
  type(top03_contact_result_t) :: local
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: sol
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cofgen(:,:),h0(:),theta0(:),conductivity(:),capacity(:),dkdh(:),origin(:),origin_theta(:)
  integer,allocatable :: parent(:)
  real(real64),parameter :: stages(6)=[0.005_real64,0.02_real64,0.05_real64,0.1_real64,0.2_real64,0.3_real64]
  real(real64),parameter :: widths(4)=[0.5_real64,0.5_real64,1.0_real64,1.0_real64]
  real(real64),parameter :: centers(4)=[-0.25_real64,-0.75_real64,-1.5_real64,-2.5_real64]
  real(real64) :: L,R,dt,H,position,ksoil,klayer,jexact,cumres,ktop,skin0,base0,skin,base,total0
  real(real64) :: top_input,bottom_out,max_mass,mass,base_delta,skin_delta,origin_pond,origin_gwl
  real(real64) :: contact_max_residual,contact_max_interface_error,contact_max_flux_error
  real(real64) :: parent_theta(4),parent_head(4),head_error,flux_error,qinterface
  integer :: policy=0
  real(real64),allocatable :: layer_origin(:),saved_layer(:)
  real(real64) :: matrix_input=0,layer_origin_mass=0
  integer :: mode,m,ns,wet,mean,analytic,n,nlayer,i,p,s,e,nstages,iterations
  character(len=80) :: arg
  call get_command_argument(1,arg);read(arg,*)mode
  call get_command_argument(2,arg);read(arg,*)L
  call get_command_argument(3,arg);read(arg,*)R
  call get_command_argument(4,arg);read(arg,*)m
  call get_command_argument(5,arg);read(arg,*)ns
  call get_command_argument(6,arg);read(arg,*)wet
  call get_command_argument(7,arg);read(arg,*)mean
  call get_command_argument(8,arg);read(arg,*)analytic
  if(mode<0.or.mode>6.or.m<1.or.ns<1.or.L<0.or.R<0) error stop 'invalid experiment arguments'
  if(mode==1.and.(L<=0.or.R<=0)) error stop 'explicit layer requires positive L/R'
  nlayer=0
  if(mode==1)nlayer=2*m
  n=nlayer+4*m
  allocate(params%z(n),params%dz(n),params%node_distance(n),parent(n))
  params%parameter_set_id=49010_int64;params%active_nodes=n
  parent=0;position=0.0_real64
  if(mode==1)then
    position=L
    do i=1,nlayer
      params%dz(i)=L/real(nlayer,real64)
      params%z(i)=position-0.5_real64*params%dz(i)
      position=position-params%dz(i)
    end do
  end if
  do p=1,4
    do s=1,m
      i=nlayer+(p-1)*m+s
      params%dz(i)=widths(p)/real(m,real64)
      params%z(i)=position-0.5_real64*params%dz(i)
      position=position-params%dz(i);parent(i)=p
    end do
  end do
  params%node_distance(1)=0.5_real64*params%dz(1)
  do i=2,n
    params%node_distance(i)=params%z(i-1)-params%z(i)
    if(abs(params%node_distance(i)-0.5_real64*(params%dz(i-1)+params%dz(i)))>1e-12_real64) &
         error stop 'inconsistent cell distances'
  end do
  if(abs(position+3.0_real64)>1e-12_real64.or.any(params%node_distance<=0)) error stop 'bad grid'
  if(abs(sum(params%dz(nlayer+1:n))-3.0_real64)>1e-12_real64) error stop 'bad underlying thickness'
  if(mode==1)then
    if(abs(sum(params%dz(1:nlayer))-L)>1e-12_real64) error stop 'bad layer thickness'
  end if
  allocate(cofgen(24,n),h0(n),theta0(n),conductivity(n),capacity(n),dkdh(n),origin(n),origin_theta(n))
  cofgen=0.0_real64;ksoil=4.75_real64;klayer=ksoil
  if(mode==1)klayer=L/R
  do i=1,n
    cofgen(1,i)=0.032_real64;cofgen(2,i)=0.423_real64;cofgen(3,i)=ksoil
    if(i<=nlayer)cofgen(3,i)=klayer
    cofgen(4,i)=0.0135_real64;cofgen(5,i)=0.365_real64;cofgen(6,i)=1.455_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i);cofgen(8,i)=cofgen(4,i)
    cofgen(9,i)=0.0_real64;cofgen(10,i)=cofgen(3,i);cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*cofgen(3,i);cofgen(22,i)=-1e6_real64;cofgen(23,i)=1e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  h0=-123.0_real64
  if(wet==1.and.mode==1)h0(1:nlayer)=0.0_real64
  H=stages(1);nstages=6
  if(analytic==1)then
    H=10.0_real64;nstages=1
    jexact=(H+L+3.0_real64-10.0_real64)/(R+3.0_real64/ksoil)
    do i=1,n
      if(i<=nlayer)then
        cumres=(L-params%z(i))/klayer
      else
        cumres=R-params%z(i)/ksoil
      end if
      h0(i)=H+L-params%z(i)-jexact*cumres
    end do
    if(any(h0<=0))error stop 'analytical control must be saturated'
  end if
  dt=0.03125_real64/real(ns,real64)
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  call hyd%evaluate(h0,theta0,conductivity,capacity,dkdh)
  if(mode==6)call bind_top03_nonlinear_contact(contact,params,hp,H,L,R,2*m)
  call get_command_argument(9,arg)
  if(len_trim(arg)>0)read(arg,*)policy
  if(mode==6)then
    allocate(layer_origin(2*m));layer_origin=merge(0.0_real64,-123.0_real64,wet==1)
    if(analytic==1)then
      do i=1,2*m
        position=L-(real(i,real64)-0.5_real64)*L/real(2*m,real64)
        layer_origin(i)=H+L-position-jexact*(L-position)/(L/R)
      end do
    end if
    call bind_top03_layer_origin(contact,layer_origin,h0(1),dt,policy)
    layer_origin_mass=sum(contact%origin_theta)*L/real(2*m,real64)
  end if
  if(analytic==2)then
    call lifecycle()
    stop
  end if
  allocate(qdra(1,n),qssdi(n),qrot(n));qdra=0;qssdi=0;qrot=0
  call bind_b110_source_sink_provider(source,qdra,qssdi,qrot)
  request%parameters=>params;request%base_state%active_nodes=n
  request%base_state%pressure_head=h0;request%base_state%water_content=theta0
  request%base_state%ponding_depth=0.0_real64;request%base_state%groundwater_level=-2.25_real64
  if(analytic==1)request%base_state%ponding_depth=H
  request%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
  request%boundary%bottom_mode=7
  request%boundary%bottom_head=-321.0_real64
  if(analytic==1)then
    request%boundary%bottom_mode=5;request%boundary%bottom_head=10.0_real64
  end if
  request%numerical%max_iterations=80
  request%numerical%max_backtracking=16
  request%numerical%conductivity_implicit_mode=0;request%numerical%conductivity_mean_method=mean
  request%numerical%min_step_duration=1e-6_real64
  request%numerical%head_abs_tolerance=1e-12_real64;request%numerical%head_rel_tolerance=1e-12_real64
  request%numerical%ponding_tolerance=1e-12_real64
  request%numerical%compartment_balance_tolerance=max(1e-12_real64,1e-12_real64/dt)
  request%numerical%total_balance_tolerance=request%numerical%compartment_balance_tolerance
  request%evaluation%constitutive=>hyd;request%evaluation%source_sink=>source;request%step_duration=dt
  base0=sum(theta0(nlayer+1:n)*params%dz(nlayer+1:n));skin0=0.0_real64
  if(nlayer>0)skin0=sum(theta0(1:nlayer)*params%dz(1:nlayer))
  if(mode==6)skin0=layer_origin_mass
  total0=base0+skin0+request%base_state%ponding_depth
  contact_max_residual=0;contact_max_interface_error=0;contact_max_flux_error=0
  top_input=0;bottom_out=0;max_mass=0;iterations=0;head_error=0;flux_error=0
  do e=1,nstages
    if(analytic==0)H=stages(e)
    call bind_top03_microrelief_provider(top%top03_microrelief_provider_t,params,hp,H,0.0_real64, &
         merge(R,0.0_real64,mode==2))
    top%eliminated_layer_thickness_cm=0.0_real64
    if(mode==2)top%eliminated_layer_thickness_cm=L
    if(mode==6)then
      contact%stage=H
      request%evaluation%dynamic_top_boundary=>contact
    else
      request%evaluation%dynamic_top_boundary=>top
    end if
    do s=1,ns
      origin=request%base_state%pressure_head;origin_theta=request%base_state%water_content
      origin_pond=request%base_state%ponding_depth;origin_gwl=request%base_state%groundwater_level
      if(mode==6)then
        call bind_top03_layer_origin(contact,layer_origin,origin(1),dt,policy)
        saved_layer=layer_origin
        call contact%solve(origin(1),local)
        if(local%status/=CONTACT_AVAILABLE)then
          write(*,'(A,3(1X,I0))')'STOP_CONTACT',e,s,local%status
          stop
        end if
      end if
      call solver%solve(request,workspace,sol)
      if(any(request%base_state%pressure_head/=origin).or.any(request%base_state%water_content/=origin_theta).or. &
           request%base_state%ponding_depth/=origin_pond.or.request%base_state%groundwater_level/=origin_gwl) &
           error stop 'solver mutated request origin'
      iterations=iterations+sol%diagnostics%nonlinear_iterations
      if(sol%status/=SW_SOLVE_CONVERGED)then
        write(*,'(A,4(1X,I0),1X,A)')'STOP',e,s,sol%status,iterations,trim(sol%diagnostics%route)
        stop
      end if
      if(.not.sol%integrated_mass_balance_residual_available)error stop 'missing typed mass residual'
      max_mass=max(max_mass,abs(sol%integrated_mass_balance_residual_cm))
      if(max_mass>1e-10_real64)error stop 'typed mass failure'
      if(analytic==1)then
        head_error=max(head_error,maxval(abs(sol%candidate_state%pressure_head-h0)))
        flux_error=max(flux_error,abs(sol%top_flux+jexact),abs(sol%bottom_flux+jexact))
      end if
      matrix_input=matrix_input-sol%top_flux*dt
      if(mode/=6)top_input=top_input-sol%top_flux*dt
      bottom_out=bottom_out-sol%bottom_flux*dt
      if(mode==6)then
        call contact%solve(sol%candidate_state%pressure_head(1),local)
        if(local%status/=CONTACT_AVAILABLE)error stop 'accepted contact unavailable'
        contact_max_residual=max(contact_max_residual,local%max_face_residual)
        contact_max_interface_error=max(contact_max_interface_error,abs(local%interface_head-local%interface_head_other))
        contact_max_flux_error=max(contact_max_flux_error,abs(local%q-sol%top_flux))
        if(contact_max_residual>1e-11_real64.or.contact_max_interface_error>1e-10_real64.or. &
             contact_max_flux_error>1e-10_real64)error stop 'candidate contact hard gate'
        if(any(layer_origin/=saved_layer).or.any(contact%origin_head/=saved_layer))error stop 'layer origin mutated'
        if(.not.validate_top03_layer_candidate(contact,sol%candidate_state%pressure_head(1),local))error stop 'invalid layer candidate'
        if(abs(local%mass_error)>1e-11_real64)error stop 'layer local mass failure'
        top_input=top_input+local%external_input
        layer_origin=local%head
      end if
      request%base_state=sol%candidate_state
    end do
    base=sum(request%base_state%water_content(nlayer+1:n)*params%dz(nlayer+1:n));skin=0
    if(nlayer>0)skin=sum(request%base_state%water_content(1:nlayer)*params%dz(1:nlayer))
    if(mode==6)skin=sum(local%theta)*L/real(2*m,real64)
    base_delta=base-base0;skin_delta=skin-skin0
    mass=base_delta+skin_delta-top_input+bottom_out
    if(abs(mass)>1e-10_real64)error stop 'independent soil mass failure'
    ! Parent-cell water means and pressure interpolated to identical physical centers.
    do p=1,4
      parent_theta(p)=sum(request%base_state%water_content,mask=parent==p)/real(m,real64)
      parent_head(p)=sample_head(centers(p),nlayer+1,n)
    end do
    qinterface=top_input-skin_delta
    write(*,'(A,1X,I0,17(1X,ES24.16),1X,I0)')'EVENT',e,top_input,bottom_out,base_delta,skin_delta, &
         request%base_state%ponding_depth,mass,max_mass,qinterface,H,parent_theta,parent_head,iterations
    if(mode==6.and.analytic==0)then
      write(*,'(A,2(1X,I0),6(1X,ES24.16))')'LAYER_BINDING',e,policy,H,origin(1), &
           sol%candidate_state%pressure_head(1),dt,local%external_input,local%matrix_input
      do i=1,2*m
        write(*,'(A,2(1X,I0),4(1X,ES24.16))')'LAYER_PROFILE',e,i,saved_layer(i),local%head(i),local%theta(i),local%flux(i)
      end do
      write(*,'(A,1X,I0,1X,ES24.16)')'LAYER_BOTTOM',e,local%flux(2*m+1)
    end if
    if(mode==6)write(*,'(A,1X,I0,5(1X,ES24.16))')'STATEFUL',e,contact_max_residual, &
         contact_max_interface_error,contact_max_flux_error,local%interface_head,local%q
    if(nlayer>0)then
      call hyd%evaluate(request%base_state%pressure_head,theta0,conductivity,capacity,dkdh)
      write(*,'(A,1X,I0,4(1X,ES24.16))')'LAYER',e,minval(request%base_state%pressure_head(1:nlayer)), &
           maxval(request%base_state%pressure_head(1:nlayer)),minval(conductivity(1:nlayer))/klayer, &
           maxval(conductivity(1:nlayer))/klayer
    end if
  end do
  if(analytic==1)write(*,'(A,3(1X,ES24.16))')'ANALYTIC',jexact,head_error,flux_error
  write(*,'(A)')'COMPLETE'
contains
  subroutine lifecycle()
    use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
    type(top03_contact_result_t) :: full,changed,replay,first,second,forged,continued,restarted
    type(top03_nonlinear_contact_t) :: restored
    real(real64),allocatable :: initial(:),saved_theta(:),checkpoint(:)
    real(real64) :: balance
    integer :: unit
    initial=layer_origin;dt=1e-4_real64
    call bind_top03_layer_origin(contact,initial,-123.0_real64,dt,0)
    saved_theta=contact%origin_theta
    call contact%solve(-123.0_real64,full)
    if(.not.validate_top03_layer_candidate(contact,-123.0_real64,full))error stop 'full lifecycle unavailable'
    call contact%solve(-120.0_real64,changed)
    if(.not.validate_top03_layer_candidate(contact,-120.0_real64,changed))error stop 'changed-head unavailable'
    if(validate_top03_layer_candidate(contact,-123.0_real64,changed))error stop 'changed-head receipt accepted'
    call contact%solve(-123.0_real64,replay)
    if(any(full%head/=replay%head).or.any(full%flux/=replay%flux))error stop 'same-origin replay differs'
    if(any(contact%origin_head/=initial).or.any(contact%origin_theta/=saved_theta))error stop 'rejected trial mutated origin'
    forged=full;forged%external_input=forged%external_input+0.001_real64
    if(validate_top03_layer_candidate(contact,-123.0_real64,forged))error stop 'forged transfer accepted'
    forged=full;forged%q=ieee_value(0.0_real64,ieee_quiet_nan)
    if(validate_top03_layer_candidate(contact,-123.0_real64,forged))error stop 'nonfinite flux accepted'
    forged=full;forged%storage_change=0.0_real64
    if(abs(full%storage_change)>1e-11_real64.and.validate_top03_layer_candidate(contact,-123.0_real64,forged))error stop 'lost storage accepted'
    forged=full;forged%head(1)=forged%head(1)+0.01_real64
    if(validate_top03_layer_candidate(contact,-123.0_real64,forged))error stop 'forged profile accepted'
    call bind_top03_layer_origin(contact,initial,-123.0_real64,dt/2,0)
    if(validate_top03_layer_candidate(contact,-123.0_real64,full))error stop 'wrong-dt candidate accepted'
    call contact%solve(-123.0_real64,first)
    if(.not.validate_top03_layer_candidate(contact,-123.0_real64,first))error stop 'half retry unavailable'
    call bind_top03_layer_origin(contact,first%head,-123.0_real64,dt/2,0)
    if(validate_top03_layer_candidate(contact,-123.0_real64,first))error stop 'stale origin candidate accepted'
    call contact%solve(-123.0_real64,second)
    if(.not.validate_top03_layer_candidate(contact,-123.0_real64,second))error stop 'second half unavailable'
    balance=first%external_input+second%external_input-first%matrix_input-second%matrix_input- &
         sum((second%theta-saved_theta)*L/real(2*m,real64))
    if(abs(balance)>1e-11_real64)error stop 'half composition mass failure'
    checkpoint=second%head
    open(newunit=unit,status='scratch',form='unformatted',action='readwrite')
    write(unit)L,R,m,contact%stage,dt,checkpoint
    rewind(unit)
    read(unit)L,R,m,H,dt,checkpoint
    close(unit)
    call bind_top03_nonlinear_contact(restored,params,hp,H,L,R,2*m)
    call bind_top03_layer_origin(restored,checkpoint,-123.0_real64,dt,0)
    call bind_top03_layer_origin(contact,second%head,-123.0_real64,dt,0)
    call contact%solve(-122.0_real64,continued);call restored%solve(-122.0_real64,restarted)
    if(.not.validate_top03_layer_candidate(contact,-122.0_real64,continued).or. &
         .not.validate_top03_layer_candidate(restored,-122.0_real64,restarted))error stop 'restart unavailable'
    if(any(continued%head/=restarted%head).or.any(continued%flux/=restarted%flux))error stop 'restart continuation differs'
    write(*,'(A,3(1X,ES24.16))')'LIFECYCLE_PASS',full%mass_error,balance,continued%mass_error
  end subroutine
  real(real64) function sample_head(at,first,last) result(value)
    real(real64),intent(in) :: at
    integer,intent(in) :: first,last
    integer :: k
    value=request%base_state%pressure_head(first)
    do k=first,last-1
      if(at<=params%z(k).and.at>=params%z(k+1))then
        value=request%base_state%pressure_head(k)+(request%base_state%pressure_head(k+1)- &
             request%base_state%pressure_head(k))*(at-params%z(k))/(params%z(k+1)-params%z(k))
        return
      end if
    end do
    if(at<params%z(last))value=request%base_state%pressure_head(last)
  end function
end program
