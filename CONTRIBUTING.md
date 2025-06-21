# Contributing to Interspace iOS

First off, thank you for considering contributing to Interspace iOS! It's people like you that make Interspace such a great tool. We welcome contributions from everyone, regardless of their experience level.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Process](#development-process)
- [Style Guidelines](#style-guidelines)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Security Vulnerabilities](#security-vulnerabilities)

## 📜 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to conduct@interspace.app.

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## 🚀 Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/yourusername/interspace-ios.git
   cd interspace-ios
   ```
3. **Add the upstream repository**:
   ```bash
   git remote add upstream https://github.com/interspace/interspace-ios.git
   ```
4. **Create a new branch** for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 🤔 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples**
- **Include screenshots if applicable**
- **Describe the behavior you observed and expected**
- **Include your environment details** (iOS version, device, Xcode version)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description of the proposed functionality**
- **Include mockups or wireframes if applicable**
- **Explain why this enhancement would be useful**

### Your First Code Contribution

Unsure where to begin? Look for these labels in our issues:

- `good-first-issue` - Simple issues perfect for beginners
- `help-wanted` - Issues where we need community help
- `documentation` - Documentation improvements

## 💻 Development Process

### Setting Up Your Environment

1. Follow the setup instructions in the [README](README.md)
2. Make sure all tests pass before making changes:
   ```bash
   xcodebuild test -workspace Interspace.xcworkspace -scheme Interspace
   ```

### Making Changes

1. **Write clean, readable code** following our style guidelines
2. **Add tests** for new functionality
3. **Update documentation** as needed
4. **Run all tests** to ensure nothing is broken
5. **Test on multiple devices/simulators** if possible

### Testing

- Write unit tests for new features
- Ensure all existing tests pass
- Add UI tests for user-facing features
- Test on both iPhone and iPad if applicable
- Test in both light and dark mode

## 🎨 Style Guidelines

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) with these additions:

```swift
// MARK: - Good Example
class ProfileManager {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func saveProfile(_ profile: Profile) throws {
        // Implementation
    }
}

// MARK: - Bad Example
class profile_manager {
    var ud: UserDefaults!
    
    func SaveProfile(profile: Profile) {
        // Implementation
    }
}
```

### Key Points

- Use descriptive variable and function names
- Prefer `let` over `var` when possible
- Use Swift's type inference where appropriate
- Group related functionality with `// MARK: -` comments
- Keep functions small and focused
- Use proper access control (`private`, `internal`, `public`)

### SwiftUI Best Practices

- Keep views small and composable
- Use `@StateObject` for view models
- Prefer `@EnvironmentObject` for shared state
- Extract complex views into separate files
- Use preview providers for development

## 📝 Commit Guidelines

We use conventional commits for clear communication:

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or modifying tests
- `chore`: Changes to build process or auxiliary tools

### Examples
```
feat(auth): add biometric authentication support

- Implement Face ID/Touch ID authentication
- Add privacy usage description to Info.plist
- Create BiometricAuthManager service

Closes #123
```

## 🔄 Pull Request Process

1. **Update your branch** with the latest upstream changes:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push your changes** to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request** with:
   - Clear title describing the change
   - Description of what changed and why
   - Link to any relevant issues
   - Screenshots for UI changes
   - Checklist of completed items

### PR Checklist

- [ ] Code follows the style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests passing
- [ ] No sensitive information exposed

### Review Process

1. At least one maintainer approval required
2. All CI checks must pass
3. No merge conflicts
4. Up-to-date with main branch

## 🔐 Security Vulnerabilities

**Do not open public issues for security vulnerabilities.** Instead, please email security@interspace.app with:

- Description of the vulnerability
- Steps to reproduce
- Possible impact
- Suggested fix (if any)

We'll respond within 48 hours and work with you to address the issue.

## 🏆 Recognition

Contributors who make significant contributions will be:
- Added to the contributors list
- Mentioned in release notes
- Given credit in the app (with permission)

## ❓ Questions?

Feel free to:
- Open an issue for questions
- Join our [Discord community](https://discord.gg/interspace)
- Email us at contributors@interspace.app

Thank you for contributing to Interspace iOS! 🎉