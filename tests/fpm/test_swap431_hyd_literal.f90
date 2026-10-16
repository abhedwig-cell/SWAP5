program test_swap431_hyd_literal
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use MOD_MvG,only:legacy_cofgen=>cofgen,iHWCKmodel,swsophy,sw_use_elas, &
      fl_use_tables,fl_use_kh_power,set_cofgen_pointers,calc_cofgen_extra,watcon,moiscap,hconduc,dhconduc
 use MOD_grid,only:numnod,layer
 use variables,only:dt
 use WC_K_models_04_11,only:BiModal,NoVap
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
      initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_b111_analytical_hydraulic_provider
 implicit none
 type(b110_default_mvg_parameters_t),target::mp
 type(b110_default_mvg_provider_t)::mv
 type(b111_analytical_hydraulic_parameters_t),target::p
 type(b111_analytical_hydraulic_provider_t)::provider
 real(real64)::input(24,numnod),h(numnod),theta(numnod),k(numnod),cap(numnod),dk(numnod)
 real(real64)::expected(4),actual(4),err(4),maximum(4),tol(4),heads(16)
 integer::kind,node,j,q,mismatches,cases,ik
 integer,parameter::kinds(4)=[2,3,6,1]
 maximum=0d0;mismatches=0;cases=0
 heads=[-1d5,-1d4,-1d3,-100.000001d0,-100d0,-99.999999d0,-10d0,-1d0,-0.01000001d0,-0.01d0,-0.00999999d0,-0.001d0,-0.0001d0,0d0,0.1d0,1d0]
 layer=[1,1,2,2];swsophy=0;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
 dt=1d-5;BiModal=.true.;NoVap=.true.
 do ik=1,size(kinds)
  kind=kinds(ik)
  input=0d0
  do node=1,numnod
   input(1,node)=0.05d0;input(2,node)=0.45d0;input(3,node)=10d0+node
   input(4,node)=0.015d0+0.002d0*node;input(5,node)=0.5d0
   input(6,node)=1.8d0;input(7,node)=1d0-1d0/input(6,node);input(8,node)=input(4,node)
   input(13,node)=0.05d0;input(14,node)=2.2d0;input(15,node)=1d0-1d0/input(14,node);input(16,node)=0.65d0;input(17,node)=1d0-input(16,node)
  end do
  legacy_cofgen=0d0;legacy_cofgen(1:24,1:numnod)=input;iHWCKmodel=kind
  call set_cofgen_pointers();call calc_cofgen_extra(numnod)
  if(kind==1)then
   do node=1,numnod
    input(22,node)=-100d0
    input(23,node)=hconduc(node,-100d0,watcon(node,-100d0),10d0)
   end do
   legacy_cofgen(22:23,1:numnod)=input(22:23,:);fl_use_kh_power=.true.
   call initialize_b110_default_mvg_parameters(mp,input,enable_conductivity_power_tail=.true.)
   call bind_b110_default_mvg_provider(mv,mp,dt)
  else
   fl_use_kh_power=.false.
   call initialize_b111_analytical_hydraulic_parameters(p,spread(kind,1,numnod),input)
   call bind_b111_analytical_hydraulic_provider(provider,p)
  end if
  do j=1,size(heads)
   h=heads(j)
   if(kind==1)then
    call mv%evaluate(h,theta,k,cap,dk)
   else
    call provider%evaluate(h,theta,k,cap,dk)
   end if
   do node=1,numnod
    expected(1)=watcon(node,h(node));expected(3)=moiscap(node,h(node))
    expected(2)=hconduc(node,h(node),expected(1),10d0)
    if(kind==1)then
     ! SWKIMPL=0 reserves typed dKdh=0; it does not migrate legacy implicit derivatives.
     expected(4)=0d0
    else
     expected(4)=dhconduc(node,h(node),expected(1),expected(3),10d0)
    end if
    actual=[theta(node),k(node),cap(node),dk(node)]
    if(any(.not.ieee_is_finite(actual)).or.any(.not.ieee_is_finite(expected)))error stop 'nonfinite literal or typed result'
    err=abs(actual-expected);maximum=max(maximum,err)
    tol=2d-12*max(1d0,abs(expected))
    do q=1,4
     if(err(q)>tol(q))then
      write(*,'(a,3i3,3es24.16)')'HYD_LITERAL_MISMATCH=',kind,node,q,h(node),expected(q),actual(q)
      mismatches=mismatches+1
     end if
    end do
    cases=cases+1
   end do
  end do
  if(kind/=1)deallocate(p%model_kind,p%theta_r,p%theta_s,p%ksat,p%alpha_1,p%lambda,p%n_1,p%m_1,p%alpha_2,p%n_2,p%m_2,p%omega_1)
 end do
 write(*,'(a,i0,a,i0,4es24.16)')'HYD_LITERAL_CASES=',cases,'|MISMATCHES=',mismatches,maximum
 if(mismatches/=0)error stop 'literal hydraulic mismatch'
 print '(a)','SWAP431_HYD_LITERAL_MODEL2_MODEL3_MODEL6_POWER=PASS'
end program
