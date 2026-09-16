      if (iTask == 1 .OR. fldaystart) then

          iqrot_day = 0.d0
          iqreddry_day = 0.d0
          iqredsol_day = 0.d0
          iptra_day = 0.d0
          do node = 1,numnod 
            inqpotrot_day(node) = 0.d0
            inqredrot_day(node) = 0.d0
          end do
          
          ialpwet_day = 0.d0
          ialpdry_day = 0.d0
      
      end if

      if (iTask == 1 .OR. flzerocumu) then

         cgrai   = 0.0d0
         cnrai   = 0.0d0
         cgird   = 0.0d0
         cnird   = 0.0d0
         caintc  = 0.0d0
         cqrot   = 0.0d0
         cqbot   = 0.0d0
         cqbotdo = 0.0d0
         cqbotup = 0.0d0
         cqtdo   = 0.0d0 
         cqtup   = 0.0d0
         cqssdi  = 0.0d0
         crunoff = 0.0d0
         crunon  = 0.0d0 
         cptra   = 0.0d0
         cepd    = 0.0d0
         cpeva   = 0.0d0
         cevap   = 0.0d0
         cinund  = 0.0d0
         cqprai  = 0.0d0
         if (swdra > 0) then
            cqdra = 0.0d0
            do level = 1, nrlevs
               cqdrain(level)    = 0.0d0
               cqdrainin(level)  = 0.0d0
               cqdrainout(level) = 0.0d0
           end do
         end if
         if (swsnow == 1) then
            cgsnow = 0.0d0
            csubl  = 0.0d0
            csnrai = 0.0d0
            cmelt  = 0.0d0
         end if
         
         volini   = volact
         pondini  = pond
         snowinco = ssnow
!         sicini   = sicact
         
         if (swmacro == 1) call macropore(6)
         
      end if

      if (iTask == 1 .OR. flzerointr) then

         igrai = 0.0d0
         inrai = 0.0d0
         igird = 0.0d0
         inird = 0.0d0
         do node = 1, numnod
            inqrot(node)    = 0.0d0
            inqpotrot(node) = 0.0d0
            inqredrot(node) = 0.0d0
            inqssdi(node)   = 0.0d0
            inq(node)       = 0.0d0
         end do
         inq(numnod+1)    = 0.0d0
         iqrot            = 0.0d0
         iqssdi           = 0.0d0
         iqredwet         = 0.0d0
         iqreddry         = 0.0d0
         iqredsol         = 0.0d0
         iqredfrs         = 0.0d0
         iintc            = 0.0d0
         isintc           = 0.0d0
         iptra            = 0.0d0
         iepd             = 0.0d0
         ipeva            = 0.0d0
         ievap            = 0.0d0
         iruno            = 0.0d0
         iqbot            = 0.0d0
         iqbdo            = 0.0d0
         iqbup            = 0.0d0
         iqtdo            = 0.0d0
         iqtup            = 0.0d0
         irunon           = 0.0d0
         iqdo(1:numnod+1) = 0.0d0
         iqup(1:numnod+1) = 0.0d0
         if (swdra > 0) then
            do node = 1,numnod
               do level = 1,nrlevs
                  inqdra(level,node)     = 0.0d0
                  inqdra_in(level,node)  = 0.0d0
                  inqdra_out(level,node) = 0.0d0
               end do
            end do
            iqdra = 0.0d0
         end if
         if (swsnow == 1) then
            igsnow = 0.0d0
            isubl  = 0.0d0
            isnrai = 0.0d0
         end if
         
         ipgass= 0.d0; ipgasspot= 0.d0
         igass = 0.d0; igasspot = 0.d0
         imres = 0.d0; imrespot = 0.d0
         
         ivolbeg   = volact
         ipondbeg  = pond
         issnowbeg = ssnow
         isicbeg   = sicact
         do node = 1, numnod
            ithetabeg(node) = theta(node)
         end do
