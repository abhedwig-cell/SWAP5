module mod_fmr_crop_certified_daily_preflight
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_crop_certified_hydrothermal_forcing, only: &
       sample_certified_committed_crop_hydrothermal_forcing,CROP_CERT_FORCE_OK
  use mod_fmr_crop_certified_germination_moisture, only: &
       sample_certified_committed_germination_head,CROP_CERT_GERM_OK
  use mod_crop_preparation_sowing_preflight, only: &
       crop_preparation_sowing_candidate_t,propose_preparation_sowing,CROP_PREP_SOW_OK
  use mod_crop_germination_preflight, only: &
       crop_germination_candidate_t,propose_crop_germination,CROP_GERM_OK
  implicit none
  private
  integer, parameter, public :: CROP_CERT_DAILY_OK=0,CROP_CERT_DAILY_HYDRO=1, &
       CROP_CERT_DAILY_MOISTURE=2,CROP_CERT_DAILY_PREP=3,CROP_CERT_DAILY_GERM=4
  type, public :: crop_certified_daily_preflight_t
    logical :: valid=.false.
    real(real64) :: hprep=0.0_real64,hsow=0.0_real64,hgerm=0.0_real64
    real(real64) :: soil_temperature=0.0_real64
    integer :: nodsow=0
    type(crop_preparation_sowing_candidate_t) :: preparation
    type(crop_germination_candidate_t) :: germination
  end type
  public :: propose_certified_crop_daily_preflight
contains
  ! Bounded read-only composition. Air temperature is EXPLICIT caller input;
  ! it is NOT a meteorological accepted-source proof or event-publication
  ! authority. F-KT certified identity guarantees only soil/head/heat.
  subroutine propose_certified_crop_daily_preflight(committed,lineage,revision,time, &
       zprep,zsow,ztempsow,zgerm,swprep,swsow, &
       hprep_threshold,hsow_threshold,sow_temperature, &
       prep_delay,sow_delay,max_prep_delay,max_sow_delay, &
       germ_mode,temperature_sum,optimal_sum,base_temperature, &
       max_effective_temperature,air_temperature,dry_head,wet_head,water_response_a, &
       candidate,status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: lineage,revision
    real(real64), intent(in) :: time,zprep,zsow,ztempsow,zgerm
    integer, intent(in) :: swprep,swsow,prep_delay,sow_delay,max_prep_delay,max_sow_delay,germ_mode
    real(real64), intent(in) :: hprep_threshold,hsow_threshold,sow_temperature, &
         temperature_sum,optimal_sum,base_temperature,max_effective_temperature, &
         air_temperature,dry_head,wet_head,water_response_a
    type(crop_certified_daily_preflight_t), intent(out) :: candidate
    integer, intent(out) :: status
    integer :: owner_status,preflight_status
    candidate=crop_certified_daily_preflight_t()
    status=CROP_CERT_DAILY_HYDRO
    if (swsow==1) then
      ! Historical B1.11 SWHEA=1 is mandatory only for simulated sowing.
      call sample_certified_committed_crop_hydrothermal_forcing(committed,lineage,revision,time, &
           zprep,zsow,ztempsow,candidate%hprep,candidate%hsow, &
           candidate%soil_temperature,candidate%nodsow,owner_status)
    else if (swsow==0) then
      ! No heat or sowing node is needed. SWPREP still requires the
      ! owner-certified accepted hydraulic head at its own depth.
      owner_status=CROP_CERT_FORCE_OK
      if (swprep==1) then
        call sample_certified_committed_germination_head(committed,lineage,revision,time, &
             zprep,candidate%hprep,owner_status)
        if(owner_status==CROP_CERT_GERM_OK) owner_status=CROP_CERT_FORCE_OK
      end if
    else
      owner_status=-1
    end if
    if(owner_status/=CROP_CERT_FORCE_OK) then
      candidate=crop_certified_daily_preflight_t()
      return
    end if
    status=CROP_CERT_DAILY_MOISTURE
    call sample_certified_committed_germination_head(committed,lineage,revision,time, &
         zgerm,candidate%hgerm,owner_status)
    if(owner_status/=CROP_CERT_GERM_OK) then
      candidate=crop_certified_daily_preflight_t()
      return
    end if
    status=CROP_CERT_DAILY_PREP
    call propose_preparation_sowing(swprep,swsow,swsow==1,candidate%hprep, &
         hprep_threshold,candidate%hsow,hsow_threshold, &
         candidate%soil_temperature,sow_temperature,prep_delay,sow_delay, &
         max_prep_delay,max_sow_delay,candidate%preparation,preflight_status)
    if(preflight_status/=CROP_PREP_SOW_OK) then
      candidate=crop_certified_daily_preflight_t()
      return
    end if
    status=CROP_CERT_DAILY_GERM
    call propose_crop_germination(germ_mode,temperature_sum,optimal_sum,base_temperature, &
         max_effective_temperature,air_temperature,candidate%hgerm,dry_head,wet_head, &
         water_response_a,candidate%germination,preflight_status)
    if(preflight_status/=CROP_GERM_OK) then
      candidate=crop_certified_daily_preflight_t()
      return
    end if
    candidate%valid=.true.
    status=CROP_CERT_DAILY_OK
  end subroutine
end module
