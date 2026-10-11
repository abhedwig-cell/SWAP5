module mod_bartholomeus_runtime_input
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  implicit none
  private

  integer, parameter, public :: BARTHOLOMEUS_INPUT_OK=0
  integer, parameter, public :: BARTHOLOMEUS_INPUT_SHAPE=1
  integer, parameter, public :: BARTHOLOMEUS_INPUT_INVALID=2

  type, public :: bartholomeus_runtime_view_t
    integer :: rooted_nodes=0
    real(real64), allocatable :: pressure_head_cm(:)
    real(real64), allocatable :: water_content(:)
    real(real64), allocatable :: soil_temperature_k(:)
  end type
  public :: build_bartholomeus_runtime_view
  public :: valid_bartholomeus_runtime_view

contains
  pure logical function valid_bartholomeus_runtime_view(view) result(ok)
    type(bartholomeus_runtime_view_t),intent(in)::view
    integer::n
    ok=.false.;n=view%rooted_nodes
    if(n<0) return
    if(.not.allocated(view%pressure_head_cm)) return
    if(.not.allocated(view%water_content)) return
    if(.not.allocated(view%soil_temperature_k)) return
    if(size(view%pressure_head_cm)/=n .or. size(view%water_content)/=n .or. size(view%soil_temperature_k)/=n) return
    if(any(.not.ieee_is_finite(view%pressure_head_cm))) return
    if(any(.not.ieee_is_finite(view%water_content))) return
    if(any(.not.ieee_is_finite(view%soil_temperature_k))) return
    if(any(view%water_content<0) .or. any(view%water_content>1)) return
    if(any(view%soil_temperature_k<=0)) return
    ok=.true.
  end function

  subroutine build_bartholomeus_runtime_view(hydraulic,thermal,rooted_nodes,view,status)
    type(process_hydraulic_view_t),intent(in)::hydraulic
    type(soil_temperature_field_view_t),intent(in)::thermal
    integer,intent(in)::rooted_nodes
    type(bartholomeus_runtime_view_t),intent(out)::view
    integer,intent(out)::status
    integer::n

    view=bartholomeus_runtime_view_t(); status=BARTHOLOMEUS_INPUT_SHAPE
    n=hydraulic%active_nodes
    if(n<=0 .or. thermal%active_nodes/=n) return
    if(rooted_nodes<0 .or. rooted_nodes>n) return
    if(.not.allocated(hydraulic%pressure_head) .or. .not.allocated(hydraulic%water_content)) return
    if(.not.allocated(thermal%temperature_c)) return
    if(size(hydraulic%pressure_head)/=n .or. size(hydraulic%water_content)/=n .or. size(thermal%temperature_c)/=n) return
    if(rooted_nodes>0) then
      if(any(.not.ieee_is_finite(hydraulic%pressure_head(1:rooted_nodes))) .or. &
         any(.not.ieee_is_finite(hydraulic%water_content(1:rooted_nodes))) .or. &
         any(.not.ieee_is_finite(thermal%temperature_c(1:rooted_nodes)))) then
        status=BARTHOLOMEUS_INPUT_INVALID; return
      end if
    end if
    view%rooted_nodes=rooted_nodes
    allocate(view%pressure_head_cm(rooted_nodes),view%water_content(rooted_nodes),view%soil_temperature_k(rooted_nodes))
    if(rooted_nodes>0) then
      view%pressure_head_cm=hydraulic%pressure_head(1:rooted_nodes)
      view%water_content=hydraulic%water_content(1:rooted_nodes)
      ! Preserve the pinned OxygenStress conversion, not a new scientific correction.
      view%soil_temperature_k=thermal%temperature_c(1:rooted_nodes)+273.0_real64
    end if
    status=BARTHOLOMEUS_INPUT_OK
  end subroutine
end module
