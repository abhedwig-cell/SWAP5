program test_ppa_wu05a3_satflow_task1_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_wu05a3_satflow_task1
  implicit none

  integer, parameter :: vector_count=100000, nmax=6
  real(real64), parameter :: pi_value=3.1415926535897932384626433832795_real64
  real(real64) :: h(nmax), z(nmax), dz(nmax), c_darcy(nmax), ksat(nmax), diameter(nmax), fraction(nmax), shape(nmax)
  real(real64) :: delh(nmax), signed_flux(nmax), incoming(nmax), expected_delh(nmax), expected_signed(nmax)
  real(real64) :: expected_in(nmax), total, expected_total, ref, lev, satfr, reduction, dt
  integer(int64) :: state
  integer :: i, top, matrix_bottom, domain_bottom, sat_comp, seepage, status

  state=20260923_int64
  do i=1,vector_count
    call fill_inputs(state,h,z,dz,c_darcy,ksat,diameter,fraction,shape)
    top=1+modulo(i,nmax-2)
    domain_bottom=top+modulo(i+1,nmax-top+1)
    matrix_bottom=modulo(i+2,nmax+1)
    sat_comp=modulo(i+3,nmax+1)
    seepage=modulo(i,2)
    ref=-2.0_real64+4.0_real64*next_unit(state)
    lev=-2.0_real64+4.0_real64*next_unit(state)
    satfr=next_unit(state)
    reduction=next_unit(state)
    dt=0.01_real64+next_unit(state)
    call source_task1(domain_bottom,top,matrix_bottom,sat_comp,ref,lev,h(1:nmax),z(1:nmax),dz(1:nmax), &
         satfr,c_darcy(1:nmax),seepage,ksat(1:nmax),diameter(1:nmax),fraction(1:nmax),shape(1:nmax), &
         pi_value,reduction,dt,expected_delh,expected_signed,expected_in,expected_total)
    call ppa_wu05a3_satflow_task1(domain_bottom,top,matrix_bottom,sat_comp,ref,lev,h,z,dz,satfr,c_darcy, &
         seepage,ksat,diameter,fraction,shape,pi_value,reduction,dt,delh,signed_flux,incoming,total,status)
    if(domain_bottom < top .or. matrix_bottom <= 0) then
      call require(status==PPA_WU05A3_SATFLOW_TASK1_INACTIVE,1)
    else
      call require(status==PPA_WU05A3_SATFLOW_TASK1_OK,2)
    end if
    call require(all(transfer(expected_delh,[0_int64],nmax)==transfer(delh,[0_int64],nmax)),3)
    call require(all(transfer(expected_signed,[0_int64],nmax)==transfer(signed_flux,[0_int64],nmax)),4)
    call require(all(transfer(expected_in,[0_int64],nmax)==transfer(incoming,[0_int64],nmax)),5)
    call require(transfer(expected_total,0_int64)==transfer(total,0_int64),6)
  end do

  print '(A)','PPA_WU05A3_SATFLOW_TASK1_SOURCE_ORACLE_100000=PASS'
  print '(A)','PPA_WU05A3_SATFLOW_TASK1_ACTIVE_ZONE_GATE_AND_BOUNDS=PASS'
  print '(A)','PPA_WU05A3_SATFLOW_TASK1_INCOMING_ONLY_TOTAL=PASS'

contains

  subroutine fill_inputs(random_state,heads,elevations,thickness,reciprocal,conductivity,diameters,proportions,shapes)
    integer(int64),intent(inout)::random_state
    real(real64),intent(out)::heads(:),elevations(:),thickness(:),reciprocal(:)
    real(real64),intent(out)::conductivity(:),diameters(:),proportions(:),shapes(:)
    integer::j
    do j=1,size(heads)
      heads(j)=-0.1_real64+3.0_real64*next_unit(random_state)
      elevations(j)=-2.0_real64+4.0_real64*next_unit(random_state)
      thickness(j)=0.25_real64+5.0_real64*next_unit(random_state)
      reciprocal(j)=0.01_real64+5.0_real64*next_unit(random_state)
      conductivity(j)=0.01_real64+10.0_real64*next_unit(random_state)
      diameters(j)=0.01_real64+0.5_real64*next_unit(random_state)
      proportions(j)=next_unit(random_state)
      shapes(j)=0.01_real64+2.0_real64*next_unit(random_state)
    end do
  end subroutine fill_inputs

  real(real64) function next_unit(random_state) result(value)
    integer(int64),intent(inout)::random_state
    random_state=modulo(random_state*48271_int64,2147483647_int64)
    value=real(modulo(random_state,1000000_int64),real64)/1000000.0_real64
  end function next_unit

  subroutine source_task1(bottom,first,matrix_bottom,sat_comp,ref,lev,heads,elevations,thickness,satfr,reciprocal, &
       switch,conductivity,diameters,proportions,shapes,pi,fr_reduce,delta_t,differences,signed,positive,total_in)
    integer,intent(in)::bottom,first,matrix_bottom,sat_comp,switch
    real(real64),intent(in)::ref,lev,heads(:),elevations(:),thickness(:),satfr,reciprocal(:),conductivity(:)
    real(real64),intent(in)::diameters(:),proportions(:),shapes(:),pi,fr_reduce,delta_t
    real(real64),intent(out)::differences(:),signed(:),positive(:),total_in
    real(real64)::hmp,dh,rr,rh,rv,rad
    integer::ic,last
    differences=0.0_real64;signed=0.0_real64;positive=0.0_real64;total_in=0.0_real64
    if(bottom<first.or.matrix_bottom<=0)return
    last=min(bottom,matrix_bottom)
    do ic=first,last
      hmp=ref-elevations(ic)
      if(hmp<1.0e-8_real64)hmp=0.0_real64
      dh=hmp-heads(ic)
      if(hmp<1.0e-8_real64.and.dh>0.0_real64)dh=0.0_real64
      if(abs(dh)<1.0e-8_real64)dh=0.0_real64
      if(heads(ic)<0.0_real64)dh=0.0_real64
      rr=0.0_real64
      if(dh>0.0_real64)then
        rr=reciprocal(ic)
        if(ic==sat_comp)rr=satfr*rr
        signed(ic)=-fr_reduce*rr*dh*delta_t
      else if(dh<0.0_real64)then
        if(hmp>0.0_real64)then
          rr=reciprocal(ic)
          if(ic==first)rr=rr*(lev-(elevations(ic)-0.5_real64*thickness(ic)))/thickness(ic)
        else if(switch==1)then
          rh=diameters(ic)**2/(8.0_real64*thickness(ic)*conductivity(ic))
          rv=thickness(ic)/conductivity(ic)
          rad=diameters(ic)*log(10.0_real64)/(pi*conductivity(ic))
          rr=proportions(ic)/(rh+rv+rad)
          if(ic==first)rr=rr*(lev-(elevations(ic)-0.5_real64*thickness(ic)))/thickness(ic)
        else
          rr=shapes(ic)*16.0_real64/diameters(ic)**2*conductivity(ic)*thickness(ic)
          if(ic==first)rr=rr*(lev-(elevations(ic)-0.5_real64*thickness(ic)))/thickness(ic)
        end if
        signed(ic)=-fr_reduce*rr*dh*delta_t
      end if
      differences(ic)=dh
      if(signed(ic)>0.0_real64)then
        positive(ic)=signed(ic)
        total_in=total_in+positive(ic)
      end if
    end do
  end subroutine source_task1

  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    write(*,'(A,I0)')'PPA_WU05A3_SATFLOW_TASK1_FAIL=',code
    error stop 1
  end subroutine require

end program test_ppa_wu05a3_satflow_task1_source_oracle
