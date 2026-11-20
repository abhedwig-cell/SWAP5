! Verification-only early entry inside the complete original HeadCalc.
! Calls its actual vector_F/jacobian_F and the actual original Boundtop.
subroutine frost_boundary_probe()
  use MOD_grid,only:numlay,layer
  use MOD_swap_base,only:swfrost,swrunon
  use MOD_MvG,only:swsophy,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power, &
      set_cofgen_pointers,calc_cofgen_extra
  use MOD_meteo,only:peva,empreva,epond
  use variables,only:indeks,ksatfit,ksatexm,fluseksatexm,swredu,pondmx
  implicit none
  real(8),parameter::reductions(4)=[0d0,0.01d0,0.5d0,1d0]
  real(8),parameter::heads(3)=[-10d0,-30d0,-100d0]
  real(8)::baseline(3),delta,minus,plus,analytic,approximation,error,scale
  real(8)::matrix(3,3),left_vector(3),right_vector(3),difference(3)
  integer::curve,mean,reduction,headindex,cases,node,column,row,mode,examined
  NN=3;numnod=3;numlay=1;layer(1:4)=1;swfrost=1;swmacro=0;swrunon=0
  swsophy=0;iHWCKmodel=1;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
  swkimpl=1;swbotb=6;swredu=0;dt=0.01d0;pondmx=1000d0
  dz(1:4)=[10d0,20d0,30d0,30d0];disnod(1:4)=[5d0,15d0,25d0,15d0]
  z(1:4)=[-5d0,-20d0,-45d0,-75d0]
  FrArMtrx=1d0;ArMpSs=0d0;sink=0d0;source=0d0;qrot=0d0
  nraidt=0d0;nird=0d0;melt=0d0;peva=0d0;empreva=0d0;epond=0d0
  qbot=0d0;fllowgwl=.false.;cofgen=0d0
  do node=1,4
    cofgen(1:12,node)=[0.02d0,0.43d0,83.2d0,0.02d0,0.5d0,1.5d0, &
        0.33333333333333337d0,0.04d0,0d0,-999d0,0d0,0d0]
  end do
  ksatfit(1:4)=83.2d0;ksatexm(1:4)=83.2d0;fluseksatexm=.false.
  call set_cofgen_pointers
  cases=0
  do curve=-1,1,2
    indeks(1:4)=curve
    do node=1,4
      call calc_cofgen_extra(node)
    end do
    call boundtop(1)
    do mean=1,6
      swkmean=mean
      do reduction=1,size(reductions)
        rfcp(1:4)=reductions(reduction)
        do headindex=1,3
        do mode=1,5
        do examined=0,0
          fluseksatexm=examined==1
          baseline=[heads(headindex),-40d0,-60d0]
          h(1:3)=baseline
          do node=1,3
            thetm1(node)=watcon(node,h(node))
          end do
          call frost_probe_evaluate(mode)
          if(mode==1.and.ftoph)then
            write(*,*)'DRY_BOUNDARY_OBSERVATION',cases+1,mode,examined,h(1),rfcp(1),pondm1,pond,hsurf,q0,qtop,peva,epd
            error stop 'Actual dry flux boundary absent'
          end if
          if(mode>1.and.(.not.ftoph.or.hsurf<=0d0))error stop 'Actual ponded boundary absent'
          if(mode==2.and.runots/=0d0)error stop 'Actual no-runoff boundary absent'
          if(mode>2.and.runots<=0d0)error stop 'Actual runoff boundary absent'
          call jacobian_F()
          analytic=dFdhM(1)
          matrix=0d0
          do node=1,3
            matrix(node,node)=dFdhM(node)
            if(node>1)matrix(node,node-1)=dFdhU(node)
            if(node<3)matrix(node,node+1)=dFdhL(node)
          end do
          delta=abs(h(1))*1d-5
          h(1:3)=baseline;h(1)=h(1)-delta
          call frost_probe_evaluate(mode);minus=F(1)
          h(1:3)=baseline;h(1)=h(1)+delta
          call frost_probe_evaluate(mode);plus=F(1)
          approximation=(plus-minus)/(2d0*delta)
          error=abs(analytic-approximation)
          scale=max(abs(analytic),abs(approximation),1d-8)
          cases=cases+1
          write(*,'(a,6(1x,i0),7(1x,es25.17e3))')'ACTUAL_FROST_BOUNDARY', &
              cases,curve,mean,headindex,mode,examined,reductions(reduction),baseline(1),analytic,approximation,error,scale,error/scale
          do column=1,3
            delta=abs(baseline(column))*1d-5
            h(1:3)=baseline;h(column)=h(column)-delta
            call frost_probe_evaluate(mode);left_vector=F(1:3)
            h(1:3)=baseline;h(column)=h(column)+delta
            call frost_probe_evaluate(mode);right_vector=F(1:3)
            difference=(right_vector-left_vector)/(2d0*delta)
            do row=1,3
              error=abs(matrix(row,column)-difference(row))
              scale=max(abs(matrix(row,column)),abs(difference(row)),1d-8)
              write(*,'(a,3(1x,i0),5(1x,es25.17e3))')'ACTUAL_FROST_MATRIX', &
                  cases,row,column,matrix(row,column),difference(row),error,scale,error/scale
            end do
          end do
        end do
        end do
        end do
      end do
    end do
  end do
  if(cases/=720)error stop 'Actual boundary probe denominator changed'
end subroutine

subroutine frost_probe_evaluate(mode)
  use variables,only:pondmx,rsro,rsroexp
  implicit none
  integer,intent(in)::mode
  integer::node
  pondm1=30d0;pondmx=0.1d0;rsro=0.5d0;rsroexp=1d0
  if(mode==1)then
    pondm1=0d0;pondmx=1000d0
  else if(mode==2)then
    pondmx=1000d0
  else if(mode==4)then
    rsroexp=2d0
  else if(mode==5)then
    rsro=1d-4;rsroexp=2d0
  end if
  pond=0d0;runots=0d0;flunsatok=.true.;flboth=.false.
  do node=1,NN
    theta(node)=watcon(node,h(node))
    dimoca(node)=moiscap(node,h(node))
    k(node)=hconduc(node,h(node),theta(node),rfcp(node))
    dkdh(node)=dhconduc(node,h(node),theta(node),dimoca(node),rfcp(node))
  end do
  dFdhU=0d0;dFdhL=0d0;dFdhM=0d0
  do node=2,NN
    kmean(node)=hcomean(swkmean,k(node-1),k(node),dz(node-1),dz(node),node,h(node-1),h(node))
    hgrad(node)=(h(node-1)-h(node))/disnod(node)+1d0
    dFdhU(node)=-kmean(node)/disnod(node)
    dFdhL(node-1)=dFdhU(node)
  end do
  call vector_F(1,hgrad)
end subroutine
