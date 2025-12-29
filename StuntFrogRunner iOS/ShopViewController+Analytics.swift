//
//  ShopViewController+Analytics.swift
//  StuntFrogRunner iOS
//
//  Analytics integration for shop and purchase tracking
//

import Foundation

extension ShopViewController {
    
    // MARK: - Shop Analytics Methods
    
    /// Track when shop is viewed
    func trackShopViewed() {
        AnalyticsManager.shared.trackShopView()
    }
    
    /// Track upgrade purchase
    func trackUpgradePurchased(upgradeName: String, newLevel: Int, cost: Int) {
        AnalyticsManager.shared.trackUpgradePurchase(
            upgradeName: upgradeName,
            level: newLevel,
            cost: cost
        )
    }
    
    /// Track consumable purchase (4-pack items)
    func trackConsumablePurchased(itemType: String, quantity: Int = 4, cost: Int) {
        AnalyticsManager.shared.trackConsumablePurchase(
            itemType: itemType,
            quantity: quantity,
            cost: cost
        )
    }
    
    /// Track IAP purchase (if you add real money purchases)
    func trackIAPPurchase(productId: String, price: Double, currency: String, itemName: String) {
        AnalyticsManager.shared.trackPurchase(
            productId: productId,
            price: price,
            currency: currency,
            itemName: itemName
        )
    }
}

// MARK: - Integration Guide for ShopViewController

/*
 
 INTEGRATION INSTRUCTIONS FOR ShopViewController.swift
 ======================================================
 
 1. ADD viewDidLoad() or viewWillAppear() tracking:
    ─────────────────────────────────────────────────────
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        trackShopViewed()
    }
 
 
 2. ADD to upgrade purchase handling:
    ─────────────────────────────────────────────────────
    // When user taps upgrade button and purchase succeeds:
    @objc private func handleUpgradePurchase(_ sender: UIButton) {
        // ... existing purchase logic ...
        
        if canAfford && purchaseSucceeds {
            // Track the purchase
            trackUpgradePurchased(
                upgradeName: upgradeType,  // e.g., "jump_power", "health"
                newLevel: newLevel,
                cost: upgradeCost
            )
        }
    }
 
 
 3. ADD to consumable purchase handling:
    ─────────────────────────────────────────────────────
    // When user buys consumable 4-packs:
    @objc private func handleConsumablePurchase(_ sender: UIButton) {
        // ... existing purchase logic ...
        
        if canAfford && purchaseSucceeds {
            trackConsumablePurchased(
                itemType: itemType,  // e.g., "ROCKET", "VEST", "HONEY"
                quantity: 4,
                cost: itemCost
            )
        }
    }
 
 
 4. EXAMPLE FULL INTEGRATION for upgrade:
    ─────────────────────────────────────────────────────
    @objc private func didTapJumpUpgrade() {
        let currentLevel = PersistenceManager.shared.jumpLevel
        let cost = ShopPricing.jumpUpgradeCost(level: currentLevel)
        let currentCoins = PersistenceManager.shared.totalCoins
        
        guard currentCoins >= cost else {
            // Show insufficient funds alert
            return
        }
        
        // Make purchase
        PersistenceManager.shared.totalCoins -= cost
        PersistenceManager.shared.jumpLevel += 1
        
        // Track analytics
        trackUpgradePurchased(
            upgradeName: "jump_power",
            newLevel: currentLevel + 1,
            cost: cost
        )
        
        // Update UI
        updateShopDisplay()
    }
 
 
 5. EXAMPLE for consumable purchase:
    ─────────────────────────────────────────────────────
    @objc private func didTapRocketPack() {
        let cost = 100  // Example cost
        let currentCoins = PersistenceManager.shared.totalCoins
        
        guard currentCoins >= cost else {
            // Show insufficient funds alert
            return
        }
        
        // Make purchase
        PersistenceManager.shared.totalCoins -= cost
        PersistenceManager.shared.rocketCount += 4
        
        // Track analytics
        trackConsumablePurchased(
            itemType: "ROCKET",
            quantity: 4,
            cost: cost
        )
        
        // Update UI
        updateShopDisplay()
    }
 
*/

// MARK: - PersistenceManager Analytics Extension

extension PersistenceManager {
    
    /// Track when coins are earned
    func trackCoinsEarned(amount: Int, source: String) {
        AnalyticsManager.shared.trackSpecialEvent(
            name: "coins_earned",
            parameters: [
                "amount": amount,
                "source": source  // e.g., "gameplay", "challenge", "treasure_chest"
            ]
        )
    }
    
    /// Update player level tracking
    func updatePlayerLevelTracking() {
        // Calculate an aggregate player level based on upgrades
        let totalLevel = jumpLevel + healthLevel + rocketCount + vestCount
        AnalyticsManager.shared.setPlayerLevel(level: totalLevel)
    }
    
    /// Update total games played tracking
    func trackGamePlayed() {
        let gamesPlayed = totalGamesPlayed + 1
        AnalyticsManager.shared.setTotalGamesPlayed(count: gamesPlayed)
        
        // Update player type based on games played
        let playerType: PlayerType
        switch gamesPlayed {
        case 0..<5:
            playerType = .new
        case 5..<20:
            playerType = .casual
        case 20..<50:
            playerType = .regular
        case 50..<100:
            playerType = .dedicated
        default:
            playerType = .veteran
        }
        AnalyticsManager.shared.setPlayerType(type: playerType)
    }
}

/*
 
 INTEGRATION INSTRUCTIONS FOR PersistenceManager.swift
 ======================================================
 
 1. ADD tracking when coins are awarded:
    ─────────────────────────────────────────────────────
    // After awarding coins from gameplay:
    func awardCoins(amount: Int, from source: String) {
        totalCoins += amount
        trackCoinsEarned(amount: amount, source: source)
    }
 
 
 2. ADD tracking after purchases:
    ─────────────────────────────────────────────────────
    // After any upgrade purchase:
    updatePlayerLevelTracking()
 
 
 3. ADD game played tracking:
    ─────────────────────────────────────────────────────
    // At the start of each game (in GameScene.resetGame or similar):
    PersistenceManager.shared.trackGamePlayed()
 
*/
