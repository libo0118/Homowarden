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

Use blue for actions and navigation. Reserve red, green, and yellow for actual states. Keep text legible in both color modes.

## Layout and components

- Wide screens use a full-height blue navigation rail, a white vault list, and a separate detail surface. The list takes 36% of the available row width; detail uses the rest.
- The selected navigation item uses a full background and stronger text. Avoid left accent bars.
- Mobile root pages use a 56 vp top bar with a 28 fp semibold title; the second login step uses a 48 vp bar with a 19 fp title. The login landing title is 18 fp.
- Vault type and item rows have a 60 vp minimum, 24 vp icons, 16 vp horizontal inset, and 15 fp primary text; item subtitles are 13 fp and type counts 12 fp. Type rows are grouped in a white rounded surface.
- Settings root uses 60 vp push rows with 24 vp leading icons and 16 vp chevrons; existing settings remain in drill-in sections.
- Generator modes sit in a separate utility row with 16 vp horizontal and 4/8 vp vertical inset. The result is a read-only field with 48 vp generate and copy targets; option rows use 15 fp text.
- Detail fields use 12 fp labels, 16 fp values, and 48 vp inputs. Homowarden retains its TOTP tab and its existing Password/Username generator modes; sharing remains under Settings.
- Put the wide-screen New action in the list header. Keep the compact-screen bottom navigation and its add action.
- Login uses a centered card on the neutral canvas. Primary buttons use a 6 px radius; native security controls retain their platform behavior.

Keep search, filter, copy, edit, vault locking, error states, and accessibility labels intact. Do not reuse Bitwarden logos or wordmarks. The unsigned HAP build validates ArkTS compilation; it does not establish pixel-level parity on a device.
