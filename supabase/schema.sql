-- =========================================================================
-- PROYECTO: CISNEROS EMPRENDE (PWA)
-- DIRECTORIO DIGITAL Y GESTIÓN COMERCIAL LOCAL
-- Municipio de Cisneros, Antioquia, Colombia
-- Motor: PostgreSQL (Supabase Free Tier)
-- Seguridad: 100% Server-Enforced via Row Level Security (RLS)
-- =========================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. ENUMERADOS
CREATE TYPE public.user_role AS ENUM ('admin', 'entrepreneur', 'user');
CREATE TYPE public.business_status AS ENUM ('pending', 'approved', 'rejected', 'paused');
CREATE TYPE public.report_reason AS ENUM ('wrong_info', 'closed_permanently', 'offensive', 'other');

-- 3. TABLA: PROFILES
-- Sincronizada automáticamente con auth.users mediante trigger
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    role public.user_role NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('America/Bogota', NOW())
);

-- 4. TABLA: CATEGORIES
CREATE TABLE public.categories (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    icon TEXT NOT NULL DEFAULT 'store',
    order_index INT DEFAULT 0
);

INSERT INTO public.categories (name, slug, icon, order_index) VALUES
('Gastronomía & Comidas', 'gastronomia', 'utensils', 1),
('Cafés & Trapiches', 'cafes-trapiches', 'coffee', 2),
('Comercio & Tiendas', 'comercio', 'shopping-bag', 3),
('Artesanías & Modas', 'artesanias', 'palette', 4),
('Servicios & Oficios', 'servicios', 'tools', 5),
('Hospedaje & Turismo', 'hospedaje-turismo', 'bed', 6)
ON CONFLICT (slug) DO NOTHING;

-- 5. TABLA: BUSINESSES (Negocios de Cisneros)
CREATE TABLE public.businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES public.categories(id),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    
    -- Dirección estrictamente por texto descriptivo (REGLA: Sin mapas interactivos)
    written_address TEXT NOT NULL, 
    reference_point TEXT,          
    
    -- Contacto
    whatsapp_number TEXT NOT NULL, 
    phone_number TEXT,
    instagram_url TEXT,
    facebook_url TEXT,
    
    -- Horarios estructurados en formato JSONB
    -- Ej: {"lunes": {"open": "08:00", "close": "20:00", "closed": false}, ...}
    schedule JSONB NOT NULL DEFAULT '{
        "lunes": {"open": "08:00", "close": "20:00", "closed": false},
        "martes": {"open": "08:00", "close": "20:00", "closed": false},
        "miercoles": {"open": "08:00", "close": "20:00", "closed": false},
        "jueves": {"open": "08:00", "close": "20:00", "closed": false},
        "viernes": {"open": "08:00", "close": "22:00", "closed": false},
        "sabado": {"open": "08:00", "close": "22:00", "closed": false},
        "domingo": {"open": "09:00", "close": "20:00", "closed": false}
    }'::jsonb,
    
    -- Domicilios
    delivery_available BOOLEAN NOT NULL DEFAULT true,
    delivery_cost NUMERIC(10, 2) DEFAULT 0.00,
    delivery_minimum NUMERIC(10, 2) DEFAULT 0.00,
    
    -- Fotos optimizadas
    logo_url TEXT,
    cover_images TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Estados y Moderación
    status public.business_status NOT NULL DEFAULT 'pending',
    is_featured BOOLEAN NOT NULL DEFAULT false, -- Destacado de la semana por Cami
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('America/Bogota', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('America/Bogota', NOW())
);

-- 6. TABLA: PRODUCTS (Menú de productos)
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    image_url TEXT,
    is_available BOOLEAN NOT NULL DEFAULT true,
    category_name TEXT DEFAULT 'General',
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('America/Bogota', NOW())
);

-- 7. TABLA: REVIEWS (1 reseña estricta por cuenta Google por negocio)
CREATE TABLE public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL,
    photos TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('America/Bogota', NOW()),
    
    -- Restricción estricta de 1 reseña por usuario y negocio
    CONSTRAINT one_review_per_user_business UNIQUE (business_id, user_id)
);

-- 8. TABLA: FAVORITES (❤️ Me Gusta)
CREATE TABLE public.favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('America/Bogota', NOW()),
    CONSTRAINT one_favorite_per_user_business UNIQUE (business_id, user_id)
);

-- 9. TABLA: SUGGESTIONS (Buzón de sugerencias)
CREATE TABLE public.suggestions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sender_name TEXT NOT NULL,
    sender_email TEXT,
    sender_phone TEXT,
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'new', -- 'new', 'read', 'resolved'
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('America/Bogota', NOW())
);

-- 10. TABLA: REPORTS (Reportes de información errónea o negocio cerrado)
CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reason public.report_reason NOT NULL,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'resolved'
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('America/Bogota', NOW())
);

-- =========================================================================
-- ÍNDICES DE VELOCIDAD
-- =========================================================================
CREATE INDEX idx_businesses_status ON public.businesses(status);
CREATE INDEX idx_businesses_category ON public.businesses(category_id);
CREATE INDEX idx_businesses_featured ON public.businesses(is_featured);
CREATE INDEX idx_products_business ON public.products(business_id);
CREATE INDEX idx_reviews_business ON public.reviews(business_id);
CREATE INDEX idx_favorites_business ON public.favorites(business_id);

-- =========================================================================
-- VISTA: ORGULLO CISNEROS 🏅
-- Premia a negocios con calificación promedio >= 4.6 y mínimo 5 reseñas
-- =========================================================================
CREATE OR REPLACE VIEW public.view_orgullo_cisneros AS
WITH stats AS (
    SELECT 
        b.id AS business_id,
        COUNT(DISTINCT r.id) AS total_reviews,
        COALESCE(ROUND(AVG(r.rating)::numeric, 1), 0.0) AS avg_rating,
        COUNT(DISTINCT f.id) AS total_favorites
    FROM public.businesses b
    LEFT JOIN public.reviews r ON r.business_id = b.id
    LEFT JOIN public.favorites f ON f.business_id = b.id
    WHERE b.status = 'approved'
    GROUP BY b.id
)
SELECT 
    b.*,
    s.avg_rating,
    s.total_reviews,
    s.total_favorites,
    (s.avg_rating >= 4.6 AND s.total_reviews >= 5) AS has_orgullo_cisneros
FROM public.businesses b
JOIN stats s ON s.business_id = b.id;

-- =========================================================================
-- FUNCIONES Y DISPARADORES (TRIGGERS)
-- =========================================================================

-- Verificar rol Administrador
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Sincronizar nuevo usuario de Google con profiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    assigned_role public.user_role := 'user';
BEGIN
    -- Asignación de rol de administradora a Cami
    IF NEW.email = 'andresc.15042010@gmail.com' OR NEW.raw_user_meta_data->>'is_admin' = 'true' THEN
        assigned_role := 'admin';
    END IF;

    INSERT INTO public.profiles (id, email, full_name, avatar_url, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Vecino de Cisneros'),
        NEW.raw_user_meta_data->>'avatar_url',
        assigned_role
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        avatar_url = EXCLUDED.avatar_url;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Timestamp auto-update
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('America/Bogota', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_businesses_touch
    BEFORE UPDATE ON public.businesses
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- =========================================================================
-- POLÍTICAS DE SEGURIDAD ROW LEVEL SECURITY (RLS)
-- =========================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- 1. PROFILES
CREATE POLICY "Profiles son legibles públicamente" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Usuarios actualizan su propio perfil" ON public.profiles 
    FOR UPDATE USING (auth.uid() = id) 
    WITH CHECK (auth.uid() = id);

-- 2. CATEGORIES
CREATE POLICY "Categorías lectura pública" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Admin gestiona categorías" ON public.categories FOR ALL USING (public.is_admin());

-- 3. BUSINESSES
CREATE POLICY "Público ve negocios aprobados" ON public.businesses 
    FOR SELECT USING (status = 'approved' OR auth.uid() = owner_id OR public.is_admin());

CREATE POLICY "Emprendedor registra negocio como pendiente" ON public.businesses 
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND 
        auth.uid() = owner_id AND 
        (status = 'pending' OR public.is_admin())
    );

CREATE POLICY "Emprendedor actualiza su propio negocio" ON public.businesses 
    FOR UPDATE USING (
        auth.uid() = owner_id OR public.is_admin()
    ) WITH CHECK (
        public.is_admin() OR (
            auth.uid() = owner_id AND 
            status = (SELECT b.status FROM public.businesses b WHERE b.id = businesses.id)
        )
    );

CREATE POLICY "Admin elimina negocios" ON public.businesses 
    FOR DELETE USING (public.is_admin());

-- 4. PRODUCTS
CREATE POLICY "Público ve productos de negocios aprobados" ON public.products 
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = products.business_id AND (b.status = 'approved' OR b.owner_id = auth.uid() OR public.is_admin()))
    );

CREATE POLICY "Dueño gestiona productos de su negocio" ON public.products 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = products.business_id AND (b.owner_id = auth.uid() OR public.is_admin()))
    );

-- 5. REVIEWS
CREATE POLICY "Reseñas legibles públicamente" ON public.reviews FOR SELECT USING (true);

CREATE POLICY "Usuarios registrados crean reseñas" ON public.reviews 
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND 
        auth.uid() = user_id
    );

CREATE POLICY "Usuario edita su propia reseña" ON public.reviews 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Autor o Admin borran reseñas" ON public.reviews 
    FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

-- 6. FAVORITES
CREATE POLICY "Favoritos legibles públicamente" ON public.favorites FOR SELECT USING (true);
CREATE POLICY "Usuario gestiona sus favoritos" ON public.favorites FOR ALL USING (auth.uid() = user_id);

-- 7. SUGGESTIONS
CREATE POLICY "Público envía sugerencias" ON public.suggestions FOR INSERT WITH CHECK (true);
CREATE POLICY "Solo admin lee sugerencias" ON public.suggestions FOR SELECT USING (public.is_admin());
CREATE POLICY "Solo admin actualiza sugerencias" ON public.suggestions FOR UPDATE USING (public.is_admin());

-- 8. REPORTS
CREATE POLICY "Público envía reportes" ON public.reports FOR INSERT WITH CHECK (true);
CREATE POLICY "Solo admin gestiona reportes" ON public.reports FOR ALL USING (public.is_admin());

-- =========================================================================
-- BUCKETS Y POLÍTICAS DE STORAGE
-- =========================================================================
INSERT INTO storage.buckets (id, name, public) VALUES 
('business-images', 'business-images', true),
('review-evidence', 'review-evidence', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Lectura pública de imágenes de negocios" ON storage.objects 
    FOR SELECT USING (bucket_id IN ('business-images', 'review-evidence'));

CREATE POLICY "Usuarios autenticados suben imágenes" ON storage.objects 
    FOR INSERT WITH CHECK (
        bucket_id IN ('business-images', 'review-evidence') AND 
        auth.uid() IS NOT NULL
    );
