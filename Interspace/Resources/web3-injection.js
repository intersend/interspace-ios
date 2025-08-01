// Interspace Web3 Provider Injection Script
(function() {
    'use strict';
    
    // Check if already injected
    if (window.ethereum && window.ethereum.isInterspace) {
        console.log('Interspace Web3 provider already injected');
        return;
    }
    
    // Create message handler
    function sendMessage(type, data) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.interspaceWeb3) {
            window.webkit.messageHandlers.interspaceWeb3.postMessage({
                type: type,
                ...data
            });
        }
    }
    
    // Response handler
    let responseHandlers = {};
    let requestId = 0;
    
    window.__handleInterspaceMessage = function(response) {
        if (response.type === 'web3_response' && responseHandlers[response.id]) {
            const handler = responseHandlers[response.id];
            delete responseHandlers[response.id];
            
            if (response.error) {
                handler.reject(new Error(response.error.message || 'Unknown error'));
            } else {
                handler.resolve(response.result);
            }
        } else if (response.type === 'initial_state') {
            // Handle initial state
            if (response.result) {
                ethereum._chainId = response.result.chainId;
                ethereum._accounts = response.result.accounts || [];
                ethereum._isConnected = response.result.isConnected || false;
                
                // Emit connect event if connected
                if (ethereum._isConnected && ethereum._accounts.length > 0) {
                    ethereum.emit('connect', { chainId: ethereum._chainId });
                    ethereum.emit('accountsChanged', ethereum._accounts);
                }
            }
        } else if (response.type === 'web3_event') {
            // Handle events
            ethereum.emit(response.event, response.data);
        }
    };
    
    // Event emitter
    class EventEmitter {
        constructor() {
            this.events = {};
        }
        
        on(event, callback) {
            if (!this.events[event]) {
                this.events[event] = [];
            }
            this.events[event].push(callback);
            return this;
        }
        
        once(event, callback) {
            const onceWrapper = (...args) => {
                callback(...args);
                this.removeListener(event, onceWrapper);
            };
            return this.on(event, onceWrapper);
        }
        
        removeListener(event, callback) {
            if (this.events[event]) {
                this.events[event] = this.events[event].filter(cb => cb !== callback);
            }
            return this;
        }
        
        emit(event, ...args) {
            if (this.events[event]) {
                this.events[event].forEach(callback => {
                    try {
                        callback(...args);
                    } catch (error) {
                        console.error('Event handler error:', error);
                    }
                });
            }
        }
    }
    
    // Ethereum provider
    class InterspaceProvider extends EventEmitter {
        constructor() {
            super();
            this.isInterspace = true;
            this.isMetaMask = true; // For compatibility
            this._chainId = '0x1';
            this._accounts = [];
            this._isConnected = false;
            
            // Request initial state
            sendMessage('get_initial_state', {});
        }
        
        isConnected() {
            return this._isConnected;
        }
        
        async request(args) {
            if (!args || typeof args !== 'object' || typeof args.method !== 'string') {
                throw new Error('Invalid request');
            }
            
            const id = ++requestId;
            
            return new Promise((resolve, reject) => {
                responseHandlers[id] = { resolve, reject };
                
                // Send request to native
                sendMessage('web3_request', {
                    id: id,
                    method: args.method,
                    params: args.params || []
                });
                
                // Timeout after 60 seconds
                setTimeout(() => {
                    if (responseHandlers[id]) {
                        delete responseHandlers[id];
                        reject(new Error('Request timeout'));
                    }
                }, 60000);
            });
        }
        
        // Legacy methods for compatibility
        async enable() {
            return this.request({ method: 'eth_requestAccounts' });
        }
        
        async send(method, params = []) {
            return this.request({ method, params });
        }
        
        sendAsync(payload, callback) {
            this.request({
                method: payload.method,
                params: payload.params
            }).then(result => {
                callback(null, {
                    id: payload.id,
                    jsonrpc: '2.0',
                    result
                });
            }).catch(error => {
                callback(error, null);
            });
        }
    }
    
    // Create and inject provider
    const ethereum = new InterspaceProvider();
    
    // Define as non-configurable to prevent overwriting
    Object.defineProperty(window, 'ethereum', {
        value: ethereum,
        writable: false,
        configurable: false
    });
    
    // For compatibility with older dApps
    window.web3 = {
        currentProvider: ethereum,
        eth: {
            accounts: ethereum._accounts
        }
    };
    
    // Notify that injection is complete
    sendMessage('injection_complete', {
        url: window.location.href
    });
    
    console.log('✅ Interspace Web3 provider injected successfully');
    
    // Dispatch ethereum provider event
    window.dispatchEvent(new Event('ethereum#initialized'));
})();