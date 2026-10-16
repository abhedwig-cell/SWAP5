  subroutine surface_restart_contract()
    use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
    type(kernel_committed_state_t)::w,x,y
    type(matrix_solute_state_t)::s,a,b,empty
    type(mobile_salt_state_t)::m
    type(solute_compartment_state_t)::c
    type(matrix_joint_restart_t)::r
    real(real64),allocatable::theta(:)
    real(real64)::t,amount,before,net
    integer(int64)::rev
    integer::j,code,unit
    character(8)::sentinel
    cfg%tiles(1)%base_forcing%top_flux=0.0_real64
    if(trim(mode)=='reject')then
      call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
        w,s,code,allow_surface_mass=.true.)
      call require(code/=JOINT_OK.and..not.w%ready().and..not.s%ready(),'V2 invalid leaves both owners empty')
      print '(A)','SURFACE_STORE_INVALID_FILE=PASS'
      return
    end if
    if(trim(mode)=='resume')then
      call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
        w,s,code,allow_surface_mass=.true.)
      call require(code==JOINT_OK,'V2 fresh import')
      call advance_store(backend,w,s,T1,2*T1,result)
      call store_endpoint(trim(endpoint_path),w,s)
      print '(A)','SURFACE_STORE_FRESH_PROCESS=PASS'
      return
    end if
    call initialize_owners(w,s,p)
    call s%snapshot(t,theta,m,c,rev)
    ! Reconstruction boundary: finite inclusive bounds, exact binary64 payload.
    do j=1,7
      select case(j)
      case(1);amount=0.0_real64
      case(2);amount=tiny(1.0_real64)
      case(3);amount=1.0e12_real64
      case(4);amount=-1.0_real64
      case(5);amount=ieee_value(0.0_real64,ieee_quiet_nan)
      case(6);amount=ieee_value(0.0_real64,ieee_positive_inf)
      case(7);amount=1.01e12_real64
      end select
      call reconstruct_matrix_solute_trusted(p,9001_int64,rev,t,theta,m%concentration_mg_cm3, &
        m%mass_mg_cm2,c%sorbed_matrix_mass,a,code,surface_mass=amount)
      if(j<=3)then
        call require(code==MATRIX_OK,'valid surface reconstruction')
        call assert_surface(a,amount)
      else
        call require(code/=MATRIX_OK.and..not.a%ready(),'invalid surface reconstruction empty')
      end if
    end do
    call reconstruct_matrix_solute_trusted(p,9001_int64,rev,t,theta,m%concentration_mg_cm3, &
      m%mass_mg_cm2,c%sorbed_matrix_mass,s,code,surface_mass=0.375_real64)
    call require(code==MATRIX_OK,'persistent mass constructor')
    call assert_surface(s,0.375_real64)
    ! Unsupported V1 export must fail before opening an existing target.
    open(newunit=unit,file=trim(restart_path),access='stream',form='unformatted',status='replace')
    write(unit)'KEEPFILE';close(unit)
    call write_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,w,s,code)
    call require(code/=JOINT_OK,'default export refuses nonzero surface mass')
    open(newunit=unit,file=trim(restart_path),access='stream',form='unformatted',status='old')
    read(unit)sentinel;close(unit)
    call require(sentinel=='KEEPFILE','refusal does not overwrite target')
    ! Chemical overdraw after a real accepted hydraulic candidate is atomic.
    pbad=p;pbad%decpot=1.0e6_real64
    call initialize_owners(x,a,pbad)
    call a%snapshot(t,theta,m,c,rev)
    call reconstruct_matrix_solute_trusted(pbad,9001_int64,rev,t,theta,m%concentration_mg_cm3, &
      m%mass_mg_cm2,c%sorbed_matrix_mass,a,code,surface_mass=0.375_real64)
    y=x;b=a
    call run_matrix_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,x, &
      cfg%tiles(1)%base_forcing,cfg%numerical,a,T0,T1,result)
    call require(result%status==JOINT_CHEMICAL_REJECTED.and.result%water%completed,'surface chemical rollback')
    call compare_water(x,y);call compare_chemical(a,b);call assert_surface(a,0.375_real64)
    call advance_store(backend,w,s,T0,T1,result)
    before=result%chemical%mass_before
    net=result%chemical%external_in-result%chemical%external_out
    call export_matrix_joint_restart(column,cfg%tiles(1)%template,670001_int64,w,s,r,code)
    call require(code==JOINT_OK,'surface opaque export')
    x=kernel_committed_state_t();a=matrix_solute_state_t()
    call restore_matrix_joint_restart(r,column,cfg%tiles(1)%template,670001_int64,9001_int64,x,a,code)
    call require(code==JOINT_OK,'surface opaque restore')
    call compare_water(w,x);call compare_chemical(s,a);call assert_surface(a,0.375_real64)
    call write_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,w,s,code, &
      allow_surface_mass=.true.)
    call require(code==JOINT_OK,'explicit V2 native export')
    y=kernel_committed_state_t();b=matrix_solute_state_t()
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
      y,b,code)
    call require(code/=JOINT_OK.and..not.y%ready().and..not.b%ready(),'V2 import is opt in')
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670002_int64,9001_int64,p, &
      y,b,code,allow_surface_mass=.true.)
    call require(code/=JOINT_OK.and..not.y%ready().and..not.b%ready(),'V2 wrong water identity atomic')
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9002_int64,p, &
      y,b,code,allow_surface_mass=.true.)
    call require(code/=JOINT_OK.and..not.y%ready().and..not.b%ready(),'V2 wrong chemical identity atomic')
    pbad=p;pbad%decpot=2*p%decpot
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,pbad, &
      y,b,code,allow_surface_mass=.true.)
    call require(code/=JOINT_OK.and..not.y%ready().and..not.b%ready(),'V2 same identity wrong parameters atomic')
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
      y,b,code,allow_surface_mass=.true.)
    call require(code==JOINT_OK,'V2 native restore')
    call compare_water(w,y);call compare_chemical(s,b);call assert_surface(b,0.375_real64)
    ! Live targets are never replaced; neither water nor chemistry may move.
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
      y,b,code,allow_surface_mass=.true.)
    call require(code/=JOINT_OK,'live targets refused')
    call compare_water(w,y);call compare_chemical(s,b);call assert_surface(b,0.375_real64)
    call advance_store(backend,w,s,T1,2*T1,result)
    net=net+result%chemical%external_in-result%chemical%external_out
    call require(abs(result%chemical%mass_after-before-net)<1e-11_real64,'two-window total includes surface')
    call advance_store(second,x,a,T1,2*T1,result2)
    call compare_water(w,x);call compare_chemical(s,a);call assert_surface(a,0.375_real64)
    call advance_store(second,y,b,T1,2*T1,result2)
    call compare_water(w,y);call compare_chemical(s,b);call assert_surface(b,0.375_real64)
    call store_endpoint(trim(endpoint_path),w,s)
    print '(A)','SURFACE_STORE_NATIVE_OPAQUE_BALANCE=PASS'
  end subroutine

  subroutine assert_surface(s,amount)
    type(matrix_solute_state_t),intent(in)::s
    real(real64),intent(in)::amount
    type(mobile_salt_state_t)::m
    type(solute_compartment_state_t)::c
    real(real64),allocatable::theta(:)
    real(real64)::t
    integer(int64)::rev
    call require(s%ready(),'surface owner ready')
    call s%snapshot(t,theta,m,c,rev)
    call require(transfer(c%pond_mass,0_int64)==transfer(amount,0_int64),'surface exact bits')
    call require(abs(c%aquifer_mass)<=0.0_real64.and.all(abs(c%age_amount)<=0.0_real64),'no other pool activated')
  end subroutine

  subroutine advance_store(be,w,s,start,finish,r)
    type(fmr_serialized_reference_backend_t),intent(inout)::be
    type(kernel_committed_state_t),intent(inout)::w
    type(matrix_solute_state_t),intent(inout)::s
    real(real64),intent(in)::start,finish
    type(matrix_joint_result_t),intent(out)::r
    type(mobile_salt_state_t)::m
    type(solute_compartment_state_t)::c
    real(real64),allocatable::theta(:)
    real(real64)::t,total
    integer(int64)::rev
    call s%snapshot(t,theta,m,c,rev)
    total=sum(m%mass_mg_cm2)+c%solute_total()
    call run_matrix_joint_interval(be,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w, &
      cfg%tiles(1)%base_forcing,cfg%numerical,s,start,finish,r)
    call require(r%status==JOINT_OK.and.r%chemical%completed_substeps>0,'real accepted matrix continuation')
    call require(abs(r%water%mass%residual)<=HARD_MASS_GATE,'surface accepted water budget')
    call require(abs(r%chemical%mass_before-total)<1e-12_real64,'receipt includes initial surface mass')
    call s%snapshot(t,theta,m,c,rev)
    total=sum(m%mass_mg_cm2)+c%solute_total()
    call require(abs(r%chemical%mass_after-total)<1e-12_real64,'receipt includes final surface mass')
    call require(abs(r%chemical%residual)<1e-11_real64,'surface whole chemical mass budget')
    call assert_surface(s,0.375_real64)
  end subroutine

  subroutine store_endpoint(path,w,s)
    character(*),intent(in)::path
    type(kernel_committed_state_t),intent(in)::w
    type(matrix_solute_state_t),intent(in)::s
    type(mobile_salt_state_t)::m
    type(solute_compartment_state_t)::c
    real(real64),allocatable::theta(:)
    real(real64)::t
    integer(int64)::rev
    integer::unit
    call write_endpoint(path,w,s)
    call s%snapshot(t,theta,m,c,rev)
    open(newunit=unit,file=path,access='stream',form='unformatted',position='append',status='old')
    write(unit)c%pond_mass;close(unit)
  end subroutine
