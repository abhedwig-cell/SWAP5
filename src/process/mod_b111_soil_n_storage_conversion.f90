module mod_b111_soil_n_storage_conversion
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer,parameter,public::B111_NSTORE_OK=0
  integer,parameter,public::B111_NSTORE_INVALID=1

  type,public::b111_soil_n_concentration_state_t
    integer::status=B111_NSTORE_INVALID
    real(real64)::cnh4_kg_m3=0.0_real64
    real(real64)::cno3_kg_m3=0.0_real64
  end type

  public::b111_soil_n_concentrations_from_mass
  public::b111_soil_n_mass_from_concentrations

contains

  pure subroutine b111_soil_n_concentrations_from_mass(depth_m,wfrac,drybd,sorpcoef,nh4_kg_m2,no3_kg_m2,result)
    real(real64),intent(in)::depth_m,wfrac,drybd,sorpcoef,nh4_kg_m2,no3_kg_m2
    type(b111_soil_n_concentration_state_t),intent(out)::result
    real(real64)::nh4_storage,no3_storage
    result=b111_soil_n_concentration_state_t()
    if(.not.all(ieee_is_finite([depth_m,wfrac,drybd,sorpcoef,nh4_kg_m2,no3_kg_m2])))return
    if(depth_m<=0.0_real64.or.wfrac<0.0_real64.or.drybd<0.0_real64.or.sorpcoef<0.0_real64.or. &
       nh4_kg_m2<0.0_real64.or.no3_kg_m2<0.0_real64)return
    nh4_storage=(wfrac+drybd*sorpcoef)*depth_m
    no3_storage=wfrac*depth_m
    if(nh4_storage<=0.0_real64)return
    if(no3_kg_m2>0.0_real64.and.no3_storage<=0.0_real64)return
    result%cnh4_kg_m3=nh4_kg_m2/nh4_storage
    if(no3_storage>0.0_real64)result%cno3_kg_m3=no3_kg_m2/no3_storage
    if(.not.all(ieee_is_finite([result%cnh4_kg_m3,result%cno3_kg_m3])))then
      result=b111_soil_n_concentration_state_t()
      return
    end if
    result%status=B111_NSTORE_OK
  end subroutine

  pure subroutine b111_soil_n_mass_from_concentrations(depth_m,wfrac,drybd,sorpcoef,cnh4,cno3, &
       nh4_kg_m2,no3_kg_m2,status)
    real(real64),intent(in)::depth_m,wfrac,drybd,sorpcoef,cnh4,cno3
    real(real64),intent(out)::nh4_kg_m2,no3_kg_m2
    integer,intent(out)::status
    nh4_kg_m2=0.0_real64
    no3_kg_m2=0.0_real64
    status=B111_NSTORE_INVALID
    if(.not.all(ieee_is_finite([depth_m,wfrac,drybd,sorpcoef,cnh4,cno3])))return
    if(depth_m<=0.0_real64.or.wfrac<0.0_real64.or.drybd<0.0_real64.or.sorpcoef<0.0_real64.or. &
       cnh4<0.0_real64.or.cno3<0.0_real64)return
    nh4_kg_m2=cnh4*(wfrac+drybd*sorpcoef)*depth_m
    no3_kg_m2=cno3*wfrac*depth_m
    if(.not.all(ieee_is_finite([nh4_kg_m2,no3_kg_m2])))then
      nh4_kg_m2=0.0_real64;no3_kg_m2=0.0_real64;return
    end if
    status=B111_NSTORE_OK
  end subroutine
end module
