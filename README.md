# Smart Soul Shards

Smart Soul Shards is a World of Warcraft addon that replaces the default Warlock Soul Shard display with a compact, configurable shard bar. It supports Affliction, Demonology, and Destruction, with optional predictive indicators for shard generation and spending.

## Features

- Custom five-segment Soul Shard bar for Warlocks
- Optional hiding of the Blizzard Soul Shard bar
- Optional hiding while skyriding
- Predictive shard display for builders and spenders
- Predictive center text that can show the expected shard count after a cast
- Per-specialization prediction toggles for Affliction, Demonology, and Destruction
- Configurable shard width, height, spacing, border size, texture, font, and font size
- Configurable inactive, active, and capped shard colors
- Edit Mode support, including per-layout positioning
- LibSharedMedia support for fonts and status bar textures

## Installation

1. Place the `SmartSoulShards` folder in:

   ```text
   World of Warcraft\_retail_\Interface\AddOns\
   ```

2. Restart World of Warcraft, or reload your UI.
3. Enable `Smart Soul Shards` from the AddOns list.
4. Log in on a Warlock.

This addon only runs on Warlock characters.

## Configuration

Open WoW Edit Mode and select the `Smart Soul Shards` frame. The addon registers its settings there.

Available settings include:

- Hide Blizzard Soul Shard bar
- Hide while skyriding
- Predictive builders by specialization
- Predictive spenders by specialization
- Predictive text
- X and Y position
- Shard width and height
- Spacing
- Border size
- Shard texture
- Count font
- Count font size
- Background color
- Shard color
- Max shards color

Changes are applied immediately.

## Prediction Notes

Prediction is based on known Warlock builder and spender spells for each specialization. The addon tracks cast start, channel updates, cast completion, failures, interrupts, power changes, talents, and specialization changes to keep the display current.

The default prediction support includes common shard interactions such as:

- Affliction builders and spenders
- Demonology builders and spenders, including Hand of Gul'dan and Call Dreadstalkers cost handling
- Destruction builders and spenders, including fractional shard generation
- Talent-aware cases where supported by the addon logic

## Media

Smart Soul Shards uses LibSharedMedia-3.0 for shared fonts and status bar textures.

To add bundled custom status bar textures, place the texture files in the addon folder and register them in `CUSTOM_STATUSBAR_TEXTURES` inside `SmartSoulShards.lua`.

Example:

```lua
local CUSTOM_STATUSBAR_TEXTURES = {
    { name = "My Texture", path = "Interface\\AddOns\\SmartSoulShards\\Media\\StatusBars\\MyTexture.tga" },
}
```

## Included Libraries

This addon includes:

- LibStub
- LibEditMode
- LibSharedMedia-3.0
- CallbackHandler-1.0

Library license files are included in the `Libs` folder where provided by the library authors.

## Saved Variables

Settings are stored in:

```text
SmartSoulShardsDB
```

Resetting settings from the addon options restores the default layout, colors, prediction settings, font, and texture choices.

## Project Files

```text
SmartSoulShards.toc          Addon metadata and load order
SmartSoulShards.lua          Main addon logic
Localization\enUS.lua        English locale strings
Libs\                       Embedded libraries
```
