import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim();
const supabasePublishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();
const rememberMeStorageKey = 'spotibai-remember-me';

const authStorage = {
  async getItem(key) {
    if (window.localStorage.getItem(rememberMeStorageKey) === 'true') {
      return window.localStorage.getItem(key);
    }

    window.localStorage.removeItem(key);
    return window.sessionStorage.getItem(key);
  },
  async setItem(key, value) {
    if (window.localStorage.getItem(rememberMeStorageKey) === 'true') {
      window.sessionStorage.removeItem(key);
      window.localStorage.setItem(key, value);
      return;
    }

    window.localStorage.removeItem(key);
    window.sessionStorage.setItem(key, value);
  },
  async removeItem(key) {
    window.localStorage.removeItem(key);
    window.sessionStorage.removeItem(key);
  }
};

export const supabaseConfigurationError = !supabaseUrl || !supabasePublishableKey
  ? new Error('Supabase is not configured. Add VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY to the workspace .env.local file.')
  : null;

export const supabase = supabaseConfigurationError
  ? null
  : createClient(supabaseUrl, supabasePublishableKey, {
      auth: {
        autoRefreshToken: true,
        detectSessionInUrl: true,
        flowType: 'pkce',
        persistSession: true,
        storage: authStorage
      }
    });
