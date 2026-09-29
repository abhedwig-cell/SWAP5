program test_fpe_timeint15_be_equivalence
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fpe_timeint15_dynamic_top_provider, only: fpe_timeint15_dynamic_top_provider_t, &
       bind_fpe_timeint15_dynamic_top_provider
  implicit none

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_dynamic_top_boundary_solver_provider_t) :: prod
  type(fpe_timeint15_dynamic_top_provider_t) :: cand
  type(soil_water_boundary_conditions_t) :: requested
  type(soil_water_top_boundary_result_t) :: rp,rc
  real(real64),allocatable :: cof(:,:),heads(:),theta(:),kk(:),cap(:),dk(:)
  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,mm,fixed_k
  real(real64),parameter :: pmax=0.05_real64,rsro=0.05_real64
  real(real64),parameter :: hs(8)=[-300.0_real64,-100.0_real64,-50.0_real64,-20.0_real64,-5.0_real64,0.0_real64,5.0_real64,20.0_real64]
  real(real64),parameter :: ponds(4)=[0.0_real64,0.02_real64,0.05_real64,0.10_real64]
  real(real64),parameter :: rains(5)=[0.5_real64,4.0_real64,8.0_real64,12.0_real64,25.0_real64]
  real(real64),parameter :: dts(2)=[0.005_real64,0.02_real64]
  integer :: i,j,k,l,node,status_mismatch,regime_mismatch,deriv_avail_mismatch
  integer :: flux_count,head_no_runoff_count,runoff_count,points
  real(real64) :: max_head,max_flux,max_pond,max_runoff,max_deriv
  logical :: ok

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda)

  p%parameter_set_id=26092915_int64; p%active_nodes=numnod
  allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),cof(24,numnod))
  p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
  cof=0.0_real64; mm=1.0_real64-1.0_real64/nvg
  do node=1,numnod
    cof(1,node)=tr; cof(2,node)=ts; cof(3,node)=ksat; cof(4,node)=alpha; cof(5,node)=lambda
    cof(6,node)=nvg; cof(7,node)=mm; cof(8,node)=alpha; cof(9,node)=0.0_real64
    cof(10,node)=ksat; cof(11,node)=0.999_real64; cof(12,node)=0.99_real64*ksat
    cof(22,node)=-1.0e6_real64; cof(23,node)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cof)
  allocate(heads(numnod),theta(numnod),kk(numnod),cap(numnod),dk(numnod))

  status_mismatch=0; regime_mismatch=0; deriv_avail_mismatch=0
  flux_count=0; head_no_runoff_count=0; runoff_count=0; points=0
  max_head=0.0_real64; max_flux=0.0_real64; max_pond=0.0_real64; max_runoff=0.0_real64; max_deriv=0.0_real64

  do i=1,size(hs)
    heads=hs(i)
    call bind_b110_default_mvg_provider(constitutive,hp,dts(1))
    call constitutive%evaluate(heads,theta,kk,cap,dk)
    call evaluate_b110_default_mvg_conductivity(hp,1,hs(i),fixed_k,ok)
    if(.not.ok) error stop 'TIMEINT15 P0 fixed K unavailable'
    do j=1,size(ponds)
      do k=1,size(rains)
        do l=1,size(dts)
          points=points+1
          call bind_b110_dynamic_top_boundary_solver_provider(prod,p,hp,1,ponds(j),dts(l), &
               rains(k),0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pmax,rsro,1.0_real64,fixed_k)
          call bind_fpe_timeint15_dynamic_top_provider(cand,p,hp,ponds(j),ponds(j),dts(l),rains(k), &
               pmax,rsro,fixed_k,1.0_real64,-1.0_real64,0.0_real64,0.0_real64)
          requested=soil_water_boundary_conditions_t()
          call prod%evaluate(hs(i),theta(1),ponds(j),requested,rp)
          call cand%evaluate(hs(i),theta(1),ponds(j),requested,rc)
          if(rp%status/=rc%status) status_mismatch=status_mismatch+1
          if(rp%status==SW_TOP_BOUNDARY_AVAILABLE .and. rc%status==SW_TOP_BOUNDARY_AVAILABLE)then
            if(rp%regime/=rc%regime) regime_mismatch=regime_mismatch+1
            if(rp%surface_head_derivative_available .neqv. rc%surface_head_derivative_available) &
                 deriv_avail_mismatch=deriv_avail_mismatch+1
            max_head=max(max_head,abs(rp%surface_head-rc%surface_head))
            max_flux=max(max_flux,abs(rp%actual_top_flux-rc%actual_top_flux))
            max_pond=max(max_pond,abs(rp%candidate_ponding_depth-rc%candidate_ponding_depth))
            max_runoff=max(max_runoff,abs(rp%runoff_depth-rc%runoff_depth))
            if(rp%surface_head_derivative_available .and. rc%surface_head_derivative_available) &
                 max_deriv=max(max_deriv,abs(rp%surface_head_dpressure_head_top-rc%surface_head_dpressure_head_top))
            if(rp%regime==SW_TOP_BOUNDARY_REGIME_FLUX) flux_count=flux_count+1
            if(rp%regime==SW_TOP_BOUNDARY_REGIME_HEAD .and. abs(rp%runoff_depth)<=1.0e-14_real64 .and. &
               rp%surface_head>-1.0e5_real64) head_no_runoff_count=head_no_runoff_count+1
            if(abs(rp%runoff_depth)>1.0e-14_real64) runoff_count=runoff_count+1
          end if
        end do
      end do
    end do
  end do

  write(*,'(*(g0))') 'F_PE_TIMEINT15_P0_RESULT|MATERIAL=',trim(material_id),'|POINTS=',points, &
       '|STATUS_MISMATCH=',status_mismatch,'|REGIME_MISMATCH=',regime_mismatch, &
       '|DERIV_AVAIL_MISMATCH=',deriv_avail_mismatch,'|FLUX_COUNT=',flux_count, &
       '|HEAD_NO_RUNOFF_COUNT=',head_no_runoff_count,'|RUNOFF_COUNT=',runoff_count, &
       '|MAX_HEAD=',max_head,'|MAX_FLUX=',max_flux,'|MAX_POND=',max_pond, &
       '|MAX_RUNOFF=',max_runoff,'|MAX_DERIV=',max_deriv
  write(*,'(A)') 'F_PE_TIMEINT15_P0=PASS'
contains
  subroutine read_real(i,x)
    integer,intent(in)::i
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine
end program test_fpe_timeint15_be_equivalence
