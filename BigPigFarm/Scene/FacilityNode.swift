/// FacilityNode — Sprite node representing a placed facility.
/// Maps from: new SpriteKit rendering layer
import SpriteKit

/// A SpriteKit node that renders a facility on the farm grid.
/// Uses center-based positioning (default anchor 0.5, 0.5) so FarmScene.gridToScene
/// can map the facility center directly.
class FacilityNode: SKSpriteNode {
    let facilityID: UUID
    let facilityType: FacilityType
    private let nameLabel: SKLabelNode
    var isSelectedInEditMode: Bool = false { didSet { updateEditHighlight() } }
    var isBeingMoved: Bool = false { didSet { updateEditHighlight() } }

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

    private func updateEditHighlight() {
        if isBeingMoved {
            alpha = 0.6
            colorBlendFactor = 0.35
            color = .yellow
        } else if isSelectedInEditMode {
            alpha = 1.0
            colorBlendFactor = 0.2
            color = .white
        } else {
            alpha = 1.0
            colorBlendFactor = 0
            color = .clear
        }
    }
}
