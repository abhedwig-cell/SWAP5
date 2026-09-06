module mod_a23bs_hupsel_worker_component
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t
  use MOD_arrays, only: fillen
  use MOD_grid, only: numnod, dz
  use MOD_swap_base, only: swmacro, swsnow, swhea, swsolu
  use variables, only: h, theta, pond, dt, dtmin, ldwet, spev, saev, gwl, volact, &
       t1900, t, tcum, timjan1, daynr, daycum, iyear, imonth, date
  use MOD_SoilTemperature, only: tsoil
  use MOD_Solute, only: cml, cmsy
  use MOD_irrigation, only: flirrigate, dayfix, nirri, irrigevent, gird, dt_irr_event
  use MOD_cropdevelopment, only: fl_cropcalendar
  use MOD_meteo, only: meteo_rec, rain_rec, i_metdetail, fl_update_meteo
  use MOD_integral, only: cgrai, cgird, crunon, cqssdi, cqbotup, caintc, crunoff, cqrot, cepd, cevap, cqdra, cqbotdo
  use mod_a23bs_worker_execution_context, only: a23bs_worker_context_t, a23bs_initialize_worker, &
       a23bs_release_worker, a23bs_reset_attempt_diagnostics, a23bs_seed_timestep_control, &
       a23bs_seed_execution_window, a23bs_scratch_payload_bytes
  implicit none
  private

  real(real64), parameter :: INTEGER_TIME_TOL = 1.0e-10_real64

  type, public :: hupsel_physical_state_t
    real(real64), allocatable :: h(:), theta(:), tsoil(:), cml(:)
    real(real64) :: pond = 0.0_real64
    real(real64) :: ldwet = 0.0_real64
    real(real64) :: spev = 0.0_real64
    real(real64) :: saev = 0.0_real64
    real(real64) :: gwl = 0.0_real64
    real(real64) :: volact = 0.0_real64
  end type hupsel_physical_state_t

  type, public :: hupsel_forcing_cursor_t
    integer :: meteo_rec = 0
    integer :: rain_rec = 0
    integer :: i_metdetail = 0
    logical :: fl_update_meteo = .false.
  end type hupsel_forcing_cursor_t

  type, public :: hupsel_process_cursor_t
    logical :: flirrigate = .false.
    logical :: fl_cropcalendar = .false.
    integer :: dayfix = 0
    integer :: nirri = 0
    integer :: irrigevent = 0
    real(real64) :: gird = 0.0_real64
    real(real64) :: dt_irr_event = 0.0_real64
  end type hupsel_process_cursor_t

  type, public :: hupsel_numerical_state_t
    real(real64) :: dt = 0.0_real64
  end type hupsel_numerical_state_t

  type, public :: hupsel_legacy_time_projection_t
    real(real64) :: t1900 = 0.0_real64
    real(real64) :: year_time = 0.0_real64
    real(real64) :: day_time = 0.0_real64
    real(real64) :: jan1_1900 = 0.0_real64
    integer :: daynr = 0
    integer :: daycum = 0
    integer :: iyear = 0
    integer :: imonth = 0
    character(len=11) :: date = ''
  end type hupsel_legacy_time_projection_t

  type, public :: hupsel_replay_cache_t
    real(real64), allocatable :: cmsy(:)
  end type hupsel_replay_cache_t


  type, public :: hupsel_legacy_accounting_cursor_t
    real(real64) :: cgrai = 0.0_real64
    real(real64) :: cgird = 0.0_real64
    real(real64) :: crunon = 0.0_real64
    real(real64) :: cqssdi = 0.0_real64
    real(real64) :: cqbotup = 0.0_real64
    real(real64) :: caintc = 0.0_real64
    real(real64) :: crunoff = 0.0_real64
    real(real64) :: cqrot = 0.0_real64
    real(real64) :: cepd = 0.0_real64
    real(real64) :: cevap = 0.0_real64
    real(real64) :: cqdra = 0.0_real64
    real(real64) :: cqbotdo = 0.0_real64
  end type hupsel_legacy_accounting_cursor_t

  type, public :: hupsel_execution_diagnostics_t
    integer :: nonlinear_iterations = 0
    integer :: internal_retries = 0
    integer :: headcalc_calls = 0
    integer :: jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    real(real64) :: mass_in = 0.0_real64
    real(real64) :: mass_out = 0.0_real64
  end type hupsel_execution_diagnostics_t

  type, extends(transaction_state_t), public :: hupsel_column_state_t
    type(hupsel_physical_state_t) :: physical
    type(hupsel_forcing_cursor_t) :: forcing
    type(hupsel_process_cursor_t) :: process
    type(hupsel_numerical_state_t) :: numerical
    type(hupsel_legacy_time_projection_t) :: legacy_time
    type(hupsel_replay_cache_t) :: replay
    type(hupsel_legacy_accounting_cursor_t) :: accounting
  contains
    procedure :: clone => hupsel_column_clone
  end type hupsel_column_state_t

  type, extends(transaction_model_t), public :: hupsel_worker_component_t
    real(real64) :: base_t1900 = 0.0_real64
    real(real64), allocatable :: dz(:)
    type(hupsel_execution_diagnostics_t) :: last_diagnostics
    type(a23bs_worker_context_t) :: worker
    logical :: initialized = .false.
  contains
    procedure :: advance => hupsel_component_advance
    procedure :: storage => hupsel_component_storage
    procedure :: temporal_error => hupsel_component_temporal_error
  end type hupsel_worker_component_t

  public :: initialize_hupsel_worker_component, finalize_hupsel_worker_component
  public :: hupsel_worker_scratch_payload_bytes
  public :: capture_hupsel_column_state, restore_hupsel_column_state

  interface
    subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, worker)
      import :: fillen, a23bs_worker_context_t
      integer, intent(in) :: iCaller, iTask
      real(8), intent(inout) :: tstart_in, tend_in
      character(len=fillen), intent(in), optional :: swp_file, outfile
      type(a23bs_worker_context_t), intent(inout), optional :: worker
    end subroutine SWAP
  end interface

contains

  subroutine initialize_hupsel_worker_component(model, committed, swp_file, outfile, seed_start, seed_end, base_t1900)
    type(hupsel_worker_component_t), intent(out) :: model
    class(transaction_state_t), allocatable, intent(out) :: committed
    character(len=*), intent(in) :: swp_file, outfile
    real(real64), intent(in) :: seed_start, seed_end, base_t1900
    real(real64) :: t0, t1
    character(len=fillen) :: swp_local, out_local

    swp_local = swp_file
    out_local = outfile
    t0 = 0.0_real64
    t1 = 0.0_real64
    call SWAP(0, 1, t0, t1, swp_local, out_local)

    if (swmacro /= 0 .or. swsnow /= 0 .or. swhea /= 1 .or. swsolu /= 1) then
      error stop 'A23BS component: Hupsel qualification configuration mismatch'
    end if

    t0 = seed_start
    t1 = seed_end
    call a23bs_initialize_worker(model%worker, numnod, 0)
    call a23bs_reset_attempt_diagnostics(model%worker)
    call SWAP(0, 21, t0, t1, worker=model%worker)
    call SWAP(0, 2, t0, t1, worker=model%worker)

    allocate(model%dz(numnod))
    model%dz = dz(1:numnod)
    model%base_t1900 = base_t1900
    model%initialized = .true.
    model%last_diagnostics = hupsel_execution_diagnostics_t()

    allocate(hupsel_column_state_t :: committed)
    select type (state => committed)
    type is (hupsel_column_state_t)
      call capture_hupsel_column_state(state)
    class default
      error stop 'A23BS component: state allocation failure'
    end select
  end subroutine initialize_hupsel_worker_component

  subroutine finalize_hupsel_worker_component(model)
    type(hupsel_worker_component_t), intent(inout) :: model
    real(real64) :: t0, t1
    t0 = 0.0_real64
    t1 = 0.0_real64
    call SWAP(0, 3, t0, t1)
    call a23bs_release_worker(model%worker)
  end subroutine finalize_hupsel_worker_component

  subroutine hupsel_column_clone(self, copy)
    class(hupsel_column_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(hupsel_column_state_t :: copy)
    select type (target => copy)
    type is (hupsel_column_state_t)
      target%physical = self%physical
      target%forcing = self%forcing
      target%process = self%process
      target%numerical = self%numerical
      target%legacy_time = self%legacy_time
      target%replay = self%replay
      target%accounting = self%accounting
    class default
      error stop 'A23BS component: clone allocation failure'
    end select
  end subroutine hupsel_column_clone

  subroutine hupsel_component_advance(self, state, t0, t1, outcome)
    class(hupsel_worker_component_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: legacy_start, legacy_end
    real(real64) :: in0, out0

    outcome = trial_outcome_t()
    self%last_diagnostics = hupsel_execution_diagnostics_t()
    if (.not. self%initialized .or. .not. supported_interval(t0, t1)) return

    select type (column => state)
    type is (hupsel_column_state_t)
      call restore_hupsel_column_state(column)
      call a23bs_seed_timestep_control(self%worker, dt, dtmin)
      legacy_start = self%base_t1900 + real(nint(t0), real64)
      legacy_end = self%base_t1900 + real(nint(t1), real64) - 1.0_real64
      call a23bs_seed_execution_window(self%worker, t0, t1, legacy_start, legacy_end)
      in0 = current_mass_in_total()
      out0 = current_mass_out_total()
      call a23bs_reset_attempt_diagnostics(self%worker)
      call SWAP(0, 21, legacy_start, legacy_end, worker=self%worker)
      call SWAP(0, 2, legacy_start, legacy_end, worker=self%worker)

      call capture_hupsel_column_state(column)
      self%last_diagnostics%nonlinear_iterations = self%worker%diagnostics%nonlinear_iterations
      self%last_diagnostics%internal_retries = self%worker%diagnostics%internal_retries
      self%last_diagnostics%headcalc_calls = self%worker%diagnostics%headcalc_calls
      self%last_diagnostics%jacobian_builds = self%worker%diagnostics%jacobian_builds
      self%last_diagnostics%linear_solves = self%worker%diagnostics%linear_solves
      self%last_diagnostics%backtracking_attempts = self%worker%diagnostics%backtracking_attempts
      self%last_diagnostics%alternative_solver_calls = self%worker%diagnostics%alternative_solver_calls
      self%last_diagnostics%mass_in = current_mass_in_total() - in0
      self%last_diagnostics%mass_out = current_mass_out_total() - out0

      outcome%solver_ok = .true.
      outcome%mass_in = self%last_diagnostics%mass_in
      outcome%mass_out = self%last_diagnostics%mass_out
      outcome%nonlinear_iterations = self%last_diagnostics%nonlinear_iterations
      outcome%internal_retries = self%last_diagnostics%internal_retries
      outcome%headcalc_calls = self%last_diagnostics%headcalc_calls
      outcome%jacobian_builds = self%last_diagnostics%jacobian_builds
      outcome%linear_solves = self%last_diagnostics%linear_solves
      outcome%backtracking_attempts = self%last_diagnostics%backtracking_attempts
      outcome%alternative_solver_calls = self%last_diagnostics%alternative_solver_calls
    class default
      outcome%solver_ok = .false.
    end select
  end subroutine hupsel_component_advance

  function hupsel_component_storage(self, state) result(value)
    class(hupsel_worker_component_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    value = huge(0.0_real64)
    select type (column => state)
    type is (hupsel_column_state_t)
      if (allocated(column%physical%theta) .and. allocated(self%dz)) then
        if (size(column%physical%theta) == size(self%dz)) then
          value = sum(column%physical%theta * self%dz) + column%physical%pond
        end if
      end if
    end select
  end function hupsel_component_storage

  function hupsel_component_temporal_error(self, full_state, half_state) result(value)
    class(hupsel_worker_component_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    value = huge(0.0_real64)
    select type (full => full_state)
    type is (hupsel_column_state_t)
      select type (half => half_state)
      type is (hupsel_column_state_t)
        if (allocated(full%physical%h) .and. allocated(half%physical%h)) then
          value = max(maxval(abs(full%physical%h-half%physical%h)), &
                      maxval(abs(full%physical%theta-half%physical%theta)))
          value = max(value, maxval(abs(full%physical%tsoil-half%physical%tsoil)))
          value = max(value, maxval(abs(full%physical%cml-half%physical%cml)))
          value = max(value, abs(full%physical%pond-half%physical%pond))
        end if
      end select
    end select
    if (.not. self%initialized) value = huge(0.0_real64)
  end function hupsel_component_temporal_error

  subroutine capture_hupsel_column_state(state)
    type(hupsel_column_state_t), intent(inout) :: state
    call ensure_state_arrays(state)
    state%physical%h = h(1:numnod)
    state%physical%theta = theta(1:numnod)
    state%physical%tsoil = tsoil(1:numnod)
    state%physical%cml = cml(1:numnod)
    state%physical%pond = pond
    state%physical%ldwet = ldwet
    state%physical%spev = spev
    state%physical%saev = saev
    state%physical%gwl = gwl
    state%physical%volact = volact

    state%forcing%meteo_rec = meteo_rec
    state%forcing%rain_rec = rain_rec
    state%forcing%i_metdetail = i_metdetail
    state%forcing%fl_update_meteo = fl_update_meteo

    state%process%flirrigate = flirrigate
    state%process%fl_cropcalendar = fl_cropcalendar
    state%process%dayfix = dayfix
    state%process%nirri = nirri
    state%process%irrigevent = irrigevent
    state%process%gird = gird
    state%process%dt_irr_event = dt_irr_event

    state%numerical%dt = dt
    state%legacy_time%t1900 = t1900
    state%legacy_time%year_time = t
    state%legacy_time%day_time = tcum
    state%legacy_time%jan1_1900 = timjan1
    state%legacy_time%daynr = daynr
    state%legacy_time%daycum = daycum
    state%legacy_time%iyear = iyear
    state%legacy_time%imonth = imonth
    state%legacy_time%date = date
    state%replay%cmsy = cmsy(1:numnod)
    state%accounting%cgrai = cgrai
    state%accounting%cgird = cgird
    state%accounting%crunon = crunon
    state%accounting%cqssdi = cqssdi
    state%accounting%cqbotup = cqbotup
    state%accounting%caintc = caintc
    state%accounting%crunoff = crunoff
    state%accounting%cqrot = cqrot
    state%accounting%cepd = cepd
    state%accounting%cevap = cevap
    state%accounting%cqdra = cqdra
    state%accounting%cqbotdo = cqbotdo
  end subroutine capture_hupsel_column_state

  subroutine restore_hupsel_column_state(state)
    type(hupsel_column_state_t), intent(in) :: state
    if (.not. allocated(state%physical%h) .or. .not. allocated(state%replay%cmsy)) then
      error stop 'A23BS component: incomplete column state'
    end if

    h(1:numnod) = state%physical%h
    theta(1:numnod) = state%physical%theta
    tsoil(1:numnod) = state%physical%tsoil
    cml(1:numnod) = state%physical%cml
    pond = state%physical%pond
    ldwet = state%physical%ldwet
    spev = state%physical%spev
    saev = state%physical%saev
    gwl = state%physical%gwl
    volact = state%physical%volact

    meteo_rec = state%forcing%meteo_rec
    rain_rec = state%forcing%rain_rec
    i_metdetail = state%forcing%i_metdetail
    fl_update_meteo = state%forcing%fl_update_meteo

    flirrigate = state%process%flirrigate
    fl_cropcalendar = state%process%fl_cropcalendar
    dayfix = state%process%dayfix
    nirri = state%process%nirri
    irrigevent = state%process%irrigevent
    gird = state%process%gird
    dt_irr_event = state%process%dt_irr_event

    dt = state%numerical%dt
    t1900 = state%legacy_time%t1900
    t = state%legacy_time%year_time
    tcum = state%legacy_time%day_time
    timjan1 = state%legacy_time%jan1_1900
    daynr = state%legacy_time%daynr
    daycum = state%legacy_time%daycum
    iyear = state%legacy_time%iyear
    imonth = state%legacy_time%imonth
    date = state%legacy_time%date
    cmsy(1:numnod) = state%replay%cmsy
    cgrai = state%accounting%cgrai
    cgird = state%accounting%cgird
    crunon = state%accounting%crunon
    cqssdi = state%accounting%cqssdi
    cqbotup = state%accounting%cqbotup
    caintc = state%accounting%caintc
    crunoff = state%accounting%crunoff
    cqrot = state%accounting%cqrot
    cepd = state%accounting%cepd
    cevap = state%accounting%cevap
    cqdra = state%accounting%cqdra
    cqbotdo = state%accounting%cqbotdo
  end subroutine restore_hupsel_column_state

  subroutine ensure_state_arrays(state)
    type(hupsel_column_state_t), intent(inout) :: state
    if (allocated(state%physical%h)) then
      if (size(state%physical%h) == numnod .and. allocated(state%replay%cmsy)) then
        if (size(state%replay%cmsy) == numnod) return
      end if
      if (allocated(state%physical%h)) deallocate(state%physical%h)
      if (allocated(state%physical%theta)) deallocate(state%physical%theta)
      if (allocated(state%physical%tsoil)) deallocate(state%physical%tsoil)
      if (allocated(state%physical%cml)) deallocate(state%physical%cml)
      if (allocated(state%replay%cmsy)) deallocate(state%replay%cmsy)
    end if
    allocate(state%physical%h(numnod), state%physical%theta(numnod), &
             state%physical%tsoil(numnod), state%physical%cml(numnod), &
             state%replay%cmsy(numnod))
  end subroutine ensure_state_arrays

  pure logical function supported_interval(t0, t1)
    real(real64), intent(in) :: t0, t1
    supported_interval = t1 > t0 .and. &
      abs(t0-real(nint(t0),real64)) <= INTEGER_TIME_TOL .and. &
      abs(t1-real(nint(t1),real64)) <= INTEGER_TIME_TOL
  end function supported_interval


  integer function hupsel_worker_scratch_payload_bytes(model) result(bytes)
    type(hupsel_worker_component_t), intent(in) :: model
    bytes = a23bs_scratch_payload_bytes(model%worker)
  end function hupsel_worker_scratch_payload_bytes

  real(real64) function current_mass_in_total()
    current_mass_in_total = cgrai + cgird + crunon + cqssdi + cqbotup
  end function current_mass_in_total

  real(real64) function current_mass_out_total()
    current_mass_out_total = caintc + crunoff + cqrot + cepd + cevap + cqdra + cqbotdo
  end function current_mass_out_total

end module mod_a23bs_hupsel_worker_component
