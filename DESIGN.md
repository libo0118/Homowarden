# Homowarden visual system

The interface follows Bitwarden's mobile vault hierarchy while retaining the Homowarden name and its native HarmonyOS controls. Visual references: [Bitwarden brand](https://bitwarden.com/brand/) and [Android app screenshots](https://play.google.com/store/apps/details?id=com.x8bit.bitwarden). Mobile dimensions below are approximations from the screenshots, pending device-level visual comparison.

## Color

| Role | Light | Dark |
| --- | --- | --- |
| Primary action | `#175DDC` | `#175DDC` |
| Navigation rail | `#175DDC` | `#0C3276` |
| Selected rail item | `#0C3276` | `#09265C` |
| List surface | `#FFFFFF` | `#121B29` |
| Detail surface | `#F3F6F9` | `#172232` |
| Dividers | `#D8E2EB` | `#314155` |

Use blue for actions and navigation. Reserve red, green, and yellow for actual states. Keep text legible in both color modes.

## Layout and components

- Wide screens use a full-height blue navigation rail, a white vault list, and a separate detail surface. The list takes 36% of the available row width; detail uses the rest.
- The selected navigation item uses a full background and stronger text. Avoid left accent bars.
- Mobile vault type rows use 18 vp icons, 14 fp names, and 12 fp counts within a 56 vp row. Vault items use 22 vp icons, 14 fp names, and 12 fp subtitles within a roughly 60 vp row.
- Detail fields use 12 fp labels, 16 fp values, and 48 vp inputs. The generator result uses 16 fp type in a compact 48 vp row.
- Put the wide-screen New action in the list header. Keep the compact-screen bottom navigation and its add action.
- Login uses a centered card on the neutral canvas. Primary buttons use a 6 px radius; native security controls retain their platform behavior.

Keep search, filter, copy, edit, vault locking, error states, and accessibility labels intact. Do not reuse Bitwarden logos or wordmarks.
