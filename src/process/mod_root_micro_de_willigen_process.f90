module mod_root_micro_de_willigen_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_root_micro_matric_flux_table, only: micro_matric_flux_table_t, evaluate_micro_matric_flux_table, MICRO_TABLE_OK
  implicit none
  private

  integer, parameter, public :: MICRO_DW_OK=0, MICRO_DW_INVALID=1, MICRO_DW_NO_CONVERGENCE=2
  real(real64), parameter :: PI=acos(-1.0_real64)
  type, public :: micro_de_willigen_parameters_t
    real(real64) :: root_radius_cm=0.0_real64, root_conductance_cm_per_day=0.0_real64
    real(real64) :: stem_a0_per_day=0.0_real64, stem_a1_per_cm=0.0_real64
    real(real64) :: half_leaf_pressure_cm=0.0_real64, campbell_exponent=0.0_real64
    real(real64) :: pressure_tolerance_cm=1.0e-6_real64, newton_tolerance_cm=1.0e-7_real64
    real(real64) :: residual_tolerance_cm_per_day=1.0e-4_real64
    integer :: max_iterations=500, oxygen_mode=0, reduction_mode=1
  contains
    procedure::ready=>valid_parameters
  end type
  type, public :: micro_de_willigen_result_t
    real(real64), allocatable :: root_extraction_sink(:), potential_root_sink(:)
    real(real64) :: actual_uptake_total=0.0_real64, root_pressure_cm=0.0_real64
    real(real64) :: leaf_pressure_cm=0.0_real64, reduction_factor=0.0_real64
    integer :: status=MICRO_DW_INVALID
  end type
  public :: evaluate_micro_de_willigen,attribute_micro_root_stress_losses

contains

  ! Literal B1.11 RootExtraction_MICRO/p_func attribution, without frost.
  ! These diagnostics allocate the one accepted uptake deficit, not a second
  ! water sink. SWMXDROUGHT=0 assigns the whole deficit to other active
  ! stressors; it does not multiply an already drought-reduced sink again.
  subroutine attribute_micro_root_stress_losses(thickness,root_length_density,oxygen_factor,salinity_factor, &
       rooted_nodes,potential,actual,maximum_drought_mode,optimal_actual,drought_loss,oxygen_loss, &
       salinity_loss,drought_factor,status,previous_drought_factor)
    real(real64),intent(in)::thickness(:),root_length_density(:),oxygen_factor(:),salinity_factor(:)
    integer,intent(in)::rooted_nodes,maximum_drought_mode
    real(real64),intent(in)::potential,actual,optimal_actual
    real(real64),intent(in),optional::previous_drought_factor
    real(real64),intent(out)::drought_loss,oxygen_loss,salinity_loss,drought_factor
    integer,intent(out)::status
    real(real64)::sum_o,sum_s,term_o,term_s,denom,p_o,p_s,reduction,optimal_reduction,remaining,tol
    integer::i,n
    status=MICRO_DW_INVALID
    drought_loss=0.0_real64;oxygen_loss=0.0_real64;salinity_loss=0.0_real64;drought_factor=0.0_real64
    n=size(thickness)
    if(rooted_nodes<0.or.rooted_nodes>n)return
    if(size(root_length_density)/=n.or.size(oxygen_factor)/=n.or.size(salinity_factor)/=n)return
    if(maximum_drought_mode/=0.and.maximum_drought_mode/=1)return
    if(.not.all(ieee_is_finite([potential,actual])))return
    if(potential<0.0_real64.or.actual<0.0_real64.or.actual>potential)return
    if(present(previous_drought_factor))then
      if(.not.ieee_is_finite(previous_drought_factor))return
      if(previous_drought_factor<0.0_real64.or.previous_drought_factor>1.0_real64)return
    end if
    ! The source exits before assigning saved ALPDRYNODRTZ when PTRA<NIHIL.
    ! Exact continuation supplies its preceding physical value, including on
    ! full/half/retry copies; zero is only the explicit initial observation.
    if(rooted_nodes==0.or.potential<1.0e-10_real64)then
      if(actual/=0.0_real64)return
      if(rooted_nodes==0.and.potential>=1.0e-10_real64)return
      if(present(previous_drought_factor))drought_factor=previous_drought_factor
      status=MICRO_DW_OK;return
    end if
    if(any(.not.ieee_is_finite(thickness(:rooted_nodes))).or. &
       any(.not.ieee_is_finite(root_length_density(:rooted_nodes))).or. &
       any(.not.ieee_is_finite(oxygen_factor(:rooted_nodes))).or. &
       any(.not.ieee_is_finite(salinity_factor(:rooted_nodes))))return
    if(any(thickness(:rooted_nodes)<=0.0_real64).or.any(root_length_density(:rooted_nodes)<0.0_real64))return
    if(any(oxygen_factor(:rooted_nodes)<0.0_real64).or.any(oxygen_factor(:rooted_nodes)>1.0_real64).or. &
       any(salinity_factor(:rooted_nodes)<0.0_real64).or.any(salinity_factor(:rooted_nodes)>1.0_real64))return
    sum_o=0.0_real64;sum_s=0.0_real64
    do i=1,rooted_nodes
      ! Validate finite malformed inputs before the literal weighted sums can
      ! overflow under the native invalid/zero/overflow traps.
      if(thickness(i)>1.0_real64)then
        if(root_length_density(i)>huge(1.0_real64)/thickness(i))return
      end if
      term_o=(1.0_real64-oxygen_factor(i))*root_length_density(i)*thickness(i)
      term_s=(1.0_real64-salinity_factor(i))*root_length_density(i)*thickness(i)
      if(sum_o>huge(1.0_real64)-term_o.or.sum_s>huge(1.0_real64)-term_s)return
      sum_o=sum_o+term_o;sum_s=sum_s+term_s
    end do
    if(sum_o>huge(1.0_real64)-sum_s)return
    denom=sum_o+sum_s;p_o=0.0_real64;p_s=0.0_real64
    if(denom>0.0_real64)then
      p_o=sum_o/denom;p_s=sum_s/denom
    end if
    reduction=max(0.0_real64,potential-actual);optimal_reduction=0.0_real64
    if(maximum_drought_mode==1)then
      if(.not.ieee_is_finite(optimal_actual))return
      if(optimal_actual<0.0_real64.or.optimal_actual>potential)return
      optimal_reduction=max(0.0_real64,potential-optimal_actual)
      ! A negative remaining deficit is not a legitimate stress partition.
      ! Report it instead of clamping or assigning a negative oxygen loss.
      if(optimal_reduction>reduction)return
    end if
    if(optimal_reduction>0.0_real64)then
      remaining=reduction-optimal_reduction
      drought_loss=optimal_reduction;oxygen_loss=p_o*remaining;salinity_loss=p_s*remaining
    else if(p_o>0.0_real64.or.p_s>0.0_real64)then
      oxygen_loss=p_o*reduction;salinity_loss=p_s*reduction
    else
      drought_loss=reduction
    end if
    tol=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,potential)
    if(abs(drought_loss+oxygen_loss+salinity_loss-reduction)>tol)then
      drought_loss=0.0_real64;oxygen_loss=0.0_real64;salinity_loss=0.0_real64;return
    end if
    drought_factor=1.0_real64-drought_loss/potential
    if(.not.ieee_is_finite(drought_factor))return
    if(drought_factor<0.0_real64.or.drought_factor>1.0_real64)return
    status=MICRO_DW_OK
  end subroutine attribute_micro_root_stress_losses

  subroutine evaluate_micro_de_willigen(parameters, pressure_head, thickness, root_length_density, stress_factor, &
                                       rooted_nodes, potential_transpiration, tables, result)
    type(micro_de_willigen_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: pressure_head(:), thickness(:), root_length_density(:), stress_factor(:)
    integer, intent(in) :: rooted_nodes
    real(real64), intent(in) :: potential_transpiration
    type(micro_matric_flux_table_t), intent(in) :: tables(:)
    type(micro_de_willigen_result_t), intent(out) :: result
    integer, allocatable :: node_of(:)
    real(real64), allocatable :: pav(:), phiav(:), q(:), s(:), x(:), delta(:), candidate_sink(:)
    real(real64) :: total_length, r1, rho, fg, phi, conductivity, stem, dpl
    real(real64) :: sumq, lo, hi, mid, flo, fhi, fm, actual, value, soil_total, rounding_bound
    integer :: n, j, m, active_count, iteration, table_status, balance_attempt
    logical :: ok, bracketed

    result=micro_de_willigen_result_t()
    n=size(pressure_head)
    if(n<=0.or.rooted_nodes<0.or.rooted_nodes>n) return
    if(size(thickness)/=n.or.size(root_length_density)/=n.or.size(stress_factor)/=n.or.size(tables)/=n) return
    if(any(.not.ieee_is_finite(pressure_head)).or.any(.not.ieee_is_finite(thickness)).or. &
       any(.not.ieee_is_finite(root_length_density)).or.any(.not.ieee_is_finite(stress_factor))) return
    if(any(thickness<=0.0_real64).or.any(root_length_density<0.0_real64)) return
    if(any(stress_factor<0.0_real64).or.any(stress_factor>1.0_real64)) return
    if(.not.ieee_is_finite(potential_transpiration).or.potential_transpiration<0.0_real64) return
    if(.not.valid_parameters(parameters)) return

    allocate(candidate_sink(n))
    candidate_sink=0.0_real64
    if(rooted_nodes==0.or.potential_transpiration<1.0e-10_real64) then
      call publish()
      return
    end if
    total_length=sum(root_length_density(1:rooted_nodes)*thickness(1:rooted_nodes))
    if(.not.ieee_is_finite(total_length).or.total_length<=0.0_real64) return
    m=count(pressure_head(1:rooted_nodes)<0.0_real64.and.stress_factor(1:rooted_nodes)>0.0_real64)
    if(m==0) then
      call publish()
      result%potential_root_sink(1:rooted_nodes)= &
           root_length_density(1:rooted_nodes)*thickness(1:rooted_nodes)/total_length*potential_transpiration
      return
    end if
    allocate(node_of(m),pav(m),phiav(m),q(m),s(m),x(m),delta(m))
    active_count=0
    do j=1,rooted_nodes
      if(pressure_head(j)>=0.0_real64.or.stress_factor(j)<=0.0_real64) cycle
      if(root_length_density(j)<=0.0_real64) return
      active_count=active_count+1
      node_of(active_count)=j
      pav(active_count)=-pressure_head(j)
      r1=1.0_real64/sqrt(PI*root_length_density(j))
      if(parameters%oxygen_mode==1) r1=1.0_real64/sqrt(PI*stress_factor(j)*root_length_density(j))
      rho=r1/parameters%root_radius_cm
      if(.not.ieee_is_finite(rho).or.rho<=1.0_real64) return
      fg=0.5_real64*((1.0_real64-3.0_real64*rho*rho)*0.25_real64+ &
         rho**4*log(rho)/(rho*rho-1.0_real64))
      if(.not.ieee_is_finite(fg).or.fg<=0.0_real64) return
      q(active_count)=root_length_density(j)*parameters%root_conductance_cm_per_day*thickness(j)
      if(parameters%oxygen_mode==1.or.parameters%oxygen_mode==2) q(active_count)=q(active_count)*stress_factor(j)
      s(active_count)=thickness(j)*PI*root_length_density(j)*(rho*rho-1.0_real64)/fg
      if(parameters%oxygen_mode==1) s(active_count)=s(active_count)*stress_factor(j)
      if(.not.ieee_is_finite(q(active_count)).or..not.ieee_is_finite(s(active_count))) return
      if(q(active_count)<=0.0_real64.or.s(active_count)<=0.0_real64) return
      call evaluate_micro_matric_flux_table(tables(j),pressure_head(j),phiav(active_count),conductivity,table_status)
      if(table_status/=MICRO_TABLE_OK) return
    end do

    stem=parameters%stem_a1_per_cm*potential_transpiration+parameters%stem_a0_per_day
    if(.not.ieee_is_finite(stem).or.stem<=0.0_real64) return
    dpl=potential_transpiration/stem
    sumq=sum(q)
    if(.not.ieee_is_finite(sumq).or.sumq<=0.0_real64) return
    lo=sum(q*pav)/sumq
    hi=lo+potential_transpiration/sumq
    if(.not.ieee_is_finite(lo).or..not.ieee_is_finite(hi)) return
    call residual(lo,flo,ok)
    if(.not.ok) then
      result%status=MICRO_DW_NO_CONVERGENCE
      return
    end if
    call residual(hi,fhi,ok)
    if(.not.ok) then
      result%status=MICRO_DW_NO_CONVERGENCE
      return
    end if
    bracketed=(flo<=0.0_real64.and.fhi>=0.0_real64).or.(flo>=0.0_real64.and.fhi<=0.0_real64)
    do iteration=1,parameters%max_iterations
      if(bracketed) exit
      if(flo>0.0_real64.and.fhi>0.0_real64) then
        lo=lo-max(1.0_real64,abs(hi-lo))
        if(.not.ieee_is_finite(lo)) exit
        call residual(lo,flo,ok)
      else
        hi=hi+max(1.0_real64,abs(hi-lo))
        if(.not.ieee_is_finite(hi)) exit
        call residual(hi,fhi,ok)
      end if
      if(.not.ok) exit
      bracketed=(flo<=0.0_real64.and.fhi>=0.0_real64).or.(flo>=0.0_real64.and.fhi<=0.0_real64)
    end do
    if(.not.bracketed) then
      result%status=MICRO_DW_NO_CONVERGENCE
      return
    end if
    mid=lo
    do iteration=1,parameters%max_iterations
      mid=0.5_real64*(lo+hi)
      call residual(mid,fm,ok)
      if(.not.ok) exit
      if(abs(fm)<=parameters%residual_tolerance_cm_per_day.or. &
         abs(hi-lo)<=parameters%pressure_tolerance_cm) exit
      if(flo*fm<=0.0_real64) then
        hi=mid
      else
        lo=mid
        flo=fm
      end if
    end do
    if(.not.ok.or.iteration>parameters%max_iterations) then
      result%status=MICRO_DW_NO_CONVERGENCE
      return
    end if
    ! Re-evaluate at the published pressure: residual evaluation owns X.
    ! Preserve the incumbent result when its independent soil/root certificate
    ! passes. At low demand the original absolute Newton head criterion can
    ! underresolve a small nodal flux; refine that SAME root pressure only when
    ! the existing flux certificate fails, without changing either tolerance.
    do balance_attempt=1,2
      call residual(mid,fm,ok,enforce_balance=balance_attempt==2)
      if(.not.ok.or.abs(fm)>parameters%residual_tolerance_cm_per_day) then
        result%status=MICRO_DW_NO_CONVERGENCE
        return
      end if
      soil_total=0.0_real64
      do j=1,m
        value=q(j)*(mid-x(j))
        if(.not.ieee_is_finite(value).or.value<0.0_real64) return
        candidate_sink(node_of(j))=value
        call evaluate_micro_matric_flux_table(tables(node_of(j)),-x(j),phi,conductivity,table_status)
        if(table_status/=MICRO_TABLE_OK) return
        soil_total=soil_total+s(j)*max(0.0_real64,phiav(j)-phi)
      end do
      actual=sum(candidate_sink)
      if(.not.ieee_is_finite(actual).or..not.ieee_is_finite(soil_total)) return
      if(actual>0.0_real64) then
        if(abs(actual-soil_total)/actual>0.01_real64) then
          if(balance_attempt==1)cycle
          result%status=MICRO_DW_NO_CONVERGENCE
          return
        end if
      end if
      exit
    end do
    if(actual>0.0_real64) then
      if(actual>potential_transpiration) then
        candidate_sink=candidate_sink*(potential_transpiration/actual)
        ! Positive summation plus one division and nodal multiplication has a
        ! gamma(n+2) relative rounding bound; reject any larger post-cap excess.
        rounding_bound=real(n+2,real64)*epsilon(1.0_real64)
        if(rounding_bound>=1.0_real64)return
        rounding_bound=rounding_bound/(1.0_real64-rounding_bound)*potential_transpiration
        if(sum(candidate_sink)-potential_transpiration>rounding_bound)return
        ! The source limits total uptake to potential demand. A rounded SUM of
        ! the rescaled nodal sinks can still exceed that demand by an ulp.
        ! Correct the rounding remainder on the largest donor, retaining the
        ! strict published total bound and the exact one sink used by Richards.
        ! This is the existing demand cap, not a stress-admission tolerance.
        do iteration=1,n+2
          actual=sum(candidate_sink)
          if(actual<=potential_transpiration)exit
          j=maxloc(candidate_sink,dim=1)
          value=candidate_sink(j)-(actual-potential_transpiration)
          if(value>=candidate_sink(j))value=nearest(candidate_sink(j),-1.0_real64)
          if(value<0.0_real64)return
          candidate_sink(j)=value
        end do
        if(sum(candidate_sink)>potential_transpiration)return
      end if
    end if
    call publish()
    result%potential_root_sink(1:rooted_nodes)= &
         root_length_density(1:rooted_nodes)*thickness(1:rooted_nodes)/total_length*potential_transpiration
    result%root_pressure_cm=mid
    result%leaf_pressure_cm=mid+dpl
    result%reduction_factor=1.0_real64
    if(potential_transpiration>0.0_real64.and.actual>0.0_real64) &
         result%reduction_factor=min(1.0_real64,actual/potential_transpiration)

  contains

    subroutine publish()
      allocate(result%root_extraction_sink(n),result%potential_root_sink(n))
      result%root_extraction_sink=candidate_sink
      result%potential_root_sink=0.0_real64
      result%actual_uptake_total=sum(candidate_sink)
      result%status=MICRO_DW_OK
    end subroutine

    real(real64) function reduced_transpiration(root_pressure) result(reduced)
      real(real64), intent(in) :: root_pressure
      real(real64) :: hrel
      hrel=(root_pressure+dpl)/parameters%half_leaf_pressure_cm
      if(parameters%reduction_mode==1) then
        if(hrel<0.0_real64) then
          reduced=potential_transpiration
        else
          reduced=potential_transpiration/(1.0_real64+hrel**parameters%campbell_exponent)
        end if
      else
        if(hrel<1.0_real64) then
          reduced=potential_transpiration
        else if(hrel>1.0_real64) then
          reduced=0.0_real64
        else
          reduced=sum(q*(root_pressure-x))
        end if
      end if
    end function

    subroutine residual(root_pressure, value_out, converged, enforce_balance)
      real(real64), intent(in) :: root_pressure
      real(real64), intent(out) :: value_out
      logical, intent(out) :: converged
      logical, intent(in), optional :: enforce_balance
      real(real64) :: mflux,kcond,b,err,water_total,leaf_total,independent_soil_total
      logical :: balance_required
      integer :: iteration, i, lookup_status
      converged=.false.
      value_out=0.0_real64
      balance_required=.false.
      if(present(enforce_balance))balance_required=enforce_balance
      x=pav
      do iteration=1,parameters%max_iterations
        delta=0.0_real64
        do i=1,m
          call evaluate_micro_matric_flux_table(tables(node_of(i)),-x(i),mflux,kcond,lookup_status)
          if(lookup_status/=MICRO_TABLE_OK) return
          if(mflux>phiav(i).or.x(i)>root_pressure) then
            x(i)=root_pressure
          else
            b=q(i)*(root_pressure-x(i))-s(i)*(phiav(i)-mflux)
            delta(i)=b/(q(i)+s(i)*kcond)
          end if
        end do
        x=x+delta
        err=sum(abs(delta))
        if(.not.ieee_is_finite(err).or.any(.not.ieee_is_finite(x))) return
        if(err<=parameters%newton_tolerance_cm) then
          if(.not.balance_required)exit
          water_total=sum(q*(root_pressure-x))
          independent_soil_total=0.0_real64
          do i=1,m
            call evaluate_micro_matric_flux_table(tables(node_of(i)),-x(i),mflux,kcond,lookup_status)
            if(lookup_status/=MICRO_TABLE_OK)return
            independent_soil_total=independent_soil_total+s(i)*max(0.0_real64,phiav(i)-mflux)
          end do
          if(.not.ieee_is_finite(water_total).or..not.ieee_is_finite(independent_soil_total))return
          if(water_total<=0.0_real64)exit
          if(abs(water_total-independent_soil_total)/water_total<=0.01_real64)exit
        end if
      end do
      if(iteration>parameters%max_iterations) return
      leaf_total=reduced_transpiration(root_pressure)
      water_total=sum(q*(root_pressure-x))
      if(.not.ieee_is_finite(leaf_total).or..not.ieee_is_finite(water_total)) return
      if(leaf_total>0.0_real64) then
        value_out=water_total-leaf_total
      else
        do i=1,m
          call evaluate_micro_matric_flux_table(tables(node_of(i)),-x(i),mflux,kcond,lookup_status)
          if(lookup_status/=MICRO_TABLE_OK) return
          water_total=water_total-s(i)*(phiav(i)-mflux)
        end do
        value_out=water_total
      end if
      converged=ieee_is_finite(value_out)
    end subroutine
  end subroutine

  pure logical function valid_parameters(p) result(valid)
    class(micro_de_willigen_parameters_t), intent(in) :: p
    valid=.false.
    if(.not.ieee_is_finite(p%root_radius_cm).or.p%root_radius_cm<=0.0_real64) return
    if(.not.ieee_is_finite(p%root_conductance_cm_per_day).or.p%root_conductance_cm_per_day<=0.0_real64) return
    if(.not.ieee_is_finite(p%stem_a0_per_day).or.p%stem_a0_per_day<=0.0_real64) return
    if(.not.ieee_is_finite(p%stem_a1_per_cm).or.p%stem_a1_per_cm<0.0_real64) return
    if(.not.ieee_is_finite(p%half_leaf_pressure_cm).or.p%half_leaf_pressure_cm<=0.0_real64) return
    if(.not.ieee_is_finite(p%campbell_exponent).or.p%campbell_exponent<=0.0_real64) return
    if(.not.ieee_is_finite(p%pressure_tolerance_cm).or.p%pressure_tolerance_cm<=0.0_real64) return
    if(.not.ieee_is_finite(p%newton_tolerance_cm).or.p%newton_tolerance_cm<=0.0_real64) return
    if(.not.ieee_is_finite(p%residual_tolerance_cm_per_day).or.p%residual_tolerance_cm_per_day<=0.0_real64) return
    if(p%max_iterations<=0.or.p%oxygen_mode<0.or.p%oxygen_mode>2) return
    if(p%reduction_mode/=1.and.p%reduction_mode/=2) return
    valid=.true.
  end function
end module
