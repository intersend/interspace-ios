import Foundation

extension MockDataProvider {
    
    // MARK: - Transaction Generation
    
    func generateAliceTransactions(profileId: String) -> [TransactionHistory.TransactionItem] {
        var transactions: [TransactionHistory.TransactionItem] = []
        
        // Transaction 1: Received ETH
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-1",
            type: "transfer",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 1,
                amount: "0.5",
                address: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD7E"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 1,
                amount: "0.5",
                address: "0x1234567890abcdef1234567890abcdef12345678"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.002",
                usdValue: 3.8
            ),
            createdAt: Date().addingTimeInterval(-2*24*60*60),
            completedAt: Date().addingTimeInterval(-2*24*60*60 + 60),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0x123456789abcdef123456789abcdef123456789abcdef123456789abcdef1234",
                    status: "confirmed",
                    gasUsed: "21000"
                )
            ]
        ))
        
        // Transaction 2: Sent USDC
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-2",
            type: "transfer",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "USDC",
                    name: "USD Coin",
                    decimals: 6,
                    address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
                ),
                chainId: 1,
                amount: "100",
                address: "0x1234567890abcdef1234567890abcdef12345678"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "USDC",
                    name: "USD Coin",
                    decimals: 6,
                    address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
                ),
                chainId: 1,
                amount: "100",
                address: "0x5A9C7B2f6D8e3a4b1c0F9d7E8a5B4c3F2A1D0E9B"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.004",
                usdValue: 7.6
            ),
            createdAt: Date().addingTimeInterval(-5*24*60*60),
            completedAt: Date().addingTimeInterval(-5*24*60*60 + 120),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0xabcdef123456789abcdef123456789abcdef123456789abcdef123456789abc",
                    status: "confirmed",
                    gasUsed: "45000"
                )
            ]
        ))
        
        // Transaction 3: NFT Purchase
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-3",
            type: "nft_purchase",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 1,
                amount: "1.2",
                address: "0x1234567890abcdef1234567890abcdef12345678"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "NFT",
                    name: "AI Portraits #7",
                    decimals: 0,
                    address: "0x9876543210fedcba9876543210fedcba98765432"
                ),
                chainId: 1,
                amount: "1",
                address: "0x1234567890abcdef1234567890abcdef12345678"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.015",
                usdValue: 28.5
            ),
            createdAt: Date().addingTimeInterval(-7*24*60*60),
            completedAt: Date().addingTimeInterval(-7*24*60*60 + 180),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0x9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedc",
                    status: "confirmed",
                    gasUsed: "150000"
                )
            ]
        ))
        
        // Transaction 4: Cross-chain USDC transfer
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-4",
            type: "bridge",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "USDC",
                    name: "USD Coin",
                    decimals: 6,
                    address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
                ),
                chainId: 1,
                amount: "500",
                address: "0x1234567890abcdef1234567890abcdef12345678"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "USDC",
                    name: "USD Coin",
                    decimals: 6,
                    address: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
                ),
                chainId: 137,
                amount: "500",
                address: "0x1234567890abcdef1234567890abcdef12345678"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.008",
                usdValue: 15.2
            ),
            createdAt: Date().addingTimeInterval(-10*24*60*60),
            completedAt: Date().addingTimeInterval(-10*24*60*60 + 600),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0x1111111111111111111111111111111111111111111111111111111111111111",
                    status: "confirmed",
                    gasUsed: "80000"
                ),
                TransactionHistory.OnChainTransaction(
                    chainId: 137,
                    hash: "0x2222222222222222222222222222222222222222222222222222222222222222",
                    status: "confirmed",
                    gasUsed: "50000"
                )
            ]
        ))
        
        return transactions.sorted { $0.createdAt > $1.createdAt }
    }
    
    func generateBobTransactions(profileId: String) -> [TransactionHistory.TransactionItem] {
        var transactions: [TransactionHistory.TransactionItem] = []
        
        // Transaction 1: Uniswap Swap
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-1",
            type: "swap",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 1,
                amount: "1.0",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "UNI",
                    name: "Uniswap",
                    decimals: 18,
                    address: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"
                ),
                chainId: 1,
                amount: "150",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.012",
                usdValue: 22.8
            ),
            createdAt: Date().addingTimeInterval(-1*24*60*60),
            completedAt: Date().addingTimeInterval(-1*24*60*60 + 120),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0x3333333333333333333333333333333333333333333333333333333333333333",
                    status: "confirmed",
                    gasUsed: "120000"
                )
            ]
        ))
        
        // Transaction 2: AAVE Deposit
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-2",
            type: "lending_deposit",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "USDC",
                    name: "USD Coin",
                    decimals: 6,
                    address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
                ),
                chainId: 1,
                amount: "1000",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "aUSDC",
                    name: "Aave USDC",
                    decimals: 6,
                    address: "0xBcca60bB61934080951369a648Fb03DF4F96263C"
                ),
                chainId: 1,
                amount: "1000",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.008",
                usdValue: 15.2
            ),
            createdAt: Date().addingTimeInterval(-3*24*60*60),
            completedAt: Date().addingTimeInterval(-3*24*60*60 + 180),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0x4444444444444444444444444444444444444444444444444444444444444444",
                    status: "confirmed",
                    gasUsed: "85000"
                )
            ]
        ))
        
        // Transaction 3: NFT Purchase (CryptoPunk)
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-3",
            type: "nft_purchase",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 1,
                amount: "50",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "NFT",
                    name: "CryptoPunk #8274",
                    decimals: 0,
                    address: "0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB"
                ),
                chainId: 1,
                amount: "1",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.025",
                usdValue: 47.5
            ),
            createdAt: Date().addingTimeInterval(-5*24*60*60),
            completedAt: Date().addingTimeInterval(-5*24*60*60 + 240),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0x5555555555555555555555555555555555555555555555555555555555555555",
                    status: "confirmed",
                    gasUsed: "250000"
                )
            ]
        ))
        
        // Transaction 4: Compound Borrow
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-4",
            type: "lending_borrow",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "COMP",
                    name: "Compound Protocol",
                    decimals: 18,
                    address: "0xc00e94Cb662C3520282E6f5717214004A7f26888"
                ),
                chainId: 1,
                amount: "0",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "DAI",
                    name: "Dai Stablecoin",
                    decimals: 18,
                    address: "0x6B175474E89094C44Da98b954EedeAC495271d0F"
                ),
                chainId: 1,
                amount: "500",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.01",
                usdValue: 19.0
            ),
            createdAt: Date().addingTimeInterval(-7*24*60*60),
            completedAt: Date().addingTimeInterval(-7*24*60*60 + 180),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0x6666666666666666666666666666666666666666666666666666666666666666",
                    status: "confirmed",
                    gasUsed: "100000"
                )
            ]
        ))
        
        // Transaction 5: Bridge ETH to Optimism
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-5",
            type: "bridge",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 1,
                amount: "2.0",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 10,
                amount: "2.0",
                address: "0xabcdef1234567890abcdef1234567890abcdef12"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.015",
                usdValue: 28.5
            ),
            createdAt: Date().addingTimeInterval(-10*24*60*60),
            completedAt: Date().addingTimeInterval(-10*24*60*60 + 900),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0x7777777777777777777777777777777777777777777777777777777777777777",
                    status: "confirmed",
                    gasUsed: "150000"
                ),
                TransactionHistory.OnChainTransaction(
                    chainId: 10,
                    hash: "0x8888888888888888888888888888888888888888888888888888888888888888",
                    status: "confirmed",
                    gasUsed: "60000"
                )
            ]
        ))
        
        // Add more DeFi transactions
        for i in 6...20 {
            let txType = ["swap", "lending_deposit", "lending_withdraw", "liquidity_add", "liquidity_remove"].randomElement()!
            let daysAgo = Double(i + 5)
            
            transactions.append(TransactionHistory.TransactionItem(
                operationSetId: "\(profileId)-tx-\(i)",
                type: txType,
                status: "completed",
                from: TransactionHistory.TransactionEndpoint(
                    token: TransactionHistory.TokenInfo(
                        symbol: ["ETH", "USDC", "UNI", "AAVE"].randomElement()!,
                        name: "Token",
                        decimals: 18,
                        address: nil
                    ),
                    chainId: 1,
                    amount: String(format: "%.2f", Double.random(in: 0.1...2.0)),
                    address: "0xabcdef1234567890abcdef1234567890abcdef12"
                ),
                to: TransactionHistory.TransactionEndpoint(
                    token: TransactionHistory.TokenInfo(
                        symbol: ["ETH", "USDC", "UNI", "AAVE", "DAI"].randomElement()!,
                        name: "Token",
                        decimals: 18,
                        address: nil
                    ),
                    chainId: 1,
                    amount: String(format: "%.2f", Double.random(in: 50...500)),
                    address: "0xabcdef1234567890abcdef1234567890abcdef12"
                ),
                gasToken: TransactionHistory.GasTokenUsed(
                    tokenId: "eth",
                    symbol: "ETH",
                    name: "Ethereum",
                    amount: String(format: "%.3f", Double.random(in: 0.005...0.02)),
                    usdValue: Double.random(in: 10...40)
                ),
                createdAt: Date().addingTimeInterval(-daysAgo*24*60*60),
                completedAt: Date().addingTimeInterval(-daysAgo*24*60*60 + 180),
                transactions: [
                    TransactionHistory.OnChainTransaction(
                        chainId: 1,
                        hash: "0x\(String(repeating: "\(i % 10)", count: 64))",
                        status: "confirmed",
                        gasUsed: String(Int.random(in: 50000...200000))
                    )
                ]
            ))
        }
        
        return transactions.sorted { $0.createdAt > $1.createdAt }
    }
    
    func generateCarolTransactions(profileId: String) -> [TransactionHistory.TransactionItem] {
        var transactions: [TransactionHistory.TransactionItem] = []
        
        // Transaction 1: NFT Purchase (Gaming)
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-1",
            type: "nft_purchase",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "MATIC",
                    name: "Polygon",
                    decimals: 18,
                    address: nil
                ),
                chainId: 137,
                amount: "50",
                address: "0x9876543210fedcba9876543210fedcba98765432"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "NFT",
                    name: "Sandbox LAND",
                    decimals: 0,
                    address: "0x5CC5B05a8A13E3fBDB0BB9FcCd98D38e50F90c38"
                ),
                chainId: 137,
                amount: "1",
                address: "0x9876543210fedcba9876543210fedcba98765432"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "matic",
                symbol: "MATIC",
                name: "Polygon",
                amount: "0.01",
                usdValue: 0.008
            ),
            createdAt: Date().addingTimeInterval(-2*24*60*60),
            completedAt: Date().addingTimeInterval(-2*24*60*60 + 30),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 137,
                    hash: "0x9999999999999999999999999999999999999999999999999999999999999999",
                    status: "confirmed",
                    gasUsed: "100000"
                )
            ]
        ))
        
        // Transaction 2: Game Token Purchase
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-2",
            type: "swap",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "USDC",
                    name: "USD Coin",
                    decimals: 6,
                    address: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
                ),
                chainId: 137,
                amount: "100",
                address: "0x9876543210fedcba9876543210fedcba98765432"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "MANA",
                    name: "Decentraland MANA",
                    decimals: 18,
                    address: "0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4"
                ),
                chainId: 137,
                amount: "200",
                address: "0x9876543210fedcba9876543210fedcba98765432"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "matic",
                symbol: "MATIC",
                name: "Polygon",
                amount: "0.005",
                usdValue: 0.004
            ),
            createdAt: Date().addingTimeInterval(-5*24*60*60),
            completedAt: Date().addingTimeInterval(-5*24*60*60 + 45),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 137,
                    hash: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    status: "confirmed",
                    gasUsed: "80000"
                )
            ]
        ))
        
        // Transaction 3: Bridge from Ethereum
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-3",
            type: "bridge",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 1,
                amount: "0.5",
                address: "0x9876543210fedcba9876543210fedcba98765432"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "ETH",
                    name: "Ethereum",
                    decimals: 18,
                    address: nil
                ),
                chainId: 137,
                amount: "0.5",
                address: "0x9876543210fedcba9876543210fedcba98765432"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "eth",
                symbol: "ETH",
                name: "Ethereum",
                amount: "0.01",
                usdValue: 19.0
            ),
            createdAt: Date().addingTimeInterval(-7*24*60*60),
            completedAt: Date().addingTimeInterval(-7*24*60*60 + 600),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 1,
                    hash: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    status: "confirmed",
                    gasUsed: "100000"
                ),
                TransactionHistory.OnChainTransaction(
                    chainId: 137,
                    hash: "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                    status: "confirmed",
                    gasUsed: "50000"
                )
            ]
        ))
        
        // Transaction 4: Gaming Item Purchase
        transactions.append(TransactionHistory.TransactionItem(
            operationSetId: "\(profileId)-tx-4",
            type: "nft_purchase",
            status: "completed",
            from: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "MATIC",
                    name: "Polygon",
                    decimals: 18,
                    address: nil
                ),
                chainId: 137,
                amount: "25",
                address: "0x9876543210fedcba9876543210fedcba98765432"
            ),
            to: TransactionHistory.TransactionEndpoint(
                token: TransactionHistory.TokenInfo(
                    symbol: "NFT",
                    name: "Decentraland Wearable",
                    decimals: 0,
                    address: "0xF87E31492Faf9A91B02Ee0dEAAd50d51d56D5d4d"
                ),
                chainId: 137,
                amount: "1",
                address: "0x9876543210fedcba9876543210fedcba98765432"
            ),
            gasToken: TransactionHistory.GasTokenUsed(
                tokenId: "matic",
                symbol: "MATIC",
                name: "Polygon",
                amount: "0.008",
                usdValue: 0.006
            ),
            createdAt: Date().addingTimeInterval(-10*24*60*60),
            completedAt: Date().addingTimeInterval(-10*24*60*60 + 60),
            transactions: [
                TransactionHistory.OnChainTransaction(
                    chainId: 137,
                    hash: "0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
                    status: "confirmed",
                    gasUsed: "90000"
                )
            ]
        ))
        
        // Add a few more gaming-related transactions
        for i in 5...10 {
            let daysAgo = Double(i + 5)
            let gameTokens = ["AXS", "SAND", "MANA", "GALA", "ENJ"]
            
            transactions.append(TransactionHistory.TransactionItem(
                operationSetId: "\(profileId)-tx-\(i)",
                type: i % 2 == 0 ? "swap" : "nft_purchase",
                status: "completed",
                from: TransactionHistory.TransactionEndpoint(
                    token: TransactionHistory.TokenInfo(
                        symbol: i % 2 == 0 ? "MATIC" : "USDC",
                        name: i % 2 == 0 ? "Polygon" : "USD Coin",
                        decimals: i % 2 == 0 ? 18 : 6,
                        address: i % 2 == 0 ? nil : "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
                    ),
                    chainId: 137,
                    amount: String(Int.random(in: 10...100)),
                    address: "0x9876543210fedcba9876543210fedcba98765432"
                ),
                to: TransactionHistory.TransactionEndpoint(
                    token: TransactionHistory.TokenInfo(
                        symbol: i % 2 == 0 ? gameTokens.randomElement()! : "NFT",
                        name: "Gaming Token",
                        decimals: i % 2 == 0 ? 18 : 0,
                        address: nil
                    ),
                    chainId: 137,
                    amount: i % 2 == 0 ? String(Int.random(in: 50...500)) : "1",
                    address: "0x9876543210fedcba9876543210fedcba98765432"
                ),
                gasToken: TransactionHistory.GasTokenUsed(
                    tokenId: "matic",
                    symbol: "MATIC",
                    name: "Polygon",
                    amount: String(format: "%.3f", Double.random(in: 0.001...0.01)),
                    usdValue: Double.random(in: 0.001...0.008)
                ),
                createdAt: Date().addingTimeInterval(-daysAgo*24*60*60),
                completedAt: Date().addingTimeInterval(-daysAgo*24*60*60 + 60),
                transactions: [
                    TransactionHistory.OnChainTransaction(
                        chainId: 137,
                        hash: "0x\(String(repeating: "e\(i)", count: 32))",
                        status: "confirmed",
                        gasUsed: String(Int.random(in: 50000...150000))
                    )
                ]
            ))
        }
        
        return transactions.sorted { $0.createdAt > $1.createdAt }
    }
}