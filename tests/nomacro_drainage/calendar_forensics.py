"""Independent reconstruction of actual original counter reset segments."""
import argparse
import json
import math
from pathlib import Path


def require(ok,message):
    if not ok:raise ValueError(message)


def audit(directory,levels):
    directory=Path(directory)
    rows=[json.loads(line) for line in (directory/'daily.jsonl').read_text().splitlines() if line.strip()]
    frames=[];active=None
    for line in (directory/'original/donor.stdout').read_text().splitlines():
        words=line.split()
        if not words:continue
        tag=words[0]
        if tag=='HYBRID_EXTENDED_OUTPUT_COUNTER_BEGIN':
            values=list(map(float,words[1:]));require(len(values)==3+levels,'Foreign original day counter shape')
            require(active is None,'Original counter day overlaps')
            active=dict(clock=values[0],origins=[values[1:3],values[3:]],terms=[[[] for _ in range(2)],[[] for _ in range(levels)]],resets=[0,0])
        elif tag=='HYBRID_EXTENDED_OUTPUT_COUNTER_RESET':
            require(active is not None,'Original reset has no day origin')
            kind=int(words[1]);values=list(map(float,words[2:]));slot=1 if kind==1 else 0
            require(kind in (1,2),'Foreign reset kind');n=levels if slot else 2
            require(len(values)==1+2*n and active['clock']<=values[0]<=active['clock']+1,'Foreign reset clock/shape')
            current,origin=values[1:1+n],values[1+n:]
            require(origin==active['origins'][slot],'Reset observer changed its actual origin')
            for terms,a,b in zip(active['terms'][slot],current,origin):terms.extend([a,-b])
            active['origins'][slot]=[0.0]*n;active['resets'][slot]+=1
        elif tag=='HYBRID_EXTENDED_OUTPUT_INTERVAL_COUNTERS':
            require(active is not None,'Original final counters have no day origin')
            values=list(map(float,words[1:]));require(len(values)==5+2*levels,'Foreign final original counter shape')
            require(values[0]==active['clock']+1,'Incomplete original day counter clock')
            current=[values[1:3],values[3:3+levels]]
            reported=[values[3+levels:5+levels],values[5+levels:]]
            actual=[]
            for slot in (0,1):
                actual.append([math.fsum([*terms,a,-b]) for terms,a,b in zip(active['terms'][slot],current[slot],active['origins'][slot])])
                require(actual[slot]==reported[slot],'Actual original reset reconstruction differs')
            active.update(actual=actual);frames.append(active);active=None
    require(active is None and len(frames)==len(rows)>0,'Missing actual original daily counter evidence')
    maximum=0.0
    base_clock=frames[0]['clock']-rows[0]['day']+1
    for frame,row in zip(frames,rows):
        require(frame['clock']+1==base_clock+row['day'],'Original counter/physical receipt clock differs')
        actual,per_level=frame['actual'];flow=row['external_flux_cm']
        errors=[actual[0]-flow[13],actual[1]-flow[8],math.fsum([*per_level,-flow[13]])]
        errors.extend(a-b for a,b in zip(per_level,row['surfacewater']['independent_level_exchange_cm']))
        maximum=max(maximum,*map(abs,errors));require(max(map(abs,errors))<=1e-10,'Original reset segments violate soil/surface transfer')
    return dict(status='ACTUAL_ORIGINAL_COUNTER_RESET_RECONSTRUCTION_PASS',actual_days=len(rows),
                reset_segments=sum(sum(frame['resets']) for frame in frames),maximum_transfer_difference_cm=maximum,
                water_guard_cm=1e-10,physical_equations_changed=False,whole_scientific_equivalence='NOT_QUALIFIED')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('--levels',type=int,required=True)
    a=p.parse_args();print(json.dumps(audit(a.directory,a.levels),indent=2))
