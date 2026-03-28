# ADR-0001: Pixel Art UI Aesthetic

## Status

Accepted

## Context

The farm scene renders pigs, terrain, and facilities in pixel art via SpriteKit, but all SwiftUI
UI elements (sheets, buttons, toolbars) use standard iOS system styling. The current HUD uses dark
earthy backgrounds with warm tan text — thematic but not pixel art. This creates a visual disconnect
between the game world and the UI chrome.

## Options Considered

### Option A: Full pixel art UI

Custom pixel art panel/frame backgrounds (9-slice textures), bitmap/pixel fonts for all text,
custom pixel art icons replacing SF Symbols, themed color palette across all sheets and modals.

Maximum immersion but large effort. Accessibility concerns: bitmap fonts don't scale with Dynamic
Type, lack Bold Text / Increase Contrast support, and require multiple glyph size variants.

### Option B: Hybrid approach

Pixel art frames and panel backgrounds for HUD bars, toolbar, and sheet chrome. Keep system fonts
(SF Pro) for all readable text. Custom pixel art icons for the toolbar; SF Symbols elsewhere.
Phase in gradually — toolbar and HUD first, then sheets.

Balances immersion with platform accessibility. System fonts respect Dynamic Type, Bold Text, and
Increase Contrast automatically. Incremental delivery reduces risk.

### Option C: Keep current dark earthy theme

No pixel art elements. Continue with dark brown backgrounds and warm tan text using system styling.
Already implemented and readable, but the visual disconnect between game world and UI persists.

## Decision

Option B (hybrid). Pixel art for decorative chrome (frames, panels, toolbar backgrounds), system
fonts for all readable text. The key deciding factor is accessibility: system fonts scale with
Dynamic Type and respond to Bold Text / Increase Contrast settings automatically, while bitmap
pixel fonts require extensive manual work to support these features and still degrade at non-native
sizes. The hybrid approach delivers the pixel art aesthetic where it matters most (visual framing)
without sacrificing readability or platform accessibility.

## Consequences

- HUD bars and toolbar get pixel art frame textures (9-slice). New convention: all decorative
  chrome uses asset catalog image sets, not SwiftUI shape fills.
- All readable text continues to use SF Pro via SwiftUI text styles. No bitmap fonts anywhere.
- Custom pixel art icons needed for the toolbar (5–7 icons). SF Symbols remain for sheet content.
- Sheets and modals can adopt pixel art panel backgrounds incrementally — no big-bang rework.
- Accessibility is preserved: Dynamic Type, Bold Text, Increase Contrast, and VoiceOver all work
  as expected since text remains system-rendered.
- Future screens must follow this convention: pixel art for framing/decoration, system fonts for
  text. Add this as a code style rule.
