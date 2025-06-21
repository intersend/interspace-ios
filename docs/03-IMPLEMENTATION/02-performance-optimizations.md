# App Launch Performance Optimizations

This document describes the performance optimizations implemented to improve app launch time.

## Overview

The app launch flow has been optimized to defer non-critical initialization and use caching for faster perceived startup time.

## Key Optimizations

### 1. Service Lazy Loading
- **ServiceInitializer**: Manages lazy initialization of services
- Core services (Keychain, API) initialized immediately
- Wallet SDKs initialized only when wallet features are accessed
- Google Sign-In initialized only when authentication is needed

### 2. Caching System
- **UserCacheManager**: Caches user and profile data locally
- Quick launch using cached data while refreshing in background
- 24-hour cache expiration for user data
- 1-hour cache for authentication state

### 3. Async SDK Initialization
- MetaMask SDK initialization moved to background queue
- Concurrent initialization of multiple SDKs using TaskGroup
- Non-blocking main thread during SDK setup

### 4. UI Optimizations
- Reduced animation duration from 0.6s to 0.3s for launch
- Progressive loading of UI components
- Immediate display with cached state

### 5. Performance Monitoring
- **AppLaunchPerformance**: Tracks launch milestones
- Measures time from process start to first content view
- Detailed reporting of initialization times

## Performance Metrics

The app now tracks the following metrics:
- Process start → AppDelegate: Time to reach app delegate
- AppDelegate → First View: Time to display first view
- Service initialization times for each service
- Total launch time from process start to interactive UI

## Usage

### Viewing Performance Metrics
Launch metrics are automatically printed to console in debug builds:
```
📊 App Launch Performance Report
================================
Total Launch Time: 523.45ms

Milestones:
  • AppDelegate Start: 145.23ms (+145.23ms)
  • AppDelegate End: 167.89ms (+22.66ms)
  • First ContentView: 523.45ms (+355.56ms)
================================
```

### Manual Service Initialization
To manually initialize services when needed:
```swift
// Initialize wallet services
await ServiceInitializer.shared.initializeWalletServices()

// Initialize Google Sign-In
ServiceInitializer.shared.initializeGoogleSignIn()
```

## Results

Expected improvements:
- 40-60% reduction in cold launch time
- Near-instant warm launches with cached data
- Non-blocking UI during SDK initialization
- Better perceived performance with progressive loading

## Future Optimizations

1. **Pre-warming**: Initialize critical services during splash screen
2. **Predictive Loading**: Pre-load likely next screens
3. **Image Optimization**: Lazy load and cache profile images
4. **Network Optimization**: Batch API calls and use HTTP/2
5. **Code Splitting**: Dynamic frameworks for rarely used features