module mod_ppa_wu05a6_vertical_flux_reconstruction
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  type, public :: vertical_flux_reconstruction_request_t
    integer :: num_domains = 0
    integer :: num_nodes = 0
    integer :: top_node = 1
    real(real64) :: step_duration = 0.0_real64
    integer, allocatable :: bottom_domain(:)
    real(real64), allocatable :: top_inflow_rate(:)
    real(real64), allocatable :: previous_water_cm(:,:)
    real(real64), allocatable :: current_water_cm(:,:)
    real(real64), allocatable :: exchange_to_matrix_rate(:,:)
    real(real64), allocatable :: external_outflow_rate(:,:)
  contains
    procedure, public :: valid => vertical_request_valid
  end type vertical_flux_reconstruction_request_t

  type, public :: vertical_flux_reconstruction_result_t
    logical :: valid = .false.
    real(real64), allocatable :: vertical_face_rate(:,:)
    real(real64), allocatable :: local_residual_rate(:,:)
    real(real64) :: max_local_residual_rate = huge(1.0_real64)
  end type vertical_flux_reconstruction_result_t

  public :: reconstruct_vertical_flux

contains

  pure logical function vertical_request_valid(self) result(ok)
    class(vertical_flux_reconstruction_request_t),intent(in)::self
    integer::nd,n

    nd=self%num_domains
    n=self%num_nodes
    ok=nd>0 .and. n>0 .and. self%top_node>=1 .and. self%top_node<=n .and. self%step_duration>0.0_real64
    if(.not.ok)return
    ok=allocated(self%bottom_domain) .and. allocated(self%top_inflow_rate) .and. &
         allocated(self%previous_water_cm) .and. allocated(self%current_water_cm) .and. &
         allocated(self%exchange_to_matrix_rate) .and. allocated(self%external_outflow_rate)
    if(.not.ok)return
    ok=size(self%bottom_domain)==nd .and. size(self%top_inflow_rate)==nd .and. &
         all(shape(self%previous_water_cm)==[nd,n]) .and. all(shape(self%current_water_cm)==[nd,n]) .and. &
         all(shape(self%exchange_to_matrix_rate)==[nd,n]) .and. &
         all(shape(self%external_outflow_rate)==[nd,n])
    if(.not.ok)return
    ok=all(self%bottom_domain>=self%top_node) .and. all(self%bottom_domain<=n) .and. &
         all(self%previous_water_cm>=0.0_real64) .and. all(self%current_water_cm>=0.0_real64) .and. &
         all(self%external_outflow_rate>=0.0_real64)
  end function vertical_request_valid

  subroutine reconstruct_vertical_flux(request,result)
    type(vertical_flux_reconstruction_request_t),intent(in)::request
    type(vertical_flux_reconstruction_result_t),intent(out)::result

    integer::id,ic,nd,n
    real(real64)::delta_rate,qtop,qbottom,residual,maxres

    result=vertical_flux_reconstruction_result_t()
    if(.not.request%valid())return

    nd=request%num_domains
    n=request%num_nodes
    allocate(result%vertical_face_rate(nd,n+1),result%local_residual_rate(nd,n))
    result%vertical_face_rate=0.0_real64
    result%local_residual_rate=0.0_real64
    maxres=0.0_real64

    do id=1,nd
      result%vertical_face_rate(id,request%top_node)=request%top_inflow_rate(id)
      do ic=request%top_node,request%bottom_domain(id)
        qtop=result%vertical_face_rate(id,ic)
        delta_rate=(request%current_water_cm(id,ic)-request%previous_water_cm(id,ic)) / &
             request%step_duration
        qbottom=qtop-request%exchange_to_matrix_rate(id,ic)-request%external_outflow_rate(id,ic)-delta_rate
        result%vertical_face_rate(id,ic+1)=qbottom

        residual=delta_rate - (qtop-qbottom-request%exchange_to_matrix_rate(id,ic) - &
             request%external_outflow_rate(id,ic))
        result%local_residual_rate(id,ic)=residual
        maxres=max(maxres,abs(residual))
      end do
    end do

    result%max_local_residual_rate=maxres
    result%valid=maxres<=1.0e-12_real64
  end subroutine reconstruct_vertical_flux

end module mod_ppa_wu05a6_vertical_flux_reconstruction
