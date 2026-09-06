module mod_a23bn_hupsel_native_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t
  use MOD_arrays, only: fillen
  use MOD_grid, only: numnod, dz
  use MOD_swap_base, only: swmacro, swsnow, swhea, swsolu
  use variables, only: h, theta, pond, dt, ldwet, spev, saev, gwl, volact, itnumb
  use MOD_SoilTemperature, only: tsoil
  use MOD_Solute, only: cml, cmsy
  use MOD_irrigation, only: flirrigate, dayfix, nirri, irrigevent, gird, dt_irr_event
  use MOD_cropdevelopment, only: fl_cropcalendar
  use MOD_meteo, only: meteo_rec, rain_rec, i_metdetail, fl_update_meteo
  use MOD_integral, only: cgrai, cgird, crunon, cqssdi, cqbotup, caintc, crunoff, cqrot, cepd, cevap, cqdra, cqbotdo
  implicit none
  private

  real(real64), parameter :: INTEGER_TIME_TOL = 1.0e-10_real64

  type, extends(transaction_state_t), public :: hupsel_native_state_t
    real(real64), allocatable :: h(:), theta(:), tsoil(:), cml(:), cmsy(:)
    real(real64) :: pond = 0.0_real64
    real(real64) :: dt = 0.0_real64
    real(real64) :: ldwet = 0.0_real64
    real(real64) :: spev = 0.0_real64
    real(real64) :: saev = 0.0_real64
    real(real64) :: gwl = 0.0_real64
    real(real64) :: volact = 0.0_real64
    logical :: flirrigate = .false.
    logical :: fl_cropcalendar = .false.
    integer :: dayfix = 0
    integer :: nirri = 0
    integer :: irrigevent = 0
    real(real64) :: gird = 0.0_real64
    real(real64) :: dt_irr_event = 0.0_real64
    integer :: meteo_rec = 0
    integer :: rain_rec = 0
    integer :: i_metdetail = 0
    logical :: fl_update_meteo = .false.
  contains
    procedure :: clone => hupsel_state_clone
  end type hupsel_native_state_t

  type, extends(transaction_model_t), public :: hupsel_native_model_t
    real(real64) :: base_t1900 = 0.0_real64
    real(real64), allocatable :: dz(:)
    integer :: last_successful_newton_iterations = 0
    logical :: initialized = .false.
    logical :: fail_next_advance = .false.
  contains
    procedure :: advance => hupsel_native_advance
    procedure :: storage => hupsel_native_storage
    procedure :: temporal_error => hupsel_native_temporal_error
  end type hupsel_native_model_t

  public :: initialize_hupsel_native, finalize_hupsel_native, capture_hupsel_state, restore_hupsel_state

  interface
    subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile)
      import :: fillen
      integer, intent(in) :: iCaller, iTask
      real(8), intent(inout) :: tstart_in, tend_in
      character(len=fillen), intent(in), optional :: swp_file, outfile
    end subroutine SWAP
  end interface

contains

  subroutine initialize_hupsel_native(model, committed, swp_file, outfile, seed_start, seed_end, base_t1900)
    type(hupsel_native_model_t), intent(out) :: model
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
      error stop 'A23BN adapter: Hupsel qualification configuration mismatch'
    end if

    t0 = seed_start
    t1 = seed_end
    call SWAP(0, 21, t0, t1)
    call SWAP(0, 2, t0, t1)

    allocate(model%dz(numnod))
    model%dz = dz(1:numnod)
    model%base_t1900 = base_t1900
    model%initialized = .true.
    allocate(hupsel_native_state_t :: committed)
    select type (state => committed)
    type is (hupsel_native_state_t)
      call capture_hupsel_state(state)
    class default
      error stop 'A23BN adapter: allocation failure'
    end select
  end subroutine initialize_hupsel_native

  subroutine finalize_hupsel_native()
    real(real64) :: t0, t1
    t0=0.0_real64; t1=0.0_real64
    call SWAP(0,3,t0,t1)
  end subroutine finalize_hupsel_native

  subroutine hupsel_state_clone(self, copy)
    class(hupsel_native_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(hupsel_native_state_t :: copy)
    select type (target => copy)
    type is (hupsel_native_state_t)
      call copy_hupsel_state(self, target)
    class default
      error stop 'A23BN adapter: clone allocation failure'
    end select
  end subroutine hupsel_state_clone

  subroutine copy_hupsel_state(source, target)
    type(hupsel_native_state_t), intent(in) :: source
    type(hupsel_native_state_t), intent(inout) :: target
    integer :: n
    if (.not. allocated(source%h)) return
    n=size(source%h)
    if (allocated(target%h)) deallocate(target%h,target%theta,target%tsoil,target%cml,target%cmsy)
    allocate(target%h(n),target%theta(n),target%tsoil(n),target%cml(n),target%cmsy(n))
    target%h=source%h; target%theta=source%theta; target%tsoil=source%tsoil; target%cml=source%cml
    target%cmsy=source%cmsy
    target%pond=source%pond; target%dt=source%dt; target%ldwet=source%ldwet; target%spev=source%spev
    target%saev=source%saev; target%gwl=source%gwl; target%volact=source%volact
    target%flirrigate=source%flirrigate; target%fl_cropcalendar=source%fl_cropcalendar
    target%dayfix=source%dayfix; target%nirri=source%nirri; target%irrigevent=source%irrigevent
    target%gird=source%gird; target%dt_irr_event=source%dt_irr_event
    target%meteo_rec=source%meteo_rec; target%rain_rec=source%rain_rec; target%i_metdetail=source%i_metdetail
    target%fl_update_meteo=source%fl_update_meteo
  end subroutine copy_hupsel_state

  subroutine hupsel_native_advance(self, state, t0, t1, outcome)
    class(hupsel_native_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: legacy_start, legacy_end
    integer :: iter_before, iter_after
    real(real64) :: in0, out0

    outcome = trial_outcome_t()
    if (.not. self%initialized .or. .not. supported_interval(t0, t1)) return

    select type (physical => state)
    type is (hupsel_native_state_t)
      if (self%fail_next_advance) then
        self%fail_next_advance = .false.
        if (allocated(physical%h)) physical%h = physical%h + 9999.0_real64
        outcome%solver_ok = .false.
        return
      end if

      call restore_hupsel_state(physical)
      legacy_start = self%base_t1900 + real(nint(t0), real64)
      legacy_end = self%base_t1900 + real(nint(t1), real64) - 1.0_real64
      iter_before = weighted_iteration_total()
      in0 = cgrai + cgird + crunon + cqssdi + cqbotup
      out0 = caintc + crunoff + cqrot + cepd + cevap + cqdra + cqbotdo
      call SWAP(0, 21, legacy_start, legacy_end)
      call SWAP(0, 2, legacy_start, legacy_end)
      iter_after = weighted_iteration_total()
      self%last_successful_newton_iterations = max(0, iter_after - iter_before)

      call capture_hupsel_state(physical)
      outcome%solver_ok = .true.
      outcome%mass_in = (cgrai + cgird + crunon + cqssdi + cqbotup) - in0
      outcome%mass_out = (caintc + crunoff + cqrot + cepd + cevap + cqdra + cqbotdo) - out0
      outcome%nonlinear_iterations = self%last_successful_newton_iterations
    class default
      outcome%solver_ok = .false.
    end select
  end subroutine hupsel_native_advance

  function hupsel_native_storage(self, state) result(value)
    class(hupsel_native_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    value = huge(0.0_real64)
    select type (physical => state)
    type is (hupsel_native_state_t)
      if (allocated(physical%theta) .and. allocated(self%dz)) then
        if (size(physical%theta) == size(self%dz)) value = sum(physical%theta * self%dz) + physical%pond
      end if
    end select
  end function hupsel_native_storage

  function hupsel_native_temporal_error(self, full_state, half_state) result(value)
    class(hupsel_native_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    value = huge(0.0_real64)
    select type (full => full_state)
    type is (hupsel_native_state_t)
      select type (half => half_state)
      type is (hupsel_native_state_t)
        if (allocated(full%h) .and. allocated(half%h)) then
          value = max(maxval(abs(full%h-half%h)), maxval(abs(full%theta-half%theta)))
          value = max(value, maxval(abs(full%tsoil-half%tsoil)))
          value = max(value, maxval(abs(full%cml-half%cml)))
          value = max(value, abs(full%pond-half%pond))
        end if
      end select
    end select
    if (.not. self%initialized) value = huge(0.0_real64)
  end function hupsel_native_temporal_error

  subroutine capture_hupsel_state(state)
    type(hupsel_native_state_t), intent(inout) :: state
    call ensure_state_arrays(state)
    state%h = h(1:numnod)
    state%theta = theta(1:numnod)
    state%tsoil = tsoil(1:numnod)
    state%cml = cml(1:numnod)
    state%cmsy = cmsy(1:numnod)
    state%pond = pond; state%dt = dt; state%ldwet = ldwet
    state%spev = spev; state%saev = saev; state%gwl = gwl; state%volact = volact
    state%flirrigate = flirrigate; state%dayfix = dayfix; state%nirri = nirri
    state%irrigevent = irrigevent; state%gird = gird; state%dt_irr_event = dt_irr_event
    state%fl_cropcalendar = fl_cropcalendar
    state%meteo_rec = meteo_rec; state%rain_rec = rain_rec; state%i_metdetail = i_metdetail
    state%fl_update_meteo = fl_update_meteo
  end subroutine capture_hupsel_state

  subroutine restore_hupsel_state(state)
    type(hupsel_native_state_t), intent(in) :: state
    if (.not. allocated(state%h)) error stop 'A23BN adapter: unallocated state'
    h(1:numnod)=state%h; theta(1:numnod)=state%theta; tsoil(1:numnod)=state%tsoil
    cml(1:numnod)=state%cml; cmsy(1:numnod)=state%cmsy
    pond=state%pond; dt=state%dt; ldwet=state%ldwet; spev=state%spev; saev=state%saev
    gwl=state%gwl; volact=state%volact
    flirrigate=state%flirrigate; dayfix=state%dayfix; nirri=state%nirri
    irrigevent=state%irrigevent; gird=state%gird; dt_irr_event=state%dt_irr_event
    fl_cropcalendar=state%fl_cropcalendar
    meteo_rec=state%meteo_rec; rain_rec=state%rain_rec; i_metdetail=state%i_metdetail
    fl_update_meteo=state%fl_update_meteo
  end subroutine restore_hupsel_state

  subroutine ensure_state_arrays(state)
    type(hupsel_native_state_t), intent(inout) :: state
    if (allocated(state%h)) then
      if (size(state%h) == numnod) return
      deallocate(state%h,state%theta,state%tsoil,state%cml,state%cmsy)
    end if
    allocate(state%h(numnod),state%theta(numnod),state%tsoil(numnod),state%cml(numnod),state%cmsy(numnod))
  end subroutine ensure_state_arrays

  pure logical function supported_interval(t0, t1)
    real(real64), intent(in) :: t0, t1
    supported_interval = t1 > t0 .and. abs(t0-real(nint(t0),real64)) <= INTEGER_TIME_TOL .and. &
                         abs(t1-real(nint(t1),real64)) <= INTEGER_TIME_TOL
  end function supported_interval

  integer function weighted_iteration_total()
    integer :: i
    weighted_iteration_total = 0
    do i=1,size(itnumb,1)
      weighted_iteration_total = weighted_iteration_total + i*itnumb(i,1)
    end do
  end function weighted_iteration_total

end module mod_a23bn_hupsel_native_adapter
