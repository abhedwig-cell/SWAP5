program test_fci09_transaction_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, trial_outcome_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t
  use mod_b1_10_transaction_binding, only: b1_10_transaction_model_t, b1_10_attempt_context_t
  use MOD_grid, only: numnod
  use MOD_swap_base, only: swhea, swsolu, swcrop, swirfix
  use variables, only: h, theta, hm1, thetm1, pond, pondm1, gwl, gwlm1, volact, ldwet, spev, saev, &
       dt, t1900
  use MOD_SoilTemperature, only: tsoil
  use MOD_solute_global, only: cml
  use MOD_Solute, only: cmsy
  use MOD_irrigation, only: schedule, dayfix, nirri
  use MOD_meteo, only: meteo_rec
  use MOD_integral, only: cgrai
  implicit none

  type(b1_10_transaction_model_t) :: model
  class(transaction_state_t), allocatable :: state, cloned
  class(transaction_attempt_context_t), allocatable :: context
  type(trial_outcome_t) :: outcome
  character(len=32) :: mode
  real(real64) :: storage_probe

  call seed_physical_state()
  call model%capture_committed_state(state)
  if (.not. allocated(state)) error stop 'FCI09: state not allocated'
  select type (physical => state)
  type is (b1_10_process_state_t)
    if (.not. allocated(physical%h)) error stop 'FCI09: water state not captured'
    if (.not. allocated(physical%thermal)) error stop 'FCI09: thermal state not captured'
    if (.not. allocated(physical%solute)) error stop 'FCI09: solute state not captured'
    if (.not. allocated(physical%irrigation)) error stop 'FCI09: irrigation state not captured'
    if (.not. allocated(physical%crop)) error stop 'FCI09: crop state not captured'
    if (.not. allocated(physical%wofost)) error stop 'FCI09: WOFOST state not captured'
  class default
    error stop 'FCI09: wrong captured state type'
  end select

  call state%clone(cloned)
  select type (copy => cloned)
  type is (b1_10_process_state_t)
    if (maxval(abs(copy%h-1.0_real64)) > 0.0_real64) error stop 'FCI09: process clone wrong'
  class default
    error stop 'FCI09: clone lost dynamic state type'
  end select

  h = -99.0_real64; theta = -99.0_real64; hm1 = -99.0_real64; thetm1 = -99.0_real64
  pond=-99.0_real64; pondm1=-99.0_real64; gwl=-99.0_real64; gwlm1=-99.0_real64
  volact=-99.0_real64; ldwet=-99.0_real64; spev=-99.0_real64; saev=-99.0_real64
  tsoil=-99.0_real64; cml=-99.0_real64; cmsy=-99.0_real64; dayfix=-99; nirri=-99
  call model%restore_committed_state(state)
  if (maxval(abs(h(1:numnod)-1.0_real64)) > 0.0_real64) error stop 'FCI09: water restore failed'
  if (maxval(abs(theta(1:numnod)-2.0_real64)) > 0.0_real64) error stop 'FCI09: theta restore failed'
  if (maxval(abs(tsoil(1:numnod)-5.0_real64)) > 0.0_real64) error stop 'FCI09: thermal restore failed'
  if (maxval(abs(cml(1:numnod)-6.0_real64)) > 0.0_real64) error stop 'FCI09: solute restore failed'
  if (dayfix /= 7 .or. nirri /= 8) error stop 'FCI09: irrigation continuation restore failed'

  dt=0.125_real64; t1900=1234.5_real64; meteo_rec=17; schedule=1; cgrai=9.25_real64
  call model%capture_attempt_context(context)
  select type (ctx => context)
  type is (b1_10_attempt_context_t)
    if (ctx%legacy%meteo_rec /= 17) error stop 'FCI09: context dynamic type/capture wrong'
  class default
    error stop 'FCI09: wrong attempt context type'
  end select
  dt=9.0_real64; t1900=-1.0_real64; meteo_rec=-1; schedule=0; cgrai=-1.0_real64
  call model%restore_attempt_context(context)
  if (abs(dt-0.125_real64) > 0.0_real64 .or. abs(t1900-1234.5_real64) > 0.0_real64) &
    error stop 'FCI09: time/numerical context restore failed'
  if (meteo_rec /= 17 .or. schedule /= 1 .or. abs(cgrai-9.25_real64) > 0.0_real64) &
    error stop 'FCI09: legacy attempt context restore failed'

  if (.not. model%capabilities%process_state_binding) error stop 'FCI09: process binding should be admitted'
  if (.not. model%capabilities%attempt_context_binding) error stop 'FCI09: context binding should be admitted'
  if (.not. model%capabilities%whole_day_restore_rerun_qualified) error stop 'FCI09: whole-day evidence pin missing'
  if (model%capabilities%generic_interval_advance) error stop 'FCI09: generic interval advance must remain blocked'
  if (model%capabilities%trial_mass_flux_contract) error stop 'FCI09: trial mass contract must remain blocked'
  if (model%capabilities%mass_storage_contract) error stop 'FCI09: storage contract must remain blocked'
  if (model%capabilities%temporal_error_contract) error stop 'FCI09: temporal error contract must remain blocked'
  if (model%reference_execution_admitted()) error stop 'FCI09: reference execution must remain fail-closed'

  call model%advance(state, 0.0_real64, 1.0_real64, outcome)
  if (outcome%solver_ok) error stop 'FCI09: blocked advance unexpectedly executed'

  mode=''
  call get_command_argument(1,mode)
  if (trim(mode) == 'storage-negative') then
    storage_probe = model%storage(state)
    print *, storage_probe
    error stop 'FCI09: storage unexpectedly admitted'
  end if

  print *, 'FCI09_TRANSACTION_BINDING PASS'
contains
  subroutine seed_physical_state()
    integer :: i
    swhea=1; swsolu=1; swcrop=1; swirfix=1; schedule=0
    h=0.0_real64; theta=0.0_real64; hm1=0.0_real64; thetm1=0.0_real64
    tsoil=0.0_real64; cml=0.0_real64; cmsy=0.0_real64
    do i=1,numnod
      h(i)=1.0_real64; theta(i)=2.0_real64; hm1(i)=3.0_real64; thetm1(i)=4.0_real64
      tsoil(i)=5.0_real64; cml(i)=6.0_real64; cmsy(i)=7.0_real64
    end do
    pond=0.1_real64; pondm1=0.2_real64; gwl=-100.0_real64; gwlm1=-101.0_real64
    volact=88.0_real64; ldwet=1.0_real64; spev=2.0_real64; saev=3.0_real64
    dayfix=7; nirri=8
  end subroutine seed_physical_state
end program test_fci09_transaction_binding
