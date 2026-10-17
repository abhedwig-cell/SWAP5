"""Select the existing actual incomplete-dispatch salt rollback discriminator."""
from pathlib import Path

def rollback(root,target):
 from salt_completion_cycle_driver import salt_cycle
 salt_cycle(root,target,3,1,'annual');s=target.read_text()
 a='    ! Original failure/retry probe is executed separately at the incumbent profile.';assert s.count(a)==1
 s=s.replace(a,'    call managed_failure_probe(tc)\n    return')
 a='    tc=tc0;tc%numerical%max_committed_substeps=1';assert s.count(a)==1
 s=s.replace(a,a+'''
    if(allocated(tc%tiles(1)%initial_state%salt))deallocate(tc%tiles(1)%initial_state%salt)
    if(allocated(tc%tiles(1)%base_forcing%c_drain_salt))deallocate(tc%tiles(1)%base_forcing%c_drain_salt)
    if(allocated(tc%tiles(1)%base_forcing%soil_salt_boundary))deallocate(tc%tiles(1)%base_forcing%soil_salt_boundary)
''')
 a='    allocation=fmr_irrigation_allocation_t(source_id=41_int64,revision=2_int64,'
 pos=s.index(a,s.index('  subroutine managed_failure_probe('))
 s=s[:pos]+'    tc%file_weather_irrigation_historical_activation=.false. ! Jan20 probe selects an actual gift.\n'+s[pos:]
 a='  call test_rooted_weather_production(oxygen=.true.)';assert s.count(a)==1
 s=s.replace(a,a+"\n  print '(a)','SALT_REAL_INCOMPLETE_PREFIX_MASS_EVENT_RETRY_OPAQUE=PASS'\n  stop")
 target.write_text(s);return target
