"""Actual sealed signed Git data and byte/tree/parent corruption refusals."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_parent_admission import ROOT,git,BASE,SYNTHETIC,archived_commit,parent_admission


def main():
    head=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(ROOT,head)
    receipt=json.loads((data/'FROST_CALENDAR_STATE02_MERGE_RECEIPT_V1.json').read_text());count=0
    with ExitStack() as stack:
        archive=Archive(data,'FROST_CALENDAR_STATE02_ADMISSION_RAW_V1',stack)
        for sha in (BASE,SYNTHETIC):
            raw=archive.get('FROST_CALENDAR_STATE02_PR1801_GENUINE_GIT_OBJECT_'+sha+'.bin')
            assert archived_commit(raw,sha,receipt['whole_tree'],receipt['ordered_parents'])['sha']==sha
            bad=bytearray(raw);bad[len(bad)//2]^=1
            for payload,expected_sha,tree,parents in (
                (bytes(bad),sha,receipt['whole_tree'],receipt['ordered_parents']),
                (raw,'0'*40,receipt['whole_tree'],receipt['ordered_parents']),
                (raw,sha,'0'*40,receipt['ordered_parents']),
                (raw,sha,receipt['whole_tree'],list(reversed(receipt['ordered_parents']))),
                (raw,sha,receipt['whole_tree'],receipt['ordered_parents'][:1])):
                try:archived_commit(payload,expected_sha,tree,parents)
                except AssertionError:count+=1
                else:raise AssertionError('Corrupt archived Git commit admitted')
    assert count==10 and parent_admission()['actual_admitted_coadmission']['contexts']==500
    assert git('rev-parse','HEAD').decode().strip()==head
    print('TWO_GENUINE_SIGNED_ARCHIVED_COMMITS_TEN_BYTE_TREE_PARENT_REFUSALS_AND_COMPLETE_PARENT500_ADMISSION_PASS_NO_GIT_OR_HEAD_PROJECTION')


if __name__=='__main__':main()
