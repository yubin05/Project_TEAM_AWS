import https from 'https';
import http from 'http';
import { config } from '../config';

export interface UserDetail {
  id: string;
  email: string;
  name: string;
}

function request<T>(url: string): Promise<T> {
  return new Promise((resolve, reject) => {
    const lib     = url.startsWith('https') ? https : http;
    const options = {
      headers: {
        'x-internal-secret': config.internal.secret,
        'Content-Type':      'application/json',
      },
    };

    lib.get(url, options, res => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (res.statusCode && res.statusCode >= 400) {
            reject(new Error(parsed.message || 'auth-service error'));
          } else {
            resolve(parsed);
          }
        } catch {
          reject(new Error('Invalid JSON from auth-service'));
        }
      });
    }).on('error', reject);
  });
}

export async function getInternalUser(userId: string): Promise<UserDetail> {
  const url = `${config.internal.authService}/internal/users/${userId}`;
  const res = await request<{ success: boolean; data: UserDetail }>(url);
  return res.data;
}
