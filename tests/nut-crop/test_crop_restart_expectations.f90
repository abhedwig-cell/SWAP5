program test_crop_restart_expectations
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_fmr_production_application_bootstrap
 use mod_kernel_transactions
 use mod_b110_default_mvg_provider
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_transaction_reference,only:TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_b111_soil_n_reactive_owner
 use mod_crop_soil_n_configuration
 use mod_crop_soil_n_day
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state
 use mod_crop_soil_n_joint_restart_file
 implicit none
 real(real64),parameter::T0=0d0,T1=1d0,HARD_MASS_GATE=1d-10
 type(fmr_production_application_config_t)::cfg
 type(fmr_logical_column_t)::column
 type(kernel_committed_state_t)::water
 type(crop_soil_state_t)::state
 type(crop_n_configuration_t)::p,bad
 type(reactive_parameters_t)::sp
 integer(int64)::wid,sid,cid
 real(real64)::k
 integer::i,status
 character(512)::path
 call get_command_argument(1,path)
 call initialize_application_config(cfg,-75d0,k)
 cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
 column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
 column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
 column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 call parameters(sp);call configure_crop(p);p%base%nitrogen%nfix_fr=.3d0
 do i=1,7
  bad=p;wid=670001_int64;sid=9001_int64;cid=9101_int64
  select case(i)
  case(1);bad%tables(13)%y(1)=.41d0
  case(2);bad%base%nitrogen%nfix_fr=.4d0
  case(3);deallocate(bad%tables(1)%x)
  case(4);bad%tables(13)%y(1)=ieee_value(0d0,ieee_quiet_nan)
  case(5);wid=9999_int64
  case(6);sid=9999_int64
  case(7);cid=9999_int64
  end select
  call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,wid,sid,cid,sp,bad,water,state,status)
  call require(status/=0.and..not.water%ready().and..not.state%ready(),'wrong expected configuration or identity publishes none')
 end do
 print '(A)','CROP_SOIL_SEVEN_EXPECTED_CONFIGURATION_IDENTITY_NEGATIVES=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'reactive_parameters.inc'
 include 'matrix_fixture.inc'
end program
