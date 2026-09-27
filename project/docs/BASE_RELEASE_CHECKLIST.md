# Repository Base release checklist

Use this checklist for each Repository Base release. It records the Base
release evidence without turning the canary into authority for consumer
adoption.

## Release record

- Base version: `<version>`
- Base source commit: `<commit>`
- Release PR / merge commit: `<url-or-commit>`
- Verify workflow: `<run-url>`

## Required validation

1. Run `knt doctor` in the Base checkout.
2. Run `knt base-check` in the Base checkout.
3. Run `knt verify` and record the Project test evidence.
4. Run the Base self-tests from `.kinotch/tests/run-tests.ps1`.
5. Run the dedicated `kinoko34077/kinotch-default-canary` repository against
   the same Base version.
6. Record the canary's `knt doctor`, `knt base-check`, `knt verify`, and
   `project/tests/test-defaults.ps1` results.

The canary is a validation target only. A passing canary does not authorize
automatic Base adoption or bulk synchronization of consumer repositories.

## Current accepted release

For Base v0.5.13, the canary was synchronized and verified at its own owner
repository. Future releases must update the release record and retain the
same evidence boundary.
