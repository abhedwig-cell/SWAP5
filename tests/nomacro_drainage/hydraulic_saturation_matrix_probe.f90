! Verification-only entry inside complete original HeadCalc; no copied solver.
subroutine hydraulic_saturation_probe()
  use MOD_grid,only:numlay,layer
  use MOD_swap_base,only:swfrost,swhyst
  use MOD_MvG,only:swsophy,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power, &
      set_cofgen_pointers,calc_cofgen_extra
  use WC_K_models_04_11,only:BiModal,NoVap
  use variables,only:indeks,fluseksatexm
  implicit none
  real(8),parameter::steps(3)=[.125d0,.25d0,1d0]
  real(8)::matrix(3,3),heads(3),water(3),capacity(3),means(4),rhs(3)
  integer::model,mode,step_index,node,row,column,code,cases
  NN=3;numnod=3;numlay=1;layer(1:4)=1;swfrost=0;swhyst=0;swmacro=0
  swsophy=0;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
  swkimpl=0;swbotb=6;fllowgwl=.false.;flboth=.false.;fluseksatexm=.false.
  dz(1:4)=[8d0,8d0,24d0,24d0];disnod(1:4)=[4d0,8d0,16d0,12d0]
  FrArMtrx=1d0;cofgen=0d0;indeks=-1;NoVap=.true.
  do node=1,4
    cofgen(1:12,node)=[.02d0,.43d0,64d0,.02d0,.5d0,1.5d0, &
        .33333333333333337d0,.04d0,-.01d0,0d0,0d0,0d0]
    cofgen(13:21,node)=[.005d0,1.5d0,.33333333333333337d0,.8d0,.2d0,1d6,10d0,-1.5d0,.01d0]
  end do
  call set_cofgen_pointers()
  cases=0
  do model=1,11
    if(model==2)cycle
    iHWCKmodel=model;BiModal=any(model==[6,7,10,11])
    call calc_cofgen_extra(3)
    do mode=0,2
      do step_index=1,3
        dt=steps(step_index);h(1:3)=[1d0,9d0,25d0]
        if(mode==2)h(1)=-10d0
        ftoph=mode==1
        do node=1,3
          theta(node)=watcon(node,h(node));dimoca(node)=moiscap(node,h(node))
        end do
        ! Exact dyadic interface conductances isolate the original null mode.
        kmean(1:4)=64d0;dFdhU=0d0;dFdhL=0d0;dFdhM=0d0
        do node=2,3
          dFdhU(node)=-kmean(node)/disnod(node);dFdhL(node-1)=dFdhU(node)
        end do
        heads=h(1:3);water=theta(1:3);capacity=dimoca(1:3);means=kmean(1:4)
        call jacobian_F()
        if(any(heads/=h(1:3)).or.any(water/=theta(1:3)).or.any(capacity/=dimoca(1:3)).or. &
           any(means/=kmean(1:4)))error stop 'Jacobian changed original physical state'
        matrix=0d0
        do node=1,3
          matrix(node,node)=dFdhM(node)
          if(node>1)matrix(node,node-1)=dFdhU(node)
          if(node<3)matrix(node,node+1)=dFdhL(node)
        end do
        rhs=[.001d0,.002d0,.003d0];difh=0d0
        call tridag(NN,dFdhU,dFdhM,dFdhL,rhs,difh,code)
        cases=cases+1
        write(*,'(a,4(1x,i0),22(1x,es25.17e3))')'ACTUAL_SATURATED_JACOBIAN', &
          model,mode,step_index,code,dt,capacity,heads,water,reshape(matrix,[9]),difh(1:3)
      end do
    end do
  end do
  if(cases/=90)error stop 'Actual original saturation matrix denominator changed'
end subroutine
