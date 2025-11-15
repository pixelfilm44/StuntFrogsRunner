import UIKit
import SpriteKit

class GameViewController: UIViewController {
    
    var skView: SKView!
    
    // Always hide the status bar for full-screen gameplay
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // Always hide the Home indicator during gameplay
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? { return nil }
    
    // Always defer system edge gestures only on the bottom edge
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.bottom]
    }
    
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? { return nil }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func loadView() {
        // Create the main view that fills the entire window
        let mainView = UIView()
        mainView.backgroundColor = .black
        self.view = mainView
        print("🐸 GameViewController: loadView called")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🐸 GameViewController: viewDidLoad called")
        print("📱 View bounds: \(view.bounds)")
        
        // Ensure content extends to all edges
        if #available(iOS 11.0, *) {
            view.insetsLayoutMarginsFromSafeArea = false
        }
        
        // Extend layout to all edges (under status bar, home indicator, etc.)
        self.edgesForExtendedLayout = .all
        self.extendedLayoutIncludesOpaqueBars = true
        
        if #available(iOS 11.0, *) {
            self.viewRespectsSystemMinimumLayoutMargins = false
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update SKView frame to fill entire screen
        if let skView = skView {
            skView.frame = view.bounds
            print("📐 SKView frame updated: \(skView.frame)")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🐸 GameViewController: viewWillAppear")
        // Ask iOS to re-query our gesture deferral preferences
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("🐸 GameViewController: viewDidAppear")
        print("📐 View bounds at appear: \(view.bounds)")
        
        // Create SKView now that we have proper bounds
        if skView == nil {
            skView = SKView(frame: view.bounds)
            skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            // Allow multi-touch for gameplay gestures
            skView.isMultipleTouchEnabled = true
            view.addSubview(skView)
            
            print("✅ SKView created with frame: \(skView.frame)")
        }
        
        // Make sure we have a valid size
        guard skView.bounds.width > 0 && skView.bounds.height > 0 else {
            print("❌ ERROR: SKView has zero size!")
            return
        }
        
        print("📐 Final SKView size: \(skView.bounds.size)")
        
        // Only present scene once
        guard skView.scene == nil else {
            print("⚠️ Scene already presented")
            // Re-assert our system gesture deferral on re-appear
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            return
        }
        
        // Create and present scene with additional safety checks
        guard let skView = skView else {
            print("❌ ERROR: SKView is nil!")
            return
        }
        
        let sceneSize = skView.bounds.size
        guard sceneSize.width > 0 && sceneSize.height > 0 else {
            print("❌ ERROR: Invalid scene size: \(sceneSize)")
            return
        }
        
        let scene = GameScene(size: sceneSize)
        scene.scaleMode = .aspectFill
        
        print("🎮 Creating GameScene with size: \(scene.size)")
        
        // Debug options
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.showsDrawCount = true
        
        print("🎮 Presenting GameScene...")
        
        // Add crash detection around scene presentation
        print("🎮 About to present scene...")
        
        // Ensure we're on main thread
        DispatchQueue.main.async { [weak self, weak skView] in
            guard let self = self, let skView = skView else {
                print("❌ ERROR: Self or SKView deallocated before scene presentation")
                return
            }
            
            do {
                skView.presentScene(scene)
                print("✅ Scene presented successfully")
                
                // Verify scene was presented
                if let presentedScene = skView.scene {
                    print("✅ GameScene presented successfully!")
                    print("🎮 Scene size: \(presentedScene.size)")
                    print("🎮 Scene scale mode: \(presentedScene.scaleMode.rawValue)")
                } else {
                    print("❌ ERROR: Scene was not presented!")
                }
            } catch {
                print("❌ CRASH during scene presentation: \(error)")
                return
            }
        }

        
        // Ensure the system applies our gesture deferral now that the view is active
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
}
