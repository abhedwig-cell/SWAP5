program benchmark_tab_hyd_swap5_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_research_direct_table_provider, only: direct_table_storage_t, direct_table_provider_t, &
       build_direct_table_from_provider, bind_direct_table_provider
  implicit none

  integer, parameter :: nnode=34, nstate=512, nround=7, cycles=384
  real(real64), parameter :: dt=0.04_real64, hmin=-1.0e7_real64, hscale=1.0e-2_real64
  real(real64) :: cof(24,nnode)
  type(b110_default_mvg_parameters_t), target :: mvg_params
  type(b110_default_mvg_provider_t), target :: mvg
  type(direct_table_storage_t), target :: table
  type(direct_table_provider_t), target :: tab
  real(real64), allocatable :: states(:,:), heads(:), theta(:), conductivity(:), capacity(:), dkdh(:)
  real(real64) :: elapsed, checksum
  integer :: r

  allocate(states(nnode,nstate),heads(nnode),theta(nnode),conductivity(nnode),capacity(nnode),dkdh(nnode))
  call configure_hupsel_like(cof)
  call initialize_b110_default_mvg_parameters(mvg_params,cof)
  call bind_b110_default_mvg_provider(mvg,mvg_params,dt)
  call build_direct_table_from_provider(table,mvg,nnode,512,hmin,hscale)
  call bind_direct_table_provider(tab,table)
  call make_states(states)

  ! Untimed warm-up for both routes.
  heads=states(:,1)
  call mvg%evaluate(heads,theta,conductivity,capacity,dkdh)
  call tab%evaluate(heads,theta,conductivity,capacity,dkdh)

  write(*,'(A)') 'round,variant,seconds,checksum'
  do r=1,nround
    if(mod(r,2)==1) then
      call time_mvg(r,elapsed,checksum)
      write(*,'(I0,",mvg,",ES18.10,",",ES24.16)') r,elapsed,checksum
      call time_table(r,elapsed,checksum)
      write(*,'(I0,",table,",ES18.10,",",ES24.16)') r,elapsed,checksum
    else
      call time_table(r,elapsed,checksum)
      write(*,'(I0,",table,",ES18.10,",",ES24.16)') r,elapsed,checksum
      call time_mvg(r,elapsed,checksum)
      write(*,'(I0,",mvg,",ES18.10,",",ES24.16)') r,elapsed,checksum
    end if
  end do
  write(*,'(A)') 'TAB_HYD_SWAP5_MICROBENCH_COMPLETED'

contains

  subroutine time_mvg(round_no,seconds,sumcheck)
    integer, intent(in) :: round_no
    real(real64), intent(out) :: seconds,sumcheck
    integer(int64) :: c0,c1,rate
    integer :: c,j,idx
    sumcheck=0.0_real64
    call system_clock(c0,rate)
    do c=1,cycles
      do j=1,nstate
        idx=1+mod(j+17*c+round_no-3,nstate)
        heads=states(:,idx)
        call mvg%evaluate(heads,theta,conductivity,capacity,dkdh)
        sumcheck=sumcheck+theta(1)+theta(nnode)+conductivity(1)+conductivity(nnode)+capacity(1)+capacity(nnode)
      end do
    end do
    call system_clock(c1)
    seconds=real(c1-c0,real64)/real(rate,real64)
  end subroutine time_mvg

  subroutine time_table(round_no,seconds,sumcheck)
    integer, intent(in) :: round_no
    real(real64), intent(out) :: seconds,sumcheck
    integer(int64) :: c0,c1,rate
    integer :: c,j,idx
    sumcheck=0.0_real64
    call system_clock(c0,rate)
    do c=1,cycles
      do j=1,nstate
        idx=1+mod(j+17*c+round_no-3,nstate)
        heads=states(:,idx)
        call tab%evaluate(heads,theta,conductivity,capacity,dkdh)
        sumcheck=sumcheck+theta(1)+theta(nnode)+conductivity(1)+conductivity(nnode)+capacity(1)+capacity(nnode)
      end do
    end do
    call system_clock(c1)
    seconds=real(c1-c0,real64)/real(rate,real64)
  end subroutine time_table

  subroutine make_states(s)
    real(real64), intent(out) :: s(nnode,nstate)
    real(real64) :: f,x,h
    integer :: i,j
    do j=1,nstate
      f=real(j-1,real64)/real(nstate-1,real64)
      x=-log(1.0_real64+1.0e6_real64/hscale)*(1.0_real64-f)
      h=hscale*(1.0_real64-exp(-x))
      if(j==nstate) h=-1.0e-8_real64
      do i=1,nnode
        s(i,j)=h*(0.82_real64+0.36_real64*real(i-1,real64)/real(nnode-1,real64))
      end do
    end do
  end subroutine make_states

  subroutine configure_hupsel_like(c)
    real(real64), intent(out) :: c(24,nnode)
    integer :: i
    c=0.0_real64
    do i=1,nnode
      if(i<=14) then
        c(1,i)=0.01_real64; c(2,i)=0.42_real64; c(3,i)=12.52_real64
        c(4,i)=0.0276_real64; c(5,i)=-1.060_real64; c(6,i)=1.491_real64; c(8,i)=0.0542_real64
      else
        c(1,i)=0.02_real64; c(2,i)=0.38_real64; c(3,i)=12.68_real64
        c(4,i)=0.0213_real64; c(5,i)=0.168_real64; c(6,i)=1.951_real64; c(8,i)=0.0426_real64
      end if
      c(7,i)=1.0_real64-1.0_real64/c(6,i)
      c(9,i)=0.0_real64
      c(10,i)=c(3,i); c(11,i)=0.999_real64; c(12,i)=0.99_real64*c(3,i)
      c(22,i)=-1.0e6_real64; c(23,i)=1.0e-12_real64
    end do
  end subroutine configure_hupsel_like

end program benchmark_tab_hyd_swap5_provider
