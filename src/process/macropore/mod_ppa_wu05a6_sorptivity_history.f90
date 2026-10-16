module mod_ppa_wu05a6_sorptivity_history
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a6_unsat_absorption_rate, only: unsat_absorption_result_t
  implicit none
  private

  type, public :: sorptivity_history_update_request_t
    integer :: num_domains = 0
    integer :: num_nodes = 0
    integer :: top_node = 1
    integer :: matrix_top_saturated_node = 1
    real(real64) :: step_duration = 0.0_real64
    integer, allocatable :: bottom_domain(:)
    integer, allocatable :: top_water_node(:)
    real(real64), allocatable :: wall_correction(:)
    real(real64), allocatable :: wet_fraction(:,:)
    real(real64), allocatable :: domain_fraction(:,:)
    real(real64), allocatable :: diameter(:)
  contains
    procedure, public :: valid => history_update_request_valid
  end type sorptivity_history_update_request_t

  public :: apply_sorptivity_history_update

contains

  pure logical function history_update_request_valid(self) result(ok)
    class(sorptivity_history_update_request_t),intent(in)::self
    integer::nd,n

    nd=self%num_domains
    n=self%num_nodes
    ok=nd>0 .and. n>0 .and. self%top_node>=1 .and. self%top_node<=n .and. &
         self%matrix_top_saturated_node>=1 .and. self%matrix_top_saturated_node<=n+1 .and. &
         self%step_duration>0.0_real64
    if(.not.ok)return
    ok=allocated(self%bottom_domain) .and. allocated(self%top_water_node) .and. &
         allocated(self%wall_correction) .and. allocated(self%wet_fraction) .and. &
         allocated(self%domain_fraction) .and. allocated(self%diameter)
    if(.not.ok)return
    ok=size(self%bottom_domain)==nd .and. size(self%top_water_node)==nd .and. &
         size(self%wall_correction)==n .and. size(self%diameter)==n .and. &
         all(shape(self%wet_fraction)==[nd,n]) .and. all(shape(self%domain_fraction)==[nd,n])
    if(.not.ok)return
    ok=all(self%bottom_domain>=self%top_node) .and. all(self%bottom_domain<=n) .and. &
         all(self%top_water_node>=self%top_node) .and. all(self%top_water_node<=n) .and. &
         all(self%wall_correction>=0.0_real64) .and. all(self%wet_fraction>=0.0_real64) .and. &
         all(self%wet_fraction<=1.0_real64) .and. all(self%domain_fraction>=0.0_real64) .and. &
         all(self%diameter>0.0_real64)
  end function history_update_request_valid

  subroutine apply_sorptivity_history_update(request,accepted_macro,absorption,candidate_macro,ok)
    type(sorptivity_history_update_request_t),intent(in)::request
    type(macropore_continuation_state_t),intent(in)::accepted_macro
    type(unsat_absorption_result_t),intent(in)::absorption
    type(macropore_continuation_state_t),intent(inout)::candidate_macro
    logical,intent(out)::ok

    integer::id,ic,ic_bottom,nd,n
    real(real64)::time,delta_root,sorp,theta_ref

    ok=.false.
    if(.not.request%valid() .or. .not.accepted_macro%ready() .or. .not.candidate_macro%ready())return
    nd=request%num_domains
    n=request%num_nodes
    if(accepted_macro%num_domains/=nd .or. accepted_macro%num_nodes/=n .or. &
       candidate_macro%num_domains/=nd .or. candidate_macro%num_nodes/=n)return
    if(.not.absorption%valid)return
    if(.not.allocated(absorption%end_event) .or. .not.allocated(absorption%seed_sorptivity) .or. &
       .not.allocated(absorption%seed_theta_ref))return
    if(.not.all(shape(absorption%end_event)==[nd,n]))return

    do id=1,nd
      ic_bottom=min(request%bottom_domain(id),request%matrix_top_saturated_node-1)

      do ic=request%top_node,request%top_water_node(id)-1
        candidate_macro%absorption_time(id,ic)=0.0_real64
        candidate_macro%sorptivity(id,ic)=0.0_real64
        candidate_macro%theta_sorption_ref(id,ic)=0.0_real64
      end do

      if(ic_bottom>=request%top_water_node(id))then
        do ic=request%top_water_node(id),ic_bottom
          if(absorption%end_event(id,ic))then
            candidate_macro%absorption_time(id,ic)=0.0_real64
            candidate_macro%sorptivity(id,ic)=0.0_real64
            candidate_macro%theta_sorption_ref(id,ic)=0.0_real64
          else
            time=accepted_macro%absorption_time(id,ic)
            sorp=absorption%seed_sorptivity(id,ic)
            theta_ref=absorption%seed_theta_ref(id,ic)
            delta_root=sqrt(time+request%step_duration)-sqrt(time)
            theta_ref=theta_ref + request%wall_correction(ic)*request%wet_fraction(id,ic) * &
                 request%domain_fraction(id,ic)*(4.0_real64/request%diameter(ic))*sorp*delta_root
            candidate_macro%sorptivity(id,ic)=sorp
            candidate_macro%theta_sorption_ref(id,ic)=theta_ref
            candidate_macro%absorption_time(id,ic)=time+request%step_duration
          end if
        end do
      end if

      do ic=max(request%top_node,ic_bottom+1),n
        candidate_macro%absorption_time(id,ic)=0.0_real64
        candidate_macro%sorptivity(id,ic)=0.0_real64
        candidate_macro%theta_sorption_ref(id,ic)=0.0_real64
      end do
    end do

    ok=.true.
  end subroutine apply_sorptivity_history_update

end module mod_ppa_wu05a6_sorptivity_history
