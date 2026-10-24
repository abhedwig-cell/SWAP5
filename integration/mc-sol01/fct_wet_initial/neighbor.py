"""Source-generate a bounded representable-head search, no guard relaxation."""
def transform(text):
 anchor='      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.'
 assert text.count(anchor)==1
 refresh='''
              call evaluation_context%constitutive%evaluate(state%h(1:numnod),fsi_ws%provider_theta, &
                fsi_ws%provider_k,fsi_ws%provider_capacity,fsi_ws%provider_dkdh)
              state%theta(1:NN)=fsi_ws%provider_theta(1:NN)
              do neighbor_j=2,NN
                fsi_ws%head_gradient(neighbor_j)=(state%h(neighbor_j-1)-state%h(neighbor_j))/grid_disnod(neighbor_j)+1d0
              end do
              call vector_F(2)
'''
 body='''
      if(.not.flnonconv.and.abs(sum1)>CritDevBalTot.and.provider_constitutive_active.and. &
        swmacro==0.and..not.picard_conductivity_iteration.and.NN==numnod.and. &
        .not.provider_macropore_rate_active.and. &
        maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN)))==0d0)then
        block
          type(reference_richards_state_binding_t)::neighbor_entry,neighbor_best
          real(8)::neighbor_score,neighbor_value,neighbor_pond_error
          integer::neighbor_i,neighbor_j,neighbor_sign,neighbor_step
          neighbor_entry=state;neighbor_best=state;neighbor_score=abs(sum1)
          do neighbor_i=2,NN-1
            do neighbor_sign=-1,1,2
              do neighbor_step=1,8
                state=neighbor_entry
                do neighbor_j=1,neighbor_step
                  state%h(neighbor_i)=nearest(state%h(neighbor_i),real(neighbor_sign,8))
                end do
'''+refresh+'''
                neighbor_value=sum(fsi_ws%residual(1:NN))
                neighbor_pond_error=state%pond-state%pondm1-provider_dynamic_top_result%net_potential_surface_flux*dt+ &
                  state%runots-state%qtop*dt
                if(abs(neighbor_value)<neighbor_score.and.maxval(abs(fsi_ws%residual(1:NN)))<=CritDevBalCp.and. &
                  abs(neighbor_pond_error)<=CritDevPondDt.and. &
                  maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))/max(abs(fsi_ws%old_head(1:NN)),1d0))<=CritDevh1Cp)then
                  neighbor_best=state;neighbor_score=abs(neighbor_value)
                end if
              end do
            end do
          end do
          state=neighbor_best
'''+refresh+'''
          sum1=sum(fsi_ws%residual(1:NN))
          provider_tuple_valid=.true.;provider_tuple_from_candidate=.true.
          write(*,*)'TRACE_NEIGHBOR',neighbor_score,CritDevBalTot,sum1*dt
        end block
      end if
'''
 return text.replace(anchor,body+anchor)
