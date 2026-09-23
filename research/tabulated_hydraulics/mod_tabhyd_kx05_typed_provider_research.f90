module mod_tabhyd_kx05_typed_provider_research
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider
  implicit none
  private

  real(real64), parameter :: H_CRIT=-1.0e-2_real64
  real(real64), parameter :: H_KSATEXM=-2.0_real64

  type, extends(constitutive_hydraulics_provider_t), public :: tabhyd_kx05_provider_t
    private
    type(tabhyd_raw_provider_t) :: base
    integer :: active_nodes=0
    real(real64), allocatable :: theta_r(:), theta_s(:), delta_theta(:)
    real(real64), allocatable :: ksatexm(:), relsat_threshold(:), k_threshold(:)
    real(real64), allocatable :: first_active_head(:)
  contains
    procedure :: evaluate => tabhyd_kx05_evaluate
  end type tabhyd_kx05_provider_t

  public :: initialize_tabhyd_kx05_provider

contains

  subroutine initialize_tabhyd_kx05_provider(provider,head_table,theta_table,conductivity_table,cofgen,step_duration)
    type(tabhyd_kx05_provider_t), intent(out) :: provider
    real(real64), intent(in) :: head_table(:,:),theta_table(:,:),conductivity_table(:,:)
    real(real64), intent(in) :: cofgen(:,:)
    real(real64), intent(in) :: step_duration
    real(real64) :: hlow,hhigh,hmid,hnext,thetaauth,seauth
    integer :: n,i,steps

    n=size(cofgen,2)
    if(n<=0 .or. size(cofgen,1)<12) error stop 'KX05 provider: invalid cofgen shape'
    if(size(head_table,2)/=n .or. size(theta_table,2)/=n .or. size(conductivity_table,2)/=n) &
      error stop 'KX05 provider: table/node shape mismatch'

    call initialize_tabhyd_raw_provider(provider%base,head_table,theta_table,conductivity_table,cofgen,step_duration)

    provider%active_nodes=n
    allocate(provider%theta_r(n),provider%theta_s(n),provider%delta_theta(n),provider%ksatexm(n), &
             provider%relsat_threshold(n),provider%k_threshold(n),provider%first_active_head(n))

    do i=1,n
      if(cofgen(9,i)/=0.0_real64) error stop 'KX05 provider: H_ENPR outside qualified scope'
      if(cofgen(2,i)<=cofgen(1,i)) error stop 'KX05 provider: invalid theta bounds'
      if(cofgen(6,i)<=1.0_real64) error stop 'KX05 provider: invalid n'
      if(cofgen(10,i)<=cofgen(3,i)) error stop 'KX05 provider: KSATEXM extension not active'
      if(cofgen(11,i)<=0.0_real64 .or. cofgen(11,i)>=1.0_real64) error stop 'KX05 provider: invalid Se threshold'
      if(cofgen(12,i)<=0.0_real64 .or. cofgen(12,i)>=cofgen(10,i)) error stop 'KX05 provider: invalid K threshold'

      provider%theta_r(i)=cofgen(1,i)
      provider%theta_s(i)=cofgen(2,i)
      provider%delta_theta(i)=cofgen(2,i)-cofgen(1,i)
      provider%ksatexm(i)=cofgen(10,i)
      provider%relsat_threshold(i)=cofgen(11,i)
      provider%k_threshold(i)=cofgen(12,i)

      hlow=H_KSATEXM
      hhigh=0.0_real64
      thetaauth=authority_theta(cofgen(:,i),hlow)
      seauth=(thetaauth-cofgen(1,i))/provider%delta_theta(i)
      if(seauth>cofgen(11,i)) error stop 'KX05 provider: lower branch bound active'
      thetaauth=authority_theta(cofgen(:,i),hhigh)
      seauth=(thetaauth-cofgen(1,i))/provider%delta_theta(i)
      if(seauth<=cofgen(11,i)) error stop 'KX05 provider: upper branch bound inactive'

      steps=0
      do
        hnext=nearest(hlow,1.0_real64)
        if(hnext>=hhigh) exit
        hmid=hlow+0.5_real64*(hhigh-hlow)
        if(hmid==hlow .or. hmid==hhigh) exit
        thetaauth=authority_theta(cofgen(:,i),hmid)
        seauth=(thetaauth-cofgen(1,i))/provider%delta_theta(i)
        if(seauth>cofgen(11,i)) then
          hhigh=hmid
        else
          hlow=hmid
        end if
        steps=steps+1
        if(steps>128) error stop 'KX05 provider: floating-boundary search exceeded bound'
      end do
      provider%first_active_head(i)=hhigh
    end do
  end subroutine initialize_tabhyd_kx05_provider

  subroutine tabhyd_kx05_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(tabhyd_kx05_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64) :: se,f
    integer :: i

    if(size(pressure_head)/=self%active_nodes) error stop 'KX05 provider: input shape mismatch'
    if(size(water_content)/=self%active_nodes .or. size(conductivity)/=self%active_nodes .or. &
       size(capacity)/=self%active_nodes .or. size(dconductivity_dhead)/=self%active_nodes) &
      error stop 'KX05 provider: output shape mismatch'

    call self%base%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)

    do i=1,self%active_nodes
      if(pressure_head(i)>=self%first_active_head(i)) then
        se=(water_content(i)-self%theta_r(i))/self%delta_theta(i)
        f=(se-self%relsat_threshold(i))/(1.0_real64-self%relsat_threshold(i))
        conductivity(i)=f*self%ksatexm(i)+(1.0_real64-f)*self%k_threshold(i)
      end if
    end do

    dconductivity_dhead=0.0_real64
  end subroutine tabhyd_kx05_evaluate

  pure real(real64) function authority_theta(c,hv) result(theta)
    real(real64), intent(in) :: c(:),hv
    real(real64) :: m,delta,theta_crit,wet_capacity,help
    m=1.0_real64-1.0_real64/c(6)
    delta=c(2)-c(1)
    if(hv>=0.0_real64) then
      theta=c(2)
    else if(hv>H_CRIT) then
      help=abs(c(4)*H_CRIT)**c(6)
      theta_crit=c(1)+delta/((1.0_real64+help)**m)
      wet_capacity=(c(2)-theta_crit)/(-H_CRIT)
      theta=theta_crit+wet_capacity*(hv-H_CRIT)
      theta=min(theta,c(2))
    else
      help=abs(c(4)*hv)**c(6)
      help=(1.0_real64+help)**m
      theta=c(1)+delta/help
    end if
  end function authority_theta

end module mod_tabhyd_kx05_typed_provider_research
