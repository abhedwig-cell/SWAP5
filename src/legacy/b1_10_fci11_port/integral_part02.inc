   real(8),                       save ::   iqtdo,iqtup         ! Intermediate amount of water flow through top of simulated soil column (L)
   
   real(8),                       save ::   igrai               ! Intermediate amount of gross rainfall (L)
   real(8),                       save ::   inrai               ! Intermediate amount of net precipitation (L)
   real(8),                       save ::   igird               ! Intermediate depth of gross irrigation (L)
   real(8),                       save ::   inird               ! Intermediate depth of net irrigation (L)
  
!  Balance period (e.g. year) cumulative amounts; output, used in outbal, outblc
   
   real(8),                       save ::   cgrai               ! Cumulative amount of gross precipitation (L)
   real(8),                       save ::   cnrai               ! Cumulative amount of net precipitation (L)
   real(8),                       save ::   caintc              ! Cumulative amount of rainfall interception (L)
   real(8),                       save ::   cqrot               ! Cumulative amount of extracted water by roots (L)
   real(8),                       save ::   cqbot               ! Cumulative amount of water flow through bottom of simulated soil column (L)
   real(8),                       save ::   cqbotdo             ! Cumulative amount of water (L) passed through the soil column bottom in downward direction
   real(8),                       save ::   cqbotup             ! Cumulative amount of water (L) passed through the soil column bottom in upward direction
   real(8),                       save ::   cqssdi              ! Cumulative amount of subsurface drip irrigation (L)
   real(8),                       save ::   cqtdo               ! Cumulative amount of water (L) passed through the soil surface in downward direction
   real(8),                       save ::   cqtup               ! Cumulative amount of water (L) passed through the soil surface in upward direction
   real(8),                       save ::   crunoff             ! Cumulative runoff (L)
   real(8),                       save ::   crunon              ! Cumulative amount of runon (L)
   real(8),                       save ::   cevap               ! Cumulative amount of actual soil evaporation (L)
   real(8),                       save ::   cepd                ! Cumulative amount of ponding evaporation (L)
   real(8),                       save ::   cpeva               ! Cumulative amount of potential soil evaporation (L)
   real(8),                       save ::   cptra               ! Cumulative amount of potential transpiration (L)
   real(8),                       save ::   cinund              ! Cumulative amount of inundation (L)
   real(8),                       save ::   cqprai              ! Cumulative amount of net rain (L)
   real(8),                       save ::   cgird               ! Cumulative amount of gross irrigation (L)
   real(8),                       save ::   cnird               ! Cumulative amount of net irrigation (L)

   ! for drainage and/or surfacewater
   real(8),                       save ::   cqdra              ! Cumulative amount of lateral drainage (L)
   real(8), dimension(madr),      save ::   cqdrain            ! Cumulative amount of lateral drainage for each drainage level (L)
