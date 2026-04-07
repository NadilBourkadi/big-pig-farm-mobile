/// FarmScene+Transition — Pig parade and farm reset animation for New Pastures prestige.
import SpriteKit

extension FarmScene {

    /// Play the prestige transition animation.
    ///
    /// Sequence: pigs parade off screen → farm fades to black → sunrise gradient →
    /// "Farm #N" banner → completion callback (triggers actual reset + scene rebuild).
    /// When Reduce Motion is enabled, plays a shorter opacity-only fast path
    /// with no parade or scale animations.
    func playPrestigeTransition(farmNumber: Int, completion: @escaping @MainActor () -> Void) {
        isUserInteractionEnabled = false

        if MotionSettings.isReduced {
            playPrestigeTransitionStatic(farmNumber: farmNumber, completion: completion)
            return
        }

        let paradeAction = buildParadeAction()
        let fadeAction = buildFadeAction()
        let overlayNode = buildOverlayNode()

        let sunriseAction = buildSunriseAction(overlayNode: overlayNode)
        let bannerAction = buildBannerAction(farmNumber: farmNumber)

        run(SKAction.sequence([
            paradeAction,
            fadeAction,
            SKAction.run { [weak self] in
                MainActor.assumeIsolated {
                    completion()
                    // Force immediate scene sync after reset
                    self?.lastGridGeneration = -1
                }
            },
            SKAction.wait(forDuration: 0.3),
            sunriseAction,
            bannerAction,
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in
                MainActor.assumeIsolated {
                    overlayNode.removeFromParent()
                    self?.isUserInteractionEnabled = true
                }
            },
        ]))
    }

    // MARK: - Reduce Motion Fast Path

    /// Opacity-only prestige transition for Reduce Motion. No parade, no scale,
    /// no easing curves on movement. Total duration ~2.4 s vs. ~6 s for the
    /// regular animation.
    ///
    /// Sequence: snap overlay opaque → rebuild farm under cover → snap overlay
    /// transparent → banner fade in/out. No layer fades, eliminating any
    /// possibility of a one-frame flash between fade-out and overlay-cover.
    private func playPrestigeTransitionStatic(
        farmNumber: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        let overlayNode = buildOverlayNode()

        run(SKAction.sequence([
            // 1. Snap overlay to opaque (instantly covers everything)
            SKAction.run {
                overlayNode.alpha = 1.0
            },
            // 2. Rebuild farm under cover of overlay
            SKAction.run { [weak self] in
                MainActor.assumeIsolated {
                    completion()
                    self?.lastGridGeneration = -1
                }
            },
            SKAction.wait(forDuration: 0.3),
            // 3. Defensive: ensure layer alphas are 1.0 in case a previous
            //    transition left them faded. Then snap overlay away.
            SKAction.run { [weak self] in
                self?.terrainLayer.alpha = 1.0
                self?.facilityLayer.alpha = 1.0
                self?.pigLayer.alpha = 1.0
                self?.treatLayer.alpha = 1.0
                overlayNode.alpha = 0
            },
            // 4. Banner — fade only, no scale animation
            SKAction.run { [weak self] in
                guard let self else { return }
                self.showStaticBanner(farmNumber: farmNumber)
            },
            SKAction.wait(forDuration: 1.9),
            SKAction.run { [weak self] in
                MainActor.assumeIsolated {
                    overlayNode.removeFromParent()
                    self?.isUserInteractionEnabled = true
                }
            },
        ]))
    }

    /// Display the "Farm #N — New Pastures" banner with fade only (no scale).
    /// Attached to the camera so it tracks viewport movement and stays
    /// centered if the camera pans during the hold window.
    private func showStaticBanner(farmNumber: Int) {
        guard let cam = camera else { return }

        let label = SKLabelNode(text: "Farm #\(farmNumber) — New Pastures")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 28
        label.fontColor = .white
        label.position = .zero // camera-local origin = viewport center
        label.zPosition = 1001
        label.alpha = 0

        cam.addChild(label)

        label.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.wait(forDuration: 1.5),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent(),
        ]))
    }

    // MARK: - Parade

    /// Move all pig nodes off the right edge of the scene with staggered timing.
    private func buildParadeAction() -> SKAction {
        let sceneRight = size.width + 100
        let sortedPigs = pigNodes.values.sorted { $0.position.x < $1.position.x }

        return SKAction.run {
            for (index, node) in sortedPigs.enumerated() {
                let delay = Double(index) * 0.08
                let moveRight = SKAction.moveTo(x: sceneRight, duration: 1.5)
                moveRight.timingMode = .easeIn
                node.run(SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    moveRight,
                    SKAction.fadeOut(withDuration: 0.2),
                ]))
            }
        }
    }

    // MARK: - Fade

    /// Fade all terrain and facility layers to black.
    private func buildFadeAction() -> SKAction {
        SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.group([
                SKAction.run { [weak self] in
                    self?.terrainLayer.run(SKAction.fadeOut(withDuration: 1.0))
                    self?.facilityLayer.run(SKAction.fadeOut(withDuration: 1.0))
                    self?.pigLayer.run(SKAction.fadeOut(withDuration: 0.5))
                    self?.treatLayer.run(SKAction.fadeOut(withDuration: 0.5))
                },
                SKAction.wait(forDuration: 1.2),
            ]),
        ])
    }

    // MARK: - Overlay

    /// Full-screen black overlay for the transition, attached to the camera
    /// so it follows viewport movement from any residual pan momentum.
    private func buildOverlayNode() -> SKNode {
        let overlaySize = CGSize(
            width: size.width * 2,
            height: size.height * 2
        )
        let overlay = SKShapeNode(
            rect: CGRect(
                x: -overlaySize.width / 2,
                y: -overlaySize.height / 2,
                width: overlaySize.width,
                height: overlaySize.height
            )
        )
        overlay.fillColor = .black
        overlay.strokeColor = .clear
        overlay.alpha = 0
        overlay.zPosition = 1000

        // Attach to camera so overlay tracks viewport
        if let cam = camera {
            cam.addChild(overlay)
        } else {
            addChild(overlay)
        }
        return overlay
    }

    // MARK: - Sunrise

    /// Fade the overlay from black to transparent, revealing the rebuilt farm.
    private func buildSunriseAction(overlayNode: SKNode) -> SKAction {
        SKAction.sequence([
            SKAction.run { [weak self] in
                // Restore layer visibility for the new farm
                self?.terrainLayer.alpha = 1.0
                self?.facilityLayer.alpha = 1.0
                self?.pigLayer.alpha = 1.0
                self?.treatLayer.alpha = 1.0
            },
            SKAction.run {
                overlayNode.run(SKAction.fadeIn(withDuration: 0.01))
            },
            SKAction.wait(forDuration: 0.1),
            SKAction.run {
                overlayNode.run(SKAction.fadeOut(withDuration: 2.0))
            },
            SKAction.wait(forDuration: 2.0),
        ])
    }

    // MARK: - Banner

    /// Display "Farm #N — New Pastures" banner that scales in and fades out.
    private func buildBannerAction(farmNumber: Int) -> SKAction {
        SKAction.run { [weak self] in
            guard let self, let cam = camera else { return }

            let label = SKLabelNode(text: "Farm #\(farmNumber) — New Pastures")
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 28
            label.fontColor = .white
            // Position at camera center — add to scene, not camera,
            // so it doesn't inherit camera scale
            label.position = cam.position
            label.zPosition = 1001
            label.setScale(0.0)
            label.alpha = 0

            addChild(label)

            label.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.0, duration: 0.6),
                    SKAction.fadeIn(withDuration: 0.6),
                ]),
                SKAction.wait(forDuration: 2.0),
                SKAction.fadeOut(withDuration: 0.8),
                SKAction.removeFromParent(),
            ]))
        }
    }
}
