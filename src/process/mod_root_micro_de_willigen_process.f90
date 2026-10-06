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
  end type
  type, public :: micro_de_willigen_result_t
    real(real64), allocatable :: root_extraction_sink(:), potential_root_sink(:)
    real(real64) :: actual_uptake_total=0.0_real64, root_pressure_cm=0.0_real64
    real(real64) :: leaf_pressure_cm=0.0_real64, reduction_factor=0.0_real64
    integer :: status=MICRO_DW_INVALID
  end type
  public :: evaluate_micro_de_willigen

contains

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
    real(real64) :: sumq, lo, hi, mid, flo, fhi, fm, actual, value, soil_total
    integer :: n, j, m, active_count, iteration, table_status
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
    call residual(mid,fm,ok)
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
        result%status=MICRO_DW_NO_CONVERGENCE
        return
      end if
      if(actual>potential_transpiration) candidate_sink=candidate_sink*(potential_transpiration/actual)
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

    subroutine residual(root_pressure, value_out, converged)
      real(real64), intent(in) :: root_pressure
      real(real64), intent(out) :: value_out
      logical, intent(out) :: converged
      real(real64) :: mflux,kcond,b,err,water_total,leaf_total
      integer :: iteration, i, lookup_status
      converged=.false.
      value_out=0.0_real64
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
        if(err<=parameters%newton_tolerance_cm) exit
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
    type(micro_de_willigen_parameters_t), intent(in) :: p
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
