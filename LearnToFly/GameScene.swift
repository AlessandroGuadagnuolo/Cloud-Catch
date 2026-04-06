//
//  GameScene.swift
//  CloudCatch
//
//  Created by AFP PAR 06 on 12/03/26.
//

import SpriteKit
import CoreMotion
import UIKit
import AudioToolbox

class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum ControlMode {
        case tilt
        case touch
    }

    private struct HUDLayout {
        let topOffset: CGFloat
        let pauseScaleWidthFactor: CGFloat
        let scoreIconScale: CGFloat
        let scoreFontSize: CGFloat
        let scoreVerticalGap: CGFloat
    }

    private let motionManager = CMMotionManager()
    private var planeNode: SKSpriteNode?
    private var monkeyNode: SKSpriteNode?
    private var planeVelocityX: CGFloat = 0.0
    private var lastUpdateTime: TimeInterval = 0.0
    private let planeCategory: UInt32 = 0x1 << 0
    private let cloudCategory:UInt32 = 0x1 << 1
    private let cloudNodeName = "cloud"
    private let goldCloudNodeName = "goldCloud"
    private let angryCloudNodeName = "angryCloud"
    private let angryTutorialShownDefaultsKey = "hasShownAngryCloudTutorialEver"
    private var areAngryCloudsUnlocked = false
    private var hasStartedAngryCloudIntro = false
    private var isAngryTutorialRunning = false
    private var score: Int = 0
    private var nextGreatJobScore: Int = 100
    private var nextDifficultyScore: Int = 20
    private var scoreLabel: SKLabelNode?
    private var energyBarContainerNode: SKSpriteNode? // Sfondo barra energia (contenitore).
    private var energyBarFillNode: SKSpriteNode? // Riempimento interno che cresce/diminuisce.
    private var multiplierLabel: SKLabelNode? // Label che mostra x1/x2/x10.
    private var catchCloudsHintLabel: SKLabelNode?
    private let energyMin: CGFloat = 0 // Valore minimo consentito per la barra.
    private let energyMax: CGFloat = 100 // Valore massimo consentito per la barra.
    private let energyX2Threshold: CGFloat = 0.2
    private let energyX5Threshold: CGFloat = 0.5
    private let energyX10Threshold: CGFloat = 0.9
    private let energyCloudGain: CGFloat = 5 // Incremento energia con cloud normale.
    private let energyGoldCloudGain: CGFloat = 9 // Incremento energia con gold cloud.
    private let energyAngryCloudLoss: CGFloat = 14 // Decremento energia con angry cloud.
    private var energyValue: CGFloat = 0 // Valore corrente della barra.
    private var currentMultiplier: Int = 1 // Moltiplicatore attivo in base alla barra.
    private var timeSinceLastCollectedCloud: TimeInterval = 0 // Tempo passato dall'ultima cloud presa.
    private var timeInX1Multiplier: TimeInterval = 0
    private let catchCloudsHintDelay: TimeInterval = 5.0
    private var dodgeHintRemaining: TimeInterval = 0
    private let dodgeHintMinVisibleTime: TimeInterval = 2.0
    private let passiveDrainDelay: TimeInterval = 2.0 // Ritardo prima dello scarico automatico.
    private let passiveDrainPerSecond: CGFloat = 5.5 // Scarico automatico al secondo.
    private var cloudFallDuration: TimeInterval = 6.0
    private let minCloudFallDuration: TimeInterval = 1.8
    private let fallDurationStep: TimeInterval = 0.11
    private let difficultyStepScore: Int = 20
    private let cloudSpawnInterval: TimeInterval = 1.35
    private let angryCloudProbability: Double = 0.25
    private let cloudToGoldRatio: Double = 2.0 // Cloud normale ha probabilità doppia rispetto alla gold.
    private let cloudSpawnActionKey = "cloudSpawnAction"
    private let controlSelectionNodeName = "controlSelectionOverlay"
    private let touchControlButtonNodeName = "touchControlButton"
    private let tiltControlButtonNodeName = "tiltControlButton"
    private let pauseButtonNodeName = "pauseButtonNode"
    private let continueButtonNodeName = "continueButtonNode"
    private let homeButtonNodeName = "homeButtonNode"
    private let pauseCuriosityNodeName = "pauseCuriosityNode"
    private let touchHandsTutorialNodeName = "touchHandsTutorialNode"
    private var pauseButtonNode: SKSpriteNode?
    private var pauseOverlayNode: SKNode?
    private var scoreIconNode: SKSpriteNode?
    private var scoreBackgroundNode: SKSpriteNode?
    private var controlMode: ControlMode?
    private var touchSteeringDirection: CGFloat = 0.0
    private var isGamePaused = false
    private var hasGameStarted = false
    private let backgroundNames = ["1-bg_day", "2-bg_ocean", "3-bg_sunset", "4-bg_night"]
    private var currentBgIndex: Int = 0
    private var timeSinceLastBackgroundChange: TimeInterval = 0
    private let backgroundChangeInterval: TimeInterval = 30.0
    private var currentBackgroundNode: SKSpriteNode?
    private let pauseCuriosities = [
        "Did you know that clouds can weigh\\nabout as much as 100 elephants?",
        "Did you know lightning can heat the air\\nup to five times hotter than the Sun's surface?",
        "Did you know there are over 10 cloud types\\nrecognized by meteorologists?"
    ]
    var feedback = UIImpactFeedbackGenerator(style: .heavy)

    override func didMove(to view: SKView) {
        UserDefaults.standard.removeObject(forKey: angryTutorialShownDefaultsKey) // DEBUG TEST DA RIMUOVERE
        backgroundColor = .blue
        physicsWorld.contactDelegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        setupInitialBackground()
        setupPlane()
        setupPauseButton()
        setupScoreHUD()
        setupEnergyBarUI()
        setupControlSelectionUI()
    }

    override func willMove(from view: SKView) {
        motionManager.stopAccelerometerUpdates()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupPlane() { //creazione del nodo plane
        let plane = SKSpriteNode(imageNamed: "plane")
        plane.position = CGPoint(x: size.width * 0.5, y: size.height * 0.28)
        plane.alpha = 0.0 //aereo inizialmente invisibile
        plane.zPosition = 10 //davanti agli altri oggetti, valore indicativo 10

        let baseScale = min(0.15, (size.width * 0.4) / max(plane.size.width, 1.0))
        let scale = UIDevice.current.userInterfaceIdiom == .pad ? baseScale * 1.2 : baseScale
        plane.setScale(scale)
        
        plane.physicsBody = SKPhysicsBody(
            texture: plane.texture!,
            size: plane.size
        )
        plane.physicsBody?.isDynamic = false
        plane.physicsBody?.affectedByGravity = false

        plane.physicsBody?.categoryBitMask = planeCategory //serve a dire "chi sono"
        plane.physicsBody?.contactTestBitMask = cloudCategory //quando avviene la collisione ? quando la nuvola tocca l'aereo
        plane.physicsBody?.collisionBitMask = 0 //nessun rimbalzo alla collisione
        
        addChild(plane)
        planeNode = plane
    }

    private func setupMonkey() {
        let monkey = SKSpriteNode(imageNamed: "monkey")
        monkey.zPosition = 100
        monkey.alpha = 1.0
        monkey.setScale(0.20)
        monkey.anchorPoint = CGPoint(x: 1.0, y: 1.0)
        monkey.position = CGPoint(x: size.width+20, y: size.height - 20)

        addChild(monkey)
        monkeyNode = monkey
    }
    
    private func setupCloud() -> SKSpriteNode {
        let roll = Double.random(in: 0...1)
        let currentAngryProbability: Double
        if score >= 2000 {
            currentAngryProbability = 0.35
        } else if score >= 1000 {
            currentAngryProbability = 0.30
        } else {
            currentAngryProbability = angryCloudProbability
        }
        let cloudType: (imageName: String, nodeName: String)
        if areAngryCloudsUnlocked && roll < currentAngryProbability {
            cloudType = ("angryCloud1", angryCloudNodeName)
        } else {
            let normalizedRoll: Double
            if areAngryCloudsUnlocked {
                normalizedRoll = (roll - currentAngryProbability) / (1.0 - currentAngryProbability)
            } else {
                normalizedRoll = roll
            }
            let goldShare = 1.0 / (cloudToGoldRatio + 1.0) // Con rapporto 2:1 -> gold 33.3%, cloud 66.6%.
            if normalizedRoll < goldShare {
                cloudType = ("GoldCloud", goldCloudNodeName)
            } else {
                cloudType = ("cloud", cloudNodeName)
            }
        }

        let cloud = SKSpriteNode(imageNamed: cloudType.imageName)
        cloud.name = cloudType.nodeName
        cloud.zPosition = 5

        // Range dimensione nuvole: minimo aumentato
        let minWidth = size.width * 0.15
        let maxWidth = minWidth * 2.5
        let mediumWidth = (minWidth + maxWidth) * 0.5
        let targetWidth: CGFloat = (cloud.name == goldCloudNodeName)
            ? mediumWidth
            : CGFloat.random(in: minWidth...maxWidth)

        let baseWidth = max(cloud.size.width, 1.0)
        cloud.setScale(targetWidth / baseWidth)

        // Spawn in alto con x casuale
        let minX = cloud.size.width * 0.5 + 8
        let maxX = size.width - cloud.size.width * 0.5 - 8
        let randomX = CGFloat.random(in: minX...maxX)
        cloud.position = CGPoint(x: randomX, y: size.height + cloud.size.height)

        cloud.physicsBody = SKPhysicsBody(circleOfRadius: cloud.size.width * 0.42)
        cloud.physicsBody?.isDynamic = true
        cloud.physicsBody?.affectedByGravity = false
        cloud.physicsBody?.categoryBitMask = cloudCategory
        cloud.physicsBody?.contactTestBitMask = planeCategory
        cloud.physicsBody?.collisionBitMask = 0

        if cloud.name == angryCloudNodeName {
            let frames = [
                SKTexture(imageNamed: "angryCloud1"),
                SKTexture(imageNamed: "angryCloud2"),
                SKTexture(imageNamed: "angryCloud3"),
                SKTexture(imageNamed: "angryCloud4")
            ]
            let animate = SKAction.animate(with: frames, timePerFrame: 0.12)
            cloud.run(.repeatForever(animate))
        }

        return cloud
    }

    private func triggerAngryCloudFeedback() {
      
        feedback.prepare()
        feedback.impactOccurred()
        //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        guard let plane = planeNode else { return }
        let left = SKAction.moveBy(x: -8, y: 0, duration: 0.03)
        let right = SKAction.moveBy(x: 16, y: 0, duration: 0.06)
        let back = SKAction.moveBy(x: -8, y: 0, duration: 0.03)
        plane.run(.sequence([left, right, back]))
    }

    private func makeBackgroundNode(named name: String) -> SKSpriteNode {
        let background = SKSpriteNode(imageNamed: name)
        background.zPosition = -1
        background.size = frame.size
        background.position = CGPoint(x: frame.midX, y: frame.midY)
        return background
    }

    private func setupInitialBackground() {
        guard !backgroundNames.isEmpty else { return }
        let background = makeBackgroundNode(named: backgroundNames[currentBgIndex])
        addChild(background)
        currentBackgroundNode = background
    }

    private func cycleBackground() {
        guard !backgroundNames.isEmpty else { return }
        currentBgIndex = (currentBgIndex + 1) % backgroundNames.count
        let newBackground = makeBackgroundNode(named: backgroundNames[currentBgIndex])
        newBackground.alpha = 0.0
        addChild(newBackground)

        let fadeIn = SKAction.fadeIn(withDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 1.5)
        let remove = SKAction.removeFromParent()

        newBackground.run(fadeIn)
        currentBackgroundNode?.run(SKAction.sequence([fadeOut, remove]))
        currentBackgroundNode = newBackground
    }

    private func updateBackgroundIfNeeded(deltaTime: TimeInterval) {
        guard hasGameStarted else { return }
        timeSinceLastBackgroundChange += deltaTime
        while timeSinceLastBackgroundChange >= backgroundChangeInterval {
            timeSinceLastBackgroundChange -= backgroundChangeInterval
            cycleBackground()
        }
    }

    private func showGreatJobBanner() {
        childNode(withName: "greatJobBanner")?.removeFromParent()

        let banner = SKSpriteNode(imageNamed: "greatJob")
        banner.name = "greatJobBanner"
        banner.zPosition = 500
        banner.position = CGPoint(x: frame.midX, y: frame.midY)
        banner.alpha = 0.0
        banner.setScale(0.2)
        addChild(banner)

        let popIn = SKAction.group([
            SKAction.fadeIn(withDuration: 0.12),
            SKAction.scale(to: 0.15, duration: 0.12)
        ])
        let grow = SKAction.scale(to: 0.25, duration: 0.18)
        let settle = SKAction.scale(to: 0.30, duration: 0.15)
        let wait = SKAction.wait(forDuration: 1.80)
        let fadeOut = SKAction.fadeOut(withDuration: 0.25)
        let remove = SKAction.removeFromParent()

        banner.run(SKAction.sequence([popIn, grow, settle, wait, fadeOut, remove]))
    }

    private func updateGreatJobIfNeeded() {
        guard score >= nextGreatJobScore else { return }
        guard childNode(withName: "greatJobBanner") == nil else { return }
        showGreatJobBanner()
        while score >= nextGreatJobScore {
            nextGreatJobScore = nextGreatJobMilestone(after: nextGreatJobScore)
        }
    }

    private func nextGreatJobMilestone(after currentMilestone: Int) -> Int {
        if currentMilestone < 500 {
            return currentMilestone + 100
        }
        if currentMilestone < 1000 {
            let candidate = currentMilestone + 200
            return min(candidate, 1000)
        }
        return currentMilestone + 500
    }

    private func updateAngryCloudUnlockIfNeeded() {
        guard score >= 45, !hasStartedAngryCloudIntro else { return }
        hasStartedAngryCloudIntro = true
        showAngryCloudIntro()
    }

    private func showAngryCloudIntro() {
        let altezza = size.height * 0.82
        
        let first = SKSpriteNode(imageNamed: "attention1")
        first.zPosition = 700
        first.position = CGPoint(x: frame.midX, y: altezza)
        first.alpha = 0.0
        addChild(first)

        let second = SKSpriteNode(imageNamed: "attention2")
        second.zPosition = 700
        second.position = CGPoint(x: frame.midX, y: altezza)
        second.alpha = 0.0
        addChild(second)

        first.setScale(0.2)
        second.setScale(0.2)
        
        first.run(.sequence([
            .fadeIn(withDuration: 0.25),
            .wait(forDuration: 2.5),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))

        second.run(.sequence([
            .wait(forDuration: 3.0),
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 1.6),
            .fadeOut(withDuration: 0.2),
            .run { [weak self] in
                self?.areAngryCloudsUnlocked = true
            },
            .removeFromParent()
        ]))
    }

    private func showGoldenPoints(at position: CGPoint, size: CGSize) {
        let pointsNode = SKSpriteNode(imageNamed: "goldenPoints")
        let baseWidth = max(pointsNode.size.width,1.0)
        let targetWidth = size.width
        let scale = targetWidth / baseWidth
        pointsNode.setScale(scale)
        
        pointsNode.zPosition = 50
        pointsNode.position = position
        
        
        pointsNode.alpha = 0.0
        addChild(pointsNode)

        let fadeIn = SKAction.fadeIn(withDuration: 0.08)
        let rise = SKAction.moveBy(x: 0, y: 18, duration: 0.45)
        let fadeOut = SKAction.fadeOut(withDuration: 0.35)
        let group = SKAction.group([rise, fadeOut])
        let remove = SKAction.removeFromParent()
        pointsNode.run(SKAction.sequence([fadeIn, group, remove]))
    }

    private func showLightning(at position: CGPoint, size: CGSize) {
        let lightningNode = SKSpriteNode(imageNamed: "fulmine")
        let baseWidth = max(lightningNode.size.width, 1.0)
        let targetWidth = size.width * 0.4
        let scale = targetWidth / baseWidth
        lightningNode.setScale(scale)

        lightningNode.zPosition = 55
        lightningNode.position = position
        lightningNode.alpha = 0.0
        addChild(lightningNode)

        let fadeIn = SKAction.fadeIn(withDuration: 0.08)
        let pulse = SKAction.sequence([
            SKAction.scale(to: scale * 1.08, duration: 0.08),
            SKAction.scale(to: scale, duration: 0.08)
        ])
        let wait = SKAction.wait(forDuration: 0.25)
        let fadeOut = SKAction.fadeOut(withDuration: 0.20)
        let remove = SKAction.removeFromParent()
        lightningNode.run(SKAction.sequence([fadeIn, pulse, wait, fadeOut, remove]))
    }

    private func spawnCloud() {
        let cloud = setupCloud()
        addChild(cloud)

        let fallDuration: TimeInterval
        if cloud.name == goldCloudNodeName {
            // Nuvola gold più veloce da prendere
            fallDuration = max(1.2, cloudFallDuration * 0.55)
        } else {
            fallDuration = cloudFallDuration
        }

        maybeRunAngryCloudTutorial(for: cloud, fallDuration: fallDuration)

        let moveDown = SKAction.moveTo(y: -cloud.size.height, duration: fallDuration)
        moveDown.timingMode = .linear
        let remove = SKAction.removeFromParent()
        cloud.run(.sequence([moveDown, remove]))
    }

    private func maybeRunAngryCloudTutorial(for cloud: SKSpriteNode, fallDuration: TimeInterval) {
        // continua solo se la nuvola è angry
        guard cloud.name == angryCloudNodeName else { return }
        //continua solo se il tutorial non è stato già mostrato
        guard !isAngryTutorialAlreadyShown() else { return }
        // continua solo se non è già in esecuzione
        guard !isAngryTutorialRunning else { return }

        let triggerY = size.height * 0.75
        let startY = cloud.position.y
        let endY = -cloud.size.height
        let totalDistance = max(1.0, startY - endY)
        let distanceToTrigger = max(0.0, startY - triggerY)
        let progressToTrigger = min(1.0, distanceToTrigger / totalDistance)
        let tutorialDelay = fallDuration * TimeInterval(progressToTrigger)

        let tutorialSequence = SKAction.sequence([
            .wait(forDuration: tutorialDelay),
            .run { [weak self, weak cloud] in
                guard let self, let cloud else { return }
                self.startAngryTutorialIfNeeded(on: cloud)
            }
        ])
        cloud.run(tutorialSequence, withKey: "angryTutorialTrigger")
    }

    private func startAngryTutorialIfNeeded(on cloud: SKSpriteNode) {
        guard cloud.parent != nil else { return }
        guard !isAngryTutorialAlreadyShown() else { return }
        guard !isAngryTutorialRunning else { return }

        isAngryTutorialRunning = true
        markAngryTutorialAsShown()

        let dangerNode = SKSpriteNode(imageNamed: "danger")
        dangerNode.zPosition = cloud.zPosition + 1
        let dangerWidth = cloud.size.width * 1.8
        let baseDangerWidth = max(dangerNode.size.width, 1.0)
        dangerNode.setScale(dangerWidth / baseDangerWidth)
        let verticalSpacing: CGFloat = 70.0
        dangerNode.position = CGPoint(x: 0.0, y: -(cloud.size.height * 0.5 + dangerNode.size.height * 0.5 + verticalSpacing))
        cloud.addChild(dangerNode)

        let blinkCycle = SKAction.sequence([
            .fadeOut(withDuration: 0.12),
            .fadeIn(withDuration: 0.12),
            .fadeOut(withDuration: 0.12),
            .fadeIn(withDuration: 0.12),
            .fadeOut(withDuration: 0.12),
            .fadeIn(withDuration: 0.12),
            .fadeOut(withDuration: 0.12),
            .fadeIn(withDuration: 0.12)
        ])
        dangerNode.run(.repeat(blinkCycle, count: 3))

        let previousSpeed = self.speed
        self.speed = max(0.05, previousSpeed * 0.15) // rallentamento dell'85%

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self, weak dangerNode] in
            guard let self else { return }
            self.speed = previousSpeed
            dangerNode?.removeFromParent()
            self.isAngryTutorialRunning = false
        }
    }

    private func isAngryTutorialAlreadyShown() -> Bool {
        UserDefaults.standard.bool(forKey: angryTutorialShownDefaultsKey)
    }

    private func markAngryTutorialAsShown() {
        UserDefaults.standard.set(true, forKey: angryTutorialShownDefaultsKey)
    }

    private func startCloudSpawning() {
        removeAction(forKey: cloudSpawnActionKey)
        let spawn = SKAction.run { [weak self] in
            self?.spawnCloud()
        }
        let wait = SKAction.wait(forDuration: cloudSpawnInterval)
        let sequence = SKAction.sequence([spawn, wait])
        run(.repeatForever(sequence), withKey: cloudSpawnActionKey)
    }

    private func setupScoreHUD() {
        let layout = currentHUDLayout()
        let marginX: CGFloat = 5

        if let systemImage = UIImage(systemName: "cloud.fill")?
            .withTintColor(.white, renderingMode: .alwaysOriginal) {
            let icon = SKSpriteNode(texture: SKTexture(image: systemImage))
            icon.zPosition = 200
            icon.setScale(layout.scoreIconScale*0.70)
            icon.alpha = 0.0
            let pauseY = pauseButtonNode?.position.y ?? (size.height - (view?.safeAreaInsets.top ?? 0) - layout.topOffset)
            let phoneScoreYOffset: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 0 : 14
            let scoreY = pauseY - layout.scoreVerticalGap - phoneScoreYOffset
            icon.position = CGPoint(
                x: marginX + icon.size.width * 0.5,
                y: scoreY
            )
            addChild(icon)
            scoreIconNode = icon
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = layout.scoreFontSize
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.alpha = 0.0
        let iconMaxX = scoreIconNode?.frame.maxX ?? marginX + 24
        label.position = CGPoint(x: iconMaxX + 10, y: scoreIconNode?.position.y ?? 0)
        label.zPosition = 200
        scoreLabel = label
        let sfondoPunti = SKSpriteNode(imageNamed: "sfondoPunti")
        let targetWidthFactor: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 0.30 : 0.50
        let targetWidth = size.width * targetWidthFactor
        let baseWidth = max(sfondoPunti.size.width, 1.0)
        sfondoPunti.setScale(targetWidth / baseWidth)
        sfondoPunti.zPosition = 199
        let xOffset: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? -10 : -18
        sfondoPunti.position = CGPoint(
            x: label.position.x + xOffset,
            y: label.position.y
        )
        sfondoPunti.alpha = 0.0
        scoreBackgroundNode = sfondoPunti
        addChild(sfondoPunti)
        addChild(label)

        updateScoreHUD()
    }

    private func updateScoreHUD() {
        scoreLabel?.text = "\(score)"
        scoreLabel?.fontSize = currentHUDLayout().scoreFontSize
    }

    private func setupEnergyBarUI() {
        let safeBottom = view?.safeAreaInsets.bottom ?? 0 // Safe area inferiore del dispositivo.
        let barWidth = size.width * 0.58 // Larghezza barra proporzionale allo schermo.
        let barHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 28 : 20 // Altezza diversa iPad/iPhone.
        let bottomInset = safeBottom + (UIDevice.current.userInterfaceIdiom == .pad ? 24 : 16) // Distanza dal bordo basso.

        let container = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.22), size: CGSize(width: barWidth, height: barHeight)) // Rettangolo sfondo barra.
        container.position = CGPoint(x: size.width * 0.5, y: bottomInset + barHeight * 0.5) // Posizione centrata in basso.
        container.zPosition = 190 // Livello dietro fill/label HUD.
        container.alpha = 0.0
        addChild(container) // Inserisce il contenitore nella scena.
        energyBarContainerNode = container // Salva riferimento per update successivi.

        let fill = SKSpriteNode(color: .systemBlue, size: CGSize(width: 0, height: max(2, barHeight - 6))) // Parte piena inizialmente a zero.
        fill.anchorPoint = CGPoint(x: 0, y: 0.5) // Ancora a sinistra per crescere verso destra.
        fill.position = CGPoint(x: -barWidth * 0.5 + 3, y: 0) // Allinea il fill al bordo interno sinistro.
        fill.zPosition = 191 // Davanti al contenitore.
        container.addChild(fill) // Aggiunge il fill dentro il contenitore.
        energyBarFillNode = fill // Salva riferimento per resize/color update.

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold") // Label moltiplicatore.
        label.text = "x1" // Valore iniziale moltiplicatore.
        label.fontSize = UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18 // Font responsive iPad/iPhone.
        label.fontColor = .white // Colore testo.
        label.horizontalAlignmentMode = .center // Allineamento orizzontale testo.
        label.verticalAlignmentMode = .center // Allineamento verticale testo.
        label.position = CGPoint(x: container.position.x, y: container.position.y + barHeight + 16) // Posizione sopra la barra.
        label.zPosition = 192 // Davanti alla barra.
        label.alpha = 0.0
        addChild(label) // Inserisce label nella scena.
        multiplierLabel = label // Salva riferimento per cambiare x1/x2/x10.

        let hintLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hintLabel.text = "Catch the clouds!"
        hintLabel.fontSize = UIDevice.current.userInterfaceIdiom == .pad ? 20 : 15
        hintLabel.fontColor = .white
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        hintLabel.position = CGPoint(x: container.position.x, y: container.position.y - barHeight - 16)
        hintLabel.zPosition = 192
        hintLabel.alpha = 0.0
        addChild(hintLabel)
        catchCloudsHintLabel = hintLabel

        updateEnergyBarVisual(animated: false) // Allinea grafica iniziale al valore energia corrente.
    }

    private func applyEnergyChange(_ delta: CGFloat, animated: Bool = true) {
        let newValue = min(energyMax, max(energyMin, energyValue + delta)) // Applica delta con clamp nel range 0...100.
        energyValue = newValue // Salva il nuovo valore energia.
        updateMultiplierFromEnergy() // Ricalcola x1/x2/x10 in base alla percentuale barra.
        updateEnergyBarVisual(animated: animated) // Aggiorna la UI della barra.
    }

    private func updateMultiplierFromEnergy() {
        let ratio = energyValue / energyMax // Converte energia in percentuale 0...1.
        if ratio >= energyX10Threshold {
            currentMultiplier = 10 // Da 90% in su.
        } else if ratio >= energyX5Threshold {
            currentMultiplier = 5 // Da 50% a 89%.
        } else if ratio >= energyX2Threshold {
            currentMultiplier = 2 // Da 20% a 49%.
        } else {
            currentMultiplier = 1 // Da 0% a 19%.
        }
        multiplierLabel?.text = "x\(currentMultiplier)" // Aggiorna testo visualizzato.
    }

    private func updateEnergyBarVisual(animated: Bool) {
        guard let container = energyBarContainerNode, let fill = energyBarFillNode else { return } // Esce se i nodi non sono pronti.
        let ratio = max(0, min(1, energyValue / energyMax)) // Percentuale sicura tra 0 e 1.
        let targetWidth = max(0, (container.size.width - 6) * ratio) // Larghezza finale del riempimento.

        let targetColor: SKColor // Colore barra in base alla soglia.
        if ratio >= energyX10Threshold {
            targetColor = .systemYellow // Stato massimo.
        } else if ratio >= energyX5Threshold {
            targetColor = .systemOrange // Stato alto.
        } else if ratio >= energyX2Threshold {
            targetColor = .systemGreen // Stato medio.
        } else {
            targetColor = .systemBlue // Stato base.
        }
        fill.color = targetColor // Applica il colore calcolato.

        if animated {
            fill.run(.resize(toWidth: targetWidth, duration: 0.12)) // Resize animato (collisioni).
        } else {
            fill.size.width = targetWidth // Resize immediato (drain continuo).
        }
    }

    private func baseScore(for cloudName: String) -> Int {
        if cloudName == goldCloudNodeName {
            return 10
        }
        if cloudName == cloudNodeName {
            return 1
        }
        return 0
    }

    private func handleCloudCollision(named cloudName: String, position: CGPoint, size: CGSize) {
        if cloudName == angryCloudNodeName {
            showLightning(at: position, size: size)
            triggerAngryCloudFeedback()
            applyEnergyChange(-energyAngryCloudLoss)
            dodgeHintRemaining = dodgeHintMinVisibleTime
        } else if cloudName == goldCloudNodeName {
            showGoldenPoints(at: position, size: size)
            applyEnergyChange(energyGoldCloudGain)
        } else {
            applyEnergyChange(energyCloudGain)
        }

        let awardedPoints = baseScore(for: cloudName) * currentMultiplier
        score += awardedPoints

        updateScoreHUD()
        updateGreatJobIfNeeded()
        updateAngryCloudUnlockIfNeeded()

        while score >= nextDifficultyScore {
            cloudFallDuration = max(minCloudFallDuration, cloudFallDuration - fallDurationStep)
            nextDifficultyScore += difficultyStepScore
        }

        timeSinceLastCollectedCloud = 0
    }

    private func applyPassiveEnergyDrain(deltaTime: TimeInterval) {
        guard hasGameStarted else { return } // Non scaricare energia prima dell'avvio partita.
        timeSinceLastCollectedCloud += deltaTime // Accumula tempo trascorso dall'ultima presa.
        guard timeSinceLastCollectedCloud > passiveDrainDelay else { return } // Attende il delay iniziale.
        let drained = CGFloat(deltaTime) * passiveDrainPerSecond // Calcola consumo proporzionale al frame time.
        applyEnergyChange(-drained, animated: false) // Riduce energia senza animazioni ripetute.
    }

    private func updateCatchCloudsHint(deltaTime: TimeInterval) {
        guard hasGameStarted, !isGamePaused else {
            catchCloudsHintLabel?.alpha = 0.0
            return
        }

        if dodgeHintRemaining > 0 {
            dodgeHintRemaining = max(0, dodgeHintRemaining - deltaTime)
            catchCloudsHintLabel?.text = "Dodge it! ⚡"
            catchCloudsHintLabel?.alpha = 1.0
            return
        }

        if currentMultiplier == 1 {
            timeInX1Multiplier += deltaTime
        } else {
            timeInX1Multiplier = 0
        }

        let shouldShowHint = timeInX1Multiplier >= catchCloudsHintDelay || timeSinceLastCollectedCloud >= catchCloudsHintDelay
        catchCloudsHintLabel?.text = "Catch the clouds!"
        catchCloudsHintLabel?.alpha = shouldShowHint ? 1.0 : 0.0
    }

    private func setupPauseButton() {
        let layout = currentHUDLayout()
        let button = SKSpriteNode(imageNamed: "pauseButton")
        button.name = pauseButtonNodeName
        button.zPosition = 220
        button.alpha = 0.0

        let targetWidth = size.width * layout.pauseScaleWidthFactor
        let baseWidth = max(button.size.width, 1.0)
        button.setScale(targetWidth / baseWidth)

        let x = 16 + button.size.width * 0.5
        let y = size.height - (view?.safeAreaInsets.top ?? 0) - layout.topOffset
        button.position = CGPoint(x: x, y: y)

        addChild(button)
        pauseButtonNode = button
    }

    private func currentHUDLayout() -> HUDLayout {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return HUDLayout(
                topOffset: 60, // leggermente più in basso su iPad
                pauseScaleWidthFactor: 0.12, // leggermente più grande su iPad
                scoreIconScale: 2,
                scoreFontSize: 28,
                scoreVerticalGap: 75
            )
        }

        return HUDLayout(
            topOffset: 12, // più in alto su iPhone (angolo)
            pauseScaleWidthFactor: 0.20, // circa +50% rispetto a 0.10
            scoreIconScale: 1.0,
            scoreFontSize: 20,
            scoreVerticalGap: 46
        )
    }

    private func setupPauseOverlayIfNeeded() {
        guard pauseOverlayNode == nil else { return }

        let overlay = SKNode()
        overlay.zPosition = 600

        let dim = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.45), size: size)
        dim.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        overlay.addChild(dim)

        let continueButton = SKSpriteNode(imageNamed: "playButton")
        continueButton.name = continueButtonNodeName
        continueButton.zPosition = 601
        let continueScale = (size.width * 0.40) / max(continueButton.size.width, 1.0)
        continueButton.setScale(continueScale)
        continueButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.54)
        overlay.addChild(continueButton)

        let homeButton = SKSpriteNode(imageNamed: "homeButton")
        homeButton.name = homeButtonNodeName
        homeButton.zPosition = 601
        let homeScale = (size.width * 0.40) / max(homeButton.size.width, 1.0)
        homeButton.setScale(homeScale)
        homeButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.42)
        overlay.addChild(homeButton)

        let curiosityNode = SKNode()
        curiosityNode.name = pauseCuriosityNodeName
        curiosityNode.zPosition = 602
        curiosityNode.position = CGPoint(x: size.width * 0.80, y: size.height * 0.80)

        let curiosityBackground = SKSpriteNode(
            color: SKColor(white: 0.0, alpha: 0.32),
            size: CGSize(
                width: UIDevice.current.userInterfaceIdiom == .pad ? size.width * 0.62 : size.width * 0.88,
                height: UIDevice.current.userInterfaceIdiom == .pad ? 76 : 58
            )
        )
        curiosityBackground.zPosition = -1
        curiosityNode.addChild(curiosityBackground)

        let topLine = SKLabelNode(fontNamed: "AvenirNext-Bold")
        topLine.name = "pauseCuriosityTopLine"
        topLine.fontSize = UIDevice.current.userInterfaceIdiom == .pad ? 21 : 15
        topLine.fontColor = .white
        topLine.horizontalAlignmentMode = .center
        topLine.verticalAlignmentMode = .center
        topLine.position = CGPoint(x: 0, y: 10)
        curiosityNode.addChild(topLine)

        let bottomLine = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bottomLine.name = "pauseCuriosityBottomLine"
        bottomLine.fontSize = UIDevice.current.userInterfaceIdiom == .pad ? 19 : 14
        bottomLine.fontColor = .white
        bottomLine.horizontalAlignmentMode = .center
        bottomLine.verticalAlignmentMode = .center
        bottomLine.position = CGPoint(x: 0, y: -14)
        curiosityNode.addChild(bottomLine)

        overlay.addChild(curiosityNode)

        overlay.isHidden = true
        addChild(overlay)
        pauseOverlayNode = overlay
    }

    private func updatePauseCuriosityText() {
        guard let curiosityText = pauseCuriosities.randomElement(),
              let curiosityNode = pauseOverlayNode?.childNode(withName: pauseCuriosityNodeName),
              let topLine = curiosityNode.childNode(withName: "pauseCuriosityTopLine") as? SKLabelNode,
              let bottomLine = curiosityNode.childNode(withName: "pauseCuriosityBottomLine") as? SKLabelNode else { return }

        let safeTop = view?.safeAreaInsets.top ?? 0
        let topCenterY = size.height - safeTop - 140
        curiosityNode.position = CGPoint(x: size.width * 0.5, y: topCenterY)

        let parts = curiosityText.components(separatedBy: "\\n")
        topLine.text = parts.first ?? curiosityText
        bottomLine.text = parts.count > 1 ? parts[1] : ""
    }

    private func showTouchHandsTutorial() {
        childNode(withName: touchHandsTutorialNodeName)?.removeFromParent()

        let container = SKNode()
        container.name = touchHandsTutorialNodeName
        container.zPosition = 250
        container.alpha = 0.0

        guard let symbolImage = UIImage(systemName: "hand.tap.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
        let handTexture = SKTexture(image: symbolImage)

        let leftHand = SKSpriteNode(texture: handTexture)
        leftHand.position = CGPoint(x: size.width * 0.25, y: size.height * 0.44)
        leftHand.setScale(UIDevice.current.userInterfaceIdiom == .pad ? 5 : 1.8)
        leftHand.xScale *= -1
        container.addChild(leftHand)

        let rightHand = SKSpriteNode(texture: handTexture)
        rightHand.position = CGPoint(x: size.width * 0.75, y: size.height * 0.44)
        rightHand.setScale(UIDevice.current.userInterfaceIdiom == .pad ? 5 : 1.8)
        container.addChild(rightHand)

        addChild(container)

        let blink = SKAction.sequence([
            .fadeAlpha(to: 0.20, duration: 0.60),
            .fadeAlpha(to: 0.65, duration: 0.60)
        ])
        let tutorialSequence = SKAction.sequence([
            .fadeAlpha(to: 0.65, duration: 0.30),
            .repeat(blink, count: 2),
            .fadeOut(withDuration: 0.30),
            .removeFromParent()
        ])
        container.run(tutorialSequence)
    }

    private func runCountdown() {
        let steps: [(String, TimeInterval)] = [
            ("Get ready to go..!", 1.4),
            ("3..", 1.0),
            ("2..", 1.0),
            ("1..", 1.0)
        ]

        var actions: [SKAction] = []

        for (text, duration) in steps {
            actions.append(SKAction.run { [weak self] in
                self?.showCountdownText(text: text, duration: duration)
            })
            actions.append(SKAction.wait(forDuration: duration))
        }

        actions.append(SKAction.run { [weak self] in
            self?.startTutorialAndPlane()
        })

        run(SKAction.sequence(actions))
    }

    private func setupControlSelectionUI() {
        childNode(withName: controlSelectionNodeName)?.removeFromParent()

        let overlay = SKNode()
        overlay.name = controlSelectionNodeName
        overlay.zPosition = 800

        let dim = SKSpriteNode(color: SKColor(white: 0.0, alpha: 0.55), size: size)
        dim.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        overlay.addChild(dim)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Select Control"
        title.fontSize = 34
        title.fontColor = .white
        title.position = CGPoint(x: size.width * 0.5, y: size.height * 0.70)
        title.zPosition = 801
        overlay.addChild(title)

        let touchButton = makeControlButton(imageName: "touch", nodeName: touchControlButtonNodeName, widthFactor: 0.36)
        touchButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.38)
        overlay.addChild(touchButton)

        let tiltButton = makeControlButton(imageName: "tilt", nodeName: tiltControlButtonNodeName, widthFactor: 0.36)
        tiltButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.22)
        overlay.addChild(tiltButton)

        addChild(overlay)
    }

    private func makeControlButton(imageName: String, nodeName: String, widthFactor: CGFloat) -> SKSpriteNode {
        let button = SKSpriteNode(imageNamed: imageName)
        button.name = nodeName
        button.zPosition = 801

        let targetWidth = size.width * widthFactor
        let baseWidth = max(button.size.width, 1.0)
        button.setScale(targetWidth / baseWidth)

        return button
    }

    private func selectControlMode(_ mode: ControlMode) {
        guard controlMode == nil else { return }
        controlMode = mode
        childNode(withName: controlSelectionNodeName)?.removeFromParent()
        runCountdown()
    }

    private func showCountdownText(text: String, duration: TimeInterval) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 42
        label.fontColor = .white
        label.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        label.alpha = 0.0
        label.zPosition = 20
        addChild(label)

        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: max(0.1, duration - 0.4))
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        let isPlaneCloud = (a == planeCategory && b == cloudCategory) ||
                           (a == cloudCategory && b == planeCategory)

        guard isPlaneCloud else { return }

        let cloudNode: SKNode? = (contact.bodyA.categoryBitMask == cloudCategory) ? contact.bodyA.node : contact.bodyB.node
        guard let cloudNode else { return }
        if cloudNode.userData == nil {
            cloudNode.userData = NSMutableDictionary()
        }
        if cloudNode.userData?["counted"] as? Bool == true {
            return
        }
        cloudNode.userData?["counted"] = true
        let cloudPositionInScene = cloudNode.parent?.convert(cloudNode.position, to: self) ?? cloudNode.position
        let cloudVisualSize = cloudNode.frame.size
        cloudNode.removeFromParent()

        handleCloudCollision(
            named: cloudNode.name ?? cloudNodeName,
            position: cloudPositionInScene,
            size: cloudVisualSize
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)

        if tappedNodes.contains(where: { $0.name == touchControlButtonNodeName }) {
            selectControlMode(.touch)
            return
        }

        if tappedNodes.contains(where: { $0.name == tiltControlButtonNodeName }) {
            selectControlMode(.tilt)
            return
        }

        if tappedNodes.contains(where: { $0.name == pauseButtonNodeName }) {
            pauseGame()
            return
        }

        if tappedNodes.contains(where: { $0.name == continueButtonNodeName }) {
            resumeGame()
            return
        }

        if tappedNodes.contains(where: { $0.name == homeButtonNodeName }) {
            goToHome()
        }

        if controlMode == .touch, hasGameStarted, !isGamePaused {
            touchSteeringDirection = location.x >= size.width * 0.5 ? 1.0 : -1.0
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard controlMode == .touch, hasGameStarted, !isGamePaused, let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchSteeringDirection = location.x >= size.width * 0.5 ? 1.0 : -1.0
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard controlMode == .touch else { return }
        touchSteeringDirection = 0.0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard controlMode == .touch else { return }
        touchSteeringDirection = 0.0
    }

    private func pauseGame() {
        guard hasGameStarted, !isGamePaused else { return }
        isGamePaused = true
        removeAction(forKey: cloudSpawnActionKey)
        setCloudNodesPaused(true)
        motionManager.stopAccelerometerUpdates()
        touchSteeringDirection = 0.0
        AudioManager.shared.pauseBackgroundMusic()
        setupPauseOverlayIfNeeded()
        updatePauseCuriosityText()
        pauseOverlayNode?.isHidden = false
    }

    private func resumeGame() {
        guard isGamePaused else { return }
        isGamePaused = false
        setCloudNodesPaused(false)
        if controlMode == .tilt {
            startMotionUpdates()
        }
        startCloudSpawning()
        AudioManager.shared.resumeBackgroundMusic()
        pauseOverlayNode?.isHidden = true
    }

    private func setCloudNodesPaused(_ paused: Bool) {
        let cloudNames = [cloudNodeName, goldCloudNodeName, angryCloudNodeName]
        for nodeName in cloudNames {
            enumerateChildNodes(withName: nodeName) { node, _ in
                node.isPaused = paused
            }
        }
    }

    @objc private func appWillResignActive() {
        pauseGame()
    }

    @objc private func appDidBecomeActive() {
        guard isGamePaused else { return }
        removeAction(forKey: cloudSpawnActionKey)
        setCloudNodesPaused(true)
        motionManager.stopAccelerometerUpdates()
        setupPauseOverlayIfNeeded()
        pauseOverlayNode?.isHidden = false
    }

    private func goToHome() {
        motionManager.stopAccelerometerUpdates()
        let nextScene = MenuScene(size: size)
        nextScene.scaleMode = .aspectFill
        AudioManager.shared.stopBackgroundMusic()
        let transition = SKTransition.fade(withDuration: 0.35)
        view?.presentScene(nextScene, transition: transition)
    }

    private func startTutorialAndPlane() {
        hasGameStarted = true
        if controlMode == .touch {
            showTouchHandsTutorial()
        } else {
            childNode(withName: touchHandsTutorialNodeName)?.removeFromParent()
        }
        if controlMode == .tilt {
            showTutorial()
            startMotionUpdates()
        }
        let fadeIn = SKAction.fadeIn(withDuration: 0.4)
        planeNode?.run(fadeIn)
        pauseButtonNode?.run(fadeIn)
        scoreBackgroundNode?.run(fadeIn)
        scoreIconNode?.run(fadeIn)
        scoreLabel?.run(fadeIn)
        energyBarContainerNode?.run(fadeIn)
        multiplierLabel?.run(fadeIn)
        setupMonkey()
        startCloudSpawning()
    }

    private func showTutorial() {
        let phoneNode = makePhoneHintNode()
        phoneNode.position = CGPoint(x: size.width * 0.5, y: size.height * 0.70)
        phoneNode.alpha = 0.0
        phoneNode.zPosition = 20
        addChild(phoneNode)

        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let wait = SKAction.wait(forDuration: 3.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()

        phoneNode.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }

    private func makePhoneHintNode() -> SKNode {
        let container = SKNode()

        let bodySize = CGSize(width: 46, height: 86)
        let body = SKShapeNode(rectOf: bodySize, cornerRadius: 10)
        body.fillColor = SKColor(white: 0.1, alpha: 0.8)
        body.strokeColor = .white
        body.lineWidth = 2

        let screenSize = CGSize(width: 34, height: 60)
        let screen = SKShapeNode(rectOf: screenSize, cornerRadius: 6)
        screen.fillColor = SKColor(white: 0.2, alpha: 0.9)
        screen.strokeColor = .clear
        screen.position = CGPoint(x: 0, y: 6)

        let home = SKShapeNode(circleOfRadius: 3)
        home.fillColor = .white
        home.strokeColor = .clear
        home.position = CGPoint(x: 0, y: -30)

        body.addChild(screen)
        body.addChild(home)
        container.addChild(body)

        let rotateRight = SKAction.rotate(toAngle: 0.35, duration: 0.6, shortestUnitArc: true)
        let rotateLeft = SKAction.rotate(toAngle: -0.35, duration: 0.6, shortestUnitArc: true)
        let rotateSequence = SKAction.sequence([rotateRight, rotateLeft])
        container.run(SKAction.repeatForever(rotateSequence))

        return container
    }

    private func startMotionUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 60.0
        motionManager.startAccelerometerUpdates()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isGamePaused,
              let plane = planeNode,
              let controlMode else {
            lastUpdateTime = currentTime
            return
        }

        let deltaTime = max(0.0, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        updateBackgroundIfNeeded(deltaTime: deltaTime)
        applyPassiveEnergyDrain(deltaTime: deltaTime)
        updateCatchCloudsHint(deltaTime: deltaTime)

        let inputX: CGFloat
        if controlMode == .tilt {
            guard motionManager.isAccelerometerActive,
                  let acceleration = motionManager.accelerometerData?.acceleration else { return }
            inputX = CGFloat(acceleration.x)
        } else {
            inputX = touchSteeringDirection
        }

        let maxSpeed: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 500 : 450
        let targetVelocity = inputX * maxSpeed
        planeVelocityX = planeVelocityX + (targetVelocity - planeVelocityX) * 0.06

        plane.position.x += planeVelocityX * CGFloat(deltaTime)

        let targetRotation = max(-0.6, min(0.6, -inputX * 0.8))
        plane.zRotation = plane.zRotation + (targetRotation - plane.zRotation) * 0.12

        let halfWidth = plane.size.width * 0.5
        let minX = halfWidth + 4
        let maxX = size.width - halfWidth - 4

        if plane.position.x < minX {
            plane.position.x = minX
            planeVelocityX = abs(planeVelocityX) * 0.4
        } else if plane.position.x > maxX {
            plane.position.x = maxX
            planeVelocityX = -abs(planeVelocityX) * 0.4
        }
    }
}
