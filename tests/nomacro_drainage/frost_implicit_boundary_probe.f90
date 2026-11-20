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
  real(8),parameter::reductions(3)=[0.01d0,0.5d0,1d0]
  real(8),parameter::heads(3)=[-10d0,-30d0,-100d0]
  real(8)::baseline(3),delta,minus,plus,analytic,approximation,error,scale
  integer::curve,mean,reduction,headindex,cases,node
  NN=3;numnod=3;numlay=1;layer(1:4)=1;swfrost=1;swmacro=0;swrunon=0
  swsophy=0;iHWCKmodel=1;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
  swkimpl=1;swbotb=6;swredu=0;dt=0.1d0;pondmx=1d0
  dz(1:4)=[10d0,20d0,30d0,30d0];disnod(1:4)=[5d0,15d0,25d0,15d0]
  z(1:4)=[-5d0,-20d0,-45d0,-75d0]
  FrArMtrx=1d0;ArMpSs=0d0;sink=0d0;source=0d0;qrot=0d0
  nraidt=0d0;nird=0d0;melt=0d0;peva=1d6;empreva=1d6;epond=0d0
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
      do reduction=1,3
        rfcp(1:4)=reductions(reduction)
        do headindex=1,3
          baseline=[heads(headindex),-40d0,-60d0]
          h(1:3)=baseline
          do node=1,3
            thetm1(node)=watcon(node,h(node))
          end do
          call frost_probe_evaluate()
          if(.not.ftoph.or.hsurf>=0d0)error stop 'Actual atmospheric head boundary absent'
          call jacobian_F()
          analytic=dFdhM(1)
          delta=abs(h(1))*1d-5
          h(1:3)=baseline;h(1)=h(1)-delta
          call frost_probe_evaluate();minus=F(1)
          h(1:3)=baseline;h(1)=h(1)+delta
          call frost_probe_evaluate();plus=F(1)
          approximation=(plus-minus)/(2d0*delta)
          error=abs(analytic-approximation)
          scale=max(abs(analytic),abs(approximation),1d-8)
          cases=cases+1
          write(*,'(a,4(1x,i0),7(1x,es25.17e3))')'ACTUAL_FROST_BOUNDARY', &
              cases,curve,mean,headindex,reductions(reduction),baseline(1),analytic,approximation,error,scale,error/scale
        end do
      end do
    end do
  end do
  if(cases/=108)error stop 'Actual boundary probe denominator changed'
end subroutine

subroutine frost_probe_evaluate()
  implicit none
  integer::node
  pondm1=0d0;pond=0d0;runots=0d0;flunsatok=.true.;flboth=.false.
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
