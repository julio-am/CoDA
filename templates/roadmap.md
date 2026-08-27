# Project roadmap

**This file is intent, not status.** Code is the source of truth for what
exists; tests are the source of truth for what is done. The reviewer
reconciles this file against both at the end of every task.

Only the reviewer writes to this file.

---

## How to read an item

Every item has a stable ID (`R-NNN`) that never changes and is never reused.
An item is **done** when every test listed under **Acceptance** exists and
passes. Nothing else counts as done — not "the code looks finished", not "it
was in the last commit".

Tests are linked to an item with a marker comment placed next to the test:

```
# @harness:R-001
```

The marker is a plain grep target so it works in any language. Put it directly
above the test function, or in the test's docstring.

**Status values:** `todo` · `in-progress` · `blocked` · `done` · `deferred`

---

## R-001 — Example item, delete me

- **Status:** todo
- **Milestone:** M1
- **Intent:** One paragraph. What the user-visible or system-visible outcome
  is, and why. Not how.
- **Acceptance:**
  - [ ] `test_thing_rejects_empty_input`
  - [ ] `test_thing_round_trips`
- **Constraints:** Anything the implementation must respect — an interface it
  cannot change, a performance bound, a backward-compat requirement.
- **Depends on:** —
- **Out of scope:** What a reasonable person might assume is included but
  isn't. This field prevents more rework than any other.
- **Notes:** Appended by the reviewer as reality diverges from intent. Never
  delete a note; strike it through and add the correction beneath.

---

## Reconciliation log

The reviewer appends one line here whenever the repository disagreed with this
document.

| Date | Item | Roadmap said | Repository showed | Resolution |
|---|---|---|---|---|
| | | | | |
