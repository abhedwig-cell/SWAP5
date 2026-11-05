# Extracted native CRC family measurement

Status: actual Windows/POSIX O0/O2 extracted-component qualification; research merged at PR1566 (`6226cbb6c`), combined-tree receipt PR1569 (`fa4867340`) qualified and merged. No production source change or full-adapter qualification.

Five other adapter files retain a local nested CRC implementation: matrix joint, mineral joint, reactive-N joint, crop output generation and saved generation. This unit extracts each exact CRC function. For the first three it also extracts the exact append/check native I/O procedures and their unchanged 10 MiB bound. The last two are CRC-function measurements only. Wrapping an extracted function does not qualify its complete original module or public writer.

The private candidate substitutes only the exact already admitted shared table-based CRC body. An independent Python zlib oracle supplies a deterministic ten-vector corpus, including the legitimate empty-input CRC zero, high bytes, all-byte orderings, zeros and mixed long data. Three native primitive pairs write four real payloads apiece and check own files, corrupted bodies, corrupted CRCs, correct resealing and truncation. A correctly resealed changed payload is valid at the CRC-only boundary and must be accepted; model/schema rejection is deliberately outside this primitive scope.

Windows GNU16.2 O0 incumbent and candidate both pass. O2 reproduces oracle failures in all five incumbents; every candidate passes the unchanged byte and native-I/O oracles. Incumbent own-file agreement is never used as independent correctness. Raw outputs, native files and failures are retained. Independent source/wrapper/binary/data remeasurement and mutation refusals remain required.

Production source, runtime ownership, numerical policy, scientific bounds and admission entrypoints are unchanged. The other chat's Andelst/thermal/numerical surfaces are untouched. Full-module source-bound execution, real public publication/restart and affected model qualification are still required before replacing any production duplicate. Whole scientific scope and migration completion remain open.

Authority: `integration/dataqual15_hupsel/CRC_FAMILY_PREREGISTRATION_20261105.json`, `CRC_FAMILY_RECOVERY_20261105.json` and raw platform records.

Cold POSIX GNU13 incumbents and candidates all pass O0/O2; original artifact13429933220 is retained and independently remeasured. All15 source-head workflows pass. The original setup-only timeout remains explicit. The actual merge raced admitted peer PR1567/1568 and differs from the preflight tree; all six measured source blobs remain exact, and combined-tree replay/current/predecessor preservation and all15 final workflows passed on receipt head1de80fce7, whose tree exactly matches actual receipt merge fa4867340. Authority: `CRC_FAMILY_CANONICAL_RECEIPT_20261105.json`.
