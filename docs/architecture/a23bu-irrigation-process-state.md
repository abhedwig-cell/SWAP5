# A23BU irrigation process-state ownership contract

## Authoritative lifetime split

### Persistent per-column process continuation
`hupsel_process_cursor_t%irrigation` contains only:
- `nirri`: fixed-irrigation event cursor / next event index;
- `dayfix`: scheduled-irrigation progression cursor.

These values are cloned with the transaction checkpoint and are restored before every trial. A rejected trial therefore cannot advance the committed irrigation cursor.

### Immutable model configuration
The adapter stores `irrigation_enabled` and `crop_calendar_enabled` on the model/component, not in every column checkpoint for this qualified model template. They describe active physics/configuration, not mutable continuation.

### Reconstructible legacy event workspace
The following legacy B1.6 values are reset at the start of every A23BU trial and rebuilt by existing process logic:
`irrigevent`, `gird`, `isua`, `cirr`, `nird`, `dt_irr_event`, `qssdi(:)`, `qssdisum`.

They are not persistent A23BU column state. They remain legacy singleton workspace until a later worker-owned process backend is introduced.

## Transaction rule
For any A23BU trial:
1. clone committed column state;
2. restore physical, forcing, process cursors, numerical state, time projection and accounting cursor;
3. restore immutable model activation flags;
4. reset reconstructible irrigation event workspace;
5. execute B1.6 trial;
6. capture only persistent continuation cursors and physical/numerical continuation;
7. commit only accepted two-half state; otherwise discard trial clone.

## Qualified boundary
This contract is dynamically qualified for the Hupsel whole-day Jan-4/Jan-5 reference, including the real fixed irrigation event on Jan 5. It is not yet a sub-day irrigation-event contract and not a scheduled-irrigation qualification.

## Hard constraints
- Mass conservation remains hard (`1e-6 cm` B1.6 qualification criterion).
- Physics and Jacobian formulas are unchanged.
- Reporting/output side effects remain suppressed on transaction trials as in A23BT.
- Legacy event workspace being reconstructible does not imply the backend is thread-safe.
