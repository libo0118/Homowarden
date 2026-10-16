import { DataPreferences } from '@abner/datastore';
import { getServerEndpoints } from '../network/ServerEndpointResolver';
import { SERVER_TYPE_KEY, ServerType, WEBSITE_ICONS } from './Constants';
import { PUBLIC_TLDS } from './PublicTlds';

/** Only public DNS website names may be disclosed to an icon service. */
export function getPublicWebsiteHostname(uri: string): string {
  if (typeof uri !== 'string' || /[\s\\\x00-\x1f\x7f]/.test(uri)) {
    return '';
  }
  const match = uri.match(/^https?:\/\/([^/?#]+)(?:[/?#]|$)/i);
  if (!match) {
    return '';
  }
  const authority = match[1].substring(match[1].lastIndexOf('@') + 1);
  const hostAndPort = authority.match(/^([^:]+)(?::([0-9]+))?$/);
  if (!hostAndPort || (hostAndPort[2] &&
    (Number(hostAndPort[2]) < 1 || Number(hostAndPort[2]) > 65535))) {
    return '';
  }
  const host = hostAndPort[1].toLowerCase().replace(/\.$/, '');
  if (host.length > 253) {
    return '';
  }
  const labels = host.split('.');
  if (labels.length < 2 || labels.some((label: string) =>
    !/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(label))) {
    return '';
  }
  const suffix = labels[labels.length - 1];
  if (!PUBLIC_TLDS.has(suffix) ||
    ['localhost', 'local', 'localdomain', 'lan', 'internal', 'intranet', 'home', 'corp',
      'private', 'test', 'invalid', 'example', 'onion', 'arpa'].includes(suffix)) {
    return '';
  }
  // shortcut: literal IPs and Unicode names use the local icon; accept ASCII punycode names.
  return host;
}

export function buildWebsiteIconUrl(iconBaseUrl: string, hostname: string): string {
  if (!iconBaseUrl || getPublicWebsiteHostname(`https://${hostname}`) !== hostname) {
    return '';
  }
  return `${iconBaseUrl}/${hostname}/icon.png`;
}

export class WebsiteIconUtil {
  static isEnabled(): boolean {
    try {
      return DataPreferences.getInstance().getSync<number>(WEBSITE_ICONS) !== 0;
    } catch (_) {
      return false;
    }
  }

  static setEnabled(enabled: boolean): void {
    DataPreferences.getInstance().putSync(WEBSITE_ICONS, enabled ? 1 : 0);
    AppStorage.setOrCreate('websiteIconsEnabled', enabled);
  }

  static async getIconBaseUrl(): Promise<string> {
    try {
      const serverType = DataPreferences.getInstance().getSync<ServerType>(SERVER_TYPE_KEY);
      if (serverType === ServerType.US) {
        return 'https://icons.bitwarden.net';
      }
      if (serverType === ServerType.EU) {
        return 'https://icons.bitwarden.eu';
      }
      if (serverType === ServerType.SELF_HOSTED) {
        const endpoints = await getServerEndpoints();
        const base = endpoints.vaultBaseUrl.replace(/\/+$/, '');
        if (/^https?:\/\/[^\s/?#@\\]+(?:\/[^\s?#\\]*)?$/i.test(base)) {
          return `${base}/icons`;
        }
      }
    } catch (_) {
      // A self-hosted failure must never disclose the domain to a public fallback service.
    }
    return '';
  }
}
