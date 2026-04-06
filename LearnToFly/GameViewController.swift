//
//  GameViewController.swift
//  CloudCatch
//
//  Created by AFP PAR 06 on 12/03/26.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func loadView() {
        view = SKView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        presentInitialSceneIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        presentInitialSceneIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 26.0, *) {
            setNeedsUpdateOfPrefersInterfaceOrientationLocked()
        }
    }

    private func presentInitialSceneIfNeeded() {
        guard let skView = view as? SKView else { return }

        if skView.scene == nil || skView.scene?.size != skView.bounds.size {
            let scene = IntroScene(size: skView.bounds.size)
            scene.scaleMode = .aspectFill
            skView.presentScene(scene)
        }

        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.showsPhysics = false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return false
    }

    @available(iOS 26.0, *)
    override var prefersInterfaceOrientationLocked: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
