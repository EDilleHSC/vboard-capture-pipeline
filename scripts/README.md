# Scripts

Scripts in this directory are used exclusively for:

- upgrade validation
- snapshot verification
- CI execution
- local dry-runs

They must:
- be deterministic
- avoid global state
- fail with non-zero exit codes on error