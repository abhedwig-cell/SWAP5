program test_tab_hyd_swap5_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, validate_soil_water_request
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_research_direct_table_provider, only: direct_table_storage_t, direct_table_provider_t, &
       build_direct_table_from_provider, bind_direct_table_provider
  implicit none

  integer, parameter :: nnode=4, nres=4, neval=6001
  integer, parameter :: resolutions(nres)=[128,256,512,1024]
  real(real64), parameter :: dt=0.04_real64, hmin=-1.0e7_real64
  real(real64) :: cof(24,nnode)
  type(b110_default_mvg_parameters_t), target :: mvg_params
  type(b110_default_mvg_provider_t), target :: mvg
  type(direct_table_storage_t), target :: table
  type(direct_table_provider_t), target :: tab
  type(soil_water_parameter_set_t), target :: ps
  type(soil_water_physical_state_t) :: state
  type(soil_water_solve_request_t) :: request
  real(real64) :: heads(nnode), theta_ref(nnode), k_ref(nnode), c_ref(nnode), dk_ref(nnode)
  real(real64) :: theta_tab(nnode), k_tab(nnode), c_tab(nnode), dk_tab(nnode)
  real(real64) :: x_min, x, h, frac
  real(real64) :: max_theta, max_logk, max_logc
  real(real64) :: branch_theta, branch_logk, branch_logc
  logical :: ok
  integer :: ir, q

  call configure_hupsel_like(cof)
  call initialize_b110_default_mvg_parameters(mvg_params,cof)
  call bind_b110_default_mvg_provider(mvg,mvg_params,dt)

  x_min=-log(1.0_real64-hmin)
  write(*,'(A)') 'resolution,max_theta_abs,max_log10K_abs,max_log10C_abs,branch_theta_abs,branch_log10K_abs,branch_log10C_abs'

  do ir=1,nres
    call build_direct_table_from_provider(table,mvg,nnode,resolutions(ir),hmin)
    call bind_direct_table_provider(tab,table)
    max_theta=0.0_real64
    max_logk=0.0_real64
    max_logc=0.0_real64

    do q=1,neval
      frac=real(q-1,real64)/real(neval-1,real64)
      x=x_min*(1.0_real64-frac)
      h=1.0_real64-exp(-x)
      if(q==neval) h=0.0_real64
      heads=h
      call mvg%evaluate(heads,theta_ref,k_ref,c_ref,dk_ref)
      call tab%evaluate(heads,theta_tab,k_tab,c_tab,dk_tab)
      call require(all(ieee_is_finite(theta_tab)) .and. all(ieee_is_finite(k_tab)) .and. &
                   all(ieee_is_finite(c_tab)),101)
      call require(all(k_tab>0.0_real64) .and. all(c_tab>0.0_real64),102)
      max_theta=max(max_theta,maxval(abs(theta_tab-theta_ref)))
      max_logk=max(max_logk,maxval(abs(log10(k_tab)-log10(k_ref))))
      max_logc=max(max_logc,maxval(abs(log10(c_tab)-log10(c_ref))))
    end do

    call branch_probe(mvg,tab,-1.0e-2_real64,branch_theta,branch_logk,branch_logc)
    write(*,'(I0,",",ES18.10,",",ES18.10,",",ES18.10,",",ES18.10,",",ES18.10,",",ES18.10)') &
      resolutions(ir),max_theta,max_logk,max_logc,branch_theta,branch_logk,branch_logc

    if(resolutions(ir)==512) then
      call configure_contract_probe(ps,state,request,tab,ok)
      call require(ok,103)
      write(*,'(A)') 'TAB_HYD_SWAP5_TYPED_PROVIDER_CONTRACT=PASS'
    end if
  end do

  ! The candidate is deliberately bounded to the ordinary SWKIMPL=0 value-provider contract.
  call require(all(dk_tab==0.0_real64),104)
  write(*,'(A)') 'TAB_HYD_SWAP5_PROVIDER_CHARACTERIZATION_COMPLETED'

contains

  subroutine configure_hupsel_like(c)
    real(real64), intent(out) :: c(24,nnode)
    integer :: i
    c=0.0_real64
    do i=1,nnode
      if(i<=2) then
        c(1,i)=0.01_real64
        c(2,i)=0.42_real64
        c(3,i)=12.52_real64
        c(4,i)=0.0276_real64
        c(5,i)=-1.060_real64
        c(6,i)=1.491_real64
        c(8,i)=0.0542_real64
      else
        c(1,i)=0.02_real64
        c(2,i)=0.38_real64
        c(3,i)=12.68_real64
        c(4,i)=0.0213_real64
        c(5,i)=0.168_real64
        c(6,i)=1.951_real64
        c(8,i)=0.0426_real64
      end if
      c(7,i)=1.0_real64-1.0_real64/c(6,i)
      c(9,i)=0.0_real64
      c(10,i)=c(3,i)
      c(11,i)=0.999_real64
      c(12,i)=0.99_real64*c(3,i)
      c(22,i)=-1.0e6_real64
      c(23,i)=1.0e-12_real64
    end do
  end subroutine configure_hupsel_like

  subroutine branch_probe(base,candidate,hprobe,e_theta,e_logk,e_logc)
    type(b110_default_mvg_provider_t), intent(in) :: base
    type(direct_table_provider_t), intent(in) :: candidate
    real(real64), intent(in) :: hprobe
    real(real64), intent(out) :: e_theta,e_logk,e_logc
    real(real64) :: hr(nnode),tr(nnode),kr(nnode),cr(nnode),dr(nnode)
    real(real64) :: tt(nnode),kt(nnode),ct(nnode),dt_local(nnode)
    hr=hprobe
    call base%evaluate(hr,tr,kr,cr,dr)
    call candidate%evaluate(hr,tt,kt,ct,dt_local)
    e_theta=maxval(abs(tt-tr))
    e_logk=maxval(abs(log10(kt)-log10(kr)))
    e_logc=maxval(abs(log10(ct)-log10(cr)))
  end subroutine branch_probe

  subroutine configure_contract_probe(p,s,r,provider,valid)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(soil_water_physical_state_t), intent(out) :: s
    type(soil_water_solve_request_t), intent(out) :: r
    type(direct_table_provider_t), target, intent(in) :: provider
    logical, intent(out) :: valid

    p%parameter_set_id=991001_int64
    p%active_nodes=nnode
    allocate(p%z(nnode),p%dz(nnode),p%node_distance(nnode))
    p%z=[-5.0_real64,-15.0_real64,-30.0_real64,-50.0_real64]
    p%dz=[10.0_real64,10.0_real64,20.0_real64,20.0_real64]
    p%node_distance=[10.0_real64,10.0_real64,15.0_real64,20.0_real64]

    s%active_nodes=nnode
    allocate(s%pressure_head(nnode),s%water_content(nnode))
    s%pressure_head=[-100.0_real64,-75.0_real64,-50.0_real64,-25.0_real64]
    call provider%evaluate(s%pressure_head,s%water_content,k_tab,c_tab,dk_tab)

    r=soil_water_solve_request_t()
    r%parameters=>p
    r%base_state=s
    r%step_duration=dt
    r%evaluation%constitutive=>provider
    call validate_soil_water_request(r,valid)
  end subroutine configure_contract_probe

  subroutine require(condition,code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if(.not.condition) then
      write(*,'(A,I0)') 'TAB_HYD_SWAP5_FAIL=',code
      error stop 1
    end if
  end subroutine require

end program test_tab_hyd_swap5_provider
