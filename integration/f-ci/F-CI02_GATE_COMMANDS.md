# F-CI02 gate commands

From the repository root on `integration/f-ci-canonical`:

```bash
python tools/fci/fci02_reference_root_gate.py --skip-vq-gate
python tools/fci/fci02_reference_root_gate.py
```

The first command is metadata/provenance validation only. The second command is the required focused gate and delegates to the existing B1.10 VQ admission/reconstruction gate.

Expected canonical pins:

```text
main root:        fafeebdece209abcc320b24a3c8c2757800b2e0e
B1.10 admission:  5a25526e77a4e1ba3b8f2755cb1e59ca0700ee96
B1.10 members:    63
B1.10 bytes:      1863575
B1.10 manifest:   2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
A23 merge base:   2d05eeab9d766d51bc7c436ea1e45f9b49940e92 (B1.6)
```

A full F-CI02 PASS must not be recorded from metadata-only validation.
