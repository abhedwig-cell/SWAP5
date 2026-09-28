program test_fpe_timeint05_bdf2
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED, SW_TOP_BOUNDARY_REGIME_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  real(real64), parameter :: PMAX=0.05_real64, RSRO=0.05_real64
  real(real64), parameter :: BAL_CONFIG=1.0e-12_real64, BAL_DEPTH=2.8e-16_real64
  real(real64), parameter :: HEAD_TOL=1.0e-9_real64, SOLVER_FLOOR=1.0e-6_real64

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: c(:,:)

  logical :: fpe_timeint05_bdf2_active
  real(real64) :: fpe_timeint05_theta_nm1(1000)
  common /fpe_timeint05_bdf2_ctrl/ fpe_timeint05_theta_nm1, fpe_timeint05_bdf2_active

  character(len=32) :: case_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain,step_dt
  type(soil_water_physical_state_t) :: initial,hist1,hist2,be,bdf,refstate,nextstate
  real(real64) :: run,ledger
  real(real64) :: be_h_err,bdf_h_err,be_theta_err,bdf_theta_err
  real(real64) :: be_water_l1,bdf_water_l1,be_storage_err,bdf_storage_err
  real(real64) :: bdf_mass_resid,max_be_ledger,max_ref_ledger
  integer :: work_h1,work_h2,work_be,work_bdf,work_ref,w,mode
  integer :: k
  logical :: ok,domain_ok

  call get_command_argument(1,case_id)
  call read_real(2,tr);call read_real(3,ts);call read_real(4,alpha);call read_real(5,nvg)
  call read_real(6,ksat);call read_real(7,lambda);call read_real(8,h0);call read_real(9,rain);call read_real(10,step_dt)

  fpe_timeint05_bdf2_active=.false.
  fpe_timeint05_theta_nm1=0.0_real64
  call setup()
  call initialize_state(h0,initial)

  domain_ok=.true.; max_be_ledger=0.0_real64; max_ref_ledger=0.0_real64

  call advance_step(initial,step_dt,.false.,initial%water_content,hist1,run,ledger,work_h1,mode,ok)
  if(.not.ok .or. mode/=SW_TOP_BOUNDARY_REGIME_FLUX .or. hist1%ponding_depth>1e-12_real64 .or. abs(run)>1e-12_real64) domain_ok=.false.
  max_be_ledger=max(max_be_ledger,abs(ledger))

  if(domain_ok)then
    call advance_step(hist1,step_dt,.false.,initial%water_content,hist2,run,ledger,work_h2,mode,ok)
    if(.not.ok .or. mode/=SW_TOP_BOUNDARY_REGIME_FLUX .or. hist2%ponding_depth>1e-12_real64 .or. abs(run)>1e-12_real64) domain_ok=.false.
    max_be_ledger=max(max_be_ledger,abs(ledger))
  else
    work_h2=0
  end if

  if(.not.domain_ok)then
    write(*,'(*(g0))')'F_PE_TIMEINT05|CASE=',trim(case_id),'|DT=',step_dt,'|DOMAIN=0'
    stop
  end if

  call advance_step(hist2,step_dt,.false.,hist1%water_content,be,run,ledger,work_be,mode,ok)
  if(.not.ok .or. mode/=SW_TOP_BOUNDARY_REGIME_FLUX .or. be%ponding_depth>1e-12_real64 .or. abs(run)>1e-12_real64)then
    write(*,'(*(g0))')'F_PE_TIMEINT05|CASE=',trim(case_id),'|DT=',step_dt,'|DOMAIN=0|STAGE=BE'
    stop
  end if
  max_be_ledger=max(max_be_ledger,abs(ledger))

  call advance_step(hist2,step_dt,.true.,hist1%water_content,bdf,run,bdf_mass_resid,work_bdf,mode,ok)
  if(.not.ok)then
    write(*,'(*(g0))')'F_PE_TIMEINT05|CASE=',trim(case_id),'|DT=',step_dt,'|DOMAIN=1|OK=0|STAGE=BDF2_SOLVER_OR_MASS'
    stop
  end if
  if(mode/=SW_TOP_BOUNDARY_REGIME_FLUX .or. bdf%ponding_depth>1e-12_real64 .or. abs(run)>1e-12_real64)then
    write(*,'(*(g0))')'F_PE_TIMEINT05|CASE=',trim(case_id),'|DT=',step_dt,'|DOMAIN=0|STAGE=BDF2_BOUNDARY'
    stop
  end if

  refstate=hist2;work_ref=0
  do k=1,4
    call advance_step(refstate,0.25_real64*step_dt,.false.,hist1%water_content,nextstate,run,ledger,w,mode,ok)
    work_ref=work_ref+w
    if(.not.ok .or. mode/=SW_TOP_BOUNDARY_REGIME_FLUX .or. nextstate%ponding_depth>1e-12_real64 .or. abs(run)>1e-12_real64)then
      write(*,'(*(g0))')'F_PE_TIMEINT05|CASE=',trim(case_id),'|DT=',step_dt,'|DOMAIN=0|STAGE=REFINED'
      stop
    end if
    max_ref_ledger=max(max_ref_ledger,abs(ledger))
    refstate=nextstate
  end do

  be_h_err=maxval(abs(be%pressure_head-refstate%pressure_head))
  bdf_h_err=maxval(abs(bdf%pressure_head-refstate%pressure_head))
  be_theta_err=maxval(abs(be%water_content-refstate%water_content))
  bdf_theta_err=maxval(abs(bdf%water_content-refstate%water_content))
  be_water_l1=sum(p%dz*abs(be%water_content-refstate%water_content))
  bdf_water_l1=sum(p%dz*abs(bdf%water_content-refstate%water_content))
  be_storage_err=abs(storage(be)-storage(refstate))
  bdf_storage_err=abs(storage(bdf)-storage(refstate))

  write(*,'(*(g0))')'F_PE_TIMEINT05|CASE=',trim(case_id),'|DT=',step_dt,'|DOMAIN=1|OK=1', &
    '|BE_H_ERR=',be_h_err,'|BDF_H_ERR=',bdf_h_err,'|BE_THETA_ERR=',be_theta_err,'|BDF_THETA_ERR=',bdf_theta_err, &
    '|BE_WATER_L1=',be_water_l1,'|BDF_WATER_L1=',bdf_water_l1, &
    '|BE_STORAGE_ERR=',be_storage_err,'|BDF_STORAGE_ERR=',bdf_storage_err, &
    '|BDF_MASS_RESID=',bdf_mass_resid,'|MAX_BE_LEDGER=',max_be_ledger,'|MAX_REF_LEDGER=',max_ref_ledger, &
    '|WORK_BE=',work_be,'|WORK_BDF=',work_bdf,'|WORK_REF=',work_ref,'|WORK_HISTORY=',work_h1+work_h2

contains

  subroutine read_real(i,x)
    integer,intent(in)::i;real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s);read(s,*)x
  end subroutine

  subroutine setup()
    integer::i;real(real64)::mm
    p%parameter_set_id=26092845_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),c(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);c=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do i=1,numnod
      c(1,i)=tr;c(2,i)=ts;c(3,i)=ksat;c(4,i)=alpha;c(5,i)=lambda;c(6,i)=nvg;c(7,i)=mm
      c(8,i)=alpha;c(9,i)=0.0_real64;c(10,i)=ksat;c(11,i)=0.999_real64;c(12,i)=0.99_real64*ksat
      c(22,i)=-1.0e6_real64;c(23,i)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    heads=h;call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod;allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water;s%ponding_depth=0.0_real64;s%groundwater_level=-999.0_real64
  end subroutine

  subroutine advance_step(s0,dt,use_bdf2,theta_nm1,s1,runoff,ledger,work,top_regime,ok)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::dt
    logical,intent(in)::use_bdf2
    real(real64),intent(in)::theta_nm1(:)
    type(soil_water_physical_state_t),intent(out)::s1
    real(real64),intent(out)::runoff,ledger
    integer,intent(out)::work,top_regime
    logical,intent(out)::ok
    type(b110_dynamic_top_boundary_solver_provider_t),target::top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::final_top
    real(real64)::fixed_k,effective_bal,s0store,s1store
    logical::k_ok

    ok=.false.;runoff=0.0_real64;ledger=huge(1.0_real64);work=0;top_regime=0
    fpe_timeint05_bdf2_active=use_bdf2
    if(use_bdf2)then
      fpe_timeint05_theta_nm1=0.0_real64
      fpe_timeint05_theta_nm1(1:numnod)=theta_nm1
    end if

    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,s0%pressure_head(1),fixed_k,k_ok)
    if(.not.k_ok)then
      fpe_timeint05_bdf2_active=.false.;return
    end if
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,s0%ponding_depth,dt, &
      rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)

    req=soil_water_solve_request_t();req%parameters=>p;req%base_state=s0;req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;req%boundary%bottom_mode=2;req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8;req%numerical%max_backtracking=8;req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1;req%numerical%min_step_duration=SOLVER_FLOOR
    effective_bal=max(BAL_CONFIG,BAL_DEPTH/dt)
    req%numerical%compartment_balance_tolerance=effective_bal;req%numerical%total_balance_tolerance=effective_bal
    req%numerical%head_abs_tolerance=HEAD_TOL;req%numerical%head_rel_tolerance=HEAD_TOL
    req%numerical%ponding_tolerance=BAL_CONFIG
    req%evaluation%constitutive=>constitutive;req%evaluation%source_sink=>source_sink;req%evaluation%dynamic_top_boundary=>top

    s0store=storage(s0)
    call solver%solve(req,ws,res)
    work=res%diagnostics%nonlinear_iterations+res%diagnostics%backtracking_attempts+res%diagnostics%jacobian_builds+res%diagnostics%linear_solves
    if(res%status/=SW_SOLVE_CONVERGED)then
      fpe_timeint05_bdf2_active=.false.;return
    end if

    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1), &
      res%candidate_state%ponding_depth,bc,final_top)
    if(final_top%status<=0)then
      fpe_timeint05_bdf2_active=.false.;return
    end if

    s1=res%candidate_state;runoff=final_top%runoff_depth;top_regime=final_top%regime
    s1store=storage(s1)
    if(use_bdf2)then
      ledger=sum(p%dz*(1.5_real64*s1%water_content-2.0_real64*s0%water_content+0.5_real64*theta_nm1)) &
             - rain*dt + runoff - res%bottom_flux*dt
    else
      ledger=s1store-s0store-rain*dt+runoff-res%bottom_flux*dt
    end if
    fpe_timeint05_bdf2_active=.false.
    if(.not.ieee_is_finite(ledger).or.abs(ledger)>5.0e-8_real64)return
    ok=.true.
  end subroutine

  real(real64) function storage(s) result(v)
    type(soil_water_physical_state_t),intent(in)::s
    v=sum(s%water_content*p%dz)+s%ponding_depth
  end function
end program test_fpe_timeint05_bdf2
