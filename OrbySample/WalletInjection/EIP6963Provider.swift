import Foundation

// EIP-6963: Multi Injected Provider Discovery
// https://eips.ethereum.org/EIPS/eip-6963

struct EIP6963ProviderInfo: Codable {
    let uuid: String      // Unique identifier for the wallet provider
    let name: String      // Human-readable name
    let icon: String      // Base64 encoded icon (ideally SVG)
    let rdns: String      // Reverse domain name notation
}

struct EIP6963ProviderDetail {
    let info: EIP6963ProviderInfo
    let provider: Any     // The actual provider object (window.ethereum)
}

// EIP-6963 Events
enum EIP6963Event {
    static let requestProvider = "eip6963:requestProvider"
    static let announceProvider = "eip6963:announceProvider"
}

// Helper to generate EIP-6963 compliant JavaScript
class EIP6963Helper {
    static func generateAnnouncementScript(for providerInfo: EIP6963ProviderInfo, debugMode: Bool = false) -> String {
        return """
        (function() {
            const EIP6963_EVENTS = {
                REQUEST: '\(EIP6963Event.requestProvider)',
                ANNOUNCE: '\(EIP6963Event.announceProvider)'
            };
            
            const providerInfo = {
                uuid: '\(providerInfo.uuid)',
                name: '\(providerInfo.name)',
                icon: '\(providerInfo.icon)',
                rdns: '\(providerInfo.rdns)'
            };
            
            function announceProvider() {
                if (\(debugMode ? "true" : "false")) {
                    console.log('[EIP-6963] Announcing provider:', providerInfo);
                }
                
                const provider = window.ethereum;
                if (!provider) {
                    console.error('[EIP-6963] No provider available to announce');
                    return;
                }
                
                window.dispatchEvent(new CustomEvent(EIP6963_EVENTS.ANNOUNCE, {
                    detail: {
                        info: providerInfo,
                        provider: provider
                    }
                }));
            }
            
            // Listen for provider requests
            window.addEventListener(EIP6963_EVENTS.REQUEST, () => {
                if (\(debugMode ? "true" : "false")) {
                    console.log('[EIP-6963] Provider requested');
                }
                announceProvider();
            });
            
            // Announce immediately if provider is already available
            if (window.ethereum) {
                setTimeout(announceProvider, 0);
            } else {
                // Wait for provider to be injected
                let checkCount = 0;
                const checkInterval = setInterval(() => {
                    if (window.ethereum) {
                        clearInterval(checkInterval);
                        announceProvider();
                    } else if (++checkCount > 20) {
                        clearInterval(checkInterval);
                        console.warn('[EIP-6963] Provider not found after 2 seconds');
                    }
                }, 100);
            }
        })();
        """
    }
    
    static func generateProviderDiscoveryScript(debugMode: Bool = false) -> String {
        return """
        (function() {
            const providers = new Map();
            
            // Listen for provider announcements
            window.addEventListener('eip6963:announceProvider', (event) => {
                if (\(debugMode ? "true" : "false")) {
                    console.log('[EIP-6963] Provider announced:', event.detail.info);
                }
                
                const { info, provider } = event.detail;
                providers.set(info.rdns, { info, provider });
                
                // Emit custom event for app to track
                window.dispatchEvent(new CustomEvent('orby:providerDiscovered', {
                    detail: { 
                        count: providers.size,
                        providers: Array.from(providers.values())
                    }
                }));
            });
            
            // Request all providers
            setTimeout(() => {
                if (\(debugMode ? "true" : "false")) {
                    console.log('[EIP-6963] Requesting providers...');
                }
                window.dispatchEvent(new Event('eip6963:requestProvider'));
            }, 100);
            
            // Expose discovered providers
            window.__discoveredProviders = providers;
        })();
        """
    }
}