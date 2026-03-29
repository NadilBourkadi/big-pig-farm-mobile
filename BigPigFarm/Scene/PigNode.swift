/// PigNode — Animated sprite node representing a guinea pig.
/// Maps from: new SpriteKit rendering layer
import SpriteKit

/// A SpriteKit node that renders and animates a single guinea pig.
class PigNode: SKSpriteNode {
    let pigID: UUID
    private var baseColor: BaseColor
    private var isBaby: Bool
    private let nameLabel: SKLabelNode
    private var indicatorNode: SKSpriteNode?
    private var glowNode: SKSpriteNode?
    private var shadowNode: SKSpriteNode?
    var isSelected: Bool = false { didSet { updateSelectionGlow() } }
    private var currentAnimationKey: String = ""
    /// Target position set during tick-rate sync; `smoothMove()` lerps toward it each frame.
    private(set) var targetPosition: CGPoint = .zero

    init(pig: GuineaPig, scene: FarmScene) {
        self.pigID = pig.id
        self.baseColor = pig.phenotype.baseColor
        self.isBaby = pig.isBaby

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = 7
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        self.nameLabel = label

        let displayState = pig.isBaby
            ? AnimationData.babyFallbackState(for: pig.displayState)
            : pig.displayState
        let texture = SpriteAssets.pigTexture(
            baseColor: pig.phenotype.baseColor,
            state: displayState,
            direction: "right",
            isBaby: pig.isBaby
        )
        let artSize = pig.isBaby ? SpriteAssets.babySpriteSize : SpriteAssets.adultSpriteSize
        let nodeSize = CGSize(
            width: artSize.width * SpriteAssets.pointsPerArtPixel,
            height: artSize.height * SpriteAssets.pointsPerArtPixel
        )

        super.init(texture: texture, color: .clear, size: nodeSize)

        // Always use "idle" for the shadow — it exists as a single-frame asset
        // for all colors/ages, and the silhouette is close enough for all states.
        let initAssetName = Self.pigAssetName(
            baseColor: pig.phenotype.baseColor, state: "idle",
            direction: "right", isBaby: pig.isBaby
        )
        if let cgImage = OutlineShadow.loadCGImage(named: initAssetName),
           let outlineTex = OutlineShadow.outlineTexture(from: cgImage) {
            let shadow = OutlineShadow.makeShadowNode(texture: outlineTex, spriteSize: nodeSize)
            addChild(shadow)
            shadowNode = shadow
        }

        nameLabel.verticalAlignmentMode = .top
        nameLabel.text = pig.name
        nameLabel.position = CGPoint(x: 0, y: -(nodeSize.height / 2) - 2)
        addChild(nameLabel)

        let initialPos = scene.gridToScene(CGFloat(pig.position.x), CGFloat(pig.position.y))
        position = initialPos
        targetPosition = initialPos
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func update(from pig: GuineaPig, in scene: FarmScene) {
        targetPosition = scene.gridToScene(CGFloat(pig.position.x), CGFloat(pig.position.y))

        let newState = pig.isBaby
            ? AnimationData.babyFallbackState(for: pig.displayState)
            : pig.displayState
        let newDir = directionFromPath(pig.path)
        let animKey = "\(newState)_\(newDir)_\(pig.isBaby)"

        if animKey != currentAnimationKey {
            currentAnimationKey = animKey
            baseColor = pig.phenotype.baseColor
            let newIsBaby = pig.isBaby
            if newIsBaby != isBaby {
                isBaby = newIsBaby
                let artSize = isBaby ? SpriteAssets.babySpriteSize : SpriteAssets.adultSpriteSize
                size = CGSize(
                    width: artSize.width * SpriteAssets.pointsPerArtPixel,
                    height: artSize.height * SpriteAssets.pointsPerArtPixel
                )
                nameLabel.position = CGPoint(x: 0, y: -(size.height / 2) - 2)
            } else {
                isBaby = newIsBaby
            }
            startAnimation(state: newState, direction: newDir)
        }

        nameLabel.text = pig.name
    }

    /// Interpolates position toward `targetPosition` each render frame.
    /// Called from `FarmScene.update()` at ~60fps for smooth movement between tick-rate syncs.
    /// Skips Y interpolation while a treat bounce action is running so the
    /// bounce SKAction owns vertical movement without being overwritten.
    func smoothMove() {
        let isBouncing = action(forKey: "treatBounce") != nil
        let dx = targetPosition.x - position.x
        let dy = targetPosition.y - position.y
        let distSq = isBouncing ? dx * dx : dx * dx + dy * dy
        guard distSq > 0.01 else {
            position.x = targetPosition.x
            if !isBouncing { position.y = targetPosition.y }
            return
        }
        let factor: CGFloat = 0.25
        position.x += dx * factor
        if !isBouncing { position.y += dy * factor }
    }

    func showIndicator(type: String, bright: Bool) {
        let texture = SpriteAssets.indicatorTexture(indicatorType: type, bright: bright)
        if let existing = indicatorNode {
            existing.texture = texture
        } else {
            let node = SKSpriteNode(
                texture: texture,
                size: CGSize(width: 8 * SpriteAssets.pointsPerArtPixel,
                             height: 8 * SpriteAssets.pointsPerArtPixel)
            )
            node.position = CGPoint(x: 0, y: size.height / 2 + 14)
            node.zPosition = 3
            node.alpha = 0
            addChild(node)
            node.run(.fadeIn(withDuration: 0.15))
            indicatorNode = node
        }
    }

    func hideIndicator() {
        guard let indicator = indicatorNode else { return }
        indicatorNode = nil
        indicator.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
    }

    private func startAnimation(state: String, direction: String) {
        removeAllActions()
        let frames = SpriteAssets.pigAnimationFrames(
            baseColor: baseColor,
            state: state,
            direction: direction,
            isBaby: isBaby
        )
        guard !frames.isEmpty else { return }
        updateShadowSize()
        // Regenerate the glow so it tracks the new direction's silhouette.
        if isSelected { regenerateGlow() }
        if frames.count == 1 {
            texture = frames[0]
            return
        }
        let tpf = AnimationData.ticksPerFrameValue(for: state) ?? 3
        let frameDuration = TimeInterval(tpf) / TimeInterval(GameConfig.Simulation.ticksPerSecond)
        let animate = SKAction.animate(with: frames, timePerFrame: frameDuration)
        run(SKAction.repeatForever(animate), withKey: "animation")
    }

    private func updateShadowSize() {
        let offset = CGFloat(OutlineShadow.artPixelOffset) * SpriteAssets.pointsPerArtPixel
        let blurPad = ceil(OutlineShadow.blurRadius * 2.5)
        let expansion = (offset + blurPad) * 2
        shadowNode?.size = CGSize(width: size.width + expansion, height: size.height + expansion)
    }

    private static func pigAssetName(
        baseColor: BaseColor, state: String, direction: String,
        isBaby: Bool, frame: Int? = nil
    ) -> String {
        let age = isBaby ? "baby" : "adult"
        var name = "Sprites/Pigs/pig_\(age)_\(baseColor.rawValue)_\(state)_\(direction)"
        if let frame { name += "_\(frame)" }
        return name
    }

    private func directionFromPath(_ path: [GridPosition]) -> String {
        guard path.count >= 2 else { return "right" }
        return path[1].x >= path[0].x ? "right" : "left"
    }

    private func updateSelectionGlow() {
        if isSelected {
            if glowNode == nil {
                regenerateGlow()
            }
        } else {
            if let glow = glowNode {
                glowNode = nil
                glow.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
            }
        }
    }

    private func regenerateGlow() {
        glowNode?.removeFromParent()
        let direction = currentAnimationKey.contains("left") ? "left" : "right"
        let assetName = Self.pigAssetName(
            baseColor: baseColor, state: "idle",
            direction: direction, isBaby: isBaby
        )
        if let cgImage = OutlineShadow.loadCGImage(named: assetName),
           let glowTex = GlowEffect.glowTexture(from: cgImage, color: GlowEffect.pigSelectionColor) {
            let node = GlowEffect.makeGlowNode(texture: glowTex, spriteSize: size)
            node.alpha = 0
            addChild(node)
            node.run(.fadeIn(withDuration: 0.2))
            glowNode = node
        } else {
            glowNode = nil
        }
    }
}
