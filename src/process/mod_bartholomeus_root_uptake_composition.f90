module mod_bartholomeus_root_uptake_composition
   use iso_fortran_env, only : real64
   implicit none
   private

   integer, parameter, public :: BARTHOLOMEUS_COMPOSE_OK = 0
   integer, parameter, public :: BARTHOLOMEUS_COMPOSE_INVALID = 1

   public :: apply_bartholomeus_reduction

contains

   subroutine apply_bartholomeus_reduction(base_sink, oxygen_factor, final_sink, status)
      real(real64), intent(in) :: base_sink(:)
      real(real64), intent(in) :: oxygen_factor(:)
      real(real64), allocatable, intent(out) :: final_sink(:)
      integer, intent(out) :: status

      integer :: n

      status = BARTHOLOMEUS_COMPOSE_INVALID
      if (size(base_sink) /= size(oxygen_factor)) return
      if (any(base_sink < 0.0_real64)) return
      if (any(oxygen_factor < 0.0_real64) .or. any(oxygen_factor > 1.0_real64)) return

      n = size(base_sink)
      allocate(final_sink(n))
      final_sink = base_sink*oxygen_factor
      status = BARTHOLOMEUS_COMPOSE_OK
   end subroutine apply_bartholomeus_reduction

end module mod_bartholomeus_root_uptake_composition
