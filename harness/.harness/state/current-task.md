# Task packet — <R-NNN> <title>

> Written by: surveyor · Generated: <date> · Base commit: <sha>

## Task

One paragraph. What changes, in behavioural terms. Not how.

## Success criteria

Copied from the roadmap item. These are the contract; every downstream stage
is measured against exactly this list.

- [ ] ...
- [ ] ...

## Constraints

Interfaces that may not change, performance bounds, compat requirements,
invariants from `CLAUDE.md` that this change strains.

## Relevant context — pointers, not paraphrase

### Files to open

| Path | Lines | Why |
|---|---|---|
| `src/...` | 40–95 | contains the handler being extended |

### Interfaces, verbatim

Quote the actual signatures, types, schema fields, config keys, and error
codes. Copied exactly from the file, each with `path:line`.

```
// src/foo.h:42
Result<Alpha> submit(const AlphaSpec& spec, SubmitOptions opts);
```

### Existing tests in this area

| Test name | Path | What it covers |
|---|---|---|

## Commands

Copied from `CLAUDE.md`. The implementer runs exactly these.

- Build: `...`
- Test (fast): `...`
- Test (full): `...`
- Lint: `...`

## Discrepancies found

Where the roadmap, tests, and code disagreed. Evidence for each. The reviewer
writes these into the roadmap's reconciliation log at the end of the loop.

| # | Roadmap says | Repository shows | Evidence |
|---|---|---|---|

## Split

Only if the roadmap item exceeded the size budget. This packet covers slice 1;
here are the remaining slices for the reviewer to write back into the roadmap.

## Size budget check

- Estimated diff: __ lines (limit 400)
- Files touched: __ (limit 5)
- New tests: __ (limit 5)
