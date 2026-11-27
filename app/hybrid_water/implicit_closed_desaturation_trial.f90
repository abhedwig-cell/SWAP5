   subroutine closed_desaturation_trial()
      real(8)::initial_head(macp),lower,upper,middle,left_value,right_value,value,shift,direction
      integer::trial,node
      initial_head(1:NN)=h(1:NN)
      lower=0d0
      direction=sign(1d0,sum(F(1:NN)))
      left_value=direction*sum(F(1:NN))
      upper=maxval(abs(initial_head(1:NN)))
      if(upper<=0d0)return
      do trial=1,MaxIt1
         shift=upper
      h(1:NN)=initial_head(1:NN)-direction*shift
      do node=1,NN
         theta(node)=watcon(node,h(node))
      end do
      do node=2,NN
         hgrad(node)=(h(node-1)-h(node))/disnod(node)+1d0
      end do
      call RootExtraction(2)
      do node=1,NN
         k(node)=hconduc(node,h(node),theta(node),rfcp(node))
         if(node>1)kmean(node)=hcomean(swkmean,k(node-1),k(node),dz(node-1),dz(node),node,h(node-1),h(node))
      end do
      kmean(NN+1)=k(NN)
      call vector_F(2,hgrad)
      value=direction*sum(F(1:NN))
         if(.not.ieee_is_finite(value))exit
         if(value<0d0)goto 100
         upper=2d0*upper
         if(.not.ieee_is_finite(upper))exit
      end do
      shift=0d0
      h(1:NN)=initial_head(1:NN)-direction*shift
      do node=1,NN
         theta(node)=watcon(node,h(node))
      end do
      do node=2,NN
         hgrad(node)=(h(node-1)-h(node))/disnod(node)+1d0
      end do
      call RootExtraction(2)
      do node=1,NN
         k(node)=hconduc(node,h(node),theta(node),rfcp(node))
         if(node>1)kmean(node)=hcomean(swkmean,k(node-1),k(node),dz(node-1),dz(node),node,h(node-1),h(node))
      end do
      kmean(NN+1)=k(NN)
      call vector_F(2,hgrad)
      value=direction*sum(F(1:NN))
      return
100   right_value=value
      do trial=1,MaxIt1
         middle=0.5d0*lower+0.5d0*upper
         if(middle==lower.or.middle==upper)exit
         shift=middle
      h(1:NN)=initial_head(1:NN)-direction*shift
      do node=1,NN
         theta(node)=watcon(node,h(node))
      end do
      do node=2,NN
         hgrad(node)=(h(node-1)-h(node))/disnod(node)+1d0
      end do
      call RootExtraction(2)
      do node=1,NN
         k(node)=hconduc(node,h(node),theta(node),rfcp(node))
         if(node>1)kmean(node)=hcomean(swkmean,k(node-1),k(node),dz(node-1),dz(node),node,h(node-1),h(node))
      end do
      kmean(NN+1)=k(NN)
      call vector_F(2,hgrad)
      value=direction*sum(F(1:NN))
         if(.not.ieee_is_finite(value))exit
         if(value>0d0)then
            lower=middle
            left_value=value
         else
            upper=middle
            right_value=value
         end if
      end do
      shift=upper
      if(abs(left_value)<abs(right_value))shift=lower
      h(1:NN)=initial_head(1:NN)-direction*shift
      do node=1,NN
         theta(node)=watcon(node,h(node))
      end do
      do node=2,NN
         hgrad(node)=(h(node-1)-h(node))/disnod(node)+1d0
      end do
      call RootExtraction(2)
      do node=1,NN
         k(node)=hconduc(node,h(node),theta(node),rfcp(node))
         if(node>1)kmean(node)=hcomean(swkmean,k(node-1),k(node),dz(node-1),dz(node),node,h(node-1),h(node))
      end do
      kmean(NN+1)=k(NN)
      call vector_F(2,hgrad)
      value=direction*sum(F(1:NN))
   end subroutine closed_desaturation_trial
