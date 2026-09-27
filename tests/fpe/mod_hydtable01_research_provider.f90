module mod_hydtable01_research_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
       CONSTITUTIVE_DEMAND_CAPACITY, CONSTITUTIVE_DEMAND_DKDH
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  implicit none
  private

  integer, parameter :: NTAB = 1024
  real(real64), parameter :: H_WET = -1.0_real64
  real(real64), parameter :: H_DRY = -1.0e6_real64
  real(real64), parameter :: LOG_RANGE = log(1.0e6_real64)

  type, extends(constitutive_hydraulics_provider_t), public :: hydtable01_provider_t
    type(b110_default_mvg_provider_t) :: analytical
    type(b110_default_mvg_parameters_t), pointer :: parameters => null()
    real(real64), allocatable :: logk(:,:)
    logical :: ready = .false.
  contains
    procedure :: evaluate => hydtable01_evaluate
    procedure :: evaluate_demand => hydtable01_evaluate_demand
    procedure :: supports_point_conductivity => hydtable01_supports_point
    procedure :: evaluate_point_conductivity => hydtable01_point
  end type hydtable01_provider_t

  public :: bind_hydtable01_provider

contains

  subroutine bind_hydtable01_provider(provider, parameters, step_duration, ok)
    type(hydtable01_provider_t), intent(out) :: provider
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    real(real64), intent(in) :: step_duration
    logical, intent(out) :: ok
    integer :: node, i
    real(real64) :: h, k
    logical :: local_ok

    ok = .false.
    provider%ready = .false.
    provider%parameters => null()
    if (parameters%active_nodes <= 0 .or. .not. allocated(parameters%cofgen)) return
    call bind_b110_default_mvg_provider(provider%analytical, parameters, step_duration)
    provider%parameters => parameters
    allocate(provider%logk(NTAB, parameters%active_nodes))
    do node = 1, parameters%active_nodes
      do i = 1, NTAB
        h = -exp(real(i-1,real64)/real(NTAB-1,real64)*LOG_RANGE)
        call evaluate_b110_default_mvg_conductivity(parameters,node,h,k,local_ok)
        if (.not. local_ok .or. k <= 0.0_real64) return
        provider%logk(i,node) = log(k)
      end do
    end do
    provider%ready = .true.
    ok = .true.
  end subroutine bind_hydtable01_provider

  subroutine hydtable01_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(hydtable01_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i
    logical :: inside
    real(real64) :: k

    if (.not. self%ready) error stop 'HYDTABLE01 provider not ready'
    water_content=0.0_real64; conductivity=0.0_real64; capacity=0.0_real64; dconductivity_dhead=0.0_real64
    call self%analytical%evaluate_demand(pressure_head, &
         CONSTITUTIVE_DEMAND_WATER_CONTENT + CONSTITUTIVE_DEMAND_CAPACITY, &
         water_content, conductivity, capacity, dconductivity_dhead)
    do i=1,size(pressure_head)
      call table_k(self, i, pressure_head(i), k, inside)
      if (inside) conductivity(i)=k
    end do
  end subroutine hydtable01_evaluate

  subroutine hydtable01_evaluate_demand(self, pressure_head, demand_mask, water_content, conductivity, capacity, dconductivity_dhead)
    class(hydtable01_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    integer, intent(in) :: demand_mask
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: rest_mask, i
    logical :: need_k, inside, ok
    real(real64) :: k

    if (.not. self%ready) error stop 'HYDTABLE01 provider not ready'
    need_k = iand(demand_mask, CONSTITUTIVE_DEMAND_CONDUCTIVITY) /= 0

    if (iand(demand_mask, CONSTITUTIVE_DEMAND_DKDH) /= 0) then
      call self%analytical%evaluate_demand(pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    else
      water_content=0.0_real64; conductivity=0.0_real64; capacity=0.0_real64; dconductivity_dhead=0.0_real64
      rest_mask=demand_mask
      if (need_k) rest_mask=rest_mask-CONSTITUTIVE_DEMAND_CONDUCTIVITY
      if (rest_mask /= 0) then
        call self%analytical%evaluate_demand(pressure_head,rest_mask,water_content,conductivity,capacity,dconductivity_dhead)
      end if
    end if

    if (need_k) then
      do i=1,size(pressure_head)
        call table_k(self,i,pressure_head(i),k,inside)
        if (inside) then
          conductivity(i)=k
        else
          call evaluate_b110_default_mvg_conductivity(self%parameters,i,pressure_head(i),conductivity(i),ok)
          if (.not. ok) error stop 'HYDTABLE01 analytical fallback failed'
        end if
      end do
    end if
  end subroutine hydtable01_evaluate_demand

  logical function hydtable01_supports_point(self) result(supported)
    class(hydtable01_provider_t), intent(in) :: self
    supported=self%ready
  end function hydtable01_supports_point

  subroutine hydtable01_point(self,node_index,pressure_head,water_content,conductivity,available)
    class(hydtable01_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    logical :: inside, ok

    available=.false.; conductivity=0.0_real64
    if(.not.self%ready) return
    call table_k(self,node_index,pressure_head,conductivity,inside)
    if(inside) then
      available=.true.
    else
      call evaluate_b110_default_mvg_conductivity(self%parameters,node_index,pressure_head,conductivity,ok)
      available=ok
    end if
  end subroutine hydtable01_point

  subroutine table_k(self,node,h,k,inside)
    class(hydtable01_provider_t), intent(in) :: self
    integer, intent(in) :: node
    real(real64), intent(in) :: h
    real(real64), intent(out) :: k
    logical, intent(out) :: inside
    real(real64) :: x,f,y
    integer :: i

    inside=.false.; k=0.0_real64
    if(h > H_WET .or. h < H_DRY) return
    if(node<1 .or. node>size(self%logk,2)) return
    x=log(-h)
    i=1+int(x*real(NTAB-1,real64)/LOG_RANGE)
    i=max(1,min(NTAB-1,i))
    f=(x-real(i-1,real64)*LOG_RANGE/real(NTAB-1,real64))/(LOG_RANGE/real(NTAB-1,real64))
    f=max(0.0_real64,min(1.0_real64,f))
    y=(1.0_real64-f)*self%logk(i,node)+f*self%logk(i+1,node)
    k=exp(y)
    inside=.true.
  end subroutine table_k
end module mod_hydtable01_research_provider
