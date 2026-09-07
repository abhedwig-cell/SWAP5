      inrai  = inrai + nraidt*dt
      inird  = inird + nird*dt
      iqbot  = iqbot + qbotts
      if (qbotts < 0.0d0) then
         iqbdo = iqbdo - qbotts
      else if (qbotts > 0.0d0) then
         iqbup = iqbup + qbotts
      end if
      if (q(1) < 0.0d0) then
         iqtdo = iqtdo - q(1)*dt
      else
         iqtup = iqtup + q(1)*dt
      end if
      do node = 1, numnod+1
         if (q(node) < 0.0d0) then
            iqdo(node) = iqdo(node) - q(node)*dt
         else
            iqup(node) = iqup(node) + q(node)*dt
         end if
      end do

!      iQMaPo = iQMaPo +QMaPo*dt
! --- add time step fluxes to total cumulative values
      cqssdi = cqssdi + qssdisum*dt
      cqrot = cqrot + qrotts
      cqdra = cqdra + qdrats
      cptra = cptra + ptrats
      cepd = cepd + epdts
      cpeva = cpeva + pevats
      cevap = cevap + revats
      if (runots < 0.0d0) then
         cinund = cinund - runots
      else if (runots > 0.0d0) then
         crunoff = crunoff + runots
      end if

      if (sw_inter /= 3) then
         caintc  = caintc + aintcdt * dt
      else
         caintc  = caintc + crsflx_out * dt
      end if

      cgrai  = cgrai + graidt*dt
      cnrai  = cnrai + nraidt*dt
!      cnrai  = cgrai - caintc
      cgird  = cgird + gird*dt
      cnird  = cnird + nird*dt

      if (qbotts < 0.0d0) then
         cqbotdo = cqbotdo - qbotts
      else if (qbotts > 0.0d0) then
         cqbotup = cqbotup + qbotts
      end if
      cqbot = cqbot + qbotts

      ! rain on the ponding surface
      cqprai = cqprai + nraidt*dt    
      crunon = crunon + runon*dt     
      if (q(1) < 0.0d0) then
         cqtdo = cqtdo - q(1)*dt
      else if (q(1) > 0.0d0) then
         cqtup = cqtup + q(1)*dt
      end if

!     drainage
      if (swdra > 0) then
         iqdra = iqdra + qdrats 
         do node = 1, numnod
            do level = 1, nrlevs
               inqdra(level,node) = inqdra(level,node)+qdra(level,node)*dt
               if (qdra(level,node) > 0.0d0) then
                  inqdra_out(level,node) = inqdra_out(level,node) + qdra(level,node)*dt
               else
                  inqdra_in(level,node)  = inqdra_in(level,node) - qdra(level,node)*dt
               end if
            end do
         end do
         do level = 1,nrlevs
            ! infiltration
            if (qdrain(level) < 0.0d0) then
               cqdrainin(level) = cqdrainin(level) - qdrain(level)*dt
            ! drainage
            else if (qdrain(level) > 0.0d0) then
               cqdrainout(level) = cqdrainout(level) + qdrain(level)*dt
            end if      
            cqdrain(level) = cqdrain(level) + qdrain(level)*dt
         end do
      end if

   ! snow
      if (swsnow == 1) then
         cgsnow = cgsnow + gsnow*dt
         csubl  = csubl  + subl*dt
         cmelt  = cmelt  + melt*dt
         csnrai = csnrai + snrai*dt
         igsnow = igsnow + gsnow*dt
         isubl  = isubl  + subl*dt
         isnrai = isnrai + snrai*dt
      end if
      
      ! interception canopy reservoir
      isintc = isintc  + (crsflx_in - crsflx_out) * dt
      sicact = min(max(0.d0, sicact + (crsflx_in - crsflx_out) * dt), siccap)

   case (4)  ! perform integrations after update crop development
      
      ! interception canopy reservoir
      if (present(trial_mass)) call record_b1_10_trial_interception_loss(trial_mass, siccaploss)
      iintc  = iintc + siccaploss
      caintc = caintc + siccaploss
      isintc = isintc - siccaploss
      siccaploss = 0.d0
      
   case default
      call swap_error ('integral', 'Illegal value for ITASK')
   end select

   return
   end subroutine integral

end module MOD_integral
   
