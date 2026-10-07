module mod_b111_crop_residue_return
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_n_pool_state, only: soil_n_transfer_t
  use mod_b111_soil_n_addition, only: b111_soil_n_material_t,b111_soil_n_split_parameters_t, &
       build_b111_residue_transfer,B111_NADD_OK
  implicit none
  private

  integer,parameter,public::B111_CRES_OK=0
  integer,parameter,public::B111_CRES_INVALID=1
  integer,parameter,public::B111_CRES_BUILD_FAILED=2
  integer,parameter,public::B111_CRES_MASS_MISMATCH=3

  type,public::b111_crop_residue_return_forcing_t
    real(real64)::depth_m=0.0_real64
    real(real64)::leaf_fraction_to_soil=0.0_real64
    real(real64)::root_apparent_age=0.0_real64
    real(real64)::leaf_apparent_age=0.0_real64
    real(real64)::root_dm_loss_kg_ha=0.0_real64
    real(real64)::leaf_dm_loss_kg_ha=0.0_real64
    real(real64)::root_n_loss_kg_ha=0.0_real64
    real(real64)::leaf_n_loss_kg_ha=0.0_real64
    type(b111_soil_n_split_parameters_t)::split
  end type

  type,public::b111_crop_residue_return_receipt_t
    integer::status=B111_CRES_INVALID
    real(real64)::root_n_return_kg_m2=0.0_real64
    real(real64)::leaf_n_return_kg_m2=0.0_real64
    real(real64)::internal_n_return_kg_m2=0.0_real64
  end type

  public::build_b111_crop_residue_return

contains

  subroutine build_b111_crop_residue_return(f,transfer,receipt)
    type(b111_crop_residue_return_forcing_t),intent(in)::f
    type(soil_n_transfer_t),intent(out)::transfer
    type(b111_crop_residue_return_receipt_t),intent(out)::receipt
    type(soil_n_transfer_t)::root_transfer,leaf_transfer
    type(b111_soil_n_material_t)::material
    real(real64)::root_dm_m2,leaf_dm_m2,root_n_m2,leaf_n_m2,tol
    integer::status

    transfer=soil_n_transfer_t()
    receipt=b111_crop_residue_return_receipt_t()
    if(.not.valid_forcing(f))return

    allocate(transfer%fom_delta_kg_m3(8))
    transfer%fom_delta_kg_m3=0.0_real64

    root_dm_m2=f%root_dm_loss_kg_ha*1.0e-4_real64
    root_n_m2=f%root_n_loss_kg_ha*1.0e-4_real64
    if(root_dm_m2>0.0_real64)then
      material=b111_soil_n_material_t()
      material%application_kg_m2=root_dm_m2
      material%application_age=f%root_apparent_age
      material%organic_matter_fraction=1.0_real64
      material%organic_n_fraction=root_n_m2/root_dm_m2
      call build_b111_residue_transfer(f%depth_m,material,f%split,root_transfer,status)
      if(status/=B111_NADD_OK)then
        receipt%status=B111_CRES_BUILD_FAILED
        return
      end if
      call accumulate_transfer(transfer,root_transfer)
      receipt%root_n_return_kg_m2=root_n_m2
    else if(root_n_m2>0.0_real64)then
      return
    end if

    leaf_dm_m2=f%leaf_fraction_to_soil*f%leaf_dm_loss_kg_ha*1.0e-4_real64
    leaf_n_m2=f%leaf_fraction_to_soil*f%leaf_n_loss_kg_ha*1.0e-4_real64
    if(leaf_dm_m2>0.0_real64)then
      material=b111_soil_n_material_t()
      material%application_kg_m2=leaf_dm_m2
      material%application_age=f%leaf_apparent_age
      material%organic_matter_fraction=1.0_real64
      material%organic_n_fraction=leaf_n_m2/leaf_dm_m2
      call build_b111_residue_transfer(f%depth_m,material,f%split,leaf_transfer,status)
      if(status/=B111_NADD_OK)then
        receipt%status=B111_CRES_BUILD_FAILED
        return
      end if
      call accumulate_transfer(transfer,leaf_transfer)
      receipt%leaf_n_return_kg_m2=leaf_n_m2
    else if(leaf_n_m2>0.0_real64)then
      return
    end if

    receipt%internal_n_return_kg_m2=receipt%root_n_return_kg_m2+receipt%leaf_n_return_kg_m2
    tol=4096.0_real64*epsilon(1.0_real64)*max(1.0_real64,receipt%internal_n_return_kg_m2)
    if(abs(transfer%external_n_input_kg_m2-receipt%internal_n_return_kg_m2)>tol .or. &
       transfer%external_n_output_kg_m2/=0.0_real64)then
      transfer=soil_n_transfer_t()
      receipt%status=B111_CRES_MASS_MISMATCH
      return
    end if

    ! The Soil-N subowner keeps this input in its own receipt so its local mass
    ! balance closes. A higher-level coupled crop/soil transaction may reclassify
    ! exactly this amount as an internal crop->soil transfer.
    receipt%status=B111_CRES_OK
  end subroutine

  subroutine accumulate_transfer(total,part)
    type(soil_n_transfer_t),intent(inout)::total
    type(soil_n_transfer_t),intent(in)::part
    total%fom_delta_kg_m3=total%fom_delta_kg_m3+part%fom_delta_kg_m3
    total%biomass_delta_kg_m3=total%biomass_delta_kg_m3+part%biomass_delta_kg_m3
    total%humus_delta_kg_m3=total%humus_delta_kg_m3+part%humus_delta_kg_m3
    total%ammonium_n_delta_kg_m2=total%ammonium_n_delta_kg_m2+part%ammonium_n_delta_kg_m2
    total%nitrate_n_delta_kg_m2=total%nitrate_n_delta_kg_m2+part%nitrate_n_delta_kg_m2
    total%external_n_input_kg_m2=total%external_n_input_kg_m2+part%external_n_input_kg_m2
    total%external_n_output_kg_m2=total%external_n_output_kg_m2+part%external_n_output_kg_m2
  end subroutine

  pure logical function valid_forcing(f) result(ok)
    type(b111_crop_residue_return_forcing_t),intent(in)::f
    real(real64)::v(9)
    v=[f%depth_m,f%leaf_fraction_to_soil,f%root_apparent_age,f%leaf_apparent_age, &
       f%root_dm_loss_kg_ha,f%leaf_dm_loss_kg_ha,f%root_n_loss_kg_ha,f%leaf_n_loss_kg_ha, &
       f%split%nfrac_fom_min]
    ok=all(ieee_is_finite(v)).and.f%depth_m>0.0_real64.and. &
       f%leaf_fraction_to_soil>=0.0_real64.and.f%leaf_fraction_to_soil<=1.0_real64.and. &
       min(f%root_apparent_age,f%leaf_apparent_age,f%root_dm_loss_kg_ha,f%leaf_dm_loss_kg_ha, &
       f%root_n_loss_kg_ha,f%leaf_n_loss_kg_ha)>=0.0_real64
  end function
end module
