module mod_tabhyd_kx03_typed_provider_research
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider
  implicit none
  private

  real(real64), parameter :: H_CRIT=-1.0e-2_real64

  type, extends(constitutive_hydraulics_provider_t), public :: tabhyd_kx03_provider_t
    private
    type(tabhyd_raw_provider_t) :: base
    integer :: active_nodes=0
    real(real64), allocatable :: theta_r(:), theta_s(:), delta_theta(:)
    real(real64), allocatable :: alpha(:), npar(:), mpar(:)
    real(real64), allocatable :: theta_crit(:), wet_capacity(:)
    real(real64), allocatable :: ksat(:), ksatexm(:), relsat_threshold(:), k_threshold(:)
  contains
    procedure :: evaluate => tabhyd_kx03_evaluate
  end type tabhyd_kx03_provider_t

  public :: initialize_tabhyd_kx03_provider

contains

  subroutine initialize_tabhyd_kx03_provider(provider,head_table,theta_table,conductivity_table,cofgen,step_duration)
    type(tabhyd_kx03_provider_t), intent(out) :: provider
    real(real64), intent(in) :: head_table(:,:),theta_table(:,:),conductivity_table(:,:)
    real(real64), intent(in) :: cofgen(:,:)
    real(real64), intent(in) :: step_duration
    real(real64) :: help
    integer :: n,i

    n=size(cofgen,2)
    if(n<=0 .or. size(cofgen,1)<12) error stop 'KX03 provider: invalid cofgen shape'
    if(size(head_table,2)/=n .or. size(theta_table,2)/=n .or. size(conductivity_table,2)/=n) &
      error stop 'KX03 provider: table/node shape mismatch'

    call initialize_tabhyd_raw_provider(provider%base,head_table,theta_table,conductivity_table,cofgen,step_duration)

    provider%active_nodes=n
    allocate(provider%theta_r(n),provider%theta_s(n),provider%delta_theta(n),provider%alpha(n),provider%npar(n), &
             provider%mpar(n),provider%theta_crit(n),provider%wet_capacity(n),provider%ksat(n),provider%ksatexm(n), &
             provider%relsat_threshold(n),provider%k_threshold(n))

    do i=1,n
      if(cofgen(9,i)/=0.0_real64) error stop 'KX03 provider: H_ENPR outside qualified scope'
      if(cofgen(2,i)<=cofgen(1,i)) error stop 'KX03 provider: invalid theta bounds'
      if(cofgen(6,i)<=1.0_real64) error stop 'KX03 provider: invalid n'
      if(cofgen(10,i)<=cofgen(3,i)) error stop 'KX03 provider: KSATEXM extension not active'
      if(cofgen(11,i)<=0.0_real64 .or. cofgen(11,i)>=1.0_real64) error stop 'KX03 provider: invalid Se threshold'
      if(cofgen(12,i)<=0.0_real64 .or. cofgen(12,i)>=cofgen(10,i)) error stop 'KX03 provider: invalid K threshold'

      provider%theta_r(i)=cofgen(1,i)
      provider%theta_s(i)=cofgen(2,i)
      provider%delta_theta(i)=cofgen(2,i)-cofgen(1,i)
      provider%alpha(i)=cofgen(4,i)
      provider%npar(i)=cofgen(6,i)
      provider%mpar(i)=1.0_real64-1.0_real64/cofgen(6,i)
      provider%ksat(i)=cofgen(3,i)
      provider%ksatexm(i)=cofgen(10,i)
      provider%relsat_threshold(i)=cofgen(11,i)
      provider%k_threshold(i)=cofgen(12,i)

      help=abs(provider%alpha(i)*H_CRIT)**provider%npar(i)
      help=(1.0_real64+help)**provider%mpar(i)
      provider%theta_crit(i)=provider%theta_r(i)+provider%delta_theta(i)/help
      provider%wet_capacity(i)=(provider%theta_s(i)-provider%theta_crit(i))/(-H_CRIT)
    end do
  end subroutine initialize_tabhyd_kx03_provider

  subroutine tabhyd_kx03_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(tabhyd_kx03_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64) :: theta_authority,se_authority,f,help
    integer :: i

    if(size(pressure_head)/=self%active_nodes) error stop 'KX03 provider: input shape mismatch'
    if(size(water_content)/=self%active_nodes .or. size(conductivity)/=self%active_nodes .or. &
       size(capacity)/=self%active_nodes .or. size(dconductivity_dhead)/=self%active_nodes) &
      error stop 'KX03 provider: output shape mismatch'

    call self%base%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)

    do i=1,self%active_nodes
      if(pressure_head(i)>=0.0_real64) then
        theta_authority=self%theta_s(i)
      else if(pressure_head(i)>H_CRIT) then
        theta_authority=self%theta_crit(i)+self%wet_capacity(i)*(pressure_head(i)-H_CRIT)
        theta_authority=min(theta_authority,self%theta_s(i))
      else
        help=abs(self%alpha(i)*pressure_head(i))**self%npar(i)
        help=(1.0_real64+help)**self%mpar(i)
        theta_authority=self%theta_r(i)+self%delta_theta(i)/help
      end if
      se_authority=(theta_authority-self%theta_r(i))/self%delta_theta(i)
      if(se_authority>self%relsat_threshold(i)) then
        f=(se_authority-self%relsat_threshold(i))/(1.0_real64-self%relsat_threshold(i))
        conductivity(i)=f*self%ksatexm(i)+(1.0_real64-f)*self%k_threshold(i)
      end if
    end do

    ! KX03 remains a K0-only provider. The derivative slot is deliberately not admitted.
    dconductivity_dhead=0.0_real64
  end subroutine tabhyd_kx03_evaluate

end module mod_tabhyd_kx03_typed_provider_research
