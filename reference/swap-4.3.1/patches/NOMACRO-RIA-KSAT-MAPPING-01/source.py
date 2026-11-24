"""Correct the original RIA Ksat compatibility binding, not its equations."""
import hashlib

ORIGINAL_SHA = 'e6fc217798d3f0424641c61b92fb8831fcdeb78c19670def00695b82ab8e80fe'
BEFORE = '            ksatfit(1:numlay)       = dble(UHCCpars(1:numlay, 1))'
AFTER = '            ksatfit(1:numlay)       = dble(UHCCpars(1:numlay, 4))'


def verify_original(raw):
    if hashlib.sha256(raw.replace(b'\r\n', b'\n')).hexdigest() != ORIGINAL_SHA:
        raise ValueError('Foreign original RIA reader')


def source(text):
    # Other explicitly selected reader owners may already have inserted carry.
    if text.count(BEFORE) != 1 or AFTER in text:
        raise ValueError('Changed original RIA Ksat compatibility assignment')
    return text.replace(BEFORE, AFTER, 1)
