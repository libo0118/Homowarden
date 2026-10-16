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
- Settings root uses 60 vp push rows with 24 vp leading icons and 16 vp chevrons. Security and About use lock and information glyph roles; account, share, and history use the same OpenDesign icon family and theme colors.
- Mobile Settings detail pages use 60 vp minimum rows, 12 fp labels and helper text, 15 fp values and actions, and 16 vp horizontal card insets. Security, Account, About, Share, and Share History keep this same form rhythm and retain their existing actions.
- Generator modes sit in a separate utility row with 16 vp horizontal and 4/8 vp vertical inset. The result is a read-only field with 48 vp generate and copy targets; option rows use 15 fp text.
- Detail fields use 12 fp labels, 16 fp values, and 48 vp inputs. Homowarden retains its TOTP tab and its existing Password/Username generator modes; sharing remains under Settings.
- TOTP follows Bitwarden's in-vault verification-code screen: a 48 vp title bar with back, search, and overflow actions; 12 fp count header; grouped white rows with 24 vp login icons, 15/13 fp title and subtitle, a 30 vp blue countdown ring in a 56 vp slot, 14 fp monospace code, and a 48 vp copy target. The separate TOTP tab remains available.
- TOTP website icons use the first valid HTTP(S) hostname from the item's encrypted website URIs, keeping the same 24 vp slot and falling back to the local login glyph on missing or failed images. Requests contain only the hostname, without the URI path, query, credentials, or account authorization headers. US and EU accounts use their regional Bitwarden icon service; self-hosted accounts use only their resolved vault's `/icons` endpoint and never fall back to a public service.
- Put the wide-screen New action in the list header. Keep the compact-screen bottom navigation and its add action.
- The locked-vault screen targets the supplied Bitwarden mobile reference: a top-aligned master-password form, account and overflow actions in the title bar, supporting lock/account text, a full-width outlined biometric action, and a primary Unlock action that stays disabled while the password is empty. Automatic biometric unlocking uses the existing opt-in and system authentication flow. Device-level spacing and typography comparison remains pending.

## Icons and attribution

The interface uses 39 icon resource names in matching light and dark variants (78 SVG files), designed for Homowarden in the OpenDesign project `homowarden-mobile-icons-20261016` (Homowarden · 手机图标重设计). The family uses a 24 px canvas, rounded silhouettes, consistent optical weight, and open counters for small mobile controls. Light glyphs use `#5A6D91`; dark glyphs use `#96A3BB`. Resource names and control hit targets stay unchanged.

These Homowarden resources are included under the project's MIT license. They replace the previous Material icon geometry and do not incorporate Bitwarden-owned vector paths, logos, or wordmarks. Application branding and tray artwork are maintained separately.

Application branding is designed in the separate OpenDesign project `homowarden-app-icon-fresh-20261016`: an H-shaped arch mark on a blue launcher background, with matching light and dark small icons. The existing layered launcher and small-icon resource names remain in use. Static image and package checks do not establish launcher masking, startup appearance, or device-level rendering; those checks remain pending on HarmonyOS hardware.

Icons contain visible filled paths with `fill-rule="evenodd"` for counters. Avoid transparent canvas paths, icon fonts, masks, filters, and external assets: native HarmonyOS tinting previously exposed a transparent canvas as a solid square. `scripts/check-svg-icons.py` checks transparent canvas hazards and light/dark pairing. Resource compilation confirms that the SVGs are accepted, but even-odd counters and tint rendering still require device-level verification.

Website icons are enabled by default and can be disabled in Security settings. Only ASCII DNS names with a delegated IANA TLD are eligible; literal IPs, private and unknown suffixes, non-HTTP(S) URIs, and Unicode names keep the local glyph. `PublicTlds.ets` pins the 1,437-entry IANA snapshot version `2026101500` from 2026-10-15; refresh it when newly delegated TLDs need icons. This offline check cannot distinguish an internal host beneath a public TLD from a public website. Disabling icons prevents subsequent image requests, but does not cancel requests already sent or clear native image caches. Device network loading and cache behavior remain unverified.

Keep search, filter, copy, edit, vault locking, error states, and accessibility labels intact. Do not reuse Bitwarden logos or wordmarks. The unsigned HAP build validates ArkTS compilation; it does not establish pixel-level parity on a device.
