"""Read-only accepted original water-carrier availability, not an energy solver.

Original upward-positive faces become downward-positive integrated amounts.
Only actual measured water paths are reported. No gas displacement or external
water temperature is inferred from the water balance, soil or air temperature.
"""
import math
from pathlib import Path

from heat_receipts import CLOCK_BUDGET_DAY

WATER_BUDGET_CM = 1e-10  # unchanged hybrid accepted water budget


def read_accepted_carriers(path, receipts, project):
    accepted = {}
    for receipt in receipts:
        if receipt.get('committed') is not True:
            continue
        day = receipt['day']
        if type(day) is not int or day < 1 or day in accepted:
            raise ValueError('Invalid or duplicate accepted day')
        if len(receipt['pressure_head_cm']) != project.nodes:
            raise ValueError('Accepted project grid differs')
        accepted[day] = []
    lines = iter(Path(path).read_text().splitlines())
    ignored = 0
    for line in lines:
        fields = line.split()
        if len(fields) != 5 or fields[0] != 'CARRIER_STEP':
            raise ValueError('Invalid carrier step')
        t0, dt = map(float, fields[1:3])
        n, macro = map(int, fields[3:])
        if not all(map(math.isfinite, (t0, dt))) or dt <= 0 or n != project.nodes or macro not in (0, 1):
            raise ValueError('Invalid carrier interval/grid/macro option')
        nodes = []
        for i in range(1, n+1):
            row = next(lines, '').split()
            if len(row) != 16 or row[:2] != ['CARRIER_NODE', str(i)]:
                raise ValueError('Invalid carrier node')
            values = list(map(float, row[2:]))
            if not all(map(math.isfinite, values)):
                raise ValueError('Nonfinite carrier')
            dz, fraction, theta0, theta1, immobile, above, below, root, drainout, drainin, exchange, drip, temp0, temp1 = values
            if dz <= 0 or not 0 < fraction <= 1 or min(theta0, theta1, drainout, drainin) < 0:
                raise ValueError('Invalid carrier geometry/state')
            if not macro and (fraction != 1 or exchange != 0):
                raise ValueError('Inactive macro path has nonzero carrier')
            nodes.append(values)
        day = math.floor(t0-project.start_clock)+1
        if t0+dt > project.start_clock+day+CLOCK_BUDGET_DAY:
            raise ValueError('Carrier crosses accepted day')
        if day not in accepted:
            ignored += 1
            continue
        if any(left[6] != right[5] for left, right in zip(nodes, nodes[1:])):
            raise ValueError('Water faces do not cancel')
        residuals = [v[0]*v[1]*(v[3]-v[2]+v[4]) - dt*(-v[5]+v[6]-v[7]-v[8]+v[9]+v[10]+v[11]) for v in nodes]
        if max(map(abs, residuals)) > WATER_BUDGET_CM:
            raise ValueError('Actual nodal water carrier exceeds unchanged budget')
        amounts = {
            'top_in':dt*max(-nodes[0][5], 0), 'top_out':dt*max(nodes[0][5], 0),
            'bottom_in':dt*max(nodes[-1][6], 0), 'bottom_out':dt*max(-nodes[-1][6], 0),
            'root_out':dt*math.fsum(max(v[7], 0) for v in nodes),
            'root_in':dt*math.fsum(max(-v[7], 0) for v in nodes),
            'drain_out':dt*math.fsum(v[8] for v in nodes),
            'drain_in':dt*math.fsum(v[9] for v in nodes),
            'macro_net_in':dt*math.fsum(v[10] for v in nodes),
            'drip_net_in':dt*math.fsum(v[11] for v in nodes),
            'immobile_increment':math.fsum(v[0]*v[1]*v[4] for v in nodes),
        }
        # Nonzero means active, including arbitrarily small accepted transfers.
        # No cutoff silently substitutes zero heat for an unknown donor.
        missing = [name for name in ('top_in','bottom_in','root_in','drain_in') if amounts[name] != 0]
        if any(v[10] != 0 for v in nodes): missing.append('macro_exchange')
        if any(v[11] != 0 for v in nodes): missing.append('subsurface_drip')
        if any(v[4] != 0 for v in nodes): missing.append('mobile_immobile_exchange')
        accepted[day].append({'t0':t0,'dt':dt,'amounts_cm':amounts,
            'missing_active_liquid_donor_paths':missing,
            'local_soil_temperature_endpoints_available':True,
            'max_node_water_residual_cm':max(map(abs,residuals))})
    daily = []
    for day, steps in sorted(accepted.items()):
        start = project.start_clock+day-1
        for step in steps:
            if abs(step['t0']-start) > CLOCK_BUDGET_DAY:
                raise ValueError('Carrier chronology has gap, overlap or duplicate')
            start = step['t0']+step['dt']
        if not steps or abs(start-(project.start_clock+day)) > CLOCK_BUDGET_DAY:
            raise ValueError('Accepted day lacks complete carrier support')
        daily.append({'day':day,'steps':len(steps),
            'amounts_cm':{k:math.fsum(s['amounts_cm'][k] for s in steps) for k in steps[0]['amounts_cm']},
            'missing_active_liquid_donor_paths':sorted({p for s in steps for p in s['missing_active_liquid_donor_paths']}),
            'max_node_water_residual_cm':max(s['max_node_water_residual_cm'] for s in steps),
            'local_soil_temperature_endpoints_available':True,
            'gas_carrier_available':False,'mass_carried_energy_available':False,
            'full_energy_balance_complete':False})
    return {'status':'ACCEPTED_ORIGINAL_WATER_CARRIER_INVENTORY_ENERGY_INCOMPLETE',
        'model':project.model,'daily':daily,'unaccepted_steps_ignored':ignored,
        'water_budget_cm':WATER_BUDGET_CM,'temperature_policy':'actual original soil endpoints; no external donor substitution',
        'gas_policy':'unavailable; not inferred from changing air volume',
        'full_energy_balance_complete':False}
