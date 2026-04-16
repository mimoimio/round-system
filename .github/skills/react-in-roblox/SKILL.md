---
name: react-in-roblox
description: Basic use React-Lua, utilizing defined primitives, focusing on flexbox style UIs. Baseline, must use the defined primitives whenever is creating client-side UIs. Only when there isnt a wanted primitive, use roblox's UIObjects. Unless specifically told not to. Must keep in mind, as default, use flexbox layout for easy and predictable positioning. Never fixed positioning unless told to.
---

# React-Lua in Roblox

When writing client-side UIs using React-Lua, enforce the following constraints:

1. **Primitive Priority (Mandatory):** Always use predefined primitives first. Read `references/primitives.md` before implementing UI.
2. **No Native Duplication (Mandatory):** Do not create raw Roblox UIObjects that duplicate an existing primitive. Existing primitives include `VStack`, `HStack`, `Grid`, `Panel`, `SmallButton`, `SmallText`, and `rounded`.
3. **Native Fallback (Exception Only):** Use raw UIObjects (e.g., `Frame`, `TextButton`) only when the needed behavior is not covered by primitives.
4. **Flexbox First (Mandatory):** Layouts should default to flex/list patterns using `VStack`/`HStack`/`Grid`, automatic sizing, and flow-based ordering.
5. **Positioning Ban (Mandatory):** Avoid fixed `Position`/manual absolute layout unless explicitly required by the user.
6. **Composition Rule (Mandatory):** Build UI via primitive composition and small wrappers, not large one-off monolith components.

**Action Plan:**
When instructed to build a new UI component, follow this sequence:

1. Read `references/primitives.md` and map requested UI sections to existing primitives.
2. Start from `assets/base-component.lua` for structure and layering.
3. Add native Roblox objects only for missing capabilities.
4. Keep layout flow-based; do not use fixed positioning unless explicitly requested.