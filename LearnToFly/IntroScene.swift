//
//  IntroScene.swift
//  CloudCatch
//
//  Created by Codex on 26/03/26.
//

import SpriteKit

final class IntroScene: SKScene {
    private let vignetteNames = ["vig1", "vig2", "vig3", "vig4"]
    private var currentIndex = 0
    private var vignetteNode: SKSpriteNode?
    private var isTransitioning = false

    override func didMove(to view: SKView) {
        backgroundColor = .black
        AudioManager.shared.playBackgroundMusic(
            named: "intro",
            fileExtension: "mp3",
            targetVolume: 0.22,
            fadeInDuration: 0.5
        )
        showVignette(at: currentIndex, animated: false)
        addTapHint()
    }

    private func addTapHint() {
        let hint = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hint.text = "Tap to continue"
        hint.fontSize = 22
        hint.fontColor = .white
        hint.alpha = 0.85
        hint.position = CGPoint(x: size.width * 0.5, y: size.height * 0.08)
        hint.zPosition = 50
        hint.name = "tapHint"
        addChild(hint)

        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.35, duration: 0.6),
            .fadeAlpha(to: 0.85, duration: 0.6)
        ])
        hint.run(.repeatForever(pulse))
    }

    private func makeVignetteNode(named name: String) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: name)
        node.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        node.zPosition = 10

        let textureSize = node.texture?.size() ?? CGSize(width: 1, height: 1)
        let scale = min(size.width / textureSize.width, size.height / textureSize.height)
        node.setScale(scale)
        return node
    }

    private func showVignette(at index: Int, animated: Bool) {
        guard vignetteNames.indices.contains(index) else { return }
        let nextNode = makeVignetteNode(named: vignetteNames[index])

        guard animated, let previousNode = vignetteNode else {
            vignetteNode?.removeFromParent()
            addChild(nextNode)
            vignetteNode = nextNode
            return
        }

        nextNode.alpha = 0.0
        addChild(nextNode)
        nextNode.run(.fadeIn(withDuration: 0.25))
        previousNode.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        vignetteNode = nextNode
    }

    private func goToMenuScene() {
        guard !isTransitioning else { return }
        isTransitioning = true

        let flash = SKSpriteNode(color: .white, size: size)
        flash.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        flash.zPosition = 100
        flash.alpha = 0.0
        addChild(flash)

        let flashAction = SKAction.sequence([
            .fadeAlpha(to: 0.7, duration: 0.12),
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ])
        flash.run(flashAction)

        vignetteNode?.run(.group([
            .scale(to: (vignetteNode?.xScale ?? 1.0) * 1.05, duration: 0.28),
            .fadeAlpha(to: 0.0, duration: 0.28)
        ]))

        run(.sequence([
            .wait(forDuration: 0.30),
            .run { [weak self] in
                guard let self else { return }
                AudioManager.shared.stopBackgroundMusic()
                let menu = MenuScene(size: self.size)
                menu.scaleMode = .aspectFill
                self.view?.presentScene(menu, transition: .fade(withDuration: 0.45))
            }
        ]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTransitioning else { return }

        if currentIndex < vignetteNames.count - 1 {
            currentIndex += 1
            showVignette(at: currentIndex, animated: true)
        } else {
            goToMenuScene()
        }
    }
}

