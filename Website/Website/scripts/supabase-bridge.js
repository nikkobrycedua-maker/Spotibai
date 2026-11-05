import { supabase, supabaseConfigurationError } from './supabase-client.js';

if (supabaseConfigurationError) {
  window.dispatchEvent(new CustomEvent('spotibai:supabase-error', {
    detail: supabaseConfigurationError
  }));
} else {
  window.dispatchEvent(new CustomEvent('spotibai:supabase-ready', {
    detail: supabase
  }));
}
