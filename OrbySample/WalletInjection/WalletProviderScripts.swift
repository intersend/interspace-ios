import Foundation

class WalletProviderScripts {
    
    // EIP-1193: Ethereum Provider JavaScript API
    static func generateEthereumProviderScript(
        provider: WalletProvider,
        testAddress: String,
        chainId: Int,
        autoConnect: Bool,
        debugMode: Bool
    ) -> String {
        return """
        (function() {
            'use strict';
            
            const DEBUG = \(debugMode ? "true" : "false");
            const PROVIDER_NAME = '\(provider.displayName)';
            const PROVIDER_TYPE = '\(provider.rawValue)';
            
            class EventEmitter {
                constructor() {
                    this._events = {};
                    this._maxListeners = 10;
                }
                
                on(event, listener) {
                    if (!this._events[event]) {
                        this._events[event] = [];
                    }
                    this._events[event].push(listener);
                    return this;
                }
                
                once(event, listener) {
                    const onceWrapper = (...args) => {
                        this.off(event, onceWrapper);
                        listener.apply(this, args);
                    };
                    onceWrapper.listener = listener;
                    return this.on(event, onceWrapper);
                }
                
                off(event, listener) {
                    if (!this._events[event]) return this;
                    this._events[event] = this._events[event].filter(l => l !== listener && l.listener !== listener);
                    return this;
                }
                
                emit(event, ...args) {
                    if (!this._events[event]) return false;
                    this._events[event].forEach(listener => {
                        try {
                            listener.apply(this, args);
                        } catch (error) {
                            console.error(`Error in event listener for ${event}:`, error);
                        }
                    });
                    return true;
                }
                
                removeListener(event, listener) {
                    return this.off(event, listener);
                }
                
                removeAllListeners(event) {
                    if (event) {
                        delete this._events[event];
                    } else {
                        this._events = {};
                    }
                    return this;
                }
                
                setMaxListeners(n) {
                    this._maxListeners = n;
                    return this;
                }
                
                getMaxListeners() {
                    return this._maxListeners;
                }
                
                listeners(event) {
                    return this._events[event] || [];
                }
                
                listenerCount(event) {
                    return this.listeners(event).length;
                }
            }
            
            class EthereumProvider extends EventEmitter {
                constructor() {
                    super();
                    
                    this._state = {
                        accounts: [],
                        isConnected: false,
                        isUnlocked: false,
                        initialized: false,
                        isPermanentlyDisconnected: false
                    };
                    
                    this._metamask = {
                        isUnlocked: () => Promise.resolve(true)
                    };
                    
                    this.chainId = '0x' + (\(chainId)).toString(16);
                    this.networkVersion = '\(chainId)';
                    
                    // Provider identification
                    this.isMetaMask = PROVIDER_TYPE === 'metamask';
                    this.isCoinbaseWallet = PROVIDER_TYPE === 'coinbase';
                    this.isTrust = PROVIDER_TYPE === 'trust';
                    this.isRainbow = PROVIDER_TYPE === 'rainbow';
                    this.isWalletConnect = PROVIDER_TYPE === 'walletconnect';
                    
                    // Additional provider flags
                    if (this.isMetaMask) {
                        this._metamask.isUnlocked = () => Promise.resolve(true);
                    }
                    
                    this._handleConnect();
                }
                
                async request({ method, params = [] }) {
                    if (DEBUG) {
                        console.log(`[${PROVIDER_NAME}] request:`, method, params);
                    }
                    
                    return new Promise((resolve, reject) => {
                        const messageId = Date.now().toString() + Math.random().toString(36);
                        
                        // Store callback
                        window.__walletCallbacks = window.__walletCallbacks || {};
                        window.__walletCallbacks[messageId] = { 
                            resolve: (result) => {
                                if (DEBUG) {
                                    console.log(`[${PROVIDER_NAME}] response for ${method}:`, result);
                                }
                                
                                // Handle state updates
                                this._handleMethodResponse(method, result);
                                resolve(result);
                            },
                            reject: (error) => {
                                if (DEBUG) {
                                    console.error(`[${PROVIDER_NAME}] error for ${method}:`, error);
                                }
                                reject(error);
                            }
                        };
                        
                        // Send to native
                        try {
                            window.webkit.messageHandlers.walletBridge.postMessage({
                                id: messageId,
                                method: method,
                                params: params,
                                address: this._state.accounts[0] || null,
                                chainId: parseInt(this.networkVersion)
                            });
                        } catch (error) {
                            delete window.__walletCallbacks[messageId];
                            reject(error);
                        }
                    });
                }
                
                _handleMethodResponse(method, result) {
                    switch (method) {
                        case 'eth_requestAccounts':
                        case 'eth_accounts':
                            if (Array.isArray(result) && result.length > 0) {
                                const changed = this._state.accounts[0] !== result[0];
                                this._state.accounts = result;
                                this._state.isConnected = true;
                                if (changed) {
                                    this.emit('accountsChanged', result);
                                }
                            }
                            break;
                        
                        case 'eth_chainId':
                            const newChainId = result;
                            if (this.chainId !== newChainId) {
                                this.chainId = newChainId;
                                this.emit('chainChanged', newChainId);
                            }
                            break;
                    }
                }
                
                _handleConnect() {
                    if (\(autoConnect ? "true" : "false")) {
                        setTimeout(() => {
                            this._state.isConnected = true;
                            this._state.accounts = ['\(testAddress.lowercased())'];
                            this.emit('connect', { chainId: this.chainId });
                            this.emit('accountsChanged', this._state.accounts);
                            
                            if (DEBUG) {
                                console.log(`[${PROVIDER_NAME}] Auto-connected with address:`, this._state.accounts[0]);
                            }
                        }, 100);
                    }
                }
                
                // Deprecated methods for compatibility
                enable() {
                    if (DEBUG) {
                        console.warn(`[${PROVIDER_NAME}] enable() is deprecated. Use request({ method: 'eth_requestAccounts' })`);
                    }
                    return this.request({ method: 'eth_requestAccounts' });
                }
                
                send(methodOrPayload, paramsOrCallback) {
                    if (typeof methodOrPayload === 'string') {
                        // Old style: send(method, params)
                        return this.request({
                            method: methodOrPayload,
                            params: paramsOrCallback
                        });
                    } else if (methodOrPayload && typeof methodOrPayload === 'object' && typeof paramsOrCallback === 'function') {
                        // Old style: send(payload, callback)
                        this.request(methodOrPayload)
                            .then(result => paramsOrCallback(null, { result }))
                            .catch(error => paramsOrCallback(error, null));
                    } else {
                        // New style: send(payload)
                        return this.request(methodOrPayload);
                    }
                }
                
                sendAsync(payload, callback) {
                    if (DEBUG) {
                        console.warn(`[${PROVIDER_NAME}] sendAsync() is deprecated`);
                    }
                    
                    this.request({
                        method: payload.method,
                        params: payload.params
                    })
                    .then(result => {
                        callback(null, {
                            id: payload.id,
                            jsonrpc: '2.0',
                            result
                        });
                    })
                    .catch(error => {
                        callback(error, null);
                    });
                }
                
                // Properties
                get selectedAddress() {
                    return this._state.accounts[0] || null;
                }
                
                get isConnected() {
                    return this._state.isConnected;
                }
                
                get accounts() {
                    return [...this._state.accounts];
                }
            }
            
            // Create and inject provider
            const provider = new EthereumProvider();
            
            // Inject at multiple locations for compatibility
            window.ethereum = provider;
            window.web3 = {
                currentProvider: provider,
                eth: {
                    accounts: provider.accounts,
                    defaultAccount: provider.selectedAddress,
                    // Add more web3.eth properties as needed
                }
            };
            
            // Provider-specific injections
            if (PROVIDER_TYPE === 'coinbase') {
                window.coinbaseWalletExtension = provider;
            } else if (PROVIDER_TYPE === 'trust') {
                window.trustwallet = provider;
            }
            
            if (DEBUG) {
                console.log(`[${PROVIDER_NAME}] Provider injected successfully`);
                console.log('Provider object:', provider);
                
                // Test basic functionality
                provider.request({ method: 'eth_chainId' }).then(chainId => {
                    console.log(`[${PROVIDER_NAME}] Current chain ID:`, chainId);
                });
            }
        })();
        """
    }
    
    // Helper script to monitor dApp interactions
    static func generateMonitoringScript() -> String {
        return """
        (function() {
            const originalRequest = window.ethereum.request;
            let requestCount = 0;
            
            window.ethereum.request = function(...args) {
                const [{ method, params }] = args;
                const requestId = ++requestCount;
                
                console.group(`🔍 Request #${requestId}: ${method}`);
                console.log('Parameters:', params);
                console.log('Timestamp:', new Date().toISOString());
                console.groupEnd();
                
                const startTime = performance.now();
                
                return originalRequest.apply(this, args).then(result => {
                    const duration = performance.now() - startTime;
                    
                    console.group(`✅ Response #${requestId}: ${method}`);
                    console.log('Result:', result);
                    console.log('Duration:', duration.toFixed(2) + 'ms');
                    console.groupEnd();
                    
                    return result;
                }).catch(error => {
                    const duration = performance.now() - startTime;
                    
                    console.group(`❌ Error #${requestId}: ${method}`);
                    console.error('Error:', error);
                    console.log('Duration:', duration.toFixed(2) + 'ms');
                    console.groupEnd();
                    
                    throw error;
                });
            };
            
            // Monitor events
            ['connect', 'disconnect', 'chainChanged', 'accountsChanged'].forEach(event => {
                window.ethereum.on(event, (...args) => {
                    console.log(`📢 Event: ${event}`, ...args);
                });
            });
            
            console.log('🔍 Wallet monitoring enabled');
        })();
        """
    }
}