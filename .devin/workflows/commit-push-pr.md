---
description: Commit changes, push to branch, and create a pull request with description
---

This workflow helps you commit your current changes, push them to a new branch, and create a pull request with a descriptive message.

## Steps

1. **Stage and commit changes**
   - Review the current changes with `git status` and `git diff`
   - Stage the relevant files with `git add`
   - Create a commit with a clear, descriptive message following the commit standards

2. **Create or checkout a branch**
   - Create a new branch for your changes: `git checkout -b feature/your-feature-name`
   - Or use the existing branch if you're already on one

3. **Push to remote**
   - Push your branch to the remote repository: `git push -u origin your-branch-name`

4. **Create a pull request**
   - Use `gh pr create` (GitHub CLI) or create a PR through the web interface
   - Include a descriptive PR title and body that explains:
     - What changes were made
     - Why the changes are necessary
     - Any relevant context or testing performed

## Example Commands

```bash
# Stage and commit
git add .
git commit -m "feat: add new feature for X"

# Create and push branch
git checkout -b feature/add-new-feature
git push -u origin feature/add-new-feature

# Create PR with description
gh pr create --title "Add new feature for X" --body "This PR adds functionality for X. Changes include: - Added module for X - Updated tests - Fixed issue #123"
```

## Tips

- Use the `/commit-standards` skill to ensure your commit message follows best practices
- Reference any related issues in your commit message and PR description (e.g., "Fixes #123")
- Keep PRs focused on a single feature or fix for easier review
