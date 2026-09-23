module mod_fmr_ribasim_management_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_request_t
  use mod_rutter_interception_process, only: rutter_interval_input_t
  use mod_fmr_hupsel_management_transaction, only: fmr_hupsel_management_demand_receipt_t, &
       fmr_hupsel_management_forcing_t, prepare_fmr_hupsel_management_forcing, FMR_RM_OK
  implicit none
  private

  integer, parameter, public :: FMR_RB_OK = 0
  integer, parameter, public :: FMR_RB_INVALID_DEMAND_RECEIPT = 1
  integer, parameter, public :: FMR_RB_INVALID_REALIZATION = 2
  integer, parameter, public :: FMR_RB_PROVENANCE_MISMATCH = 3
  integer, parameter, public :: FMR_RB_FULL_REALIZATION_NOT_ADMITTED = 4
  integer, parameter, public :: FMR_RB_FORCING_CONSTRUCTION_FAILED = 5

  real(real64), parameter, public :: FMR_RB_FULL_ALLOCATION_TOLERANCE_CM = 1.0e-6_real64
  real(real64), parameter, public :: FMR_RB_FULL_SUPPLY_TOLERANCE_CM = 1.0e-4_real64
  real(real64), parameter, public :: FMR_RB_LOW_STORAGE_FACTOR_TOLERANCE = 1.0e-12_real64
  real(real64), parameter, public :: FMR_RB_REQUIRED_LEVEL_MARGIN_MULTIPLE = 3.0_real64

  type, public :: fmr_ribasim_realization_receipt_t
    private
    logical :: initialized = .false.
    integer(int64) :: management_lineage_value = 0_int64
    integer(int64) :: management_revision_value = -1_int64
    integer(int64) :: crop_revision_value = -1_int64
    integer(int64) :: ribasim_origin_id_value = 0_int64
    integer(int64) :: ribasim_origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: requested_depth_cm_value = 0.0_real64
    real(real64) :: allocated_depth_cm_value = 0.0_real64
    real(real64) :: supplied_depth_cm_value = 0.0_real64
    real(real64) :: source_level_margin_m_value = 0.0_real64
    real(real64) :: level_difference_threshold_m_value = 0.0_real64
    real(real64) :: low_storage_factor_value = 0.0_real64
  contains
    procedure, public :: ready => fmr_ribasim_realization_receipt_ready
    procedure, public :: matches_demand => fmr_ribasim_realization_matches_demand
    procedure, public :: management_lineage_id => fmr_ribasim_management_lineage
    procedure, public :: management_origin_revision => fmr_ribasim_management_revision
    procedure, public :: crop_origin_revision => fmr_ribasim_crop_revision
    procedure, public :: ribasim_origin_id => fmr_ribasim_origin_id
    procedure, public :: ribasim_origin_revision => fmr_ribasim_origin_revision
    procedure, public :: interval => fmr_ribasim_interval
    procedure, public :: requested_depth_cm => fmr_ribasim_requested_depth
    procedure, public :: allocated_depth_cm => fmr_ribasim_allocated_depth
    procedure, public :: supplied_depth_cm => fmr_ribasim_supplied_depth
  end type fmr_ribasim_realization_receipt_t

  public :: construct_fmr_ribasim_full_realization_receipt
  public :: prepare_fmr_hupsel_management_forcing_from_ribasim_receipt

contains

  pure real(real64) function scalar_tolerance(a,b) result(tol)
    real(real64), intent(in) :: a,b
    tol = 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64,abs(a),abs(b))
  end function scalar_tolerance

  pure logical function same_scalar(a,b) result(same)
    real(real64), intent(in) :: a,b
    same = ieee_is_finite(a) .and. ieee_is_finite(b) .and. abs(a-b) <= scalar_tolerance(a,b)
  end function same_scalar

  logical function fmr_ribasim_realization_receipt_ready(self) result(ready)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self

    ready = self%initialized
    if (.not. ready) return
    ready = self%management_lineage_value > 0_int64 .and. self%management_revision_value >= 0_int64 .and. &
         self%crop_revision_value >= 0_int64 .and. self%ribasim_origin_id_value > 0_int64 .and. &
         self%ribasim_origin_revision_value >= 0_int64
    if (.not. ready) return
    ready = ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%requested_depth_cm_value) .and. ieee_is_finite(self%allocated_depth_cm_value) .and. &
         ieee_is_finite(self%supplied_depth_cm_value) .and. self%requested_depth_cm_value >= 0.0_real64 .and. &
         self%allocated_depth_cm_value >= 0.0_real64 .and. self%supplied_depth_cm_value >= 0.0_real64
    if (.not. ready) return
    ready = ieee_is_finite(self%source_level_margin_m_value) .and. &
         ieee_is_finite(self%level_difference_threshold_m_value) .and. &
         ieee_is_finite(self%low_storage_factor_value) .and. self%level_difference_threshold_m_value >= 0.0_real64
    if (.not. ready) return
    ready = abs(self%allocated_depth_cm_value-self%requested_depth_cm_value) <= FMR_RB_FULL_ALLOCATION_TOLERANCE_CM .and. &
         abs(self%supplied_depth_cm_value-self%requested_depth_cm_value) <= FMR_RB_FULL_SUPPLY_TOLERANCE_CM .and. &
         self%supplied_depth_cm_value <= self%allocated_depth_cm_value + FMR_RB_FULL_SUPPLY_TOLERANCE_CM .and. &
         self%source_level_margin_m_value + scalar_tolerance(self%source_level_margin_m_value, &
         FMR_RB_REQUIRED_LEVEL_MARGIN_MULTIPLE*self%level_difference_threshold_m_value) >= &
         FMR_RB_REQUIRED_LEVEL_MARGIN_MULTIPLE*self%level_difference_threshold_m_value .and. &
         abs(self%low_storage_factor_value-1.0_real64) <= FMR_RB_LOW_STORAGE_FACTOR_TOLERANCE
  end function fmr_ribasim_realization_receipt_ready

  subroutine construct_fmr_ribasim_full_realization_receipt(demand,ribasim_origin_id,ribasim_origin_revision, &
       allocated_depth_cm,supplied_depth_cm,source_level_margin_m,level_difference_threshold_m,low_storage_factor, &
       receipt,status)
    type(fmr_hupsel_management_demand_receipt_t), intent(in) :: demand
    integer(int64), intent(in) :: ribasim_origin_id, ribasim_origin_revision
    real(real64), intent(in) :: allocated_depth_cm,supplied_depth_cm
    real(real64), intent(in) :: source_level_margin_m,level_difference_threshold_m,low_storage_factor
    type(fmr_ribasim_realization_receipt_t), intent(out) :: receipt
    integer, intent(out) :: status
    real(real64) :: t0,t1,requested
    logical :: available

    receipt = fmr_ribasim_realization_receipt_t()
    status = FMR_RB_INVALID_DEMAND_RECEIPT
    if (.not. demand%ready()) return
    call demand%interval(t0,t1,available)
    if (.not. available) return
    requested = demand%requested_depth_cm()

    status = FMR_RB_INVALID_REALIZATION
    if (ribasim_origin_id <= 0_int64 .or. ribasim_origin_revision < 0_int64) return
    if (.not. ieee_is_finite(allocated_depth_cm) .or. .not. ieee_is_finite(supplied_depth_cm)) return
    if (.not. ieee_is_finite(source_level_margin_m) .or. .not. ieee_is_finite(level_difference_threshold_m) .or. &
         .not. ieee_is_finite(low_storage_factor)) return
    if (allocated_depth_cm < 0.0_real64 .or. supplied_depth_cm < 0.0_real64 .or. &
         level_difference_threshold_m < 0.0_real64) return

    status = FMR_RB_FULL_REALIZATION_NOT_ADMITTED
    if (abs(allocated_depth_cm-requested) > FMR_RB_FULL_ALLOCATION_TOLERANCE_CM) return
    if (abs(supplied_depth_cm-requested) > FMR_RB_FULL_SUPPLY_TOLERANCE_CM) return
    if (supplied_depth_cm > allocated_depth_cm + FMR_RB_FULL_SUPPLY_TOLERANCE_CM) return
    if (source_level_margin_m + scalar_tolerance(source_level_margin_m, &
         FMR_RB_REQUIRED_LEVEL_MARGIN_MULTIPLE*level_difference_threshold_m) < &
         FMR_RB_REQUIRED_LEVEL_MARGIN_MULTIPLE*level_difference_threshold_m) return
    if (abs(low_storage_factor-1.0_real64) > FMR_RB_LOW_STORAGE_FACTOR_TOLERANCE) return

    receipt%management_lineage_value = demand%origin_lineage_id()
    receipt%management_revision_value = demand%origin_revision()
    receipt%crop_revision_value = demand%crop_origin_revision()
    receipt%ribasim_origin_id_value = ribasim_origin_id
    receipt%ribasim_origin_revision_value = ribasim_origin_revision
    receipt%t0_value = t0
    receipt%t1_value = t1
    receipt%requested_depth_cm_value = requested
    receipt%allocated_depth_cm_value = allocated_depth_cm
    receipt%supplied_depth_cm_value = supplied_depth_cm
    receipt%source_level_margin_m_value = source_level_margin_m
    receipt%level_difference_threshold_m_value = level_difference_threshold_m
    receipt%low_storage_factor_value = low_storage_factor
    receipt%initialized = .true.
    if (.not. receipt%ready()) then
      receipt = fmr_ribasim_realization_receipt_t()
      status = FMR_RB_INVALID_REALIZATION
      return
    end if
    status = FMR_RB_OK
  end subroutine construct_fmr_ribasim_full_realization_receipt

  logical function fmr_ribasim_realization_matches_demand(self,demand) result(matches)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    type(fmr_hupsel_management_demand_receipt_t), intent(in) :: demand
    real(real64) :: t0,t1
    logical :: available

    matches = self%ready() .and. demand%ready()
    if (.not. matches) return
    call demand%interval(t0,t1,available)
    if (.not. available) then
      matches = .false.
      return
    end if
    matches = self%management_lineage_value == demand%origin_lineage_id() .and. &
         self%management_revision_value == demand%origin_revision() .and. &
         self%crop_revision_value == demand%crop_origin_revision() .and. &
         same_scalar(self%t0_value,t0) .and. same_scalar(self%t1_value,t1) .and. &
         abs(self%requested_depth_cm_value-demand%requested_depth_cm()) <= FMR_RB_FULL_ALLOCATION_TOLERANCE_CM
  end function fmr_ribasim_realization_matches_demand

  subroutine prepare_fmr_hupsel_management_forcing_from_ribasim_receipt(demand,rutter_template,realization,forcing,status)
    type(fmr_hupsel_management_demand_receipt_t), intent(in) :: demand
    type(rutter_interval_input_t), intent(in) :: rutter_template
    type(fmr_ribasim_realization_receipt_t), intent(in) :: realization
    type(fmr_hupsel_management_forcing_t), intent(out) :: forcing
    integer, intent(out) :: status
    type(tcs1_dcs2_sprinkling_request_t) :: request
    logical :: available
    integer :: rm_status

    forcing = fmr_hupsel_management_forcing_t()
    status = FMR_RB_INVALID_DEMAND_RECEIPT
    if (.not. demand%ready()) return
    status = FMR_RB_INVALID_REALIZATION
    if (.not. realization%ready()) return
    status = FMR_RB_PROVENANCE_MISMATCH
    if (.not. realization%matches_demand(demand)) return

    call demand%request_copy(request,available)
    if (.not. available) then
      status = FMR_RB_INVALID_DEMAND_RECEIPT
      return
    end if

    call prepare_fmr_hupsel_management_forcing(request,rutter_template,demand%crop_origin_revision(), &
         realization%allocated_depth_cm(),realization%supplied_depth_cm(),forcing,rm_status)
    if (rm_status /= FMR_RM_OK) then
      status = FMR_RB_FORCING_CONSTRUCTION_FAILED
      return
    end if
    status = FMR_RB_OK
  end subroutine prepare_fmr_hupsel_management_forcing_from_ribasim_receipt

  integer(int64) function fmr_ribasim_management_lineage(self) result(value)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    value = self%management_lineage_value
  end function fmr_ribasim_management_lineage

  integer(int64) function fmr_ribasim_management_revision(self) result(value)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    value = self%management_revision_value
  end function fmr_ribasim_management_revision

  integer(int64) function fmr_ribasim_crop_revision(self) result(value)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    value = self%crop_revision_value
  end function fmr_ribasim_crop_revision

  integer(int64) function fmr_ribasim_origin_id(self) result(value)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    value = self%ribasim_origin_id_value
  end function fmr_ribasim_origin_id

  integer(int64) function fmr_ribasim_origin_revision(self) result(value)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    value = self%ribasim_origin_revision_value
  end function fmr_ribasim_origin_revision

  subroutine fmr_ribasim_interval(self,t0,t1,available)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    real(real64), intent(out) :: t0,t1
    logical, intent(out) :: available
    available = self%ready()
    if (available) then
      t0=self%t0_value; t1=self%t1_value
    else
      t0=0.0_real64; t1=0.0_real64
    end if
  end subroutine fmr_ribasim_interval

  real(real64) function fmr_ribasim_requested_depth(self) result(value)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    if (self%ready()) then; value=self%requested_depth_cm_value; else; value=0.0_real64; end if
  end function fmr_ribasim_requested_depth

  real(real64) function fmr_ribasim_allocated_depth(self) result(value)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    if (self%ready()) then; value=self%allocated_depth_cm_value; else; value=0.0_real64; end if
  end function fmr_ribasim_allocated_depth

  real(real64) function fmr_ribasim_supplied_depth(self) result(value)
    class(fmr_ribasim_realization_receipt_t), intent(in) :: self
    if (self%ready()) then; value=self%supplied_depth_cm_value; else; value=0.0_real64; end if
  end function fmr_ribasim_supplied_depth

end module mod_fmr_ribasim_management_binding
