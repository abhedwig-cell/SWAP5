module mod_wofost81_parameter_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_wofost81_nitrogen, only: WOFOST81_n_param
  implicit none
  private

  integer, parameter, public :: WOFOST81_PARAMETER_OK = 0
  integer, parameter, public :: WOFOST81_PARAMETER_INVALID_ASSIMILATION = 1
  integer, parameter, public :: WOFOST81_PARAMETER_INVALID_NITROGEN = 2

  type, public :: wofost81_assimilation_parameters_t
    real(real64) :: amax_lnb = 0.0_real64
    real(real64) :: amax_ref = 0.0_real64
    real(real64) :: amax_slp = 0.0_real64
    real(real64) :: kn = 0.0_real64
  contains
    procedure, public :: validate => validate_assimilation_parameters
  end type wofost81_assimilation_parameters_t

  type, public :: wofost81_nitrogen_parameters_t
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
    real(real64) :: rgrlai_min = 0.0_real64
  contains
    procedure, public :: validate => validate_nitrogen_parameters
    procedure, public :: donor_view => nitrogen_donor_view
  end type wofost81_nitrogen_parameters_t

  type, public :: wofost81_parameter_contract_t
    type(wofost81_assimilation_parameters_t) :: assimilation
    type(wofost81_nitrogen_parameters_t) :: nitrogen
  contains
    procedure, public :: validate => validate_parameter_contract
  end type wofost81_parameter_contract_t

contains

  integer function validate_assimilation_parameters(self) result(status)
    class(wofost81_assimilation_parameters_t), intent(in) :: self
    real(real64) :: values(4)
    values = [self%amax_lnb, self%amax_ref, self%amax_slp, self%kn]
    status = WOFOST81_PARAMETER_INVALID_ASSIMILATION
    if (.not. all(ieee_is_finite(values))) return
    if (self%amax_lnb < 0.0_real64) return
    if (self%amax_ref <= 0.0_real64) return
    if (self%amax_slp < 0.0_real64) return
    if (self%kn <= 0.0_real64) return
    status = WOFOST81_PARAMETER_OK
  end function validate_assimilation_parameters

  integer function validate_nitrogen_parameters(self) result(status)
    class(wofost81_nitrogen_parameters_t), intent(in) :: self
    real(real64) :: values(11)
    values = [self%nmaxst_fr, self%nmaxrt_fr, self%nmaxso, self%nresidlv, self%nresidst, self%nresidrt, &
              self%tcnt, self%nfix_fr, self%rnuptakemax, self%dvs_n_transl, self%rgrlai_min]
    status = WOFOST81_PARAMETER_INVALID_NITROGEN
    if (.not. all(ieee_is_finite(values))) return
    if (any(values < 0.0_real64)) return
    if (self%tcnt <= 0.0_real64) return
    if (self%nfix_fr > 1.0_real64) return
    status = WOFOST81_PARAMETER_OK
  end function validate_nitrogen_parameters

  function nitrogen_donor_view(self) result(value)
    class(wofost81_nitrogen_parameters_t), intent(in) :: self
    type(WOFOST81_n_param) :: value
    value%nmaxst_fr = self%nmaxst_fr
    value%nmaxrt_fr = self%nmaxrt_fr
    value%nmaxso = self%nmaxso
    value%nresidlv = self%nresidlv
    value%nresidst = self%nresidst
    value%nresidrt = self%nresidrt
    value%tcnt = self%tcnt
    value%nfix_fr = self%nfix_fr
    value%rnuptakemax = self%rnuptakemax
    value%dvs_n_transl = self%dvs_n_transl
  end function nitrogen_donor_view

  integer function validate_parameter_contract(self) result(status)
    class(wofost81_parameter_contract_t), intent(in) :: self
    status = self%assimilation%validate()
    if (status /= WOFOST81_PARAMETER_OK) return
    status = self%nitrogen%validate()
  end function validate_parameter_contract

end module mod_wofost81_parameter_contract
