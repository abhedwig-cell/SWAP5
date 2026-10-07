module mod_fmr_bartholomeus_activation
  use mod_bartholomeus_waterfilm_provider, only: BARTHOLOMEUS_WATERFILM_REFERENCE
  implicit none
  private

  integer,parameter,public::FMR_OXYGEN_OFF=0
  integer,parameter,public::FMR_OXYGEN_BARTHOLOMEUS=2
  integer,parameter,public::FMR_OXYGEN_TYPE_BARTHOLOMEUS=1
  integer,parameter,public::FMR_OXYGEN_TYPE_REPRODUCTION=2
  integer,parameter,public::FMR_HYDRAULICS_ANALYTICAL_MVG=0

  integer,parameter,public::FMR_BARTHOLOMEUS_DISABLED=0
  integer,parameter,public::FMR_BARTHOLOMEUS_ACTIVE=1
  integer,parameter,public::FMR_BARTHOLOMEUS_UNSUPPORTED=2
  integer,parameter,public::FMR_BARTHOLOMEUS_REPRODUCTION=3

  type,public::fmr_bartholomeus_selection_t
    integer::oxygen_mode=FMR_OXYGEN_OFF
    integer::oxygen_type=0
    integer::hydraulic_waterfilm_mode=FMR_HYDRAULICS_ANALYTICAL_MVG
  end type
  public::select_fmr_bartholomeus_route

contains
  subroutine select_fmr_bartholomeus_route(config,route,waterfilm_mode)
    type(fmr_bartholomeus_selection_t),intent(in)::config
    integer,intent(out)::route,waterfilm_mode
    waterfilm_mode=BARTHOLOMEUS_WATERFILM_REFERENCE
    if(config%oxygen_mode==FMR_OXYGEN_OFF) then
      route=FMR_BARTHOLOMEUS_DISABLED;return
    end if
    if(config%oxygen_mode==FMR_OXYGEN_BARTHOLOMEUS .and. &
       config%oxygen_type==FMR_OXYGEN_TYPE_BARTHOLOMEUS .and. &
       config%hydraulic_waterfilm_mode==FMR_HYDRAULICS_ANALYTICAL_MVG) then
      route=FMR_BARTHOLOMEUS_ACTIVE;return
    end if
    if(config%oxygen_mode==FMR_OXYGEN_BARTHOLOMEUS .and. &
       config%oxygen_type==FMR_OXYGEN_TYPE_REPRODUCTION) then
      route=FMR_BARTHOLOMEUS_REPRODUCTION;return
    end if
    route=FMR_BARTHOLOMEUS_UNSUPPORTED
  end subroutine
end module
