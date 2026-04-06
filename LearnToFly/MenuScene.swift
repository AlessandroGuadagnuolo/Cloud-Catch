//
//  MenuScene.swift
//  CloudCatch
//
//  Created on 12/03/26.
//

import SpriteKit // Framework SpriteKit
import UIKit

class MenuScene: SKScene { // Classe della scena menu
    private let playButtonName = "playButton" // Nome del bottone per giocare
    private var isStartingGame = false

    override func didMove(to view: SKView) { // Chiamato quando la scena appare
        backgroundColor = SKColor(red: 0.63, green: 0.82, blue: 0.98, alpha: 1.0) // Colore del cielo
        addBackground() // Aggiunge lo sfondo
        addPlayButton() // Aggiunge il pulsante Play
        AudioManager.shared.playBackgroundMusic(
            named: "menu",
            fileExtension: "mp3",
            targetVolume: 0.25,
            fadeInDuration: 0.5
        )
    }

    private func addBackground() { // Crea lo sfondo
        let backgroundTexture = menuBackgroundTexture()
        let background = SKSpriteNode(texture: backgroundTexture) // usa l'immagine come sfondo
        background.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5) // Centra l'immagine
        background.zPosition = -10 // La mette dietro a tutto il resto

        let textureSize = background.texture?.size() ?? CGSize(width: 1, height: 1) // Dimensioni sicure
        let scale = max(size.width / textureSize.width, size.height / textureSize.height) // Riempie lo schermo
        background.setScale(scale) // Applica la scala

        addChild(background) // Aggiunge alla scena
    }

    private func menuBackgroundTexture() -> SKTexture {
        // Usiamo sempre lo sfondo iPad. I nomi alternativi coprono differenze di maiuscole/spazi.
        let candidates = [
            "schermata iniziale Ipad",
            "schermata iniziale iPad",
            "Schermata iniziale Ipad",
            "Schermata iniziale iPad",
            "menu_bg"
        ]

        for name in candidates {
            let texture = SKTexture(imageNamed: name)
            if texture.size().width > 1 && texture.size().height > 1 {
                return texture
            }
        }

        return SKTexture(imageNamed: "menu_bg")
    }

    private func addPlayButton() { // Crea il pulsante Play
        // Tap target invisibile: resta cliccabile ma non visibile.
        let buttonSize = CGSize(width: size.width * 0.36, height: size.height * 0.12)
        let button = SKSpriteNode(color: .clear, size: buttonSize)
        button.alpha = 0.01
        button.position = CGPoint(x: size.width * 0.5, y: size.height * 0.38 + playButtonYOffset())
        button.name = playButtonName
        addChild(button)
    }

    private func playButtonYOffset() -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 350
        }
        return 220
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { // Gestisce il tap
        guard !isStartingGame else { return }
        guard let touch = touches.first else { return } // Prende il primo tocco
        let location = touch.location(in: self) // Punto del tocco
        let nodesAtPoint = nodes(at: location) // Nodi sotto il tocco

        if nodesAtPoint.contains(where: { $0.name == playButtonName }) { // Se ha toccato Play
            isStartingGame = true
            AudioManager.shared.fadeOutBackgroundMusic(duration: 0.5) { [weak self] in
                guard let self else { return }
                let nextScene = GameScene(size: self.size) // Crea la scena gioco
                nextScene.scaleMode = .aspectFill // Riempie lo schermo
                AudioManager.shared.playBackgroundMusic(
                    named: "music",
                    fileExtension: "mp3",
                    targetVolume: 0.05,
                    fadeInDuration: 2.5
                )
                let transition = SKTransition.fade(withDuration: 0.5) // Transizione fade
                self.view?.presentScene(nextScene, transition: transition) // Presenta la scena
            }
        }
    }
}
