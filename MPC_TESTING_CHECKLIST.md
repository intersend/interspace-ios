# MPC Wallet Testing Checklist

## Prerequisites
- [ ] Backend running locally: `docker-compose -f docker-compose.local.yml --profile local up`
- [ ] Backend health check: `curl http://localhost:3000/health`
- [ ] Duo-node running: `curl http://localhost:3001/health`
- [ ] iOS Simulator or device ready
- [ ] Test account credentials available

## Manual Testing Steps

### 1. Profile Creation with MPC Wallet
- [ ] Launch app
- [ ] Navigate to "Create New Profile"
- [ ] Enter profile name
- [ ] Verify MPC wallet option is visible (if feature flag enabled)
- [ ] Create profile
- [ ] **Expected**: Loading indicator appears with "Generating MPC wallet..."
- [ ] **Expected**: Wallet address appears after ~5-10 seconds
- [ ] **Expected**: Address format is valid (0x... with 42 characters)
- [ ] Take screenshot of successful creation

### 2. Wallet Display
- [ ] Navigate to Wallet tab
- [ ] **Expected**: MPC badge/indicator is visible
- [ ] **Expected**: Wallet address is displayed correctly
- [ ] **Expected**: Balance loads properly
- [ ] Tap on wallet info/details
- [ ] **Expected**: Shows "Multi-Party Computation (2-2)" as wallet type

### 3. Transaction Signing
- [ ] From Wallet tab, tap "Send"
- [ ] Enter recipient address: `0x742d35Cc6634C0532925a3b844Bc9e7595f8150`
- [ ] Enter amount: `0.001`
- [ ] Tap "Review"
- [ ] **Expected**: Transaction details are correct
- [ ] Tap "Sign & Send"
- [ ] **Expected**: Biometric authentication prompt appears
- [ ] Authenticate with Face ID/Touch ID
- [ ] **Expected**: "Signing transaction..." indicator appears
- [ ] **Expected**: Transaction completes successfully
- [ ] **Expected**: Success notification/alert appears

### 4. Error Scenarios
- [ ] Stop backend service
- [ ] Try to create a new profile
- [ ] **Expected**: Error message about service unavailability
- [ ] Restart backend
- [ ] Try to sign without network
- [ ] **Expected**: Appropriate network error message

### 5. Session Management
- [ ] Create multiple profiles rapidly
- [ ] **Expected**: Each gets unique wallet address
- [ ] Switch between profiles
- [ ] **Expected**: Correct wallet displayed for each profile
- [ ] Sign transactions from different profiles
- [ ] **Expected**: Each uses its own MPC key

### 6. Backup & Recovery (if implemented)
- [ ] Navigate to Settings > Wallet & Security
- [ ] Tap "Backup Wallet"
- [ ] **Expected**: Warning about backup importance
- [ ] Create backup with password
- [ ] **Expected**: Backup file created/displayed
- [ ] Store backup securely

### 7. Performance Testing
- [ ] Time wallet generation: _________________ seconds
- [ ] Time transaction signing: _________________ seconds
- [ ] Memory usage before: _________________ MB
- [ ] Memory usage after: _________________ MB

## Automated Test Execution

### Run Integration Tests
```bash
cd /Users/ardaerturk/Documents/GitHub/interspace-codebase/interspace-ios
./scripts/test-mpc.sh
```

### Run Specific Test
```bash
xcodebuild test \
  -scheme Interspace \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  -only-testing:InterspaceTests/MPCIntegrationTests/testGenerateMPCWallet
```

## Test Data

### Test Addresses
- Test recipient: `0x742d35Cc6634C0532925a3b844Bc9e7595f8150`
- Test contract: `0x6B175474E89094C44Da98b954EedeAC495271d0F` (DAI)

### Test Transactions
- Simple ETH transfer: Amount = 0.001 ETH
- Token transfer: Use any ERC20 token contract
- Contract interaction: Use a simple contract call

## Debugging

### Check Logs
1. **Backend logs**: 
   ```bash
   docker-compose -f docker-compose.local.yml logs -f app
   ```

2. **Duo-node logs**:
   ```bash
   docker-compose -f docker-compose.local.yml logs -f duo-node
   ```

3. **iOS Console**:
   - Xcode > Devices and Simulators > Open Console
   - Filter by "MPC" or "WebSocket"

### Common Issues
- **WebSocket connection failed**: Check duo-node is running
- **Key generation timeout**: Check backend/duo-node connectivity
- **Signing fails**: Verify keyshare storage in duo-node
- **Biometric prompt not appearing**: Check device capabilities

## Metrics to Track
- [ ] Wallet generation success rate: _____%
- [ ] Average generation time: _____ seconds
- [ ] Transaction signing success rate: _____%
- [ ] Average signing time: _____ seconds
- [ ] Error rate: _____%
- [ ] Most common error: _________________

## Sign-off
- [ ] All manual tests passed
- [ ] All automated tests passed
- [ ] Performance acceptable
- [ ] No critical bugs found
- [ ] Ready for deployment

**Tested by**: _________________
**Date**: _________________
**Version**: _________________