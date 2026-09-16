// =========================================================================
// Cliente de Conexión: Supabase JS (Free Tier - Cisneros Emprende)
// =========================================================================

import { createClient } from '@supabase/supabase-js';

// Claves de Supabase integradas directamente con fallback de variables de entorno
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://qopvmadvijnjgzgxwjpe.supabase.co';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'sb_publishable_AVcBF5PDKQ5oS2FYsCYzLw__Hqd8Hkz';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

/**
 * Autenticación mediante Google OAuth
 */
export async function signInWithGoogle() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: typeof window !== 'undefined' ? window.location.origin : undefined,
    },
  });
  if (error) throw error;
  return data;
}

/**
 * Cierre de sesión seguro
 */
export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

/**
 * Obtener perfil completo del usuario actual
 */
export async function getCurrentProfile() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;

  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single();

  if (error) {
    console.error('Error al obtener perfil:', error);
    return null;
  }
  return data;
}
