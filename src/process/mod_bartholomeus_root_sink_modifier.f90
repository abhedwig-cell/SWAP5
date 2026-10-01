module mod_bartholomeus_root_sink_modifier
   use iso_fortran_env, only : real64
   use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
   implicit none
   private

   integer, parameter, public :: OXYGEN_MODIFIER_OK = 0
   integer, parameter, public :: OXYGEN_MODIFIER_INVALID_INPUT = 1

   public :: apply_bartholomeus_root_sink_modifier

contains

   subroutine apply_bartholomeus_root_sink_modifier(base_sink, oxygen_factor, modified_sink, status)
      real(real64), intent(in) :: base_sink(:)
      real(real64), intent(in) :: oxygen_factor(:)
      real(real64), allocatable, intent(out) :: modified_sink(:)
      integer, intent(out) :: status

      integer :: i, n

      status = OXYGEN_MODIFIER_INVALID_INPUT
      n = size(base_sink)
      if (n <= 0 .or. size(oxygen_factor) /= n) return
      if (any(.not. ieee_is_finite(base_sink)) .or. any(.not. ieee_is_finite(oxygen_factor))) return
      if (any(base_sink < 0.0_real64)) return
      if (any(oxygen_factor < 0.0_real64) .or. any(oxygen_factor > 1.0_real64)) return

      allocate(modified_sink(n))
      do i = 1, n
         modified_sink(i) = base_sink(i) * oxygen_factor(i)
      end do
      status = OXYGEN_MODIFIER_OK
   end subroutine apply_bartholomeus_root_sink_modifier

end module mod_bartholomeus_root_sink_modifier
