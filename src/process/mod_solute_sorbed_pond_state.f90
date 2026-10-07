module mod_solute_sorbed_pond_state
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::SOLSP_OK=0,SOLSP_INVALID=1
 type,public::solute_sorbed_pond_state_t
   real(real64),allocatable::sorbed_matrix_mass(:)
   real(real64)::pond_mass=0d0
 contains
   procedure::ready=>solute_sorbed_pond_ready
   procedure::total=>solute_sorbed_pond_total
 end type
 public::initialize_solute_sorbed_pond_state
contains
 pure logical function solute_sorbed_pond_ready(self,active_nodes) result(ok)
  class(solute_sorbed_pond_state_t),intent(in)::self
  integer,intent(in)::active_nodes
  ok=.false.
  if(active_nodes<=0.or..not.allocated(self%sorbed_matrix_mass))return
  if(size(self%sorbed_matrix_mass)/=active_nodes)return
  if(.not.all(ieee_is_finite(self%sorbed_matrix_mass)).or.any(self%sorbed_matrix_mass<0d0))return
  if(.not.ieee_is_finite(self%pond_mass).or.self%pond_mass<0d0)return
  ok=.true.
 end function
 pure real(real64) function solute_sorbed_pond_total(self) result(value)
  class(solute_sorbed_pond_state_t),intent(in)::self
  value=self%pond_mass
  if(allocated(self%sorbed_matrix_mass))value=value+sum(self%sorbed_matrix_mass)
 end function
 subroutine initialize_solute_sorbed_pond_state(sorbed_matrix_mass,pond_mass,state,status)
  real(real64),intent(in)::sorbed_matrix_mass(:),pond_mass
  type(solute_sorbed_pond_state_t),intent(out)::state
  integer,intent(out)::status
  state=solute_sorbed_pond_state_t();status=SOLSP_INVALID
  if(size(sorbed_matrix_mass)<1)return
  state%sorbed_matrix_mass=sorbed_matrix_mass;state%pond_mass=pond_mass
  if(.not.state%ready(size(sorbed_matrix_mass)))return
  status=SOLSP_OK
 end subroutine
end module
