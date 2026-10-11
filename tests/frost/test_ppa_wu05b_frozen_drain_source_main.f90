program source_probe
  use MOD_frost
  use MOD_drain
  use variables
  implicit none
  real(8)::node_out,reported_out
  nodfrostbot=2;zfrostbot=-2.d0;rfcp=0.d0
  qdra(1,4)=.1d0;qdrain(1)=sum(qdra(1,:))
  call FrozenBounds
  node_out=sum(qdra)-qbot
  reported_out=qdrtot-qbot
  if(abs(qdrain(1)-.09d0)>1.d-14)error stop 'source level result changed'
  if(abs(sum(qdra)-.1d0)>1.d-14)error stop 'source node result changed'
  if(abs(node_out-reported_out-.01d0)>1.d-14)error stop 'independent ledger discrepancy oracle'
  print '(A,F10.6)','FROZEN_DRAIN_NODE_MINUS_LEVEL_CM_DAY=',node_out-reported_out
  print '(A)','PPA-WU05B_FROZEN_DRAIN_SOURCE_MISMATCH_REPRODUCED=PASS'
end program
