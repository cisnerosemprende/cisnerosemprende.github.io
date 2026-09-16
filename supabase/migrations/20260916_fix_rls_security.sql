-- =========================================================================
-- MIGRACIÓN DE SEGURIDAD RLS (V5 y V6)
-- Corrige vulnerabilidad de auto-aprobación en businesses y race-condition en reviews
-- =========================================================================

-- 1. CORREGIR POLÍTICA DE UPDATE EN BUSINESSES (V5)
DROP POLICY IF EXISTS "Emprendedor actualiza su propio negocio" ON public.businesses;

CREATE POLICY "Emprendedor actualiza su propio negocio" ON public.businesses 
    FOR UPDATE USING (
        auth.uid() = owner_id OR public.is_admin()
    ) WITH CHECK (
        public.is_admin() OR (
            auth.uid() = owner_id AND 
            status = (SELECT b.status FROM public.businesses b WHERE b.id = businesses.id)
        )
    );

-- 2. CORREGIR POLÍTICA DE INSERT EN REVIEWS (V6)
DROP POLICY IF EXISTS "Solo 1 reseña por usuario y negocio" ON public.reviews;

CREATE POLICY "Usuarios registrados crean reseñas" ON public.reviews 
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND 
        auth.uid() = user_id
    );

-- 3. SIMPLIFICAR POLÍTICA DE UPDATE EN PROFILES (B10)
DROP POLICY IF EXISTS "Usuarios actualizan su propio perfil" ON public.profiles;

CREATE POLICY "Usuarios actualizan su propio perfil" ON public.profiles 
    FOR UPDATE USING (auth.uid() = id) 
    WITH CHECK (auth.uid() = id);
