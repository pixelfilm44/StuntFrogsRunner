//
//  GameViewController.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 11/20/25.
//


import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("📱 GameViewController: viewDidLoad() called")
        print("   View type: \(type(of: self.view))")
        print("   View bounds: \(self.view.bounds)")
        
        // Note: The Coordinator sets self.view to be the SKView.
        // We configure specific view properties here if they weren't set by the coordinator.
        if let skView = self.view as? SKView {
            print("✅ GameViewController: View is SKView")
            print("   SKView frame: \(skView.frame)")
            print("   SKView scene: \(String(describing: skView.scene))")
            
            // Debug info for development builds
            #if DEBUG
            skView.showsFPS = true
            skView.showsNodeCount = true
            #endif
            
            skView.ignoresSiblingOrder = true
        } else {
            print("❌ GameViewController: View is NOT SKView!")
        }
    }

    // MARK: - Configuration
    
    // Lock to Portrait for "Vertical Endless Hopper" genre
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }

    // Hide status bar for immersive experience
    override var prefersStatusBarHidden: Bool {
        return true
    }
}