module MOD_wofost81_nitrogen

   use iso_fortran_env, only: real64
   use ieee_arithmetic, only: ieee_is_finite
   implicit none
   private

   integer, parameter, public :: WOFN81_OK = 0
   integer, parameter, public :: WOFN81_INVALID_INPUT = 1
   integer, parameter, public :: WOFN81_NEGATIVE_CANDIDATE = 2
   integer, parameter, public :: WOFN81_BALANCE_FAILURE = 3

   type, public :: WOFOST81_n_param
      real(real64) :: nmaxst_fr = 0.0_real64
      real(real64) :: nmaxrt_fr = 0.0_real64
      real(real64) :: nmaxso = 0.0_real64
      real(real64) :: nresidlv = 0.0_real64
      real(real64) :: nresidst = 0.0_real64
      real(real64) :: nresidrt = 0.0_real64
      real(real64) :: tcnt = 1.0_real64
      real(real64) :: nfix_fr = 0.0_real64
      real(real64) :: rnuptakemax = 0.0_real64
      real(real64) :: dvs_n_transl = 0.0_real64
   end type WOFOST81_n_param

   type, public :: WOFOST81_n_state
      real(real64) :: namountlv = 0.0_real64
      real(real64) :: namountst = 0.0_real64
      real(real64) :: namountrt = 0.0_real64
      real(real64) :: namountso = 0.0_real64
      real(real64) :: nuptake_total = 0.0_real64
      real(real64) :: nfix_total = 0.0_real64
      real(real64) :: nlosses_total = 0.0_real64
      real(real64) :: initial_total = 0.0_real64
   end type WOFOST81_n_state

   type, public :: WOFOST81_n_request
      integer :: status = WOFN81_OK
      real(real64) :: ndemandlv = 0.0_real64
      real(real64) :: ndemandst = 0.0_real64
      real(real64) :: ndemandrt = 0.0_real64
      real(real64) :: ndemandso = 0.0_real64
      real(real64) :: ndemand = 0.0_real64
      real(real64) :: ntranslocatablelv = 0.0_real64
      real(real64) :: ntranslocatablest = 0.0_real64
      real(real64) :: ntranslocatablert = 0.0_real64
      real(real64) :: ntranslocatable = 0.0_real64
      real(real64) :: rntranslocationlv = 0.0_real64
      real(real64) :: rntranslocationst = 0.0_real64
      real(real64) :: rntranslocationrt = 0.0_real64
      real(real64) :: rntranslocation = 0.0_real64
      real(real64) :: rnfixation = 0.0_real64
      real(real64) :: soil_request = 0.0_real64
   end type WOFOST81_n_request

   type, public :: WOFOST81_n_flux
      integer :: status = WOFN81_OK
      real(real64) :: rnuptake = 0.0_real64
      real(real64) :: rnfixation = 0.0_real64
      real(real64) :: rntranslocationlv_applied = 0.0_real64
      real(real64) :: rntranslocationst_applied = 0.0_real64
      real(real64) :: rntranslocationrt_applied = 0.0_real64
      real(real64) :: rntranslocation_applied = 0.0_real64
      real(real64) :: rnuptakelv = 0.0_real64
      real(real64) :: rnuptakest = 0.0_real64
      real(real64) :: rnuptakert = 0.0_real64
      real(real64) :: rnuptakeso = 0.0_real64
      real(real64) :: rndeathlv = 0.0_real64
      real(real64) :: rndeathst = 0.0_real64
      real(real64) :: rndeathrt = 0.0_real64
      real(real64) :: rnamountlv = 0.0_real64
      real(real64) :: rnamountst = 0.0_real64
      real(real64) :: rnamountRT = 0.0_real64
      real(real64) :: rnamountso = 0.0_real64
      real(real64) :: rnloss = 0.0_real64
      real(real64) :: balance_residual = 0.0_real64
      real(real64) :: balance_tolerance = 0.0_real64
   end type WOFOST81_n_flux

   public :: initialize_wofost81_n_state
   public :: prepare_wofost81_n_request
   public :: apply_wofost81_n_supply

contains

   pure subroutine initialize_wofost81_n_state(wlv, wst, wrt, nmaxlv, params, state, status)
      real(real64), intent(in) :: wlv, wst, wrt, nmaxlv
      type(WOFOST81_n_param), intent(in) :: params
      type(WOFOST81_n_state), intent(out) :: state
      integer, intent(out) :: status

      state = WOFOST81_n_state()
      status = WOFN81_OK
      if (.not. finite_nonnegative([wlv, wst, wrt, nmaxlv, params%nmaxst_fr, params%nmaxrt_fr])) then
         status = WOFN81_INVALID_INPUT
         return
      end if
      state%namountlv = wlv*nmaxlv
      state%namountst = wst*nmaxlv*params%nmaxst_fr
      state%namountrt = wrt*nmaxlv*params%nmaxrt_fr
      state%namountso = 0.0_real64
      state%initial_total = state%namountlv + state%namountst + state%namountrt
   end subroutine initialize_wofost81_n_state

   pure subroutine prepare_wofost81_n_request(params, committed, dvs, nmaxlv, wlv, wst, wrt, wso, &
                                               grlv, grst, grrt, grso, rftra, request)
      type(WOFOST81_n_param), intent(in) :: params
      type(WOFOST81_n_state), intent(in) :: committed
      real(real64), intent(in) :: dvs, nmaxlv, wlv, wst, wrt, wso
      real(real64), intent(in) :: grlv, grst, grrt, grso, rftra
      type(WOFOST81_n_request), intent(out) :: request

      real(real64) :: nmaxst, nmaxrt, nutrient_limit

      request = WOFOST81_n_request()
      if (.not. valid_params(params) .or. .not. valid_state(committed) .or. &
          .not. finite_nonnegative([nmaxlv, wlv, wst, wrt, wso, grlv, grst, grrt, grso]) .or. &
          .not. ieee_is_finite(dvs) .or. .not. ieee_is_finite(rftra)) then
         request%status = WOFN81_INVALID_INPUT
         return
      end if

      nmaxst = params%nmaxst_fr*nmaxlv
      nmaxrt = params%nmaxrt_fr*nmaxlv
      nutrient_limit = merge(1.0_real64, 0.0_real64, rftra > 0.01_real64)

      request%ndemandlv = max(nmaxlv*wlv - committed%namountlv, 0.0_real64) + max(grlv*nmaxlv, 0.0_real64)
      request%ndemandst = max(nmaxst*wst - committed%namountst, 0.0_real64) + max(grst*nmaxst, 0.0_real64)
      request%ndemandrt = max(nmaxrt*wrt - committed%namountrt, 0.0_real64) + max(grrt*nmaxrt, 0.0_real64)
      request%ndemandso = max(params%nmaxso*wso - committed%namountso, 0.0_real64) + max(grso*params%nmaxso, 0.0_real64)
      request%ndemand = request%ndemandlv + request%ndemandst + request%ndemandrt + request%ndemandso

      request%rnfixation = max(0.0_real64, params%nfix_fr*request%ndemand)*nutrient_limit

      if (dvs >= params%dvs_n_transl) then
         request%ntranslocatablelv = max(0.0_real64, committed%namountlv - wlv*params%nresidlv)
         request%ntranslocatablest = max(0.0_real64, committed%namountst - wst*params%nresidst)
         request%ntranslocatablert = max(0.0_real64, committed%namountrt - wrt*params%nresidrt)
         request%ntranslocatable = request%ntranslocatablelv + request%ntranslocatablest + request%ntranslocatablert
      end if

      request%rntranslocation = min(request%ndemandso, request%ntranslocatable/params%tcnt)
      if (request%ntranslocatable > 0.0_real64) then
         request%rntranslocationlv = request%rntranslocation*request%ntranslocatablelv/request%ntranslocatable
         request%rntranslocationst = request%rntranslocation*request%ntranslocatablest/request%ntranslocatable
         request%rntranslocationrt = request%rntranslocation*request%ntranslocatablert/request%ntranslocatable
      end if

      request%soil_request = max(0.0_real64, min(request%ndemand - request%rnfixation, params%rnuptakemax))*nutrient_limit
   end subroutine prepare_wofost81_n_request

   pure subroutine apply_wofost81_n_supply(params, committed, request, wlv, wst, wrt, drlv, drst, drrt, &
                                           soil_supply, candidate, flux)
      type(WOFOST81_n_param), intent(in) :: params
      type(WOFOST81_n_state), intent(in) :: committed
      type(WOFOST81_n_request), intent(in) :: request
      real(real64), intent(in) :: wlv, wst, wrt, drlv, drst, drrt, soil_supply
      type(WOFOST81_n_state), intent(out) :: candidate
      type(WOFOST81_n_flux), intent(out) :: flux

      real(real64) :: supplied_n, target_lv, target_st, target_rt, target_so, scale
      real(real64) :: surviving_wlv, surviving_wst, surviving_wrt
      real(real64) :: surviving_nlv, surviving_nst, surviving_nrt
      real(real64) :: available_trans_lv, available_trans_st, available_trans_rt
      real(real64) :: total_now, balance_scale

      candidate = committed
      flux = WOFOST81_n_flux()
      if (.not. valid_params(params) .or. .not. valid_state(committed) .or. request%status /= WOFN81_OK .or. &
          .not. finite_nonnegative([wlv, wst, wrt, drlv, drst, drrt, soil_supply])) then
         flux%status = WOFN81_INVALID_INPUT
         return
      end if

      flux%rnuptake = min(request%soil_request, soil_supply)
      flux%rnfixation = request%rnfixation
      supplied_n = flux%rnuptake + flux%rnfixation

      if (wlv > 0.0_real64) flux%rndeathlv = (committed%namountlv/wlv)*drlv
      if (wst > 0.0_real64) flux%rndeathst = (committed%namountst/wst)*drst
      if (wrt > 0.0_real64) flux%rndeathrt = (committed%namountrt/wrt)*drrt

      ! PCSE computes senescence and translocation as same-step rates from the
      ! same committed donor pools. When strong senescence occurs this can make
      ! a donor-N candidate negative. Preserve the reference request, but apply
      ! only N that remains physically translocatable after same-step senescence.
      surviving_wlv = max(0.0_real64, wlv - drlv)
      surviving_wst = max(0.0_real64, wst - drst)
      surviving_wrt = max(0.0_real64, wrt - drrt)
      surviving_nlv = max(0.0_real64, committed%namountlv - flux%rndeathlv)
      surviving_nst = max(0.0_real64, committed%namountst - flux%rndeathst)
      surviving_nrt = max(0.0_real64, committed%namountrt - flux%rndeathrt)
      available_trans_lv = max(0.0_real64, surviving_nlv - surviving_wlv*params%nresidlv)
      available_trans_st = max(0.0_real64, surviving_nst - surviving_wst*params%nresidst)
      available_trans_rt = max(0.0_real64, surviving_nrt - surviving_wrt*params%nresidrt)

      flux%rntranslocationlv_applied = min(request%rntranslocationlv, available_trans_lv)
      flux%rntranslocationst_applied = min(request%rntranslocationst, available_trans_st)
      flux%rntranslocationrt_applied = min(request%rntranslocationrt, available_trans_rt)
      flux%rntranslocation_applied = flux%rntranslocationlv_applied + flux%rntranslocationst_applied + &
                                     flux%rntranslocationrt_applied

      if (request%ndemand > 0.0_real64) then
         target_lv = request%ndemandlv + flux%rntranslocationlv_applied
         target_st = request%ndemandst + flux%rntranslocationst_applied
         target_rt = request%ndemandrt + flux%rntranslocationrt_applied
         target_so = request%ndemandso - flux%rntranslocation_applied
         scale = supplied_n/request%ndemand
         flux%rnuptakelv = max(0.0_real64, min(target_lv, target_lv*scale))
         flux%rnuptakest = max(0.0_real64, min(target_st, target_st*scale))
         flux%rnuptakert = max(0.0_real64, min(target_rt, target_rt*scale))
         flux%rnuptakeso = max(0.0_real64, min(target_so, target_so*scale))
      end if

      flux%rnamountlv = flux%rnuptakelv - flux%rntranslocationlv_applied - flux%rndeathlv
      flux%rnamountst = flux%rnuptakest - flux%rntranslocationst_applied - flux%rndeathst
      flux%rnamountRT = flux%rnuptakert - flux%rntranslocationrt_applied - flux%rndeathrt
      flux%rnamountso = flux%rnuptakeso + flux%rntranslocation_applied
      flux%rnloss = flux%rndeathlv + flux%rndeathst + flux%rndeathrt

      candidate%namountlv = committed%namountlv + flux%rnamountlv
      candidate%namountst = committed%namountst + flux%rnamountst
      candidate%namountrt = committed%namountrt + flux%rnamountRT
      candidate%namountso = committed%namountso + flux%rnamountso
      candidate%nuptake_total = committed%nuptake_total + flux%rnuptake
      candidate%nfix_total = committed%nfix_total + flux%rnfixation
      candidate%nlosses_total = committed%nlosses_total + flux%rnloss

      balance_scale = max(1.0_real64, committed%initial_total + candidate%nuptake_total + candidate%nfix_total)
      flux%balance_tolerance = 2048.0_real64*epsilon(1.0_real64)*balance_scale

      if (min(candidate%namountlv, candidate%namountst, candidate%namountrt, candidate%namountso) < &
          -flux%balance_tolerance) then
         candidate = committed
         flux%status = WOFN81_NEGATIVE_CANDIDATE
         return
      end if
      candidate%namountlv = max(0.0_real64, candidate%namountlv)
      candidate%namountst = max(0.0_real64, candidate%namountst)
      candidate%namountrt = max(0.0_real64, candidate%namountrt)
      candidate%namountso = max(0.0_real64, candidate%namountso)

      total_now = candidate%namountlv + candidate%namountst + candidate%namountrt + candidate%namountso
      flux%balance_residual = committed%initial_total + candidate%nuptake_total + candidate%nfix_total - &
                              total_now - candidate%nlosses_total
      if (abs(flux%balance_residual) > flux%balance_tolerance) then
         candidate = committed
         flux%status = WOFN81_BALANCE_FAILURE
         return
      end if
   end subroutine apply_wofost81_n_supply

   pure logical function finite_nonnegative(v)
      real(real64), intent(in) :: v(:)
      finite_nonnegative = all(ieee_is_finite(v)) .and. all(v >= 0.0_real64)
   end function finite_nonnegative

   pure logical function valid_state(s)
      type(WOFOST81_n_state), intent(in) :: s
      real(real64) :: v(8)
      v = [s%namountlv, s%namountst, s%namountrt, s%namountso, s%nuptake_total, s%nfix_total, s%nlosses_total, s%initial_total]
      valid_state = finite_nonnegative(v)
   end function valid_state

   pure logical function valid_params(p)
      type(WOFOST81_n_param), intent(in) :: p
      real(real64) :: v(10)
      v = [p%nmaxst_fr, p%nmaxrt_fr, p%nmaxso, p%nresidlv, p%nresidst, p%nresidrt, &
           p%tcnt, p%nfix_fr, p%rnuptakemax, p%dvs_n_transl]
      valid_params = finite_nonnegative(v) .and. p%tcnt > 0.0_real64 .and. p%nfix_fr <= 1.0_real64
   end function valid_params

end module MOD_wofost81_nitrogen
