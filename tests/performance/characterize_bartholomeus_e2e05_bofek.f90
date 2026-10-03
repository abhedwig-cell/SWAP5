program test_fpe_bofek01_policy_case
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_bartholomeus_parameter_contract
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t
  use mod_bartholomeus_no_stress_gate, only: bartholomeus_macro_supply_bound_no_stress
  use mod_bartholomeus_temperature, only: BartholomeusTemperatureResult, bartholomeus_temperature_parameters
  use mod_bartholomeus_soil_diffusivity, only: bartholomeus_soil_diffusivity
  use mod_bartholomeus_microbial, only: bartholomeus_microbial_respiration
  use mod_bartholomeus_micro, only: BartholomeusMicroInput, bartholomeus_micro_concentration
  use mod_bartholomeus_waterfilm, only: BartholomeusWaterfilmMvgInput, bartholomeus_waterfilm_mvg_integrand, &
       bartholomeus_waterfilm_from_length_density
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none
  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  type(soil_water_physical_state_t) :: state
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  type(BartholomeusImmutableDataset) :: gate_data
  type(BartholomeusCropParameters) :: gate_crop
  real(real64),allocatable :: gate_wroot(:),gate_root_density(:)
  real(real64) :: gate_demand_scale
  real(real64),allocatable :: c(:,:)
  character(len=32) :: case_id,policy_id,arg
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,h0,rain,horizon,dtmin,dtmax,dt0
  real(real64) :: fact_inc,fact_dec,fact_fail,headtol
  integer :: numbit_crit,maxit,maxback
  real(real64), parameter :: PMAX=0.05_real64,RSRO=0.05_real64
  real(real64), parameter :: BALTOL_CONFIGURED=1.0e-12_real64,BALTOL_DEPTH=2.8e-16_real64
  real(real64), parameter :: EPS_TIME=1.0e-13_real64
  integer :: attempts,accepted,rejected,growths,reductions,total_nl,total_back,total_jac,total_lin,gate_hits,gate_total
  real(real64) :: t,dt,cumrun,maxledger,storage0,storage1
  call get_command_argument(1,case_id); call get_command_argument(2,policy_id)
  call read_real(3,tr); call read_real(4,ts); call read_real(5,alpha); call read_real(6,nvg)
  call read_real(7,ksat); call read_real(8,lambda); call read_real(9,h0); call read_real(10,rain)
  call read_real(11,horizon); call read_real(12,dtmin); call read_real(13,dtmax); call read_real(14,dt0)
  call read_int(15,numbit_crit); call read_int(16,maxit); call read_int(17,maxback)
  call read_real(18,fact_inc); call read_real(19,fact_dec); call read_real(20,fact_fail); call read_real(21,headtol)
  call read_real(22,gate_demand_scale)
  call require(dtmin>0 .and. dtmax>=dtmin .and. dt0>0,'invalid timestep policy')
  call setup()
  call setup_gate()
  call initialize_state(h0,state)
  t=0.0_real64; dt=min(max(dt0,dtmin),dtmax)
  attempts=0;accepted=0;rejected=0;growths=0;reductions=0;gate_hits=0;gate_total=0
  total_nl=0;total_back=0;total_jac=0;total_lin=0;cumrun=0.0_real64;maxledger=0.0_real64
  do while(t<horizon-EPS_TIME)
    call execute_attempt()
    call require(attempts<10000,'attempt limit')
  end do
  storage1=sum(state%water_content*p%dz)+state%ponding_depth
  write(*,'(*(g0))') 'F_PE_BOFEK01_RESULT|CASE=',trim(case_id),'|POLICY=',trim(policy_id), &
    '|ATTEMPTS=',attempts,'|ACCEPTED=',accepted,'|REJECTED=',rejected,'|GROWTHS=',growths,'|REDUCTIONS=',reductions, &
    '|NL=',total_nl,'|BACK=',total_back,'|JAC=',total_jac,'|LIN=',total_lin,'|CUM_RUNOFF=',cumrun, &
    '|TOP_H=',state%pressure_head(1),'|MID_H=',state%pressure_head((numnod+1)/2), &
    '|BOTTOM_H=',state%pressure_head(numnod),'|POND=',state%ponding_depth, &
    '|STORAGE=',storage1,'|MAX_LEDGER=',maxledger
  write(*,'(*(g0))') 'E2E05_GATE_SUMMARY|CASE=',trim(case_id),'|TOTAL=',gate_total,'|HITS=',gate_hits, &
       '|FRACTION=',real(gate_hits,real64)/max(1.0_real64,real(gate_total,real64)),'|DEMAND_SCALE=',gate_demand_scale
  write(*,'(A)') 'F_PE_BOFEK01_CASE=PASS'
contains
  subroutine read_real(i,x)
    integer,intent(in)::i; real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine
  subroutine read_int(i,x)
    integer,intent(in)::i; integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(i,s); read(s,*)x
  end subroutine
  subroutine setup()
    integer::k; real(real64)::mm
    p%parameter_set_id=26092811_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),c(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);c=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do k=1,numnod
      c(1,k)=tr;c(2,k)=ts;c(3,k)=ksat;c(4,k)=alpha;c(5,k)=lambda;c(6,k)=nvg;c(7,k)=mm
      c(8,k)=alpha;c(9,k)=0.0_real64;c(10,k)=ksat;c(11,k)=0.999_real64;c(12,k)=0.99_real64*ksat
      c(22,k)=-1.0e6_real64;c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod));qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine
  subroutine setup_gate()
    integer::j
    allocate(gate_data%soil(numnod),gate_wroot(3),gate_root_density(3))
    gate_wroot=1.0_real64
    gate_root_density=gate_demand_scale*[1.0_real64,0.8_real64,0.6_real64]
    gate_crop%c_mroot=1.0e-5_real64;gate_crop%f_senes=1;gate_crop%q10_root=2.0_real64
    gate_crop%specific_resp_humus=1.0e-6_real64;gate_crop%q10_microbial=2.0_real64
    gate_crop%microbial_shape_m=0.9_real64;gate_crop%root_shape_m=0.9_real64
    gate_crop%root_radius_m=0.0002_real64;gate_crop%max_resp_factor=2.0_real64
    do j=1,numnod
      gate_data%soil(j)%saturated_water_content=ts
      gate_data%soil(j)%percent_org_mat=2.0_real64
      gate_data%soil(j)%soil_density=1300.0_real64
      gate_data%soil(j)%percent_sand=60.0_real64
      gate_data%soil(j)%diffusivity%term1=1.0_real64
      gate_data%soil(j)%diffusivity%exponent=2.0_real64
      gate_data%soil(j)%diffusivity%gfp100=max(1.0e-3_real64,ts-0.25_real64)
      gate_data%soil(j)%depth_m=max(0.01_real64,0.01_real64*real(j,real64))
      gate_data%soil(j)%waterfilm_capac_term=1.0_real64
      gate_data%soil(j)%waterfilm_n_minus_1=max(1.0e-6_real64,nvg-1.0_real64)
      gate_data%soil(j)%waterfilm_m_plus_1=2.0_real64-1.0_real64/nvg
      gate_data%soil(j)%waterfilm_alpha_per_pa=alpha/98.0665_real64
      gate_data%soil(j)%waterfilm_gen_n=nvg
    enddo
  end subroutine setup_gate
  subroutine classify_gate(s)
    type(soil_water_physical_state_t),intent(in)::s
    type(bartholomeus_runtime_view_t)::v
    logical::skip
    gate_total=gate_total+1
    v%rooted_nodes=3
    allocate(v%pressure_head_cm(3),v%water_content(3),v%soil_temperature_k(3))
    v%pressure_head_cm=s%pressure_head(1:3);v%water_content=s%water_content(1:3);v%soil_temperature_k=293.15_real64
    skip=bartholomeus_macro_supply_bound_no_stress(v,gate_data,gate_crop,gate_wroot,gate_root_density,0.275_real64)
    if(skip)gate_hits=gate_hits+1
    if(gate_total==1)then
      write(*,'(*(g0))')'E2E05_FIRST_STATE|CASE=',trim(case_id),'|H1=',s%pressure_head(1),'|THETA1=',s%water_content(1),'|TS=',ts,'|N=',nvg
      if(abs(gate_demand_scale-0.001_real64)<1.0e-12_real64) call diagnose_gate(s)
    endif
    deallocate(v%pressure_head_cm,v%water_content,v%soil_temperature_k)
  end subroutine classify_gate
  subroutine diagnose_gate(s)
    type(soil_water_physical_state_t),intent(in)::s
    type(BartholomeusTemperatureResult)::tt
    type(BartholomeusMicroInput)::mi
    type(BartholomeusWaterfilmMvgInput)::wf
    real(real64)::ctop,gfp,dsoil,mp,rm,a,b,cmacro,ilower,film_ub,film_ref,cmicro_ub,cmicro_ref
    real(real64)::integ,x,fx,weight
    integer::i,k
    integer,parameter::nsim=4096
    ctop=0.275_real64
    do i=1,3
      gfp=max(0.0_real64,gate_data%soil(i)%saturated_water_content-s%water_content(i))
      if(s%pressure_head(i)>=0.0_real64)gfp=0.0_real64
      tt=bartholomeus_temperature_parameters(293.15_real64)
      dsoil=bartholomeus_soil_diffusivity(tt%d_gas_free_air,gfp,gate_data%soil(i)%diffusivity)
      mp=-s%pressure_head(i)*100.0_real64
      rm=bartholomeus_microbial_respiration(293.15_real64,2.0_real64,1300.0_real64,60.0_real64,mp, &
           gate_crop%specific_resp_humus,gate_crop%q10_microbial)
      if(dsoil>0.0_real64)then
        a=gate_crop%microbial_shape_m**2*rm/dsoil
        b=gate_crop%root_shape_m**2*(gate_crop%f_senes*gate_crop%c_mroot*gate_root_density(i)*gate_crop%max_resp_factor * &
          gate_crop%q10_root**(.1_real64*(293.15_real64-298.0_real64)))/dsoil
      else
        a=huge(1.0_real64);b=huge(1.0_real64)
      endif
      cmacro=ctop-a*(1.0_real64-exp(-gate_data%soil(i)%depth_m/gate_crop%microbial_shape_m)) - &
                   b*(1.0_real64-exp(-gate_data%soil(i)%depth_m/gate_crop%root_shape_m))
      wf%capac_term=gate_data%soil(i)%waterfilm_capac_term;wf%n_minus_1=gate_data%soil(i)%waterfilm_n_minus_1
      wf%m_plus_1=gate_data%soil(i)%waterfilm_m_plus_1;wf%alpha_per_pa=gate_data%soil(i)%waterfilm_alpha_per_pa
      wf%gen_n=gate_data%soil(i)%waterfilm_gen_n;wf%surface_tension_water=tt%surface_tension_water
      ilower=.5_real64*mp*bartholomeus_waterfilm_mvg_integrand(.5_real64*mp,wf)
      film_ub=bartholomeus_waterfilm_from_length_density(ilower,mp,tt%surface_tension_water)
      integ=0.0_real64
      do k=0,nsim
        x=mp*real(k,real64)/real(nsim,real64)
        if(k==0)then
          fx=0.0_real64
        else
          fx=bartholomeus_waterfilm_mvg_integrand(x,wf)
        endif
        if(k==0 .or. k==nsim)then;weight=1.0_real64
        else if(mod(k,2)==0)then;weight=2.0_real64
        else;weight=4.0_real64
        endif
        integ=integ+weight*fx
      enddo
      integ=integ*mp/(3.0_real64*real(nsim,real64))
      film_ref=bartholomeus_waterfilm_from_length_density(integ,mp,tt%surface_tension_water)
      mi%c_mroot=gate_crop%c_mroot;mi%w_root=gate_wroot(i);mi%f_senes=gate_crop%f_senes;mi%q10_root=gate_crop%q10_root
      mi%soil_temp_k=293.15_real64;mi%sat_water_content=ts;mi%gas_filled_porosity=gfp
      mi%d_o2_in_water=tt%d_o2_in_water;mi%d_root=tt%d_root;mi%percent_org_mat=2.0_real64;mi%soil_density=1300.0_real64
      mi%specific_resp_humus=gate_crop%specific_resp_humus;mi%q10_microbial=gate_crop%q10_microbial
      mi%depth_m=gate_data%soil(i)%depth_m;mi%microbial_shape_m=gate_crop%microbial_shape_m
      mi%root_radius_m=gate_crop%root_radius_m;mi%bunsen_coeff=tt%bunsen_coeff
      mi%waterfilm_thickness_m=film_ub;cmicro_ub=bartholomeus_micro_concentration(mi,gate_crop%max_resp_factor)
      mi%waterfilm_thickness_m=film_ref;cmicro_ref=bartholomeus_micro_concentration(mi,gate_crop%max_resp_factor)
      write(*,'(*(g0))')'E2E05_GATE_DIAG|CASE=',trim(case_id),'|NODE=',i,'|N=',nvg,'|GFP=',gfp,'|DSOIL=',dsoil, &
        '|A=',a,'|B=',b,'|CTOP=',ctop,'|CMACRO=',cmacro,'|FILM_REF=',film_ref,'|FILM_UB=',film_ub, &
        '|CMICRO_REF=',cmicro_ref,'|CMICRO_UB=',cmicro_ub,'|MARGIN=',cmacro-cmicro_ub
      ctop=cmacro
    enddo
  end subroutine diagnose_gate
  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(constitutive,hp,dt0)
    heads=h; call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod;allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water;s%ponding_depth=0.0_real64;s%groundwater_level=-999.0_real64
  end subroutine
  subroutine execute_attempt()
    type(b110_dynamic_top_boundary_solver_provider_t),target :: top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(reference_richards_legacy_workspace_t)::ws
    type(soil_water_boundary_conditions_t)::bc
    type(soil_water_top_boundary_result_t)::final_top
    real(real64)::fixed_k,try_dt,ledger,new_dt,effective_baltol
    logical::ok
    try_dt=min(dt,horizon-t);attempts=attempts+1
    call bind_b110_default_mvg_provider(constitutive,hp,try_dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,state%pressure_head(1),fixed_k,ok)
    call require(ok,'fixed conductivity')
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,state%ponding_depth,try_dt, &
      rain,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,PMAX,RSRO,1.0_real64,fixed_k)
    req=soil_water_solve_request_t();req%parameters=>p;req%base_state=state;req%step_duration=try_dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;req%boundary%bottom_mode=2;req%boundary%bottom_flux=0.0_real64
    req%physical%macropore_active=.false.;req%numerical%max_iterations=maxit;req%numerical%max_backtracking=maxback
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    effective_baltol=max(BALTOL_CONFIGURED,BALTOL_DEPTH/try_dt)
    req%numerical%min_step_duration=dtmin;req%numerical%compartment_balance_tolerance=effective_baltol
    req%numerical%total_balance_tolerance=effective_baltol;req%numerical%head_abs_tolerance=headtol
    req%numerical%head_rel_tolerance=headtol;req%numerical%ponding_tolerance=BALTOL_CONFIGURED
    req%evaluation%constitutive=>constitutive;req%evaluation%source_sink=>source_sink;req%evaluation%dynamic_top_boundary=>top
    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    call solver%solve(req,ws,res)
    total_nl=total_nl+res%diagnostics%nonlinear_iterations;total_back=total_back+res%diagnostics%backtracking_attempts
    total_jac=total_jac+res%diagnostics%jacobian_builds;total_lin=total_lin+res%diagnostics%linear_solves
    if(res%status/=SW_SOLVE_CONVERGED)then
      rejected=rejected+1;new_dt=dt
      if(new_dt>fact_fail*dtmin)then;new_dt=new_dt/fact_fail;else;new_dt=dtmin;end if
      if(new_dt<dt-EPS_TIME)reductions=reductions+1
      call require(new_dt<dt-EPS_TIME,'nonconvergence at dtmin')
      dt=new_dt;return
    end if
    bc=soil_water_boundary_conditions_t()
    call top%evaluate(res%candidate_state%pressure_head(1),res%candidate_state%water_content(1),res%candidate_state%ponding_depth,bc,final_top)
    call require(final_top%status>0,'final top')
    storage1=sum(res%candidate_state%water_content*p%dz)+res%candidate_state%ponding_depth
    ledger=storage1-storage0-rain*try_dt+final_top%runoff_depth-res%bottom_flux*try_dt
    call require(ieee_is_finite(ledger).and.abs(ledger)<=5.0e-8_real64,'ledger')
    accepted=accepted+1;cumrun=cumrun+final_top%runoff_depth;maxledger=max(maxledger,abs(ledger))
    call classify_gate(res%candidate_state)
    t=t+try_dt;state=res%candidate_state
    new_dt=dt
    if(res%diagnostics%nonlinear_iterations<=numbit_crit)new_dt=min(new_dt*fact_inc,dtmax)
    if(res%diagnostics%nonlinear_iterations>=maxit)new_dt=max(new_dt*fact_dec,dtmin)
    if(new_dt>dt+EPS_TIME)growths=growths+1
    if(new_dt<dt-EPS_TIME)reductions=reductions+1
    dt=new_dt
  end subroutine
  subroutine require(cond,msg)
    logical,intent(in)::cond;character(len=*),intent(in)::msg
    if(.not.cond)then;write(*,'(A,1X,A)')'F_PE_BOFEK01_FAIL',trim(msg);error stop 1;end if
  end subroutine
end program test_fpe_bofek01_policy_case
