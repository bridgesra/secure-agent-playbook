# Test policy

Tests in this repo are the source of truth for playbook behavior. They are not a living sketch of the code.

## Write, fire, freeze

For each new test file (or new assertion group):

1. Write the test against current behavior.
2. Sabotage the production file the test targets (wrong JSON key, missing copy, wrong mode branch, broken status-line field, and so on).
3. Run that test and confirm it **fails**. A test that has never failed is not proven.
4. Revert the sabotage. Confirm the test **passes**.
5. Mark the file `LOCKED` in its header comment.

Do this per test as it is added, not once at the end.

## After a test is locked

- Do **not** edit a locked test unless the repo owner explicitly okays it.
- When a test fails, fix [secure-agent-template/](../secure-agent-template/) or [secure-agent-playbook.sh](../secure-agent-playbook.sh), not the test.
- Do not rewrite assertions to match new code. Do not delete failing checks. Do not “update fixtures” to silence a break.
- Tests are not copied into `new-project` output. They belong only in this playbook repo.

## How to run

```bash
./tests/run.sh              # Layers 1–2 (contract, unit, installer)
RUN_RUNTIME=1 ./tests/run.sh  # also Layer 3 Docker / Dev Container smokes
```
