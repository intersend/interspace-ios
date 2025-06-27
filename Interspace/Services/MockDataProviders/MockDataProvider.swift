import Foundation
import SwiftUI

/// Main mock data provider for demo mode
class MockDataProvider {
    static let shared = MockDataProvider()
    
    private(set) var demoProfiles: [SmartProfile] = []
    private(set) var currentProfile: SmartProfile?
    private var appsByProfile: [String: [BookmarkedApp]] = [:]
    private var foldersByProfile: [String: [AppFolder]] = [:]
    private var balancesByProfile: [String: UnifiedBalance] = [:]
    private var transactionsByProfile: [String: [TransactionHistory.TransactionItem]] = [:]
    private var nftsByProfile: [String: [NFTCollection]] = [:]
    private var linkedAccountsByProfile: [String: [LinkedAccount]] = [:]
    
    private init() {
        setupDemoData()
    }
    
    private func setupDemoData() {
        // Create demo profiles
        let aliceProfile = createAliceProfile()
        let bobProfile = createBobProfile()  
        let carolProfile = createCarolProfile()
        
        demoProfiles = [aliceProfile, bobProfile, carolProfile]
        currentProfile = aliceProfile
        
        // Setup apps for each profile
        setupAliceApps(profileId: aliceProfile.id)
        setupBobApps(profileId: bobProfile.id)
        setupCarolApps(profileId: carolProfile.id)
        
        // Setup wallet data for each profile
        setupAliceWallet(profile: aliceProfile)
        setupBobWallet(profile: bobProfile)
        setupCarolWallet(profile: carolProfile)
        
        // Setup linked accounts
        setupLinkedAccounts()
    }
    
    // MARK: - Profile Creation
    
    private func createAliceProfile() -> SmartProfile {
        SmartProfile(
            id: "alice-work-profile",
            name: "Alice's Work Profile",
            isActive: true,
            sessionWalletAddress: "0x1234567890abcdef1234567890abcdef12345678",
            linkedAccountsCount: 2,
            appsCount: 6,
            foldersCount: 2,
            isDevelopmentWallet: true,
            clientShare: nil,
            createdAt: Date().addingTimeInterval(-30*24*60*60),
            updatedAt: Date()
        )
    }
    
    private func createBobProfile() -> SmartProfile {
        SmartProfile(
            id: "bob-defi-profile",
            name: "Bob's DeFi Profile",
            isActive: false,
            sessionWalletAddress: "0xabcdef1234567890abcdef1234567890abcdef12",
            linkedAccountsCount: 3,
            appsCount: 8,
            foldersCount: 1,
            isDevelopmentWallet: true,
            clientShare: nil,
            createdAt: Date().addingTimeInterval(-45*24*60*60),
            updatedAt: Date()
        )
    }
    
    private func createCarolProfile() -> SmartProfile {
        SmartProfile(
            id: "carol-gaming-profile",
            name: "Carol's Gaming Profile",
            isActive: false,
            sessionWalletAddress: "0x9876543210fedcba9876543210fedcba98765432",
            linkedAccountsCount: 1,
            appsCount: 5,
            foldersCount: 0,
            isDevelopmentWallet: true,
            clientShare: nil,
            createdAt: Date().addingTimeInterval(-15*24*60*60),
            updatedAt: Date()
        )
    }
    
    // MARK: - Apps Setup
    
    private func setupAliceApps(profileId: String) {
        let productivityFolder = AppFolder(
            id: "\(profileId)-productivity",
            name: "Productivity",
            color: "#FF6B6B",
            position: 0,
            isPublic: false,
            appsCount: 4,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let communicationFolder = AppFolder(
            id: "\(profileId)-communication",
            name: "Communication",
            color: "#4ECDC4",
            position: 1,
            isPublic: false,
            appsCount: 2,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let apps = [
            BookmarkedApp(
                id: "\(profileId)-notion",
                name: "Notion",
                url: "https://notion.so",
                iconUrl: "https://www.notion.so/images/favicon.ico",
                position: 0,
                folderId: productivityFolder.id,
                folderName: productivityFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-github",
                name: "GitHub",
                url: "https://github.com",
                iconUrl: "https://github.githubassets.com/favicons/favicon.png",
                position: 1,
                folderId: productivityFolder.id,
                folderName: productivityFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-linear",
                name: "Linear",
                url: "https://linear.app",
                iconUrl: "https://linear.app/favicon.ico",
                position: 2,
                folderId: productivityFolder.id,
                folderName: productivityFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-figma",
                name: "Figma",
                url: "https://figma.com",
                iconUrl: "https://static.figma.com/app/icon/1/favicon.png",
                position: 3,
                folderId: productivityFolder.id,
                folderName: productivityFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-slack",
                name: "Slack",
                url: "https://slack.com",
                iconUrl: "https://a.slack-edge.com/80588/marketing/img/icons/icon_slack_hash_colored.png",
                position: 0,
                folderId: communicationFolder.id,
                folderName: communicationFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-gmail",
                name: "Gmail",
                url: "https://mail.google.com",
                iconUrl: "https://ssl.gstatic.com/ui/v1/icons/mail/rfr/gmail.ico",
                position: 1,
                folderId: communicationFolder.id,
                folderName: communicationFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        appsByProfile[profileId] = apps
        foldersByProfile[profileId] = [productivityFolder, communicationFolder]
    }
    
    private func setupBobApps(profileId: String) {
        let defiFolder = AppFolder(
            id: "\(profileId)-defi",
            name: "DeFi Tools",
            color: "#A8E6CF",
            position: 0,
            isPublic: false,
            appsCount: 6,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let apps = [
            BookmarkedApp(
                id: "\(profileId)-uniswap",
                name: "Uniswap",
                url: "https://app.uniswap.org",
                iconUrl: "https://app.uniswap.org/favicon.png",
                position: 0,
                folderId: defiFolder.id,
                folderName: defiFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-aave",
                name: "Aave",
                url: "https://app.aave.com",
                iconUrl: "https://app.aave.com/favicon.ico",
                position: 1,
                folderId: defiFolder.id,
                folderName: defiFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-compound",
                name: "Compound",
                url: "https://app.compound.finance",
                iconUrl: "https://app.compound.finance/images/favicon.ico",
                position: 2,
                folderId: defiFolder.id,
                folderName: defiFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-coingecko",
                name: "CoinGecko",
                url: "https://www.coingecko.com",
                iconUrl: "https://static.coingecko.com/s/coingecko-logo-8903d34ce19ca4be1c81f0db30e924154750d208683fad7ae6f2ce06c76d0a56.png",
                position: 3,
                folderId: defiFolder.id,
                folderName: defiFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-zapper",
                name: "Zapper",
                url: "https://zapper.xyz",
                iconUrl: "https://zapper.xyz/images/favicon.png",
                position: 4,
                folderId: defiFolder.id,
                folderName: defiFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-1inch",
                name: "1inch",
                url: "https://app.1inch.io",
                iconUrl: "https://app.1inch.io/assets/favicon/favicon.png",
                position: 5,
                folderId: defiFolder.id,
                folderName: defiFolder.name,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-rainbow",
                name: "Rainbow",
                url: "https://rainbow.me",
                iconUrl: "https://rainbow.me/img/rainbow.png",
                position: 6,
                folderId: nil,
                folderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-etherscan",
                name: "Etherscan",
                url: "https://etherscan.io",
                iconUrl: "https://etherscan.io/images/favicon3.ico",
                position: 7,
                folderId: nil,
                folderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        appsByProfile[profileId] = apps
        foldersByProfile[profileId] = [defiFolder]
    }
    
    private func setupCarolApps(profileId: String) {
        let apps = [
            BookmarkedApp(
                id: "\(profileId)-discord",
                name: "Discord",
                url: "https://discord.com",
                iconUrl: "https://discord.com/assets/favicon.ico",
                position: 0,
                folderId: nil,
                folderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-twitch",
                name: "Twitch",
                url: "https://twitch.tv",
                iconUrl: "https://static.twitchcdn.net/assets/favicon-32-e29e246c157142c94346.png",
                position: 1,
                folderId: nil,
                folderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-opensea",
                name: "OpenSea",
                url: "https://opensea.io",
                iconUrl: "https://opensea.io/static/images/logos/opensea-logo.png",
                position: 2,
                folderId: nil,
                folderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-steam",
                name: "Steam",
                url: "https://store.steampowered.com",
                iconUrl: "https://store.steampowered.com/favicon.ico",
                position: 3,
                folderId: nil,
                folderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            BookmarkedApp(
                id: "\(profileId)-epicgames",
                name: "Epic Games",
                url: "https://www.epicgames.com",
                iconUrl: "https://static-assets-prod.epicgames.com/epic-store/static/favicon.ico",
                position: 4,
                folderId: nil,
                folderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        appsByProfile[profileId] = apps
        foldersByProfile[profileId] = []
    }
    
    // MARK: - Wallet Setup
    
    private func setupAliceWallet(profile: SmartProfile) {
        // Will be implemented in next file
    }
    
    private func setupBobWallet(profile: SmartProfile) {
        // Will be implemented in next file
    }
    
    private func setupCarolWallet(profile: SmartProfile) {
        // Will be implemented in next file
    }
    
    private func setupLinkedAccounts() {
        // Will be implemented in next file
    }
    
    // MARK: - Public Methods
    
    func switchProfile(to profile: SmartProfile) {
        currentProfile = profile
    }
    
    func getApps(for profileId: String) -> [BookmarkedApp] {
        return appsByProfile[profileId] ?? []
    }
    
    func getFolders(for profileId: String) -> [AppFolder] {
        return foldersByProfile[profileId] ?? []
    }
    
    func getBalance(for profileId: String) -> UnifiedBalance? {
        return balancesByProfile[profileId]
    }
    
    func getTransactions(for profileId: String) -> [TransactionHistory.TransactionItem] {
        return transactionsByProfile[profileId] ?? []
    }
    
    func getNFTCollections(for profileId: String) -> [NFTCollection] {
        return nftsByProfile[profileId] ?? []
    }
    
    func getLinkedAccounts(for profileId: String) -> [LinkedAccount] {
        return linkedAccountsByProfile[profileId] ?? []
    }
}