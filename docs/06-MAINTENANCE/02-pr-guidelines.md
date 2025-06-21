# Pull Request Guidelines

## PR Structure

### Title Format
`[TYPE] Brief description (max 50 chars)`

Types:
- `FEAT` - New feature
- `FIX` - Bug fix
- `DOCS` - Documentation only
- `REFACTOR` - Code refactoring
- `TEST` - Test additions/changes
- `CHORE` - Maintenance tasks

### PR Size
- Keep PRs focused on a single feature or fix
- Maximum 400 lines changed (excluding generated files)
- Split large features into multiple PRs

## PR Description Template

```markdown
## Summary
Brief description of changes and their purpose

## Changes
- List specific changes made
- Group by component/feature
- Note any breaking changes

## Testing
- [ ] Unit tests pass
- [ ] Manual testing completed
- [ ] No console errors
- [ ] Performance verified

## Screenshots
(If UI changes)

## Related Issues
Closes #XXX
```

## Review Checklist

### Code Quality
- [ ] No commented-out code
- [ ] No console.log statements
- [ ] Proper error handling
- [ ] Code follows Swift style guide

### Testing
- [ ] New features have tests
- [ ] All tests pass
- [ ] Test coverage maintained

### Documentation
- [ ] Code is self-documenting
- [ ] Complex logic has comments
- [ ] API changes documented

### Security
- [ ] No hardcoded secrets
- [ ] Input validation present
- [ ] Sensitive data protected

## Merge Requirements

1. **Approval**: At least 1 review approval
2. **Tests**: All CI checks pass
3. **Conflicts**: No merge conflicts
4. **Up-to-date**: Branch rebased on main

## Branch Protection Rules

- Require PR reviews before merge
- Dismiss stale reviews on new commits
- Require status checks to pass
- Include administrators in rules
- Enforce linear history