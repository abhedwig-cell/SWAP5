program inf_split_contract
  use, intrinsic :: iso_fortran_env,only:real64
  use, intrinsic :: ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use MOD_grid,only:dz,zbotcp,layer,numnod
  use MOD_drain,only:nrlevs,cofani,Lspacing,qdrain,qdra,DIVDRA,swdivdinf,drainl,FacDpthInf
  use mod_process_hydraulic_view,only:process_hydraulic_view_t
  use mod_drainage_spatial_distribution,only:drainage_distribution_parameters_t
  use mod_drainage_b19_separate_infiltration_adapter
  use mod_fmr_divdra_separate_infiltration_binding
  implicit none
  type(drainage_distribution_parameters_t)::p(3),bad(3)
  type(drainage_b19_separate_infiltration_parameters_t)::control(3)
  type(fmr_divdra_separate_infiltration_binding_diagnostics_t)::b
  type(process_hydraulic_view_t)::v
  real(real64),allocatable::flux(:,:)
  real(real64)::k(8),qs(3),gw(6),rates(3,8),space(3,4),maximum,depth,offsets(3),factors(3),expected(8)
  integer::grid,g,s,w,q,h,i,j,cases,held,samecomp
  swdivdinf=1;numnod=8;maximum=0;cases=0;held=0;samecomp=0
  rates(:,1)=[.003d0,.002d0,.001d0];rates(:,2)=-rates(:,1)
  rates(:,3)=[.003d0,-.002d0,.001d0];rates(:,4)=[0.d0,-.002d0,.002d0]
  rates(:,5)=[.003d0,0.d0,0.d0];rates(:,6)=[0.d0,0.d0,-.001d0]
  rates(:,7)=0;rates(:,8)=[.003d0,-.003d0,0.d0]
  space(:,1)=[40.d0,12.d0,4.d0];space(:,2)=[4.d0,40.d0,12.d0]
  space(:,3)=[8.d0,8.d0,8.d0];space(:,4)=[.5d0,2.d0,1.d0]
  offsets=[0.d0,.05d0,.6d0];factors=[0.d0,.5d0,1.d0]
  do grid=1,3
    dz=1;cofani=1;k=2
    if(grid==2)then
      dz=[.25d0,.75d0,1.5d0,.5d0,2.d0,.25d0,1.25d0,1.5d0]
      cofani=[.4d0,3.d0];k=[1.d0,4.d0,.2d0,2.d0,8.d0,.7d0,3.d0,1.3d0]
    else if(grid==3)then
      cofani=[2.d0,.6d0];k=[.3d0,2.d0,4.d0,1.d0,.8d0,5.d0,.6d0,2.2d0]
    end if
    depth=0
    do i=1,8
      depth=depth+dz(i);zbotcp(i)=-depth
    end do
    gw=[0.d0,-.15d0,-.85d0,zbotcp(2),zbotcp(2)-2.d-10,-depth+.1d0]
    do nrlevs=1,3
    do s=1,4
      Lspacing=space(:,s)
      do i=1,3
        p(i)%active_nodes=8;p(i)%dz=dz;p(i)%zbotcp=zbotcp;p(i)%saturated_conductivity=k
        p(i)%horizontal_anisotropy_factor=cofani(layer);p(i)%drain_spacing=Lspacing(i)
      end do
      do w=1,6
      do g=1,3
      do h=1,3
        v%groundwater_level=gw(w);FacDpthInf=factors(h)
        drainl=-max(0.d0,-gw(w)-offsets(g))
        control%infiltration_depth_factor=FacDpthInf;control%drain_level_cm=drainl
        do q=1,8
          qs=rates(:,q);qdrain=qs
          if(allocated(flux))deallocate(flux)
          call fmr_bind_separate_infiltration(p(:nrlevs),v,qs(:nrlevs),control(:nrlevs),flux,b)
          ! At an exact water-node bottom and factor0, source KDsat=0: no valid saturated zone.
          if(w==4.and.h==1.and.any(qs(:nrlevs)<0.d0))then
            call check(.not.b%published.and..not.allocated(flux),'zero saturated span unavailable')
            held=held+1;cycle
          end if
          call check(b%status==FMR_DIVDRA_INF_SPLIT_OK.and.b%published,'production binding')
          call DIVDRA(k,v%groundwater_level)
          maximum=max(maximum,maxval(abs(flux-qdra(:nrlevs,:))))
          if(maxval(abs(flux-qdra(:nrlevs,:)))>=1.d-14)then
            print *,grid,nrlevs,s,w,g,h,q,maxval(abs(flux-qdra(:nrlevs,:)))
            print *,flux;print *,qdra(:nrlevs,:)
          end if
          call check(maxval(abs(flux-qdra(:nrlevs,:)))<1.d-14,'unedited corrected reference')
          call check(all(abs(sum(flux,dim=2)-qs(:nrlevs))<1.d-14),'per-level scalar')
          call check(all(b%authoritative_scalar_transfer==qs(:nrlevs)),'authoritative rates')
          if(g<=2.and.w==2.and.any(qs(:nrlevs)<0.d0))samecomp=samecomp+1
          cases=cases+1
        end do
      end do
      end do
      end do
    end do
    end do
  end do
  ! Independent equal-K integral: surface0,GWL.5,finish1, uns=sat=.5.
  nrlevs=1;v%groundwater_level=-.5d0;p(1)%drain_spacing=4;p(1)%dz=1
  p(1)%zbotcp=[(-real(i,8),i=1,8)];p(1)%saturated_conductivity=2;p(1)%horizontal_anisotropy_factor=1
  control(1)%drain_level_cm=0;control(1)%infiltration_depth_factor=.5d0;qs(1)=-.003d0
  if(allocated(flux))deallocate(flux)
  call fmr_bind_separate_infiltration(p(:1),v,qs(:1),control(:1),flux,b)
  expected=0;expected(1)=qs(1)
  call check(b%published.and.all(abs(flux(1,:)-expected)<1.d-14),'literal same-compartment integral')
  ! Exact known 2-node integral: surface0,GWL1.5,finish2, uniformK.
  v%groundwater_level=-1.5d0
  deallocate(flux)
  call fmr_bind_separate_infiltration(p(:1),v,qs(:1),control(:1),flux,b)
  expected=0;expected(1)=qs(1)/3.d0;expected(2)=qs(1)*2.d0/3.d0
  call check(b%published.and.all(abs(flux(1,:)-expected)<1.d-14),'literal unsaturated saturated integral')
  ! One-node ordinary grid is valid even though the frost wrapper requires >=2 nodes.
  numnod=1;dz=1;k=2;cofani=1;zbotcp(1)=-1;Lspacing(1)=4;drainl(1)=0;FacDpthInf=.5d0
  p(1)%active_nodes=1;p(1)%dz=[1.d0];p(1)%zbotcp=[-1.d0]
  p(1)%saturated_conductivity=[2.d0];p(1)%horizontal_anisotropy_factor=[1.d0]
  v%groundwater_level=-.5d0;qdrain(1)=qs(1)
  deallocate(flux)
  call fmr_bind_separate_infiltration(p(:1),v,qs(:1),control(:1),flux,b)
  call DIVDRA(k,v%groundwater_level)
  call check(b%published.and.abs(flux(1,1)-qdra(1,1))<1.d-14,'one-node corrected reference')
  print '(A)','INF_SPLIT_SINGLE_NODE=PASS'
  deallocate(flux);qs(1)=ieee_value(0.d0,ieee_quiet_nan)
  call fmr_bind_separate_infiltration(p(:1),v,qs(:1),control(:1),flux,b)
  call check(.not.b%published.and..not.allocated(flux),'nan unpublished')
  qs(1)=-1.d-10
  call fmr_bind_separate_infiltration(p(:1),v,qs(:1),control(:1),flux,b)
  call check(.not.b%published.and..not.allocated(flux),'tiny unpublished')
  qs(1)=-.003d0;control(1)%infiltration_depth_factor=2
  call fmr_bind_separate_infiltration(p(:1),v,qs(:1),control(:1),flux,b)
  call check(.not.b%published.and..not.allocated(flux),'invalid control unpublished')
  allocate(flux(2,2));flux=123
  call fmr_bind_separate_infiltration(p(:1),v,qs(:1),control(:1),flux,b)
  call check(b%status==FMR_DIVDRA_INF_SPLIT_TARGET_ALREADY_BOUND.and.all(flux==123),'prebound unchanged')
  print '(A,I0,A,I0,A,I0,A,ES12.4)','INF_SPLIT_SOURCE_CASES=',cases,' SAME_COMP=',samecomp,' ZERO_SAT_HELD=',held,' MAX=',maximum
  print '(A)','INF_SPLIT_SOURCE_SHARED_INTEGRAL_LITERAL_BINDER=PASS'
contains
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
