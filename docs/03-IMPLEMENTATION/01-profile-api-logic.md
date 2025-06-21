# Profile API Logic Documentation

## Overview
This document provides comprehensive documentation of all profile-related API logic, flows, and test cases for the Interspace backend.

## API Endpoints

### 1. Profile Management

#### Create Profile
- **Endpoint**: `POST /api/v1/profiles`
- **Request Body**:
  ```json
  {
    "name": "string",
    "clientShare": "string", // MPC key share (optional for dev mode)
    "developmentMode": "boolean" // Optional, defaults to false
  }
  ```
- **Response**: `SmartProfile` object
- **Flow**:
  1. Validate profile name (min 3 characters)
  2. Check user hasn't exceeded profile limit
  3. Create session wallet (ERC-7702 proxy)
  4. Store MPC key share (or mock for dev)
  5. Create Orby account cluster
  6. Return profile with session wallet address

#### List Profiles
- **Endpoint**: `GET /api/v1/profiles`
- **Response**: Array of `SmartProfile` objects
- **Notes**: Returns all profiles for authenticated user

#### Get Active Profile
- **Endpoint**: `GET /api/v1/profiles/active`
- **Response**: `SmartProfile` object or null
- **Notes**: Returns currently active profile

#### Activate Profile
- **Endpoint**: `POST /api/v1/profiles/:profileId/activate`
- **Flow**:
  1. Verify profile belongs to user
  2. Deactivate current active profile
  3. Activate selected profile
  4. Update session context

#### Update Profile
- **Endpoint**: `PUT /api/v1/profiles/:profileId`
- **Request Body**:
  ```json
  {
    "name": "string", // Optional
    "isActive": "boolean" // Optional
  }
  ```
- **Validation**: Name must be min 3 characters if provided

#### Delete Profile
- **Endpoint**: `DELETE /api/v1/profiles/:profileId`
- **Flow**:
  1. Verify profile belongs to user
  2. Cannot delete last profile
  3. Cannot delete active profile
  4. Remove all linked accounts
  5. Remove all apps and folders
  6. Delete Orby account cluster
  7. Delete profile

### 2. Linked Account Management

#### Link Account
- **Endpoint**: `POST /api/v1/profiles/:profileId/accounts`
- **Request Body**:
  ```json
  {
    "address": "string",
    "walletType": "metamask|coinbase|walletconnect",
    "customName": "string", // Optional
    "signature": "string",
    "message": "string",
    "chainId": "number" // Optional
  }
  ```
- **Flow**:
  1. Verify signature matches address
  2. Check account not already linked
  3. Create linked account record
  4. First account becomes primary by default

#### List Linked Accounts
- **Endpoint**: `GET /api/v1/profiles/:profileId/accounts`
- **Response**: Array of `LinkedAccount` objects

#### Update Linked Account
- **Endpoint**: `PUT /api/v1/accounts/:accountId`
- **Request Body**:
  ```json
  {
    "customName": "string", // Optional
    "isPrimary": "boolean" // Optional
  }
  ```
- **Notes**: Setting isPrimary=true makes this primary and others non-primary

#### Unlink Account
- **Endpoint**: `DELETE /api/v1/accounts/:accountId`
- **Validation**: Cannot unlink last account if profile has apps

### 3. Social Account Management

#### Link Social Account
- **Endpoint**: `POST /api/v1/users/me/social-accounts`
- **Request Body**:
  ```json
  {
    "provider": "google|apple|twitter|telegram|farcaster|github",
    "oauthCode": "string",
    "redirectUri": "string" // Optional
  }
  ```
- **Flow**:
  1. Exchange OAuth code for tokens
  2. Fetch user profile from provider
  3. Check not already linked
  4. Store social account

#### List Social Accounts
- **Endpoint**: `GET /api/v1/users/me/social-accounts`
- **Response**: Array of `SocialAccount` objects
- **Notes**: Returns all social accounts for user (not profile-specific)

#### Unlink Social Account
- **Endpoint**: `DELETE /api/v1/users/me/social-accounts/:id`

## Test Cases

### Profile Creation Tests

1. **Valid Profile Creation**
   - Create profile with valid name (3+ chars)
   - Verify session wallet created
   - Verify profile is active if first profile
   - Verify MPC key share stored (or mock for dev)

2. **Invalid Profile Creation**
   - Name too short (<3 chars) → 400 error
   - Empty name → 400 error
   - User at profile limit → 400 error
   - Missing clientShare (non-dev mode) → 400 error

3. **Development Mode Profile**
   - Create with developmentMode=true
   - Verify mock wallet created
   - Verify isDevelopmentWallet=true in response

### Profile Switching Tests

1. **Activate Different Profile**
   - Create 2 profiles
   - Activate profile 2
   - Verify profile 1 isActive=false
   - Verify profile 2 isActive=true

2. **Activate Non-Existent Profile**
   - Attempt to activate invalid profileId → 404 error

3. **Activate Profile Not Owned**
   - Attempt to activate another user's profile → 403 error

### Account Linking Tests

1. **Link First Account**
   - Link wallet to profile
   - Verify isPrimary=true
   - Verify signature validation

2. **Link Additional Account**
   - Link second wallet
   - Verify isPrimary=false
   - Verify both accounts listed

3. **Invalid Signature**
   - Provide mismatched signature → 400 error

4. **Duplicate Account**
   - Try linking same address twice → 400 error

5. **Link to Non-Existent Profile**
   - Invalid profileId → 404 error

### Account Unlinking Tests

1. **Unlink Non-Primary Account**
   - Link 2 accounts
   - Unlink non-primary → Success

2. **Unlink Primary Account**
   - Link 2 accounts
   - Unlink primary
   - Verify other account becomes primary

3. **Unlink Last Account**
   - Profile with no apps → Success
   - Profile with apps → 400 error

### Profile Update Tests

1. **Update Profile Name**
   - Change name to valid string → Success
   - Change name to <3 chars → 400 error

2. **Update Non-Existent Profile**
   - Invalid profileId → 404 error

### Profile Deletion Tests

1. **Delete Inactive Profile**
   - Create 2 profiles
   - Delete inactive → Success
   - Verify all associated data removed

2. **Delete Active Profile**
   - Attempt to delete active profile → 400 error

3. **Delete Last Profile**
   - Attempt to delete only profile → 400 error

### Social Account Tests

1. **Link Social Account**
   - Valid OAuth code → Success
   - Invalid OAuth code → 400 error
   - Already linked provider → 400 error

2. **Unlink Social Account**
   - Unlink existing → Success
   - Unlink non-existent → 404 error

## Error Scenarios

### Authentication Errors
- Missing JWT token → 401
- Invalid/expired token → 401
- User not found → 404

### Validation Errors
- Invalid request body → 400
- Missing required fields → 400
- Invalid field formats → 400

### Business Logic Errors
- Profile limit exceeded → 400
- Cannot delete last/active profile → 400
- Cannot unlink last account with apps → 400
- Duplicate account/social link → 400

### Permission Errors
- Accessing another user's profile → 403
- Modifying another user's data → 403

## State Transitions

### Profile States
1. **Created** → Active (if first) or Inactive
2. **Active** → Can be updated, cannot be deleted
3. **Inactive** → Can be activated, updated, or deleted

### Account States
1. **Linked** → Can be updated or unlinked
2. **Primary** → At least one must exist per profile
3. **Non-Primary** → Can be made primary or unlinked

## Integration Notes

### MPC Wallet Integration
- Client provides key share during profile creation
- Server combines with server share to derive wallet
- Development mode uses mock implementation

### Session Management
- Active profile stored in session context
- Profile switch updates session
- All API calls use active profile by default

### Cross-Profile Considerations
- Apps are profile-specific
- Linked accounts are profile-specific
- Social accounts are user-specific (shared across profiles)

## Performance Considerations

1. **Profile Loading**
   - Batch load profile + accounts + apps
   - Cache active profile in session
   - Minimize database queries

2. **Account Verification**
   - Cache signature verification results
   - Rate limit verification attempts

3. **Social OAuth**
   - Cache provider tokens
   - Implement refresh token rotation