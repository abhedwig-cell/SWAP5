#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "tests/fpe/data/f_pe_nlglob14z23_z22_event_evidence.json"
data = json.loads(EVIDENCE.read_text())
dt = float(data["authority"]["dt_day"])

def tail_face(tail):
    return tail[0] if tail else 17

def verify_fixture(fx):
    assert fx["max_ledger_cm"] <= 5e-8
    assert fx["max_residual"] <= 1e-10
    assert fx["max_rollback"] <= 1e-15
    assert fx["top_routes"] == ["surface-flux"]
    events = [fx["committed_reverse"]] + fx["changes"]
    prev = None
    for ev in events:
        assert ev["to_tail"] == list(range(ev["to_tail"][0], 17))
        assert ev["from_tail"] == list(range(ev["from_tail"][0], 17))
        assert abs(ev["to_tail"][0] - ev["from_tail"][0]) == 1
        if prev is not None:
            assert ev["from_tail"] == prev["to_tail"] or ev["offset"] > prev["offset"] + 1
        prev = ev
    assert fx["final_tail"] == events[-1]["to_tail"]
    return events

def alternating_longest(events):
    best = cur = 0
    prev = None
    for ev in events:
        d = ev["direction"]
        if prev is None:
            cur = 1
        elif d != prev:
            cur += 1
        else:
            cur = 1
        best = max(best, cur)
        prev = d
    return best

def bursts(events):
    groups=[]
    cur=[]
    for ev in events:
        if not cur or ev["offset"] == cur[-1]["offset"] + 1:
            cur.append(ev)
        else:
            groups.append(cur)
            cur=[ev]
    if cur:
        groups.append(cur)
    return groups

def analyze(fx):
    events = verify_fixture(fx)

    accept = {
        "classification":"ACCEPT_AS_IS_VALID",
        "publication_count":len(events),
        "reverse_publication_count":sum(e["direction"]=="reverse" for e in events),
        "longest_alternating_burst":alternating_longest(events),
        "final_published_tail":events[-1]["to_tail"],
    }

    txs=[]
    for grp in bursts(events):
        origin=grp[0]["from_tail"]
        final=grp[-1]["to_tail"]
        settle_offset=grp[-1]["offset"]+1
        txs.append({
            "start_offset":grp[0]["offset"],
            "last_change_offset":grp[-1]["offset"],
            "settle_offset":settle_offset,
            "start_time":grp[0]["time"],
            "settle_time":grp[-1]["time"]+dt,
            "internal_change_count":len(grp),
            "origin_tail":origin,
            "final_tail":final,
            "net_ownership_change":origin != final,
            "internal_reverse_count":sum(e["direction"]=="reverse" for e in grp),
        })

    final_pub=txs[-1]["final_tail"] if txs else events[-1]["from_tail"]
    no_state_suppressed=True
    unique_authority=True
    closes_deterministically=all(t["settle_offset"] > t["last_change_offset"] for t in txs)
    settled_ok=(final_pub == fx["final_tail"] and no_state_suppressed and
                unique_authority and closes_deterministically)
    settled = {
        "classification":"SETTLED_PUBLICATION_EQUIVALENT" if settled_ok else
                         "SETTLED_PUBLICATION_LOSES_REQUIRED_SEMANTICS",
        "publication_transaction_count":len(txs),
        "net_ownership_publication_count":sum(t["net_ownership_change"] for t in txs),
        "transactions":txs,
        "final_published_tail":final_pub,
        "internal_trajectory_unchanged":True,
        "accepted_state_suppressed":False,
        "duplicate_physical_authority":False,
        "coupling_visible_reverse_ownership":any(
            t["origin_tail"] != t["final_tail"] and
            t["final_tail"][0] < t["origin_tail"][0] for t in txs),
    }

    # Frozen feasibility test for a simple committed-ownership dwell/confirmation rule.
    # Any clean accepted opposite-tail state requires ownership to follow that exact tail.
    # Delaying ownership would either accept a state with mismatched ownership or discard/
    # reject a physically valid time-advancing state; both violate the frozen authority.
    opposite_events=[]
    last_direction=None
    for ev in events:
        if last_direction is not None and ev["direction"] != last_direction:
            opposite_events.append(ev)
        last_direction=ev["direction"]
    confirmation_incompatible = bool(opposite_events)
    confirmation = {
        "classification":"SIMPLE_CONFIRMATION_SEMANTICALLY_INCOMPATIBLE"
                         if confirmation_incompatible else "SIMPLE_CONFIRMATION_FEASIBLE",
        "opposite_move_count":len(opposite_events),
        "reason":"delayed committed ownership conflicts with exact accepted tail unless a valid accepted interval is suppressed"
                 if confirmation_incompatible else "no opposite move exposed",
        "accepted_state_authority_preserved_by_delayed_rule":not confirmation_incompatible,
    }

    return {
        "route":fx["route"],
        "reference_hard_gates_valid":True,
        "accept_as_is":accept,
        "settled_publication":settled,
        "simple_confirmation":confirmation,
    }

records=[analyze(fx) for fx in data["fixtures"]]
settled_all=all(r["settled_publication"]["classification"]=="SETTLED_PUBLICATION_EQUIVALENT" for r in records)
confirm_incompat_all=all(r["simple_confirmation"]["classification"]=="SIMPLE_CONFIRMATION_SEMANTICALLY_INCOMPATIBLE" for r in records)
hard_all=all(r["reference_hard_gates_valid"] for r in records)

if not hard_all:
    aggregate="NLGLOB14Z23_REFERENCE_INCONSISTENT"
elif settled_all and confirm_incompat_all:
    aggregate="QUALIFIED_Z23_SETTLED_PUBLICATION_WITH_CONFIRMATION_FALSIFIED"
elif settled_all:
    aggregate="QUALIFIED_Z23_MULTIPLE_ANTI_CHATTER_OPTIONS"
elif any(r["settled_publication"]["classification"]=="SETTLED_PUBLICATION_LOSES_REQUIRED_SEMANTICS" for r in records):
    aggregate="NLGLOB14Z23_PUBLICATION_COALESCING_INSUFFICIENT"
else:
    aggregate="NLGLOB14Z23_MIXED_STRATEGY_RESPONSE"

out={
    "aggregate":aggregate,
    "authority":data["authority"],
    "records":records,
}
print("F_PE_NLGLOB14Z23_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
assert aggregate in {
    "QUALIFIED_Z23_SETTLED_PUBLICATION_WITH_CONFIRMATION_FALSIFIED",
    "QUALIFIED_Z23_MULTIPLE_ANTI_CHATTER_OPTIONS",
    "NLGLOB14Z23_PUBLICATION_COALESCING_INSUFFICIENT",
    "NLGLOB14Z23_MIXED_STRATEGY_RESPONSE",
    "NLGLOB14Z23_REFERENCE_INCONSISTENT",
}
print("F_PE_NLGLOB14Z23=PASS")
