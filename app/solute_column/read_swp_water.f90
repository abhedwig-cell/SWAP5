! File adapter only. No hydraulic equations or accepted state live here.
module mod_column_swp_water
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: import_column_swp_water, initialize_column_hydrostatic_water
contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if (.not.ok) then
      print '(A)','SWP_WATER_REJECTED: '//message
      error stop 1
    end if
  end subroutine

  subroutine initialize_column_hydrostatic_water(width,gwli,bottom_mode,heads,source_pond)
    real(real64),intent(in)::width(:),gwli
    integer,intent(in)::bottom_mode
    real(real64),allocatable,intent(out)::heads(:)
    real(real64),intent(out)::source_pond
    real(real64)::depth,z
    integer::i,n
    n=size(width)
    call require(n>=2.and.n<=256,'hydrostatic node capacity')
    call require(all(ieee_is_finite(width)).and.all(width>0d0),'invalid hydrostatic grid')
    call require(ieee_is_finite(gwli),'nonfinite GWLI')
    call require(gwli>=-10000d0.and.gwli<=1000d0,'GWLI outside original input domain')
    call require(bottom_mode>=2.and.bottom_mode<=8,'hydrostatic bottom mode not selected')
    allocate(heads(n));depth=0d0
    do i=1,n
      z=-(depth+.5d0*width(i));depth=depth+width(i)
      heads(i)=gwli-z
    end do
    if(bottom_mode/=8)call require(abs(gwli-(z-.5d0*width(n)))>=1d-4, &
      'initial groundwater level too close to column bottom')
    source_pond=max(gwli,0d0)
  end subroutine initialize_column_hydrostatic_water

  subroutine import_column_swp_water(path,nodes,width,heads,cofgen,source_pond,initial_bottom_mode,source_groundwater)
    character(*),intent(in)::path
    integer,intent(out)::nodes
    real(real64),intent(out)::width(:)
    real(real64),allocatable,intent(out)::heads(:),cofgen(:,:)
    real(real64),optional,intent(out)::source_pond
    integer,optional,intent(in)::initial_bottom_mode
    real(real64),optional,intent(out)::source_groundwater
    integer::nsub,nlay,i,j,k,mode,nhead,pos,initial_mode,bottom_mode
    integer::ids(256),layers(256),counts(256),models(256)
    real(real64)::height(256),ores(256),osat(256),alfa(256),npar(256),lexp(256),ksat(256),entry(256)
    real(real64),allocatable::htb(:)
    real(real64)::depth,z,gwli
    logical::rdinqr,rdinar
    call rdinit(73,0,trim(path))
    ! Extensions need their own physical owner; never silently downgrade them.
    if(present(source_pond))source_pond=-1d0
    if(present(source_groundwater))source_groundwater=-2d0
    call rdsinr('swinco',1,3,initial_mode)
    call require(initial_mode/=3,'loose historical restart not selected')
    if(initial_mode==2)then
      call require(present(source_pond),'SWINCO2 requires source pond ownership')
      if(rdinqr('swbotb'))then
        call rdsinr('swbotb',1,8,bottom_mode)
        if(present(initial_bottom_mode))call require(bottom_mode==initial_bottom_mode, &
          'conflicting initial bottom mode')
      else
        call require(present(initial_bottom_mode),'external BBC mode must be resolved by caller')
        bottom_mode=initial_bottom_mode
        call require(bottom_mode>=1.and.bottom_mode<=8,'invalid resolved bottom mode')
      end if
      call require(bottom_mode/=1,'SWBOTB1 time-table initialization excluded')
      call rdsdor('gwli',-10000d0,1000d0,gwli)
      call require(ieee_is_finite(gwli),'nonfinite GWLI')
      if(present(source_groundwater))source_groundwater=gwli
    end if
    call rdsinr('swhyst',0,2,mode);call require(mode==0,'hysteresis not selected')
    if(rdinqr('swsophy'))then
      call rdsinr('swsophy',-1,1,mode);call require(mode==0,'hydraulic tables not selected')
    end if
    call require(.not.rdinqr('swap_soils_db'),'external soil database not selected')
    call require(.not.rdinqr('ksatexm'),'KSATEXM extension not selected')
    call require(.not.rdinqr('h_power'),'conductivity power tail not selected')
    call require(.not.rdinqr('elas'),'elastic storage not selected')
    call rdinne('isublay',nsub)
    call require(nsub>=1.and.nsub<=256,'sublayer count')
    call rdfinr('isublay',1,256,ids,256,nsub)
    call rdfinr('isoillay',1,256,layers,256,nsub)
    call rdfinr('ncomp',1,256,counts,256,nsub)
    call rdfdor('hsublay',1d-4,1d4,height,256,nsub)
    call require(all(ids(:nsub)==[(i,i=1,nsub)]),'ordered sublayer identities')
    nodes=sum(counts(:nsub));nlay=maxval(layers(:nsub))
    call require(nodes>=2.and.nodes<=size(width),'node count outside application capacity')
    do i=1,nlay
      call require(any(layers(:nsub)==i),'soil-layer identity gap')
    end do
    models=1
    if(rdinqr('ihwckmodel'))then
      if(rdinar('ihwckmodel'))then
        call rdfinr('ihwckmodel',1,12,models,256,nlay)
      else
        call rdsinr('ihwckmodel',1,12,mode);models=mode
      end if
    end if
    call require(all(models(:nlay)==1),'only default unimodal MvG selected')
    ! Original readswap.f90 ranges and KSATFIT/KSAT fallback, via original TTUTIL.
    call rdfdor('ores',0d0,1d0,ores,256,nlay)
    call rdfdor('osat',0d0,1d0,osat,256,nlay)
    call rdfdor('alfa',1d-4,100d0,alfa,256,nlay)
    call rdfdor('npar',1.001d0,9d0,npar,256,nlay)
    call rdfdor('lexp',-25d0,50d0,lexp,256,nlay)
    call rdfdor('h_enpr',-40d0,0d0,entry,256,nlay)
    if(rdinqr('ksatfit'))then
      call rdfdor('ksatfit',1d-5,1d5,ksat,256,nlay)
    else
      call rdfdor('ksat',1d-5,1d5,ksat,256,nlay)
    end if
    call require(all(osat(:nlay)>ores(:nlay)),'invalid retention limits')
    ! Keep the current application's numerical envelope rather than broadening it.
    call require(all(alfa(:nlay)<=1d0).and.all(npar(:nlay)<=5d0).and. &
      all(abs(lexp(:nlay))<=10d0).and.all(ksat(:nlay)<=1d4),'hydraulics outside application envelope')
    if(initial_mode==1)then
    call require(.not.rdinqr('h'),'deprecated ZI/H needs separate qualification')
    call rdinne('htb',nhead)
    call require(nhead>=4.and.mod(nhead,2)==0.and.nhead<=512,'HTB table size')
    allocate(htb(nhead));htb=0d0
    call rdadortb('htb',-1d5,0d0,-1d10,1d4,htb,nhead,.true.)
    call require(all(ieee_is_finite(htb)),'nonfinite HTB')
    call require(all(htb(3:nhead:2)>htb(1:nhead-2:2)),'HTB depths must increase after absolute-depth conversion')
    ! Saturated reconstruction and pond initialization belong to a later contract.
    call require(all(htb(2:nhead:2)<-1d-5).and.all(htb(2:nhead:2)>=-1d6),'only unsaturated HTB selected')
    end if
    close(73)
    allocate(heads(nodes),cofgen(24,nodes));cofgen=0d0;width=0d0
    k=0;depth=0d0;pos=0
    do i=1,nsub
      j=layers(i)
      do mode=1,counts(i)
        k=k+1;width(k)=height(i)/counts(i);z=-(depth+0.5d0*width(k));depth=depth+width(k)
        if(initial_mode==1)then
          call afgen_2(htb,nhead,abs(z),heads(k),pos)
        end if
        cofgen(1:6,k)=[ores(j),osat(j),ksat(j),alfa(j),lexp(j),npar(j)]
        cofgen(7,k)=1d0-1d0/npar(j);cofgen(8,k)=alfa(j);cofgen(9,k)=entry(j)
        cofgen(10,k)=-999d0;cofgen(14,k)=1d0;cofgen(16,k)=1d0;cofgen(21,k)=0.1d0
      end do
    end do
    if(initial_mode==2)call initialize_column_hydrostatic_water(width(:nodes),gwli,bottom_mode,heads,source_pond)
    print '(A)','SWP_NATIVE_WATER_BOOTSTRAP_IMPORTED'
  end subroutine
end module
