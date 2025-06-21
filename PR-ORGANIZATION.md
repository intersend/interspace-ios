# PR Organization Plan

## PR #1: Documentation Reorganization
**Branch**: `chore/docs-reorganization`
**Files**:
- All docs/ changes
- Deleted documentation files
- PR guidelines

**Description**: Centralizes all documentation under /docs with clear hierarchical structure

---

## PR #2: V2 API Authentication Implementation
**Branch**: `feat/v2-api-authentication`
**Files**:
- Interspace/Services/AuthAPI.swift
- Interspace/Services/AuthenticationManager.swift
- Interspace/Services/AuthenticationManagerV2.swift
- Interspace/ViewModels/AuthViewModel.swift
- Interspace/Views/AuthView.swift
- Interspace/Views/EmailAuthView.swift

**Description**: Implements V2 API authentication with flat identity model

---

## PR #3: Profile Management Enhancement
**Branch**: `feat/profile-management`
**Files**:
- Interspace/Services/ProfileAPI.swift
- Interspace/ViewModels/ProfileViewModel.swift
- Interspace/Views/ProfileView.swift
- Interspace/Views/Profile/ProfileHeaderView.swift

**Description**: Enhanced profile management with V2 API integration

---

## PR #4: Component Library Updates
**Branch**: `feat/component-updates`
**Files**:
- Interspace/Views/Components/UniversalAddTray.swift
- Interspace/Views/Components/WalletConnectTray.swift
- Interspace/Views/Components/LoadingSkeletons.swift
- Interspace/Views/Components/StatefulAuthorizationTray.swift

**Description**: UI component improvements and new loading states

---

## PR #5: Testing Infrastructure
**Branch**: `test/v2-api-tests`
**Files**:
- InterspaceTests/V2APITests/V2APITests.swift
- InterspaceTests/V2APITests/V2APITestRunner.swift
- .github/workflows/v2-api-tests.yml
- scripts/run-v2-tests.sh
- Makefile

**Description**: Comprehensive V2 API test suite and CI/CD integration

---

## PR #6: Core Services Update
**Branch**: `refactor/core-services`
**Files**:
- Interspace/Services/APIService.swift
- Interspace/Services/SessionCoordinator.swift
- Interspace/Models/Environment.swift
- Interspace/Views/WalletConnectionView.swift

**Description**: Core service improvements and session management

---

## PR #7: Build Configuration
**Branch**: `chore/build-config`
**Files**:
- Interspace/Supporting/BuildConfiguration.xcconfig
- .gitignore
- Package.resolved
- Interspace.xcodeproj/project.pbxproj

**Description**: Build configuration and project setup improvements

---

## PR #8: Test Hub Feature
**Branch**: `feat/test-hub`
**Files**:
- Interspace/TestHub/

**Description**: Developer testing interface (if keeping this feature)

---

## Merge Order
1. Documentation (no dependencies)
2. Build Configuration (foundation)
3. Core Services (base functionality)
4. V2 API Authentication (depends on core)
5. Profile Management (depends on auth)
6. Component Library (UI layer)
7. Testing Infrastructure (tests all above)
8. Test Hub (optional feature)