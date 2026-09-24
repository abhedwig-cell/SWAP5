program test_ahl24_qbot_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_ahl08_klookup_provider, only: ahl08_klookup_provider_t, bind_ahl08_klookup_provider
  implicit none
  integer,parameter::NREPLAY=32768,NTIMING=7
  real(real64),parameter::dt=0.0625_real64,mass_gate=1e-12_real64,qfactor=0.99_real64
  type(soil_water_parameter_set_t),target::parameters
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::analytical
  type(ahl08_klookup_provider_t),target::candidate
  type(b110_source_sink_provider_t),target::source_sink
  type(fmr04_fixed_flux_top_provider_t),target::top_provider
  type(soil_water_physical_state_t)::initial_state
  type(soil_water_solve_request_t)::request
  type(soil_water_solve_result_t)::rr,cr
  type(reference_richards_legacy_solver_t)::sr,sc
  type(reference_richards_legacy_workspace_t)::wr,wc
  real(real64),allocatable,target::drainage(:,:),subsurface(:),root_sink(:)
  real(real64),allocatable::cofgen(:,:)
  real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
  real(real64)::rt(NTIMING),ct(NTIMING),rat(NTIMING),t0,t1,k0,qbot,h0,tr,ts,alpha,nvg,ksat,lambda
  character(len=512)::table_path,material,arg
  logical::valid
  integer::k,r,q
  if(command_argument_count()/=3)error stop 'usage TABLE MATERIAL H0'
  call get_command_argument(1,table_path);call get_command_argument(2,material)
  call get_command_argument(3,arg);read(arg,*)h0
  call params(trim(material),tr,ts,alpha,nvg,ksat,lambda)
  parameters%parameter_set_id=406024_int64;parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z;parameters%dz=dz;parameters%node_distance=disnod(1:numnod)
  allocate(cofgen(24,numnod));cofgen=0
  do k=1,numnod
    cofgen(1,k)=tr;cofgen(2,k)=ts;cofgen(3,k)=ksat;cofgen(4,k)=alpha;cofgen(5,k)=lambda;cofgen(6,k)=nvg
    cofgen(7,k)=1-1/nvg;cofgen(8,k)=alpha;cofgen(9,k)=0;cofgen(10,k)=ksat;cofgen(11,k)=0.999
    cofgen(12,k)=0.99*ksat;cofgen(22,k)=-1e6;cofgen(23,k)=1e-12
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,dt)
  call bind_ahl08_klookup_provider(candidate,hp,dt,trim(table_path),valid);call req(valid,'candidate bound')
  heads=h0;call analytical%evaluate(heads,water,conductivity,capacity,dkdh);k0=conductivity(1);qbot=-qfactor*k0
  initial_state%active_nodes=numnod;allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
  initial_state%pressure_head=heads;initial_state%water_content=water;initial_state%ponding_depth=0;initial_state%groundwater_level=-2
  allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod));drainage=0;subsurface=0;root_sink=0
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)
  call build(request);request%evaluation%constitutive=>analytical;call sr%solve(request,wr,rr);call req(rr%status==SW_SOLVE_CONVERGED,'ref converged')
  request%base_state=initial_state;request%evaluation%constitutive=>candidate;call sc%solve(request,wc,cr);call req(cr%status==SW_SOLVE_CONVERGED,'cand converged')
  call req(cr%diagnostics%nonlinear_iterations==rr%diagnostics%nonlinear_iterations,'iter path')
  call req(cr%diagnostics%backtracking_attempts==rr%diagnostics%backtracking_attempts,'backtrack path')
  do r=1,NTIMING
    if(mod(r,2)==1)then
      call cpu_time(t0);do q=1,NREPLAY;request%base_state=initial_state;request%evaluation%constitutive=>analytical;call sr%solve(request,wr,rr);end do;call cpu_time(t1);rt(r)=(t1-t0)/NREPLAY
      call cpu_time(t0);do q=1,NREPLAY;request%base_state=initial_state;request%evaluation%constitutive=>candidate;call sc%solve(request,wc,cr);end do;call cpu_time(t1);ct(r)=(t1-t0)/NREPLAY
    else
      call cpu_time(t0);do q=1,NREPLAY;request%base_state=initial_state;request%evaluation%constitutive=>candidate;call sc%solve(request,wc,cr);end do;call cpu_time(t1);ct(r)=(t1-t0)/NREPLAY
      call cpu_time(t0);do q=1,NREPLAY;request%base_state=initial_state;request%evaluation%constitutive=>analytical;call sr%solve(request,wr,rr);end do;call cpu_time(t1);rt(r)=(t1-t0)/NREPLAY
    end if
    rat(r)=ct(r)/rt(r);write(*,'(A,1X,A,1X,I0,1X,F10.6)')'AHL24_PAIR',trim(material),r,rat(r)
  end do
  call sort7(rat);write(*,'(A,1X,A,1X,F10.6)')'AHL24_MEDIAN_RATIO',trim(material),rat(4)
contains
  subroutine build(x)
    type(soil_water_solve_request_t),intent(out)::x
    x=soil_water_solve_request_t();x%parameters=>parameters;x%base_state=initial_state;x%step_duration=dt
    x%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;x%boundary%bottom_mode=2;x%boundary%top_flux=-k0;x%boundary%bottom_flux=qbot
    x%boundary%top_head=h0;x%boundary%bottom_head=0;x%physical%macropore_active=.false.
    x%numerical%max_iterations=8;x%numerical%max_backtracking=4;x%numerical%conductivity_implicit_mode=0;x%numerical%conductivity_mean_method=1
    x%numerical%min_step_duration=1e-6;x%numerical%compartment_balance_tolerance=mass_gate;x%numerical%total_balance_tolerance=mass_gate
    x%numerical%head_abs_tolerance=1e-12;x%numerical%head_rel_tolerance=1e-12;x%numerical%ponding_tolerance=1e-12
    x%evaluation%source_sink=>source_sink;x%evaluation%top_boundary=>top_provider
  end subroutine
  subroutine params(id,a,b,c,d,e,f)
    character(len=*),intent(in)::id;real(real64),intent(out)::a,b,c,d,e,f
    select case(id)
    case('B01');a=.02;b=.427494;c=.021659;d=1.734737;e=31.225016;f=.98087
    case('O05');a=.01;b=.336701;c=.030304;d=2.887502;e=17.418504;f=.0736
    case default;error stop 'unsupported'
    end select
  end subroutine
  subroutine sort7(v)
    real(real64),intent(inout)::v(7);real(real64)::x;integer::i,j
    do i=1,6;do j=i+1,7;if(v(j)<v(i))then;x=v(i);v(i)=v(j);v(j)=x;end if;end do;end do
  end subroutine
  subroutine req(ok,msg)
    logical,intent(in)::ok;character(len=*),intent(in)::msg;if(.not.ok)then;write(*,*)'AHL24_FAIL',trim(msg);error stop 1;end if
  end subroutine
end program
