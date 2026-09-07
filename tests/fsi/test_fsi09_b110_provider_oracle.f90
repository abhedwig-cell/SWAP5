program test_fsi09_b110_provider_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  use MOD_swap_base, only: swhyst,swfrost,swmacro
  use variables, only: dt,indeks,fluseksatexm
  use MOD_MvG, only: cofgen,iHWCKmodel,swsophy,sw_use_elas,fl_use_tables,fl_use_kh_power, &
       set_cofgen_pointers,calc_cofgen_extra,watcon,moiscap,hconduc
  use mod_b110_constitutive_provider
  implicit none

  real(real64), parameter :: heads(*)=[-1.0e15_real64,-1.0e6_real64,-1.0e4_real64,-1000.0_real64, &
       -100.0_real64,-10.0_real64,-5.25_real64,-5.0_real64,-4.9_real64,-1.0_real64,-0.5_real64, &
       -0.02_real64,-0.0101_real64,-0.01_real64,-0.009_real64,-1.0e-6_real64,0.0_real64,0.1_real64]
  type(b110_constitutive_parameters_t),target :: p
  type(b110_constitutive_conditions_t),target :: conditions
  type(b110_constitutive_provider_t) :: provider
  real(real64) :: h(numnod),theta(numnod),k(numnod),c(numnod),dk(numnod)
  real(real64) :: theta_ref,k_ref,c_ref
  integer :: ih,i,failures
  logical :: ok

  failures=0
  call configure_exact_oracle()
  call copy_oracle_parameters(p)
  conditions%step_duration=dt
  conditions%conductivity_implicit_mode=0
  call bind_b110_constitutive_provider(provider,p,conditions,ok)
  call expect(ok,failures)

  do ih=1,size(heads)
    h=heads(ih)
    call provider%evaluate(h,theta,k,c,dk)
    do i=1,numnod
      theta_ref=watcon(i,h(i))
      c_ref=moiscap(i,h(i))
      k_ref=hconduc(i,h(i),theta_ref,1.0_real64)
      call expect(same_real(theta(i),theta_ref),failures)
      call expect(same_real(c(i),c_ref),failures)
      call expect(same_real(k(i),k_ref),failures)
      call expect(dk(i)==0.0_real64,failures)
      if(.not.same_real(theta(i),theta_ref) .or. .not.same_real(c(i),c_ref) .or. .not.same_real(k(i),k_ref)) then
        write(*,'(A,I0,A,I0,7(1X,ES24.16))') 'MISMATCH head=',ih,' node=',i,h(i),theta_ref,theta(i),c_ref,c(i),k_ref,k(i)
      end if
    end do
  end do

  call test_fail_closed(p,conditions,failures)
  if(failures/=0) then
    write(*,'(A,I0)') 'F-SI09_B110_PROVIDER_ORACLE FAIL failures=',failures
    error stop 1
  end if
  write(*,'(A)') 'F-SI09_B110_PROVIDER_ORACLE PASS'
  write(*,'(A,I0)') 'heads=',size(heads)
  write(*,'(A,I0)') 'node_profiles=',numnod

contains

  subroutine configure_exact_oracle()
    integer :: i
    swsophy=0; sw_use_elas=0; fl_use_tables=.false.; fl_use_kh_power=.false.
    swhyst=0; swfrost=0; swmacro=0; indeks=0; fluseksatexm=.false.; dt=0.25_real64
    cofgen=0.0_real64
    iHWCKmodel=[1,1,2,3]
    do i=1,numnod
      cofgen(1,i)=0.05_real64
      cofgen(2,i)=0.45_real64
      cofgen(3,i)=10.0_real64+real(i,real64)
      cofgen(4,i)=0.02_real64+0.002_real64*real(i,real64)
      cofgen(5,i)=0.5_real64
      cofgen(6,i)=1.5_real64+0.05_real64*real(i,real64)
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
      cofgen(8,i)=cofgen(4,i)
      cofgen(9,i)=0.0_real64
      cofgen(13,i)=0.005_real64
      cofgen(14,i)=2.0_real64
      cofgen(15,i)=0.5_real64
      cofgen(16,i)=0.60_real64
    end do
    cofgen(9,2)=-5.0_real64
    call set_cofgen_pointers()
    call calc_cofgen_extra(numnod)
  end subroutine configure_exact_oracle

  subroutine copy_oracle_parameters(out)
    type(b110_constitutive_parameters_t),intent(out),target::out
    integer::n
    n=numnod; out%active_nodes=n
    allocate(out%model(n),out%wcr(n),out%wcs(n),out%wcs_min_wcr(n),out%alpha(n),out%npar(n),out%mpar(n), &
      out%ksat(n),out%lambda(n),out%alpha2(n),out%npar2(n),out%mpar2(n),out%omega1(n), &
      out%alfanm(n),out%nmin1(n),out%mplus1(n),out%one_over_m(n),out%alfanm2(n),out%nmin1_2(n), &
      out%mplus1_2(n),out%one_over_m2(n),out%h_enpr(n),out%wc_crit(n),out%c_crit(n),out%s_enpr(n), &
      out%term_105_a(n),out%term_105_ab(n))
    out%model=iHWCKmodel
    out%wcr=cofgen(1,1:n); out%wcs=cofgen(2,1:n); out%ksat=cofgen(3,1:n); out%alpha=cofgen(4,1:n)
    out%lambda=cofgen(5,1:n); out%npar=cofgen(6,1:n); out%mpar=cofgen(7,1:n)
    out%h_enpr=cofgen(9,1:n); out%alpha2=cofgen(13,1:n); out%npar2=cofgen(14,1:n)
    out%mpar2=cofgen(15,1:n); out%omega1=cofgen(16,1:n)
    out%wcs_min_wcr=cofgen(25,1:n); out%wc_crit=cofgen(26,1:n); out%c_crit=cofgen(27,1:n)
    out%s_enpr=cofgen(28,1:n); out%alfanm=cofgen(29,1:n); out%nmin1=cofgen(30,1:n)
    out%mplus1=cofgen(31,1:n); out%one_over_m=cofgen(32,1:n)
    out%alfanm2=cofgen(37,1:n); out%nmin1_2=cofgen(38,1:n); out%mplus1_2=cofgen(39,1:n)
    out%one_over_m2=cofgen(40,1:n); out%term_105_a=cofgen(41,1:n); out%term_105_ab=cofgen(42,1:n)
  end subroutine copy_oracle_parameters

  subroutine test_fail_closed(base,cond,failures)
    type(b110_constitutive_parameters_t),intent(in)::base
    type(b110_constitutive_conditions_t),intent(in)::cond
    integer,intent(inout)::failures
    type(b110_constitutive_parameters_t),target::badp
    type(b110_constitutive_conditions_t),target::badc
    type(b110_constitutive_provider_t)::bad_provider
    logical::accepted
    badp=base; badp%model(1)=4
    call bind_b110_constitutive_provider(bad_provider,badp,cond,accepted)
    call expect(.not.accepted,failures)
    badp=base; badc=cond; badc%conductivity_implicit_mode=1
    call bind_b110_constitutive_provider(bad_provider,badp,badc,accepted)
    call expect(.not.accepted,failures)
    badc=cond; badc%frost_active=.true.
    call bind_b110_constitutive_provider(bad_provider,base,badc,accepted)
    call expect(.not.accepted,failures)
  end subroutine test_fail_closed

  logical function same_real(a,b)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b))
    same_real=abs(a-b)<=64.0_real64*epsilon(1.0_real64)*scale
  end function same_real

  subroutine expect(condition,failures)
    logical,intent(in)::condition
    integer,intent(inout)::failures
    if(.not.condition) failures=failures+1
  end subroutine expect
end program test_fsi09_b110_provider_oracle
