module mod_ppa_wu05d3_walsum_compensation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05D3_OK = 0
  integer, parameter, public :: PPA_WU05D3_INVALID_INPUT = 1
  real(real64), parameter :: vsmall = 1.0e-14_real64
  real(real64), parameter :: nihil = 1.0e-10_real64
  public :: apply_ppa_wu05d3_walsum_compensation

contains

  subroutine apply_ppa_wu05d3_walsum_compensation(qrot_in, qrosum_in, ptra, dcritrtz, rdm, rd_noddrz, &
      sw_stressor, qredwet_in, qreddry_in, qredsol_in, qredfrs_in, alphacrit_out, &
      qrot_out, qrosum_out, qredwet_out, qreddry_out, qredsol_out, qredfrs_out, applied, status)
    real(real64), intent(in) :: qrot_in(:), qrosum_in, ptra, dcritrtz, rdm, rd_noddrz
    integer, intent(in) :: sw_stressor
    real(real64), intent(in) :: qredwet_in, qreddry_in, qredsol_in, qredfrs_in
    real(real64), intent(out) :: alphacrit_out, qrot_out(:), qrosum_out
    real(real64), intent(out) :: qredwet_out, qreddry_out, qredsol_out, qredfrs_out
    logical, intent(out) :: applied
    integer, intent(out) :: status

    real(real64) :: alptot, qred, alpdry, alpwet, alpsol, alpfrs
    real(real64) :: alptotcom, alpdrycom, alpwetcom, alpsolcom, alpfrscom, redtot

    applied = .false.
    status = PPA_WU05D3_INVALID_INPUT
    alphacrit_out = 0.0_real64
    if (size(qrot_in) == 0 .or. size(qrot_out) /= size(qrot_in)) return
    qrot_out = qrot_in
    qrosum_out = qrosum_in
    qredwet_out = qredwet_in
    qreddry_out = qreddry_in
    qredsol_out = qredsol_in
    qredfrs_out = qredfrs_in

    if (.not. all(ieee_is_finite(qrot_in)) .or. &
        .not. all(ieee_is_finite([qrosum_in, ptra, dcritrtz, rdm, rd_noddrz, &
        qredwet_in, qreddry_in, qredsol_in, qredfrs_in]))) return
    if (ptra < nihil .or. dcritrtz < 0.02_real64 .or. dcritrtz > 100.0_real64) return
    if (rdm <= 0.0_real64 .or. rd_noddrz < 0.0_real64 .or. rd_noddrz > rdm) return
    if (sw_stressor < 1 .or. sw_stressor > 5) return
    if (min(qredwet_in, qreddry_in, qredsol_in, qredfrs_in) < 0.0_real64) return

    ! Exact B1.11 Walsum per-call ALPHACRIT; source caps only the upper end.
    alphacrit_out = min((dcritrtz + rdm - rd_noddrz) / rdm, 1.0_real64)
    if (.not. ieee_is_finite(alphacrit_out) .or. alphacrit_out <= 0.0_real64) then
      alphacrit_out = 0.0_real64
      return
    end if
    status = PPA_WU05D3_OK

    alptot = qrosum_in / ptra
    qred = ptra - qrosum_in
    if (.not. (abs(alphacrit_out-1.0_real64) >= vsmall .and. qred > vsmall .and. alptot >= vsmall)) return

    alpdry = alptot**(qreddry_in/qred)
    alpwet = alptot**(qredwet_in/qred)
    alpsol = alptot**(qredsol_in/qred)
    alpfrs = alptot**(qredfrs_in/qred)
    if (.not. all(ieee_is_finite([alpdry, alpwet, alpsol, alpfrs]))) then
      status = PPA_WU05D3_INVALID_INPUT
      return
    end if

    if (sw_stressor == 1) then
      alptotcom = min(alptot/alphacrit_out, 1.0_real64)
      alpdrycom = alpdry
      alpwetcom = alpwet
      alpsolcom = alpsol
      alpfrscom = alpfrs
    else
      alpdrycom = alpdry
      alpwetcom = alpwet
      alpsolcom = alpsol
      alpfrscom = alpfrs
      if (sw_stressor == 2) then
        alpdrycom = min(alpdry/alphacrit_out, 1.0_real64)
      else if (sw_stressor == 3) then
        alpwetcom = min(alpwet/alphacrit_out, 1.0_real64)
      else if (sw_stressor == 4) then
        alpsolcom = min(alpsol/alphacrit_out, 1.0_real64)
      else if (sw_stressor == 5) then
        alpfrscom = min(alpfrs/alphacrit_out, 1.0_real64)
      end if
      alptotcom = alpwetcom*alpdrycom*alpsolcom*alpfrscom
    end if

    redtot = (1.0_real64-alpwetcom)+(1.0_real64-alpdrycom)+ &
        (1.0_real64-alpsolcom)+(1.0_real64-alpfrscom)
    if (.not. ieee_is_finite(redtot)) then
      status = PPA_WU05D3_INVALID_INPUT
      return
    end if

    qrot_out = qrot_in*alptotcom/alptot
    qrosum_out = ptra*alptotcom
    qred = ptra-qrosum_out
    if (qred < vsmall) then
      qredwet_out = 0.0_real64
      qreddry_out = 0.0_real64
      qredsol_out = 0.0_real64
      qredfrs_out = 0.0_real64
    else
      if (redtot <= 0.0_real64) then
        qrot_out = qrot_in
        qrosum_out = qrosum_in
        qredwet_out = qredwet_in
        qreddry_out = qreddry_in
        qredsol_out = qredsol_in
        qredfrs_out = qredfrs_in
        alphacrit_out = 0.0_real64
        status = PPA_WU05D3_INVALID_INPUT
        return
      end if
      qredwet_out = (1.0_real64-alpwetcom)/redtot*qred
      qreddry_out = (1.0_real64-alpdrycom)/redtot*qred
      qredsol_out = (1.0_real64-alpsolcom)/redtot*qred
      qredfrs_out = (1.0_real64-alpfrscom)/redtot*qred
    end if

    if (.not. all(ieee_is_finite(qrot_out)) .or. &
        .not. all(ieee_is_finite([qrosum_out, qredwet_out, qreddry_out, qredsol_out, qredfrs_out]))) then
      qrot_out = qrot_in
      qrosum_out = qrosum_in
      qredwet_out = qredwet_in
      qreddry_out = qreddry_in
      qredsol_out = qredsol_in
      qredfrs_out = qredfrs_in
      alphacrit_out = 0.0_real64
      status = PPA_WU05D3_INVALID_INPUT
      return
    end if
    applied = .true.
  end subroutine apply_ppa_wu05d3_walsum_compensation

end module mod_ppa_wu05d3_walsum_compensation
