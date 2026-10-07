module mod_b111_crop_n_harvest_continuation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b111_crop_n_owner, only: b111_crop_n_state_t
  implicit none
  private

  integer,parameter,public::B111_HARVEST_N_OK=0
  integer,parameter,public::B111_HARVEST_N_INVALID=1
  integer,parameter,public::B111_HARVEST_N_BALANCE=2

  type,public::b111_crop_n_harvest_forcing_t
    logical::active=.false.
    real(real64)::root_dm_kg_ha=0.0_real64
    real(real64)::leaf_living_dm_kg_ha=0.0_real64
    real(real64)::stem_living_dm_kg_ha=0.0_real64
    real(real64)::storage_living_dm_kg_ha=0.0_real64
    real(real64)::leaf_dead_dm_kg_ha=0.0_real64
    real(real64)::stem_dead_dm_kg_ha=0.0_real64
    real(real64)::storage_dead_dm_kg_ha=0.0_real64
    real(real64)::leaf_fraction_to_soil=0.0_real64
    real(real64)::stem_fraction_to_soil=0.0_real64
    real(real64)::storage_fraction_to_soil=0.0_real64
  end type

  type,public::b111_crop_n_harvest_receipt_t
    integer::status=B111_HARVEST_N_INVALID
    real(real64)::root_residue_dm_kg_ha=0.0_real64
    real(real64)::root_residue_n_kg_ha=0.0_real64
    real(real64)::leaf_residue_dm_kg_ha=0.0_real64
    real(real64)::leaf_residue_n_kg_ha=0.0_real64
    real(real64)::stem_residue_dm_kg_ha=0.0_real64
    real(real64)::stem_residue_n_kg_ha=0.0_real64
    real(real64)::storage_residue_dm_kg_ha=0.0_real64
    real(real64)::storage_residue_n_kg_ha=0.0_real64
    real(real64)::external_harvest_n_kg_ha=0.0_real64
    real(real64)::balance_residual_kg_ha=0.0_real64
  end type

  public::apply_b111_crop_n_harvest

contains

  subroutine apply_b111_crop_n_harvest(committed,f,candidate,receipt)
    type(b111_crop_n_state_t),intent(in)::committed
    type(b111_crop_n_harvest_forcing_t),intent(in)::f
    type(b111_crop_n_state_t),intent(out)::candidate
    type(b111_crop_n_harvest_receipt_t),intent(out)::receipt
    real(real64)::before,after,removed,residue_n,scale,tol
    real(real64)::leaf_dead_n,stem_dead_n,storage_dead_n

    candidate=committed
    receipt=b111_crop_n_harvest_receipt_t()
    if(.not.committed%valid().or..not.valid_forcing(f))return
    if(.not.f%active)then
      receipt%status=B111_HARVEST_N_OK
      return
    end if

    before=committed%anlv_kg_ha+committed%anst_kg_ha+committed%anrt_kg_ha+committed%anso_kg_ha

    ! Source semantics: all living roots are residue at harvest.
    receipt%root_residue_dm_kg_ha=f%root_dm_kg_ha
    receipt%root_residue_n_kg_ha=committed%anrt_kg_ha
    candidate%anrt_kg_ha=0.0_real64

    ! Living fractions follow FraHarLosOrm_*; already-dead material can also be
    ! returned, but its N must come from the corresponding cumulative loss pool.
    receipt%leaf_residue_dm_kg_ha=f%leaf_fraction_to_soil*(f%leaf_living_dm_kg_ha+f%leaf_dead_dm_kg_ha)
    leaf_dead_n=f%leaf_fraction_to_soil*committed%nloss_leaf_kg_ha
    receipt%leaf_residue_n_kg_ha=f%leaf_fraction_to_soil*committed%anlv_kg_ha+leaf_dead_n
    candidate%anlv_kg_ha=(1.0_real64-f%leaf_fraction_to_soil)*committed%anlv_kg_ha
    candidate%nloss_leaf_kg_ha=committed%nloss_leaf_kg_ha-leaf_dead_n

    receipt%stem_residue_dm_kg_ha=f%stem_fraction_to_soil*(f%stem_living_dm_kg_ha+f%stem_dead_dm_kg_ha)
    stem_dead_n=f%stem_fraction_to_soil*committed%nloss_stem_kg_ha
    receipt%stem_residue_n_kg_ha=f%stem_fraction_to_soil*committed%anst_kg_ha+stem_dead_n
    candidate%anst_kg_ha=(1.0_real64-f%stem_fraction_to_soil)*committed%anst_kg_ha
    candidate%nloss_stem_kg_ha=committed%nloss_stem_kg_ha-stem_dead_n

    ! B1.11 storage-organ dead N is zero in the ordinary route; retain an
    ! explicit dead-DM slot but no hidden N pool is invented.
    storage_dead_n=0.0_real64
    receipt%storage_residue_dm_kg_ha=f%storage_fraction_to_soil*(f%storage_living_dm_kg_ha+f%storage_dead_dm_kg_ha)
    receipt%storage_residue_n_kg_ha=f%storage_fraction_to_soil*committed%anso_kg_ha+storage_dead_n
    candidate%anso_kg_ha=(1.0_real64-f%storage_fraction_to_soil)*committed%anso_kg_ha

    residue_n=receipt%root_residue_n_kg_ha+receipt%leaf_residue_n_kg_ha+ &
         receipt%stem_residue_n_kg_ha+receipt%storage_residue_n_kg_ha
    removed=before-(candidate%anlv_kg_ha+candidate%anst_kg_ha+candidate%anrt_kg_ha+candidate%anso_kg_ha)+ &
         leaf_dead_n+stem_dead_n+storage_dead_n
    receipt%external_harvest_n_kg_ha=max(0.0_real64,removed-residue_n)
    after=candidate%anlv_kg_ha+candidate%anst_kg_ha+candidate%anrt_kg_ha+candidate%anso_kg_ha
    receipt%balance_residual_kg_ha=before+committed%nloss_leaf_kg_ha+committed%nloss_stem_kg_ha - &
         (after+candidate%nloss_leaf_kg_ha+candidate%nloss_stem_kg_ha+residue_n+receipt%external_harvest_n_kg_ha)

    scale=max(1.0_real64,before,residue_n)
    tol=4096.0_real64*epsilon(1.0_real64)*scale
    if(.not.candidate%valid().or.abs(receipt%balance_residual_kg_ha)>tol)then
      candidate=committed
      receipt=b111_crop_n_harvest_receipt_t()
      receipt%status=B111_HARVEST_N_BALANCE
      return
    end if
    receipt%status=B111_HARVEST_N_OK
  end subroutine

  pure logical function valid_forcing(f) result(ok)
    type(b111_crop_n_harvest_forcing_t),intent(in)::f
    real(real64)::v(10)
    v=[f%root_dm_kg_ha,f%leaf_living_dm_kg_ha,f%stem_living_dm_kg_ha,f%storage_living_dm_kg_ha, &
       f%leaf_dead_dm_kg_ha,f%stem_dead_dm_kg_ha,f%storage_dead_dm_kg_ha, &
       f%leaf_fraction_to_soil,f%stem_fraction_to_soil,f%storage_fraction_to_soil]
    ok=all(ieee_is_finite(v)).and.all(v>=0.0_real64).and. &
       f%leaf_fraction_to_soil<=1.0_real64.and.f%stem_fraction_to_soil<=1.0_real64.and. &
       f%storage_fraction_to_soil<=1.0_real64
  end function
end module
