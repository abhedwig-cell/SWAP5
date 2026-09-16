module mod_reference_richards_workspace
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_solver_workspace_base_t, soil_water_solver_diagnostics_t
  implicit none
  private

  type, extends(soil_water_solver_workspace_base_t), public :: reference_richards_workspace_t
     integer :: active_nodes = 0
     integer(int64) :: generation = 0_int64
     logical :: poisoned = .false.
     real(real64), allocatable :: dfdh_lower(:)
     real(real64), allocatable :: dfdh_main(:)
     real(real64), allocatable :: dfdh_upper(:)
     real(real64), allocatable :: residual(:)
     real(real64), allocatable :: delta_head(:)
     real(real64), allocatable :: tridag_gamma(:)
     real(real64), allocatable :: sink(:)
     real(real64), allocatable :: source(:)
     real(real64), allocatable :: provider_theta(:)
     real(real64), allocatable :: provider_k(:)
     real(real64), allocatable :: provider_capacity(:)
     real(real64), allocatable :: provider_dkdh(:)
     real(real64), allocatable :: provider_root_sink(:)
     real(real64), allocatable :: dconductivity_dhead(:)
     real(real64), allocatable :: old_head(:)
     real(real64), allocatable :: vertical_flux(:)
     real(real64), allocatable :: head_gradient(:)
     real(real64), allocatable :: band_matrix(:,:)
     real(real64), allocatable :: band_aux(:,:)
     real(real64), allocatable :: band_rhs(:)
     integer, allocatable :: band_pivots(:)
     logical, allocatable :: nonconverged_balance(:)
     logical, allocatable :: nonconverged_head(:)
     logical :: unsaturated_flags(3) = .false.
     real(real64), allocatable :: warm_start_head(:)
     logical :: has_warm_start = .false.
     type(soil_water_solver_diagnostics_t) :: diagnostics
  end type reference_richards_workspace_t

  public :: initialize_reference_workspace
  public :: reset_reference_workspace
  public :: poison_reference_workspace
  public :: release_reference_workspace
  public :: reference_workspace_payload_bytes
  public :: prepare_reference_tridag_factorization_capture
  public :: release_reference_tridag_factorization_capture

contains

  subroutine initialize_reference_workspace(workspace, active_nodes)
    type(reference_richards_workspace_t), intent(inout) :: workspace
    integer, intent(in) :: active_nodes

    if (active_nodes <= 0) error stop 'reference workspace requires active_nodes > 0'
    if (workspace%active_nodes /= active_nodes .or. .not. allocated(workspace%residual)) then
       call release_reference_workspace(workspace)
       allocate(workspace%dfdh_lower(active_nodes), workspace%dfdh_main(active_nodes), workspace%dfdh_upper(active_nodes))
       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes), workspace%tridag_gamma(active_nodes))
       allocate(workspace%sink(active_nodes), workspace%source(active_nodes))
       allocate(workspace%provider_theta(active_nodes), workspace%provider_k(active_nodes))
       allocate(workspace%provider_capacity(active_nodes), workspace%provider_dkdh(active_nodes))
       allocate(workspace%provider_root_sink(active_nodes))
       allocate(workspace%dconductivity_dhead(active_nodes), workspace%old_head(active_nodes))
       allocate(workspace%vertical_flux(active_nodes+1), workspace%head_gradient(active_nodes+1))
       allocate(workspace%band_matrix(active_nodes,3), workspace%band_aux(active_nodes,1))
       allocate(workspace%band_rhs(active_nodes), workspace%band_pivots(active_nodes))
       allocate(workspace%nonconverged_balance(active_nodes), workspace%nonconverged_head(active_nodes))
       allocate(workspace%warm_start_head(active_nodes))
       workspace%active_nodes = active_nodes
    end if
    workspace%generation = workspace%generation + 1_int64
    call reset_reference_workspace(workspace)
  end subroutine initialize_reference_workspace

  subroutine reset_reference_workspace(workspace)
    type(reference_richards_workspace_t), intent(inout) :: workspace

    if (workspace%active_nodes <= 0) return
    if (.not. allocated(workspace%residual)) return
    workspace%dfdh_lower = 0.0_real64
    workspace%dfdh_main = 0.0_real64
    workspace%dfdh_upper = 0.0_real64
    workspace%residual = 0.0_real64
    workspace%delta_head = 0.0_real64
    workspace%tridag_gamma = 0.0_real64
    workspace%sink = 0.0_real64
    workspace%source = 0.0_real64
    workspace%provider_theta = 0.0_real64
    workspace%provider_k = 0.0_real64
    workspace%provider_capacity = 0.0_real64
    workspace%provider_dkdh = 0.0_real64
    workspace%provider_root_sink = 0.0_real64
    workspace%dconductivity_dhead = 0.0_real64
    workspace%old_head = 0.0_real64
    workspace%vertical_flux = 0.0_real64
    workspace%head_gradient = 0.0_real64
    workspace%band_matrix = 0.0_real64
    workspace%band_aux = 0.0_real64
    workspace%band_rhs = 0.0_real64
    workspace%band_pivots = 0
    workspace%nonconverged_balance = .false.
    workspace%nonconverged_head = .false.
    workspace%unsaturated_flags = .false.
    workspace%warm_start_head = 0.0_real64
    workspace%has_warm_start = .false.
    workspace%diagnostics = soil_water_solver_diagnostics_t()
    workspace%poisoned = .false.
  end subroutine reset_reference_workspace

  subroutine prepare_reference_tridag_factorization_capture(workspace)
    type(reference_richards_workspace_t), intent(inout) :: workspace
    real(real64), allocatable :: expanded(:)
    integer :: n

    n = workspace%active_nodes
    if (n <= 0 .or. .not. allocated(workspace%tridag_gamma)) &
         error stop 'TRIDAG factorization capture requires initialized workspace'
    if (size(workspace%tridag_gamma) /= 2*n) then
       allocate(expanded(2*n))
       expanded = 0.0_real64
       deallocate(workspace%tridag_gamma)
       call move_alloc(expanded, workspace%tridag_gamma)
    else
       workspace%tridag_gamma = 0.0_real64
    end if
  end subroutine prepare_reference_tridag_factorization_capture

  subroutine release_reference_tridag_factorization_capture(workspace)
    type(reference_richards_workspace_t), intent(inout) :: workspace
    real(real64), allocatable :: compact(:)
    integer :: n

    n = workspace%active_nodes
    if (n <= 0 .or. .not. allocated(workspace%tridag_gamma)) return
    if (size(workspace%tridag_gamma) == n) return
    allocate(compact(n))
    compact = 0.0_real64
    deallocate(workspace%tridag_gamma)
    call move_alloc(compact, workspace%tridag_gamma)
  end subroutine release_reference_tridag_factorization_capture

  subroutine poison_reference_workspace(workspace)
    type(reference_richards_workspace_t), intent(inout) :: workspace
    real(real64) :: qnan

    if (workspace%active_nodes <= 0) return
    if (.not. allocated(workspace%residual)) return
    qnan = ieee_value(0.0_real64, ieee_quiet_nan)
    workspace%dfdh_lower = qnan
    workspace%dfdh_main = qnan
    workspace%dfdh_upper = qnan
    workspace%residual = qnan
    workspace%delta_head = qnan
    workspace%tridag_gamma = qnan
    workspace%sink = qnan
    workspace%source = qnan
    workspace%provider_theta = qnan
    workspace%provider_k = qnan
    workspace%provider_capacity = qnan
    workspace%provider_dkdh = qnan
    workspace%provider_root_sink = qnan
    workspace%dconductivity_dhead = qnan
    workspace%old_head = qnan
    workspace%vertical_flux = qnan
    workspace%head_gradient = qnan
    workspace%band_matrix = qnan
    workspace%band_aux = qnan
    workspace%band_rhs = qnan
    workspace%band_pivots = -huge(0)
    workspace%nonconverged_balance = .true.
    workspace%nonconverged_head = .true.
    workspace%unsaturated_flags = .true.
    workspace%warm_start_head = qnan
    workspace%has_warm_start = .true.
    workspace%diagnostics%route = 'poisoned'
    workspace%poisoned = .true.
  end subroutine poison_reference_workspace

  subroutine release_reference_workspace(workspace)
    type(reference_richards_workspace_t), intent(inout) :: workspace

    if (allocated(workspace%dfdh_lower)) deallocate(workspace%dfdh_lower)
    if (allocated(workspace%dfdh_main)) deallocate(workspace%dfdh_main)
    if (allocated(workspace%dfdh_upper)) deallocate(workspace%dfdh_upper)
    if (allocated(workspace%residual)) deallocate(workspace%residual)
    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)
    if (allocated(workspace%tridag_gamma)) deallocate(workspace%tridag_gamma)
    if (allocated(workspace%sink)) deallocate(workspace%sink)
    if (allocated(workspace%source)) deallocate(workspace%source)
    if (allocated(workspace%provider_theta)) deallocate(workspace%provider_theta)
    if (allocated(workspace%provider_k)) deallocate(workspace%provider_k)
    if (allocated(workspace%provider_capacity)) deallocate(workspace%provider_capacity)
    if (allocated(workspace%provider_dkdh)) deallocate(workspace%provider_dkdh)
    if (allocated(workspace%provider_root_sink)) deallocate(workspace%provider_root_sink)
    if (allocated(workspace%dconductivity_dhead)) deallocate(workspace%dconductivity_dhead)
    if (allocated(workspace%old_head)) deallocate(workspace%old_head)
    if (allocated(workspace%vertical_flux)) deallocate(workspace%vertical_flux)
    if (allocated(workspace%head_gradient)) deallocate(workspace%head_gradient)
    if (allocated(workspace%band_matrix)) deallocate(workspace%band_matrix)
    if (allocated(workspace%band_aux)) deallocate(workspace%band_aux)
    if (allocated(workspace%band_rhs)) deallocate(workspace%band_rhs)
    if (allocated(workspace%band_pivots)) deallocate(workspace%band_pivots)
    if (allocated(workspace%nonconverged_balance)) deallocate(workspace%nonconverged_balance)
    if (allocated(workspace%nonconverged_head)) deallocate(workspace%nonconverged_head)
    if (allocated(workspace%warm_start_head)) deallocate(workspace%warm_start_head)
    workspace%active_nodes = 0
    workspace%poisoned = .false.
    workspace%has_warm_start = .false.
    workspace%unsaturated_flags = .false.
    workspace%diagnostics = soil_water_solver_diagnostics_t()
  end subroutine release_reference_workspace

  function reference_workspace_payload_bytes(workspace) result(nbytes)
    type(reference_richards_workspace_t), intent(in) :: workspace
    integer(int64) :: nbytes
    integer(int64) :: nreal, nlogical, ninteger

    nreal = 0_int64
    nlogical = 0_int64
    ninteger = 0_int64
    if (allocated(workspace%dfdh_lower)) nreal = nreal + size(workspace%dfdh_lower, kind=int64)
    if (allocated(workspace%dfdh_main)) nreal = nreal + size(workspace%dfdh_main, kind=int64)
    if (allocated(workspace%dfdh_upper)) nreal = nreal + size(workspace%dfdh_upper, kind=int64)
    if (allocated(workspace%residual)) nreal = nreal + size(workspace%residual, kind=int64)
    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)
    if (allocated(workspace%tridag_gamma)) nreal = nreal + size(workspace%tridag_gamma, kind=int64)
    if (allocated(workspace%sink)) nreal = nreal + size(workspace%sink, kind=int64)
    if (allocated(workspace%source)) nreal = nreal + size(workspace%source, kind=int64)
    if (allocated(workspace%provider_theta)) nreal = nreal + size(workspace%provider_theta, kind=int64)
    if (allocated(workspace%provider_k)) nreal = nreal + size(workspace%provider_k, kind=int64)
    if (allocated(workspace%provider_capacity)) nreal = nreal + size(workspace%provider_capacity, kind=int64)
    if (allocated(workspace%provider_dkdh)) nreal = nreal + size(workspace%provider_dkdh, kind=int64)
    if (allocated(workspace%provider_root_sink)) nreal = nreal + size(workspace%provider_root_sink, kind=int64)
    if (allocated(workspace%dconductivity_dhead)) nreal = nreal + size(workspace%dconductivity_dhead, kind=int64)
    if (allocated(workspace%old_head)) nreal = nreal + size(workspace%old_head, kind=int64)
    if (allocated(workspace%vertical_flux)) nreal = nreal + size(workspace%vertical_flux, kind=int64)
    if (allocated(workspace%head_gradient)) nreal = nreal + size(workspace%head_gradient, kind=int64)
    if (allocated(workspace%warm_start_head)) nreal = nreal + size(workspace%warm_start_head, kind=int64)
    if (allocated(workspace%band_matrix)) nreal = nreal + size(workspace%band_matrix, kind=int64)
    if (allocated(workspace%band_aux)) nreal = nreal + size(workspace%band_aux, kind=int64)
    if (allocated(workspace%band_rhs)) nreal = nreal + size(workspace%band_rhs, kind=int64)
    if (allocated(workspace%band_pivots)) ninteger = ninteger + size(workspace%band_pivots, kind=int64)
    if (allocated(workspace%nonconverged_balance)) nlogical = nlogical + size(workspace%nonconverged_balance, kind=int64)
    if (allocated(workspace%nonconverged_head)) nlogical = nlogical + size(workspace%nonconverged_head, kind=int64)
    nlogical = nlogical + 3_int64
    nbytes = nreal * int(storage_size(0.0_real64)/8, int64) + &
             nlogical * int(storage_size(.false.)/8, int64) + &
             ninteger * int(storage_size(0)/8, int64)
  end function reference_workspace_payload_bytes

end module mod_reference_richards_workspace
