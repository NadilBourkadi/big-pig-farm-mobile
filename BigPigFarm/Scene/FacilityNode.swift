/// FacilityNode — Sprite node representing a placed facility.
/// Maps from: new SpriteKit rendering layer
import SpriteKit

/// Edit mode glow state for facility nodes.
enum FacilityGlowState: Sendable {
    case none
    case selected
    case moving
}

/// A SpriteKit node that renders a facility on the farm grid.
/// Uses center-based positioning (default anchor 0.5, 0.5) so FarmScene.gridToScene
/// can map the facility center directly.
class FacilityNode: SKSpriteNode {
    let facilityID: UUID
    let facilityType: FacilityType
    private let nameLabel: SKLabelNode
    private var glowNode: SKSpriteNode?
    var glowState: FacilityGlowState = .none { didSet { if glowState != oldValue { updateGlow() } } }

    init(facility: Facility, scene: FarmScene) {
        self.facilityID = facility.id
        self.facilityType = facility.facilityType

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = 8
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        self.nameLabel = label

        let texture = SpriteAssets.facilityTexture(facilityType: facility.facilityType.rawValue)
        let footprintWidth = CGFloat(facility.width) * SceneConstants.cellSize
        let footprintHeight = CGFloat(facility.height) * SceneConstants.cellSize

        // Scale texture to fit within the grid footprint while preserving aspect ratio.
        // Without this, textures are force-stretched to fill the footprint, causing
        // horizontal distortion (the original art was designed for terminal half-block
        // rendering where character cells are taller than wide).
        // The resulting node may be smaller than the footprint on the non-constraining
        // axis. Use facility.width/height (not self.size) when you need the grid footprint.
        let textureSize = texture.size()
        let nodeWidth: CGFloat
        let nodeHeight: CGFloat
        if textureSize.width > 0, textureSize.height > 0 {
            let fitScale = min(footprintWidth / textureSize.width,
                               footprintHeight / textureSize.height)
            nodeWidth = textureSize.width * fitScale
            nodeHeight = textureSize.height * fitScale
        } else {
            nodeWidth = footprintWidth
            nodeHeight = footprintHeight
        }

        super.init(texture: texture, color: .clear, size: CGSize(width: nodeWidth, height: nodeHeight))

        let facilityAsset = "Sprites/Facilities/facility_\(facility.facilityType.rawValue)"
        if let cgImage = OutlineShadow.loadCGImage(named: facilityAsset),
           let outlineTex = OutlineShadow.outlineTexture(from: cgImage) {
            let shadow = OutlineShadow.makeShadowNode(
                texture: outlineTex,
                spriteSize: CGSize(width: nodeWidth, height: nodeHeight)
            )
            addChild(shadow)
        }

        label.text = facility.facilityType.displayName
        // Position label above the top edge of the sprite (which is at +nodeHeight/2 from center).
        label.position = CGPoint(x: 0, y: nodeHeight / 2 + 4)
        addChild(nameLabel)

        update(from: facility, in: scene)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func update(from facility: Facility, in scene: FarmScene) {
        // Place at the center of the facility footprint.
        let centerGridX = CGFloat(facility.positionX) + CGFloat(facility.width) / 2.0
        let centerGridY = CGFloat(facility.positionY) + CGFloat(facility.height) / 2.0
        position = scene.gridToScene(centerGridX, centerGridY)
    }

    private func updateGlow() {
        glowNode?.removeFromParent()
        glowNode = nil

        let glowColor: UIColor
        switch glowState {
        case .none:
            alpha = 1.0
            return
        case .selected:
            glowColor = GlowEffect.facilitySelectedColor
            alpha = 1.0
        case .moving:
            glowColor = GlowEffect.facilityMovingColor
            alpha = 0.7
        }

        let facilityAsset = "Sprites/Facilities/facility_\(facilityType.rawValue)"
        if let cgImage = OutlineShadow.loadCGImage(named: facilityAsset),
           let glowTex = GlowEffect.glowTexture(from: cgImage, color: glowColor) {
            let node = GlowEffect.makeGlowNode(texture: glowTex, spriteSize: size)
            addChild(node)
            glowNode = node
        }
    }
}
