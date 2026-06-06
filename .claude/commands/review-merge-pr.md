Review and merge an open PR against the main branch.

## Steps

### 1. Ensure main is current
```bash
git checkout main
git pull origin main
```

### 2. Find the open PR
```bash
gh pr list --state open --limit 10
```
If zero PRs are open, stop and tell the user. If multiple, ask which one.

### 3. Checkout and read the PR
```bash
gh pr checkout <PR_NUMBER>
gh pr view <PR_NUMBER>
```
Summarize the PR title, description, and checklist items.

### 4. Review the diff
```bash
gh pr diff <PR_NUMBER> --name-only
gh pr diff <PR_NUMBER> --patch | head -500
```
Review criteria:
- Changes match the PR description
- No accidental deletions
- No circular imports
- New files have module docstrings
- Test changes are documented in the PR description

For large diffs, read changed files individually.

### 5. Run tests
```bash
python -m pytest tests/ -x -q 2>&1 | tail -20
```
**All tests must pass.** If a failure is pre-existing (also fails on main), note it but don't block. If the PR introduces a new failure, do NOT merge.

### 6. Verify public API (if applicable)
```bash
python -c "from bookbuilder import convert_markdown_to_pdf, find_markdown_files, convert_file, convert_files_parallel, convert_all, get_output_pdf_path, is_conversion_needed, build_book, create_toc_page, resolve_file_path, find_files_in_directory, collect_files_for_chapter, cleanup_output, get_gitignore_patterns, is_ignored, get_default_output_dir, ensure_dir; print('Public API OK')"
```
If this fails and the PR claims to preserve the public API, do NOT merge.

### 7. Check downstream impact
Verify these changes by the PR:
```bash
git diff main -- bookbuilder/__init__.py
git diff main -- bookbuilder/resources/default-config.json
```
If the public API or config schema changed, ensure the PR description documents the migration path.

### 8. Present summary and ask to merge
Show a table with: tests pass, public API preserved (if applicable), changes match description, downstream impact. Ask: **"Merge this PR?"**

### 9. Merge (only after user confirms)
```bash
gh pr merge <PR_NUMBER> --squash --delete-branch
git checkout main
git pull origin main
```

### 10. Post-merge summary
Show PR number, title, and merge commit hash (`git log -1 --format="%H %s"`).

## Notes
- Pre-existing test failures don't block the merge
- For high-risk changes, consider running a downstream smoke build
