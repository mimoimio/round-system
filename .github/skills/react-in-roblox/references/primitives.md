# UI Primitives Reference

Source folder: `src/shared/ReactComponents/ui`

Use these primitives first when building client UI.

## Import Pattern

```lua
local Primitives = game.ReplicatedStorage.Shared.ReactComponents.ui

local VStack = require(Primitives.VStack)
local HStack = require(Primitives.HStack)
local Grid = require(Primitives.Grid)
local Panel = require(Primitives.Panel)
local SmallButton = require(Primitives.SmallButton)
local SmallText = require(Primitives.SmallText)
local rounded = require(Primitives.rounded)
```

## Available Primitives

### `VStack` (`VStack.lua`)
Vertical list layout wrapper (`Frame` or `ImageLabel` when `BackgroundImage` is set).

Accepted props:
- `children`
- `Size` (default `UDim2.fromScale(1, 1)`)
- `AutomaticSize` (default `Enum.AutomaticSize.None`)
- `BackgroundTransparency` (default `1`)
- `BackgroundColor3`
- `LayoutOrder`
- `AnchorPoint`
- `Position`
- `Active`
- `HorizontalAlignment` (default `Enum.HorizontalAlignment.Center`)
- `VerticalAlignment` (default `Enum.VerticalAlignment.Top`)
- `HorizontalFlex` (default `"Fill"`)
- `VerticalFlex` (default `"Fill"`)
- `Spacing` (`UDim` for list padding)
- `Wraps`
- `Padding` table with `All`, `Top`, `Bottom`, `Left`, `Right` (`UDim`)
- `FlexMode` (adds `UIFlexItem`)
- `BackgroundImage`
- `BackgroundImageColor3`
- `BackgroundImageTransparency`

Notes:
- Uses `UIListLayout` with `FillDirection = Vertical`.
- If `BackgroundImage` exists, root instance becomes `ImageLabel` and uses tiled scale type.

### `HStack` (`HStack.lua`)
Horizontal list layout wrapper (`Frame`).

Accepted props:
- `children`
- `Size` (default `UDim2.fromScale(1, 1)`)
- `AutomaticSize` (default `Enum.AutomaticSize.None`)
- `BackgroundTransparency` (default `1`)
- `BackgroundColor3`
- `LayoutOrder`
- `AnchorPoint`
- `Position`
- `HorizontalAlignment` (default `Enum.HorizontalAlignment.Left`)
- `VerticalAlignment` (default `Enum.VerticalAlignment.Center`)
- `Spacing` (`UDim` for list padding)
- `HorizontalFlex`
- `Padding` table with `All`, `Top`, `Bottom`, `Left`, `Right` (`UDim`)

Notes:
- Uses `UIListLayout` with `FillDirection = Horizontal`.

### `Grid` (`Grid.lua`)
Grid layout wrapper (`Frame`) using `UIGridLayout`.

Accepted props:
- `children`
- `Size` (default `UDim2.fromScale(1, 1)`)
- `AutomaticSize` (default `Enum.AutomaticSize.None`)
- `BackgroundTransparency` (default `1`)
- `BackgroundColor3`
- `LayoutOrder`
- `CellSize` (default `UDim2.new(0, 100, 0, 100)`)
- `CellPadding` (default `UDim2.new(0, 6, 0, 6)`)
- `FillDirection` (default `Enum.FillDirection.Horizontal`)
- `FillDirectionMaxCells` (default `0`)
- `HorizontalAlignment` (default `Enum.HorizontalAlignment.Center`)
- `VerticalAlignment` (default `Enum.VerticalAlignment.Top`)
- `SortOrder` (default `Enum.SortOrder.LayoutOrder`)
- `StartCorner` (default `Enum.StartCorner.TopLeft`)
- `Padding` table with `All`, `Top`, `Bottom`, `Left`, `Right` (`UDim`)

### `Panel` (`Panel.luau`)
Animated panel primitive with layered background (`ImageLabel`) + content (`VStack`) and a built-in header (`title + close button`).

Required/primary props:
- `Open: boolean?` (defaults to `true`; panel is always visible and animates to open/hidden position)
- `OnClose: (() -> ())?` (if set, renders close button and binds `Activated`)

Layout and content props:
- `children` (rendered inside the body `VStack`)
- `Title`
- `TitleSize` (default `18`)
- `Size` (default `UDim2.fromScale(0.45, 0.6)`)
- `AutomaticSize`
- `LayoutOrder`
- `AnchorPoint` (default `Vector2.new(0.5, 0.5)`)
- `VerticalAlignment`
- `HorizontalAlignment`
- `Padding`
- `Spacing`

Animation props (ReactFlow `useSpring`):
- `OpenPosition` (default `UDim2.fromScale(0.5, 0.5)`)
- `HiddenPosition` (default `UDim2.fromScale(0.5, 1.2)`)
- `SpringSpeed` (default `18`)
- `SpringDamper` (default `0.85`)

Background/layering props:
- `BackgroundMode` (`"Slice"` or `"Tile"`, default `"Slice"`)
- `BackgroundImage`
- `BackgroundImageColor3`
- `BackgroundImageTransparency`
- `SliceCenter` (for 9-slice mode)
- `TileSize` (for tile mode)
- `BackgroundZIndex` (default `1`)
- `ContentZIndex` (default `2`)
- `BackgroundColor3`
- `ClipsDescendants`
- `ZIndex`

Close button style props:
- `CloseButtonBackgroundTransparency`
- `CloseButtonBackgroundColor3`
- `CloseButtonTextColor3`

Notes:
- Uses `React.useEffect` to drive the spring setter when `Open` changes.
- Uses `UDim2.fromScale` defaults for both hidden and open positions.
- Root `Frame.Visible` is always `true`.

### `SmallButton` (`SmallButton.lua`)
Small interactive button primitive (`TextButton` or `ImageButton`).

Accepted props:
- `ButtonClass` (`"TextButton"` or `"ImageButton"`; default auto-detect from `Image`)
- `children`
- `LayoutOrder`
- `Size` (default `UDim2.new(0, 48, 0, 48)`)
- `Position`
- `AnchorPoint`
- `BackgroundColor3`
- `BackgroundTransparency` (default `0.3`)
- `ZIndex` (default `11`)
- `AutoButtonColor`
- `[React.Event.Activated]`
- `CornerRadius` (default `UDim.new(0, 8)`)

Text mode props:
- `Text` (default empty string)
- `TextSize` (default `16`)
- `TextStrokeTransparency` (default `1`)
- `Font` (default `Enum.Font.FredokaOne`)
- `TextColor3` (default white)

Image mode props:
- `Image`
- `ImageRectOffset`
- `ImageRectSize`
- `ImageTransparency` (default `0`)
- `ImageColor3` (default `TextColor3`)
- `ScaleType` (default `Enum.ScaleType.Fit`)

Keybind overlay props:
- `KeybindText`
- `KeybindColor3`
- `KeybindTextSize`
- `KeybindTextTransparency`
- `KeybindTextStrokeTransparency`
- `KeybindFont`

Notes:
- Adds hover scale animation via `UIScale`.
- Plays click sound on mouse enter through `SoundController.Sound("Click")`.

### `SmallText` (`SmallText.luau`)
Text label primitive for compact text with enforced size constraint.

Accepted props:
- `children`
- `Text`
- `TextSize` (also used for min/max `UITextSizeConstraint`, default `18`)
- `TextScaled`
- `TextXAlignment` (default `Enum.TextXAlignment.Left`)
- `AutomaticSize` (default `Enum.AutomaticSize.XY`)
- `Size`
- `LayoutOrder`

Notes:
- Uses `Font = "FredokaOne"` in current implementation.
- Sets `BackgroundTransparency = 1` and `TextStrokeTransparency = 0`.

### `rounded` (`rounded.lua`)
Helper primitive returning a `UICorner`.

Accepted props:
- None currently used.

Behavior:
- Always returns `UICorner` with `CornerRadius = UDim.new(0, 8)`.

## Simple Composition Example

```lua
local React = require(game.ReplicatedStorage.Packages.React)
local e = React.createElement
local Primitives = game.ReplicatedStorage.Shared.ReactComponents.ui

local VStack = require(Primitives.VStack)
local HStack = require(Primitives.HStack)
local SmallText = require(Primitives.SmallText)
local SmallButton = require(Primitives.SmallButton)

local function Example(props)
	return e(VStack, {
		Size = UDim2.fromScale(1, 1),
		Spacing = UDim.new(0, 8),
		Padding = { All = UDim.new(0, 12) },
	}, {
		Header = e(HStack, {
			AutomaticSize = Enum.AutomaticSize.Y,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Spacing = UDim.new(0, 8),
		}, {
			Title = e(SmallText, {
				Text = "Inventory",
				TextSize = 18,
			}),
			Close = e(SmallButton, {
				Text = "X",
				[React.Event.Activated] = props.OnClose,
			}),
		}),
	})
end

return Example
```
