import Foundation

extension MockDataProvider {
    
    // MARK: - Wallet Setup Methods
    
    func setupAliceWallet(profile: SmartProfile) {
        // Setup balance data
        let ethBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "eth",
            symbol: "ETH",
            name: "Ethereum",
            totalAmount: "2.5",
            totalUsdValue: 4750.0,
            decimals: 18,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 1,
                    chainName: "Ethereum",
                    amount: "2.5",
                    tokenAddress: nil,
                    isNative: true
                )
            ]
        )
        
        let usdcBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "usdc",
            symbol: "USDC",
            name: "USD Coin",
            totalAmount: "1500",
            totalUsdValue: 1500.0,
            decimals: 6,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 1,
                    chainName: "Ethereum",
                    amount: "1000",
                    tokenAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                    isNative: false
                ),
                UnifiedBalance.ChainBalance(
                    chainId: 137,
                    chainName: "Polygon",
                    amount: "500",
                    tokenAddress: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
                    isNative: false
                )
            ]
        )
        
        let balance = UnifiedBalance(
            profileId: profile.id,
            profileName: profile.name,
            unifiedBalance: UnifiedBalance.BalanceData(
                totalUsdValue: 6250.0,
                tokenBalances: [ethBalance, usdcBalance]
            ),
            gasAnalysis: UnifiedBalance.GasAnalysis(
                suggestedGasToken: UnifiedBalance.GasToken(
                    tokenId: "eth",
                    symbol: "ETH",
                    name: "Ethereum",
                    score: 100,
                    totalBalance: "2.5",
                    totalUsdValue: 4750.0,
                    availableChains: [1],
                    isNative: true,
                    factors: UnifiedBalance.GasTokenFactors(
                        balanceScore: 90,
                        chainAvailabilityScore: 100,
                        nativeTokenBonus: 10
                    )
                ),
                nativeGasAvailable: [1: true, 137: false],
                availableGasTokens: []
            )
        )
        
        balancesByProfile[profile.id] = balance
        
        // Setup NFTs
        let artCollection = NFTCollection(
            id: "alice-art-collection",
            name: "Digital Art Collection",
            nfts: [
                NFT(
                    id: "art-1",
                    name: "Abstract Dreams #42",
                    tokenId: "42",
                    collection: "Abstract Dreams",
                    imageUrl: "https://via.placeholder.com/400x400/FF6B6B/FFFFFF?text=Abstract+Dreams",
                    rarity: .rare,
                    floorPrice: 0.5
                ),
                NFT(
                    id: "art-2",
                    name: "Generative Landscapes #128",
                    tokenId: "128",
                    collection: "Generative Landscapes",
                    imageUrl: "https://via.placeholder.com/400x400/4ECDC4/FFFFFF?text=Landscape",
                    rarity: .uncommon,
                    floorPrice: 0.3
                ),
                NFT(
                    id: "art-3",
                    name: "AI Portraits #7",
                    tokenId: "7",
                    collection: "AI Portraits",
                    imageUrl: "https://via.placeholder.com/400x400/FFE66D/FFFFFF?text=AI+Portrait",
                    rarity: .epic,
                    floorPrice: 1.2
                )
            ],
            floorPrice: 0.3,
            totalValue: 2.0
        )
        
        nftsByProfile[profile.id] = [artCollection]
        
        // Setup transactions
        let transactions = generateAliceTransactions(profileId: profile.id)
        transactionsByProfile[profile.id] = transactions
        
        // Setup linked accounts
        let linkedAccounts = [
            LinkedAccount(
                id: "\(profile.id)-metamask",
                address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
                walletType: .metamask,
                customName: "Main MetaMask",
                isPrimary: true,
                createdAt: Date().addingTimeInterval(-20*24*60*60),
                updatedAt: Date()
            ),
            LinkedAccount(
                id: "\(profile.id)-coinbase",
                address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
                walletType: .coinbase,
                customName: "Coinbase Wallet",
                isPrimary: false,
                createdAt: Date().addingTimeInterval(-10*24*60*60),
                updatedAt: Date()
            )
        ]
        
        linkedAccountsByProfile[profile.id] = linkedAccounts
    }
    
    func setupBobWallet(profile: SmartProfile) {
        // Setup balance data
        let ethBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "eth",
            symbol: "ETH",
            name: "Ethereum",
            totalAmount: "5.2",
            totalUsdValue: 9880.0,
            decimals: 18,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 1,
                    chainName: "Ethereum",
                    amount: "3.2",
                    tokenAddress: nil,
                    isNative: true
                ),
                UnifiedBalance.ChainBalance(
                    chainId: 10,
                    chainName: "Optimism",
                    amount: "2.0",
                    tokenAddress: nil,
                    isNative: true
                )
            ]
        )
        
        let usdcBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "usdc",
            symbol: "USDC",
            name: "USD Coin",
            totalAmount: "3200",
            totalUsdValue: 3200.0,
            decimals: 6,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 1,
                    chainName: "Ethereum",
                    amount: "2000",
                    tokenAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                    isNative: false
                ),
                UnifiedBalance.ChainBalance(
                    chainId: 42161,
                    chainName: "Arbitrum",
                    amount: "1200",
                    tokenAddress: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
                    isNative: false
                )
            ]
        )
        
        let uniBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "uni",
            symbol: "UNI",
            name: "Uniswap",
            totalAmount: "150",
            totalUsdValue: 900.0,
            decimals: 18,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 1,
                    chainName: "Ethereum",
                    amount: "150",
                    tokenAddress: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
                    isNative: false
                )
            ]
        )
        
        let aaveBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "aave",
            symbol: "AAVE",
            name: "Aave",
            totalAmount: "20",
            totalUsdValue: 1400.0,
            decimals: 18,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 1,
                    chainName: "Ethereum",
                    amount: "20",
                    tokenAddress: "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
                    isNative: false
                )
            ]
        )
        
        let balance = UnifiedBalance(
            profileId: profile.id,
            profileName: profile.name,
            unifiedBalance: UnifiedBalance.BalanceData(
                totalUsdValue: 15380.0,
                tokenBalances: [ethBalance, usdcBalance, uniBalance, aaveBalance]
            ),
            gasAnalysis: UnifiedBalance.GasAnalysis(
                suggestedGasToken: UnifiedBalance.GasToken(
                    tokenId: "eth",
                    symbol: "ETH",
                    name: "Ethereum",
                    score: 100,
                    totalBalance: "5.2",
                    totalUsdValue: 9880.0,
                    availableChains: [1, 10],
                    isNative: true,
                    factors: UnifiedBalance.GasTokenFactors(
                        balanceScore: 95,
                        chainAvailabilityScore: 100,
                        nativeTokenBonus: 10
                    )
                ),
                nativeGasAvailable: [1: true, 10: true, 42161: false],
                availableGasTokens: []
            )
        )
        
        balancesByProfile[profile.id] = balance
        
        // Setup NFTs - DeFi focused
        let defiNFTs = NFTCollection(
            id: "bob-defi-nfts",
            name: "DeFi Protocol NFTs",
            nfts: [
                NFT(
                    id: "defi-1",
                    name: "Uniswap V3 Position #2847",
                    tokenId: "2847",
                    collection: "Uniswap V3 Positions",
                    imageUrl: "https://via.placeholder.com/400x400/7C3AED/FFFFFF?text=UNI-V3",
                    rarity: .common,
                    floorPrice: 0.01
                ),
                NFT(
                    id: "defi-2",
                    name: "AAVE Ghost #512",
                    tokenId: "512",
                    collection: "AAVE Ghosts",
                    imageUrl: "https://via.placeholder.com/400x400/B8A5CE/FFFFFF?text=AAVE",
                    rarity: .rare,
                    floorPrice: 0.8
                ),
                NFT(
                    id: "defi-3",
                    name: "Compound Finance OG #88",
                    tokenId: "88",
                    collection: "Compound OGs",
                    imageUrl: "https://via.placeholder.com/400x400/00D395/FFFFFF?text=COMP",
                    rarity: .legendary,
                    floorPrice: 2.5
                ),
                NFT(
                    id: "defi-4",
                    name: "1inch Pathfinder #1024",
                    tokenId: "1024",
                    collection: "1inch Pathfinders",
                    imageUrl: "https://via.placeholder.com/400x400/FF4B4B/FFFFFF?text=1INCH",
                    rarity: .uncommon,
                    floorPrice: 0.15
                ),
                NFT(
                    id: "defi-5",
                    name: "Curve Wars Veteran #333",
                    tokenId: "333",
                    collection: "Curve Wars",
                    imageUrl: "https://via.placeholder.com/400x400/0066FF/FFFFFF?text=CRV",
                    rarity: .epic,
                    floorPrice: 1.0
                )
            ],
            floorPrice: 0.01,
            totalValue: 4.46
        )
        
        let pfpCollection = NFTCollection(
            id: "bob-pfp",
            name: "Profile Pictures",
            nfts: [
                NFT(
                    id: "pfp-1",
                    name: "CryptoPunk #8274",
                    tokenId: "8274",
                    collection: "CryptoPunks",
                    imageUrl: "https://via.placeholder.com/400x400/C3A634/FFFFFF?text=Punk",
                    rarity: .rare,
                    floorPrice: 50.0
                ),
                NFT(
                    id: "pfp-2",
                    name: "Bored Ape #6529",
                    tokenId: "6529",
                    collection: "BAYC",
                    imageUrl: "https://via.placeholder.com/400x400/9B8B4A/FFFFFF?text=BAYC",
                    rarity: .uncommon,
                    floorPrice: 35.0
                ),
                NFT(
                    id: "pfp-3",
                    name: "Azuki #1337",
                    tokenId: "1337",
                    collection: "Azuki",
                    imageUrl: "https://via.placeholder.com/400x400/C93C5A/FFFFFF?text=Azuki",
                    rarity: .rare,
                    floorPrice: 12.0
                )
            ],
            floorPrice: 12.0,
            totalValue: 97.0
        )
        
        nftsByProfile[profile.id] = [defiNFTs, pfpCollection]
        
        // Setup transactions
        let transactions = generateBobTransactions(profileId: profile.id)
        transactionsByProfile[profile.id] = transactions
        
        // Setup linked accounts
        let linkedAccounts = [
            LinkedAccount(
                id: "\(profile.id)-rainbow",
                address: "0x5A9C7B2f6D8e3a4b1c0F9d7E8a5B4c3F2A1D0E9B",
                walletType: .rainbow,
                customName: "Rainbow Mobile",
                isPrimary: true,
                createdAt: Date().addingTimeInterval(-40*24*60*60),
                updatedAt: Date()
            ),
            LinkedAccount(
                id: "\(profile.id)-ledger",
                address: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD7E",
                walletType: .ledger,
                customName: "Hardware Wallet",
                isPrimary: false,
                createdAt: Date().addingTimeInterval(-35*24*60*60),
                updatedAt: Date()
            ),
            LinkedAccount(
                id: "\(profile.id)-walletconnect",
                address: "0x8B9C7B2f6D8e3a4b1c0F9d7E8a5B4c3F2A1D0E9B",
                walletType: .walletConnect,
                customName: "WalletConnect",
                isPrimary: false,
                createdAt: Date().addingTimeInterval(-25*24*60*60),
                updatedAt: Date()
            )
        ]
        
        linkedAccountsByProfile[profile.id] = linkedAccounts
    }
    
    func setupCarolWallet(profile: SmartProfile) {
        // Setup balance data - smaller amounts for gaming profile
        let ethBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "eth",
            symbol: "ETH",
            name: "Ethereum",
            totalAmount: "0.8",
            totalUsdValue: 1520.0,
            decimals: 18,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 1,
                    chainName: "Ethereum",
                    amount: "0.3",
                    tokenAddress: nil,
                    isNative: true
                ),
                UnifiedBalance.ChainBalance(
                    chainId: 137,
                    chainName: "Polygon",
                    amount: "0.5",
                    tokenAddress: nil,
                    isNative: true
                )
            ]
        )
        
        let usdcBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "usdc",
            symbol: "USDC",
            name: "USD Coin",
            totalAmount: "500",
            totalUsdValue: 500.0,
            decimals: 6,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 137,
                    chainName: "Polygon",
                    amount: "500",
                    tokenAddress: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
                    isNative: false
                )
            ]
        )
        
        let maticBalance = UnifiedBalance.TokenBalance(
            standardizedTokenId: "matic",
            symbol: "MATIC",
            name: "Polygon",
            totalAmount: "250",
            totalUsdValue: 200.0,
            decimals: 18,
            balancesPerChain: [
                UnifiedBalance.ChainBalance(
                    chainId: 137,
                    chainName: "Polygon",
                    amount: "250",
                    tokenAddress: nil,
                    isNative: true
                )
            ]
        )
        
        let balance = UnifiedBalance(
            profileId: profile.id,
            profileName: profile.name,
            unifiedBalance: UnifiedBalance.BalanceData(
                totalUsdValue: 2220.0,
                tokenBalances: [ethBalance, usdcBalance, maticBalance]
            ),
            gasAnalysis: UnifiedBalance.GasAnalysis(
                suggestedGasToken: UnifiedBalance.GasToken(
                    tokenId: "matic",
                    symbol: "MATIC",
                    name: "Polygon",
                    score: 90,
                    totalBalance: "250",
                    totalUsdValue: 200.0,
                    availableChains: [137],
                    isNative: true,
                    factors: UnifiedBalance.GasTokenFactors(
                        balanceScore: 80,
                        chainAvailabilityScore: 90,
                        nativeTokenBonus: 10
                    )
                ),
                nativeGasAvailable: [1: false, 137: true],
                availableGasTokens: []
            )
        )
        
        balancesByProfile[profile.id] = balance
        
        // Setup NFTs - Gaming focused
        let gamingNFTs = NFTCollection(
            id: "carol-gaming-nfts",
            name: "Gaming NFTs",
            nfts: [
                NFT(
                    id: "gaming-1",
                    name: "Axie #128493",
                    tokenId: "128493",
                    collection: "Axie Infinity",
                    imageUrl: "https://via.placeholder.com/400x400/FF6BB5/FFFFFF?text=Axie",
                    rarity: .uncommon,
                    floorPrice: 0.02
                ),
                NFT(
                    id: "gaming-2",
                    name: "Gods Unchained - Demogorgon",
                    tokenId: "9472",
                    collection: "Gods Unchained",
                    imageUrl: "https://via.placeholder.com/400x400/4A0E4E/FFFFFF?text=GU",
                    rarity: .legendary,
                    floorPrice: 0.5
                ),
                NFT(
                    id: "gaming-3",
                    name: "Sandbox LAND (-42, 108)",
                    tokenId: "5832",
                    collection: "The Sandbox",
                    imageUrl: "https://via.placeholder.com/400x400/0084FF/FFFFFF?text=LAND",
                    rarity: .rare,
                    floorPrice: 0.8
                ),
                NFT(
                    id: "gaming-4",
                    name: "Decentraland Wearable - Epic Sword",
                    tokenId: "2931",
                    collection: "Decentraland",
                    imageUrl: "https://via.placeholder.com/400x400/FF2D55/FFFFFF?text=DCL",
                    rarity: .epic,
                    floorPrice: 0.15
                ),
                NFT(
                    id: "gaming-5",
                    name: "Illuvium - Rhamphyre",
                    tokenId: "777",
                    collection: "Illuvium",
                    imageUrl: "https://via.placeholder.com/400x400/9B4DFF/FFFFFF?text=ILV",
                    rarity: .rare,
                    floorPrice: 0.3
                ),
                NFT(
                    id: "gaming-6",
                    name: "Star Atlas Ship - X6",
                    tokenId: "1984",
                    collection: "Star Atlas",
                    imageUrl: "https://via.placeholder.com/400x400/00D9FF/FFFFFF?text=STAR",
                    rarity: .uncommon,
                    floorPrice: 0.1
                )
            ],
            floorPrice: 0.02,
            totalValue: 1.87
        )
        
        nftsByProfile[profile.id] = [gamingNFTs]
        
        // Setup transactions
        let transactions = generateCarolTransactions(profileId: profile.id)
        transactionsByProfile[profile.id] = transactions
        
        // Setup linked accounts - only one for gaming profile
        let linkedAccounts = [
            LinkedAccount(
                id: "\(profile.id)-metamask",
                address: "0x3E5e9C7B2f6D8e3a4b1c0F9d7E8a5B4c3F2A1D0E9B",
                walletType: .metamask,
                customName: "Gaming Wallet",
                isPrimary: true,
                createdAt: Date().addingTimeInterval(-10*24*60*60),
                updatedAt: Date()
            )
        ]
        
        linkedAccountsByProfile[profile.id] = linkedAccounts
    }
}