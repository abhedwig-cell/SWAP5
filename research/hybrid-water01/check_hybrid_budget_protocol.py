"""Exercise actual generic-kernel project budgets and independent clocks."""
import argparse
from pathlib import Path
import subprocess

def check(kernel):
    # Same small nonzero mass defect is refused by Grass and admitted by Andelst.
    for model,nodes,epoch,accepted in [('HYBRID_GRASSGROWTH_WATER',113,29220,False),
                                      ('HYBRID_ANDELST_WATER',112,35795,True)]:
        initial=' '.join(map(str,[0,1,1,0,0,0,0,0,*([0]*nodes)]))
        reply=' '.join(map(str,[1,1,5e-10,0,0,0,*([0]*nodes),1,0,0,0,0,0]))
        data=f'1\n{nodes} {epoch}\n{initial}\n1 1\n{reply}\n0 0\n'
        r=subprocess.run([str(kernel),model,'explicit-project'],input=data,text=True,capture_output=True,timeout=10)
        assert r.returncode==0,r.stderr
        expected='DAILY_ACCEPTED 1 1 1' if accepted else 'DAILY_REFUSED 1 1 0'
        assert expected in r.stdout,(model,r.stdout)
    # Two columns in one kernel own different grids and epochs, no shared clock.
    initial=lambda n:' '.join(map(str,[0,1,1,0,0,0,0,0,*([0]*n)]))
    reply=lambda n:' '.join(map(str,[1,1,0,0,0,0,*([0]*n),1,0,0,0,0,0]))
    data=f'2\n3 10\n{initial(3)}\n113 29220\n{initial(113)}\n2 1\n{reply(113)}\n1 1\n{reply(3)}\n0 0\n'
    r=subprocess.run([str(kernel),'HYBRID_GRASSGROWTH_WATER','explicit-project'],input=data,text=True,capture_output=True,timeout=10)
    assert r.returncode==0 and 'DAILY_ACCEPTED 2 1 1' in r.stdout and 'DAILY_ACCEPTED 1 1 1' in r.stdout,r.stderr
    assert '29220.00000000   29221.00000000' in r.stdout and '10.00000000      11.00000000' in r.stdout,r.stdout
    return 'EXACT_PROJECT_BUDGETS_AND_HETEROGENEOUS_GRID_CLOCK_PROTOCOL_PASS'

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--kernel',type=Path,required=True)
    print(check(p.parse_args().kernel))
