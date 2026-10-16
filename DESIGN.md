# Homowarden visual system

The light mobile interface follows the [Bitwarden Android UI source](https://github.com/bitwarden/android/tree/1470154cf3d3d0511cdbe5bfc6493971b6478edf) while retaining Homowarden branding and native HarmonyOS controls. Source-derived layout values are implementation targets; device-level visual comparison remains pending.

## Color

| Role | Light | Dark |
| --- | --- | --- |
| Primary action | `#175DDC` | `#175DDC` |
| Navigation rail | `#175DDC` | `#0C3276` |
| Selected rail item | `#0C3276` | `#09265C` |
| List surface | `#FFFFFF` | `#121B29` |
| Detail surface | `#F3F6F9` | `#172232` |
| Dividers | `#D3D9E3` | `#314155` |
| Settings glyphs | `#5A6D91` | `#96A3BB` |

Use blue for actions and navigation. Reserve red, green, and yellow for actual states. Keep text legible in both color modes.

## Layout and components

- Wide screens use a full-height blue navigation rail, a white vault list, and a separate detail surface. The list takes 36% of the available row width; detail uses the rest.
- The selected navigation item uses a full background and stronger text. Avoid left accent bars.
- Mobile root pages use a 56 vp top bar with a 28 fp semibold title; the second login step uses a 48 vp bar with a 19 fp title. The login landing title is 18 fp.
- Vault type and item rows have a 60 vp minimum, 24 vp icons, 16 vp horizontal inset, and 15 fp primary text; item subtitles are 13 fp and type counts 12 fp. Type rows are grouped in a white rounded surface.
- Settings root uses 60 vp push rows with 24 vp leading icons and 16 vp chevrons. Security and About use lock and information glyph roles; account, share, and history use the same Material Icons Outlined family and theme colors.
- Mobile Settings detail pages use 60 vp minimum rows, 12 fp labels and helper text, 15 fp values and actions, and 16 vp horizontal card insets. Security, Account, About, Share, and Share History keep this same form rhythm and retain their existing actions.
- Generator modes sit in a separate utility row with 16 vp horizontal and 4/8 vp vertical inset. The result is a read-only field with 48 vp generate and copy targets; option rows use 15 fp text.
- Detail fields use 12 fp labels, 16 fp values, and 48 vp inputs. Homowarden retains its TOTP tab and its existing Password/Username generator modes; sharing remains under Settings.
- TOTP follows Bitwarden's in-vault verification-code screen: a 48 vp title bar with back, search, and overflow actions; 12 fp count header; grouped white rows with 24 vp login icons, 15/13 fp title and subtitle, a 30 vp blue countdown ring in a 56 vp slot, 14 fp monospace code, and a 48 vp copy target. The separate TOTP tab remains available.
- Put the wide-screen New action in the list header. Keep the compact-screen bottom navigation and its add action.
- The locked-vault screen targets the supplied Bitwarden mobile reference: a top-aligned master-password form, account and overflow actions in the title bar, supporting lock/account text, a full-width outlined biometric action, and a primary Unlock action that stays disabled while the password is empty. Automatic biometric unlocking uses the existing opt-in and system authentication flow. Device-level spacing and typography comparison remains pending.

## Icons and attribution

The interface uses 39 icon resource names in matching light and dark variants (78 SVG files). Of these, 38 use Google Material Icons Outlined 24 px geometry; the selected favorite uses the family's filled star. Material vector paths are preserved, with only root dimensions and theme colors adapted. The vault safe-door icon is original Homowarden artwork under the project's MIT license.

These icons match the reference's visual roles without incorporating Bitwarden-owned vector paths, logos, or wordmarks. The complete upstream file mapping and Apache-2.0 license are in [`third_party/material-icons/NOTICE.md`](third_party/material-icons/NOTICE.md) and [`LICENSE`](third_party/material-icons/LICENSE), pinned to Material Icons commit `49d4db35df873165d6bd6ba09b063c7dafbac2f4`. Identical notice and license copies live in `entry/src/main/resources/rawfile/third_party/material_icons/` for inclusion in the HAP's raw resources.

Keep search, filter, copy, edit, vault locking, error states, and accessibility labels intact. Do not reuse Bitwarden logos or wordmarks. The unsigned HAP build validates ArkTS compilation; it does not establish pixel-level parity on a device.
