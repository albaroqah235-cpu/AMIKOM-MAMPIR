-- ========================================================================
-- SKRIP SQL SETUP SUPABASE UNTUK MAMPIR APP
-- ========================================================================
-- Jalankan skrip ini di SQL Editor dashboard Supabase Anda:
-- https://supabase.com/dashboard/project/vdqdithxujxvzyybjtpn/sql/new
-- ========================================================================

-- 1. Buat Tabel 'places'
CREATE TABLE IF NOT EXISTS public.places (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    city TEXT NOT NULL,
    category TEXT NOT NULL,
    min_price INTEGER DEFAULT 0,
    max_price INTEGER DEFAULT 0,
    avg_price INTEGER DEFAULT 0,
    rating NUMERIC(3, 2) DEFAULT 4.5,
    review_count INTEGER DEFAULT 100,
    facilities JSONB DEFAULT '[]'::jsonb,
    address TEXT DEFAULT '',
    description TEXT DEFAULT '',
    open_hours TEXT DEFAULT '09.00 - 22.00 WIB',
    latitude NUMERIC(10, 6) DEFAULT -7.4244,
    longitude NUMERIC(10, 6) DEFAULT 109.2302,
    image_url TEXT DEFAULT '',
    menu_highlights JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Baseline dari Google Places dan override yang dikelola admin.
ALTER TABLE public.places
    ADD COLUMN IF NOT EXISTS google_place_id TEXT,
    ADD COLUMN IF NOT EXISTS google_snapshot JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS google_synced_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS override_fields JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS data_source TEXT DEFAULT 'google';

CREATE UNIQUE INDEX IF NOT EXISTS places_google_place_id_idx
    ON public.places (google_place_id)
    WHERE google_place_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT DEFAULT '',
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.place_categories (
    place_id TEXT PRIMARY KEY REFERENCES public.places(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.place_preferences (
    place_id TEXT NOT NULL REFERENCES public.places(id) ON DELETE CASCADE,
    preference_id UUID NOT NULL REFERENCES public.preferences(id) ON DELETE CASCADE,
    PRIMARY KEY (place_id, preference_id)
);

CREATE TABLE IF NOT EXISTS public.place_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    place_id TEXT NOT NULL REFERENCES public.places(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rating NUMERIC(2, 1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    body TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    place_id TEXT REFERENCES public.places(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
$$;

DROP POLICY IF EXISTS "Public can read categories" ON public.categories;
CREATE POLICY "Public can read categories" ON public.categories
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public can read preferences" ON public.preferences;
CREATE POLICY "Public can read preferences" ON public.preferences
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public can read place categories" ON public.place_categories;
CREATE POLICY "Public can read place categories" ON public.place_categories
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public can read place preferences" ON public.place_preferences;
CREATE POLICY "Public can read place preferences" ON public.place_preferences
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Public can read notifications" ON public.notifications;
CREATE POLICY "Public can read notifications" ON public.notifications
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can read profiles" ON public.user_profiles;
CREATE POLICY "Authenticated users can read profiles" ON public.user_profiles
    FOR SELECT TO authenticated USING (id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Admins manage places" ON public.places;
CREATE POLICY "Admins manage places" ON public.places
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage categories" ON public.categories;
CREATE POLICY "Admins manage categories" ON public.categories
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage preferences" ON public.preferences;
CREATE POLICY "Admins manage preferences" ON public.preferences
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage place categories" ON public.place_categories;
CREATE POLICY "Admins manage place categories" ON public.place_categories
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage place preferences" ON public.place_preferences;
CREATE POLICY "Admins manage place preferences" ON public.place_preferences
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users create own reviews" ON public.place_reviews;
CREATE POLICY "Users create own reviews" ON public.place_reviews
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Public read reviews" ON public.place_reviews;
CREATE POLICY "Public read reviews" ON public.place_reviews
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Admins manage notifications" ON public.notifications;
CREATE POLICY "Admins manage notifications" ON public.notifications
    FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users insert analytics" ON public.analytics_events;
CREATE POLICY "Users insert analytics" ON public.analytics_events
    FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Admins read analytics" ON public.analytics_events;
CREATE POLICY "Admins read analytics" ON public.analytics_events
    FOR SELECT TO authenticated USING (public.is_admin());

-- 2. Aktifkan Row Level Security (RLS) dan Berikan Izin Baca Publik (Anon)
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access" ON public.places;
CREATE POLICY "Allow public read access" 
ON public.places FOR SELECT 
TO anon, authenticated 
USING (true);

DROP POLICY IF EXISTS "Allow public insert access" ON public.places;

-- 3. Seed data awal.
-- Jangan menjalankan TRUNCATE di sini karena places direferensikan oleh
-- place_categories, place_preferences, place_reviews, dan analytics_events.
-- Jika memang ingin mengosongkan seluruh katalog secara sengaja, jalankan
-- perintah berikut secara terpisah setelah memastikan data sudah dicadangkan:
-- TRUNCATE TABLE public.places CASCADE;

-- 4. Masukkan 25 Data Autentik Purwokerto & Sekitarnya
INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('pwt-1', 'Kopi Kenangan Sudirman', 'Purwokerto Kota', 'Cafe', 15000, 50000, 25000, 4.8, 1250, '["AC", "WiFi", "Colokan", "Indoor", "Parkir"]'::jsonb, 'Jl. Jend. Sudirman No. 392, Purwokerto', 'Tempat ngopi modern yang nyaman di pusat Kota Purwokerto, cocok untuk bekerja, nugas, atau sekadar santai bersama teman.', '08.00 - 22.00 WIB', -7.4244, 109.2302, 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80', '[{"name": "Kopi Kenangan Mantan", "price": 18000}, {"name": "Avocado Coffee", "price": 24000}, {"name": "Roti Cokelat Klasik", "price": 12000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('pwt-2', 'The Local Space', 'Purwokerto Kota', 'Cafe', 20000, 70000, 35000, 4.6, 640, '["WiFi", "Colokan", "AC", "Indoor", "Outdoor", "Ramah Hewan"]'::jsonb, 'Jl. Dr. Angka No. 45, Purwokerto', 'Cafe estetik dengan desain modern kontemporer di kawasan Dr. Angka, tempat favorit nugas skripsi, meeting casual, dan hangout sore.', '10.00 - 23.00 WIB', -7.4172, 109.2395, 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?auto=format&fit=crop&w=800&q=80', '[{"name": "Caramel Macchiato", "price": 28000}, {"name": "Truffle French Fries", "price": 25000}, {"name": "Pasta Carbonara", "price": 35000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('pwt-3', 'Roti Bakar 88 GOR Satria', 'Purwokerto Kota', 'Warkop', 15000, 40000, 22000, 4.5, 410, '["WiFi", "Outdoor", "Colokan", "Musik", "Parkir"]'::jsonb, 'Jl. Prof. Dr. Suharso (Kompleks GOR Satria), Purwokerto', 'Spot nongkrong malam favorit pemuda Purwokerto di kawasan GOR Satria dengan roti bakar tebal, pisang keju cokelat, dan aneka minuman segar.', '16.00 - 01.00 WIB', -7.412, 109.251, 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=800&q=80', '[{"name": "Roti Bakar Cokelat Keju", "price": 18000}, {"name": "Indomie Kuah Kornet Telur", "price": 16000}, {"name": "Es Ovaltine Volcano", "price": 14000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('pwt-4', 'Warmindo Sudirman Sentosa', 'Purwokerto Kota', 'Warkop', 6000, 18000, 12000, 4.6, 850, '["WiFi", "Colokan", "Outdoor"]'::jsonb, 'Jl. Jend. Sudirman No. 120, Purwokerto', 'Warmindo andalan begadang anak muda dan mahasiswa di jantung kota. Buka 24 jam dengan racikan mie dok-dok kuah kental, magelangan gurih, dan es nutrisari dingin.', 'Buka 24 Jam', -7.423, 109.235, 'https://images.unsplash.com/photo-1612927601601-6638404737ce?auto=format&fit=crop&w=800&q=80', '[{"name": "Mie Dok-Dok Pedas Telur", "price": 12000}, {"name": "Nasi Magelangan", "price": 14000}, {"name": "Es Kopi Goodday Dingin", "price": 5000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('pwt-5', 'Choco Klik Cafe & Resto', 'Purwokerto Kota', 'Cafe', 18000, 55000, 32000, 4.6, 780, '["AC", "WiFi", "Colokan", "Indoor", "Outdoor"]'::jsonb, 'Jl. Overste Isdiman No. 11, Purwokerto', 'Surga bagi pecinta olahan cokelat murni dan dessert kekinian di kawasan kuliner hits Overste Isdiman, sangat cocok untuk kumpul kencan atau nongkrong santai.', '11.00 - 23.00 WIB', -7.4145, 109.2415, 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?auto=format&fit=crop&w=800&q=80', '[{"name": "Dark Choco Volcano", "price": 26000}, {"name": "Choco Fondue Platter", "price": 38000}, {"name": "Spageti Aglio Olio", "price": 30000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('pwt-6', 'Bakso & Soto Sami Asih', 'Purwokerto Kota', 'Restoran', 15000, 35000, 24000, 4.8, 1950, '["Parkir", "Indoor", "Mushola"]'::jsonb, 'Jl. Pramuka No. 23, Purwokerto', 'Kuliner bakso dan soto daging legendaris di jantung kota Purwokerto dengan kuah kaldu sapi bening pekat gurih, tetelan empuk, dan tetelan gajih melimpah.', '09.00 - 21.00 WIB', -7.429, 109.241, 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=800&q=80', '[{"name": "Bakso Urat Tetelan Spesial", "price": 25000}, {"name": "Soto Daging Sapi Sami Asih", "price": 26000}, {"name": "Es Dawet Campur", "price": 8000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('pwt-7', 'Orak Arik Pedas Sukun', 'Purwokerto Kota', 'Warkop', 10000, 22000, 14000, 4.7, 1150, '["Outdoor", "Parkir", "Rumahan"]'::jsonb, 'Jl. Gatot Subroto No. 64, Purwokerto', 'Kuliner malam legendaris dengan orak-arik telur sayur pedas nampol khas Purwokerto, dimasak dadakan di wajan panas dengan aroma gurih memikat.', '17.00 - 02.00 WIB', -7.4265, 109.238, 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80', '[{"name": "Nasi Orak-Arik Sukun Pedas", "price": 14000}, {"name": "Tambahan Ayam Suwir", "price": 6000}, {"name": "Es Jeruk Manis", "price": 4000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('pwt-8', 'Angkringan Pendopo Alun-Alun Purwokerto', 'Purwokerto Kota', 'Warkop', 5000, 20000, 12000, 4.6, 1300, '["Outdoor", "Lesehan", "Musik"]'::jsonb, 'Sisi Timur Alun-Alun Purwokerto, Jl. Jend. Sudirman', 'Pusat tongkrongan lesehan malam hari di Alun-Alun Purwokerto dengan view gemerlap lampu kota dan tugu air mancur, sate kulit, sate usus, dan wedang jahe rempah.', '18.00 - 02.00 WIB', -7.4246, 109.2315, 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80', '[{"name": "Nasi Kucing Sambal Bandeng", "price": 4000}, {"name": "Sate Kulit Puyuh Bakar", "price": 3000}, {"name": "Wedang Ronde Jahe Geprek", "price": 7000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('btr-1', 'Kopi Keprok Baturraden', 'Baturraden', 'Cafe', 15000, 45000, 25000, 4.8, 1450, '["Outdoor", "WiFi", "Colokan", "Mushola", "Romantis"]'::jsonb, 'Jl. Raya Baturraden KM 7, Karanggintung, Baturraden', 'Cafe bernuansa alam pedesaan sejuk di kaki Gunung Slamet dengan pemandangan sawah terasering, gemericik sungai kecil, dan kopi tubruk tradisional nikmat.', '09.00 - 23.00 WIB', -7.3621, 109.2435, 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80', '[{"name": "Kopi Tubruk Keprok", "price": 15000}, {"name": "Pisang Goreng Gula Aren", "price": 14000}, {"name": "Nasi Sayur Desa", "price": 22000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('btr-2', 'Massapi Kafe & Resto Baturraden', 'Baturraden', 'Cafe', 25000, 80000, 45000, 4.8, 1720, '["Outdoor", "Indoor", "WiFi", "Mushola", "Romantis", "Parkir"]'::jsonb, 'Dusun III Berkat, Desa Kebumen, Baturraden', 'Resto & kafe berkonsep peternakan modern di dataran tinggi Baturraden dengan view perbukitan hijau, udara berkabut, susu segar murni, dan aneka steak lezat.', '10.00 - 22.00 WIB', -7.3325, 109.228, 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80', '[{"name": "Sirloin Steak BBQ", "price": 58000}, {"name": "Susu Segar Murni Baturraden", "price": 15000}, {"name": "Massapi Platter", "price": 35000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('btr-3', 'Warung Pengkolan Sate Kelinci', 'Baturraden', 'Warkop', 15000, 40000, 26000, 4.7, 1100, '["Outdoor", "Parkir", "Lesehan"]'::jsonb, 'Kawasan Wana Wisata Baturraden, Karangmangu', 'Kuliner ikonik pegunungan Baturraden dengan sajian sate kelinci empuk berbumbu kacang manis pedas, mendoan hangat ukuran jumbo, dan wedang ronde.', '08.30 - 21.00 WIB', -7.315, 109.224, 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80', '[{"name": "Sate Kelinci 10 Tusuk + Lontong", "price": 28000}, {"name": "Tempe Mendoan Jumbo", "price": 12000}, {"name": "Wedang Jahe Susu Ronde", "price": 10000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('btr-4', 'Limpakuwus Resto & Coffee Baturraden', 'Baturraden', 'Restoran', 20000, 65000, 38000, 4.7, 950, '["Outdoor", "Parkir", "Mushola", "Romantis", "WiFi"]'::jsonb, 'Kawasan Wisata Hutan Pinus Limpakuwus, Sumbang - Baturraden', 'Sensasi bersantap di bawah rimbun pohon pinus raksasa dengan udara sejuk pegunungan, menu masakan hangat khas dataran tinggi, dan racikan kopi arabika.', '08.00 - 18.00 WIB', -7.319, 109.252, 'https://images.unsplash.com/photo-1447933601403-0c6688de566e?auto=format&fit=crop&w=800&q=80', '[{"name": "Sup Buntut Rempah Hangat", "price": 48000}, {"name": "Kopi Pinus Arabika", "price": 22000}, {"name": "Pisang Bakar Keju Aren", "price": 18000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('btr-5', 'Kandang Kopi Curug Bayan', 'Baturraden', 'Cafe', 15000, 45000, 24000, 4.7, 880, '["WiFi", "Outdoor", "Colokan", "Romantis", "Musik"]'::jsonb, 'Jl. Wisata Curug Bayan, Ketenger, Baturraden', 'Kedai kopi berkonsep rustic outdoor dekat aliran Curug Bayan yang dingin dan jernih, menikmati hangatnya kopi arabika Gunung Slamet diiringi suara riak air terjun.', '10.00 - 22.00 WIB', -7.327, 109.221, 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&q=80', '[{"name": "Kopi Arabika Slamet V60", "price": 20000}, {"name": "Singkong Goreng Sambal Roa", "price": 15000}, {"name": "Cireng Salju Bumbu Rujak", "price": 14000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('btr-6', 'Agathis Resto Wana Wisata', 'Baturraden', 'Restoran', 22000, 70000, 40000, 4.6, 710, '["Outdoor", "Indoor", "Parkir", "Mushola", "Lesehan"]'::jsonb, 'Kawasan Hutan Agathis Palawi, Baturraden', 'Resto keluarga di tengah teduhnya kanopi pohon damar (Agathis) dengan hidangan khas sunda-jawa, gurame asam manis, dan aneka minuman jahe hangat.', '09.00 - 20.00 WIB', -7.321, 109.229, 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80', '[{"name": "Gurame Bakar Cobek Agathis", "price": 58000}, {"name": "Ayam Kampung Goreng Kremes", "price": 30000}, {"name": "Kopi Jahe Susu Palawi", "price": 14000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('uns-1', 'Warung Makan Bu Sari', 'Purwokerto Utara', 'Restoran', 10000, 25000, 15000, 4.7, 980, '["Outdoor", "Parkir", "Mushola", "Rumahan"]'::jsonb, 'Jl. HR Bunyamin No. 88 (Dekat Kampus Unsoed Grendeng), Purwokerto', 'Warung makan prasmanan khas Banyumasan dengan aneka sayur lodeh, ayam goreng lengkuas, mendoan hangat, dan sambal terasi segar harga mahasiswa.', '07.00 - 21.00 WIB', -7.4085, 109.245, 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80', '[{"name": "Paket Nasi Sayur + Ayam", "price": 18000}, {"name": "Mendoan Purwokerto (3 pcs)", "price": 9000}, {"name": "Es Jeruk Peras Segar", "price": 5000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('uns-2', 'Table Nine Kitchen & Resto', 'Purwokerto Utara', 'Restoran', 30000, 120000, 60000, 4.8, 2100, '["AC", "WiFi", "Parkir", "Indoor", "Outdoor", "Mushola"]'::jsonb, 'Jl. Prof. Dr. HR Bunyamin No. 9, Pabuaran, Purwokerto Utara', 'Restoran keluarga & casual dining modern paling representatif di Purwokerto dengan aneka menu nusantara, chinese food, dan western dalam suasana elegan.', '10.00 - 22.00 WIB', -7.404, 109.243, 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80', '[{"name": "Gurame Bakar Madu Pedas", "price": 65000}, {"name": "Nasi Goreng Table Nine", "price": 38000}, {"name": "Rib Eye Steak Australian", "price": 98000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('uns-3', 'Serabine.co Unsoed', 'Purwokerto Utara', 'Warkop', 8000, 25000, 15000, 4.6, 670, '["WiFi", "Outdoor", "Colokan", "Musik"]'::jsonb, 'Jl. Suparno No. 34, Karangwangkal, Purwokerto Utara', 'Tongkrongan anak muda dengan sajian serabi tradisional Jawa yang dimodernisasi berbagai topping lumer seperti keju mozzarella, cokelat nutella, dan oreo.', '15.00 - 23.30 WIB', -7.401, 109.253, 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=800&q=80', '[{"name": "Serabi Cokelat Keju Lumer", "price": 12000}, {"name": "Serabi Telur Asin Pedas", "price": 14000}, {"name": "Es Cokelat Klasik", "price": 10000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('skr-1', 'Soto H. Loso Sokaraja', 'Sokaraja', 'Restoran', 20000, 45000, 30000, 4.9, 2300, '["Parkir", "Mushola", "Outdoor", "Indoor"]'::jsonb, 'Jl. Raya Bank Jateng No. 15, Sokaraja, Banyumas', 'Soto khas Sokaraja paling legendaris dengan kuah kaldu sapi kental berpadu sambal kacang gurih serta ketupat dan kerupuk cantir merah khas.', '08.00 - 20.30 WIB', -7.4612, 109.2789, 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?auto=format&fit=crop&w=800&q=80', '[{"name": "Soto Daging Sapi Komplit", "price": 28000}, {"name": "Soto Ayam Kampung", "price": 23000}, {"name": "Tempe Mendoan Sokaraja", "price": 10000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('skr-2', 'Getuk Goreng Asli H. Tohirin', 'Sokaraja', 'Restoran', 15000, 45000, 25000, 4.9, 3200, '["Parkir", "AC", "Indoor"]'::jsonb, 'Jl. Jend. Sudirman No. 151, Sokaraja Tengah', 'Pusat oleh-oleh dan kuliner legendaris paling ternama di Banyumas sejak 1918. Getuk singkong manis legit dibalut gula kelapa murni yang renyah di luar dan lumer di dalam.', '07.00 - 21.30 WIB', -7.458, 109.274, 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=800&q=80', '[{"name": "Getuk Goreng Original 1 Besek", "price": 25000}, {"name": "Getuk Goreng Aneka Rasa", "price": 28000}, {"name": "Nopia Khas Banyumas", "price": 15000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('skr-3', 'Soto Kecik Dua Rasa Sokaraja', 'Sokaraja', 'Restoran', 18000, 40000, 27000, 4.8, 1400, '["Parkir", "Outdoor", "Indoor", "Mushola"]'::jsonb, 'Jl. Jend. Sudirman No. 42, Sokaraja Kidul', 'Varian soto Sokaraja istimewa dengan bumbu kecik rahasia turun-temurun, pilihan daging sapi lembut atau babat iso, disiram sambal kacang kental beraroma rempah.', '08.00 - 20.00 WIB', -7.4635, 109.2805, 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?auto=format&fit=crop&w=800&q=80', '[{"name": "Soto Kecik Daging Sapi", "price": 26000}, {"name": "Soto Campur Babat Daging", "price": 29000}, {"name": "Kerupuk Cantir Renyah", "price": 5000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('tim-1', 'Warung Djoglo Arcawinangun', 'Purwokerto Timur', 'Restoran', 18000, 55000, 32000, 4.7, 890, '["Parkir", "Outdoor", "Indoor", "Mushola", "Romantis"]'::jsonb, 'Jl. Sunan Bonang No. 8, Arcawinangun, Purwokerto Timur', 'Resto berarsitektur rumah Joglo Jawa kuno dengan suasana teduh alami, menyajikan masakan tradisional jawa timuran & banyumasan serta aneka kopi tubruk.', '09.30 - 21.30 WIB', -7.416, 109.262, 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80', '[{"name": "Nasi Liwet Ayam Suwir Komplit", "price": 28000}, {"name": "Rawon Daging Djoeglo", "price": 32000}, {"name": "Mendoan Krispi Cabai Rawit", "price": 12000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('tim-2', 'Kopi Sadarwana Kembaran', 'Purwokerto Timur', 'Warkop', 12000, 35000, 20000, 4.6, 510, '["WiFi", "Outdoor", "Colokan", "Mushola"]'::jsonb, 'Jl. Raya Ledug, Kembaran (Dekat Kampus UMP)', 'Tempat ngopi syahdu di perbatasan timur Purwokerto dengan angin sejuk persawahan, favorit mahasiswa UMP untuk diskusi kelompok dan menikmati senja.', '13.00 - 23.00 WIB', -7.4175, 109.2745, 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80', '[{"name": "Kopi Susu Sadarwana", "price": 16000}, {"name": "Tahu Gejrot Banyumas", "price": 12000}, {"name": "Tempe Mendoan Hangat", "price": 10000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('tim-3', 'Lesehan Ikan Bakar Sekar Surya', 'Purwokerto Timur', 'Restoran', 20000, 60000, 35000, 4.7, 730, '["Parkir", "Outdoor", "Mushola", "Lesehan"]'::jsonb, 'Jl. Raya Sumbang No. 17, Sumbang, Banyumas', 'Warung lesehan keluarga di kawasan Sumbang dengan kolam ikan asri, sajian gurame bakar kecap pedas, nila goreng renyah, dan lalapan segar daun kemangi.', '10.00 - 21.00 WIB', -7.382, 109.268, 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80', '[{"name": "Gurame Bakar Madu Pedas", "price": 52000}, {"name": "Nila Goreng Terbang", "price": 28000}, {"name": "Cah Kangkung Terasi", "price": 12000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('brt-1', 'D''Java Cafe & Bistro Stasiun', 'Purwokerto Barat', 'Cafe', 20000, 60000, 32000, 4.6, 530, '["AC", "WiFi", "Colokan", "Indoor", "Parkir"]'::jsonb, 'Jl. Kober No. 12 (Dekat Pintu Keluar Stasiun Purwokerto)', 'Cafe strategis berkonsep heritage modern dekat Stasiun Purwokerto, tempat singgah paling nyaman sebelum naik kereta atau setelah tiba di kota Purwokerto.', '09.00 - 23.00 WIB', -7.418, 109.219, 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80', '[{"name": "DJava Signature Latte", "price": 25000}, {"name": "Chicken Schnitzel", "price": 34000}, {"name": "Singkong Keju Salju", "price": 16000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;

INSERT INTO public.places (id, name, city, category, min_price, max_price, avg_price, rating, review_count, facilities, address, description, open_hours, latitude, longitude, image_url, menu_highlights)
VALUES ('brt-2', 'Restoran Pringsewu Purwokerto', 'Purwokerto Selatan', 'Restoran', 25000, 85000, 45000, 4.7, 2450, '["Parkir", "AC", "Mushola", "Outdoor", "Indoor", "Lesehan"]'::jsonb, 'Jl. Gerilya Barat No. 8, Tanjung, Purwokerto Selatan', 'Restoran keluarga dengan taman asri, kolam ikan, dan saung lesehan. Spesialis gurame terbang bumbu cobek, ayam bakar taliwang, dan aneka tumisan lezat.', '08.00 - 22.00 WIB', -7.4385, 109.227, 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80', '[{"name": "Gurame Terbang Sambal Cobek", "price": 68000}, {"name": "Ayam Bakar Bumbu Rujak", "price": 32000}, {"name": "Es Teler Pringsewu", "price": 18000}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
name = EXCLUDED.name,
city = EXCLUDED.city,
category = EXCLUDED.category,
min_price = EXCLUDED.min_price,
max_price = EXCLUDED.max_price,
avg_price = EXCLUDED.avg_price,
rating = EXCLUDED.rating,
review_count = EXCLUDED.review_count,
facilities = EXCLUDED.facilities,
address = EXCLUDED.address,
description = EXCLUDED.description,
open_hours = EXCLUDED.open_hours,
latitude = EXCLUDED.latitude,
longitude = EXCLUDED.longitude,
image_url = EXCLUDED.image_url,
menu_highlights = EXCLUDED.menu_highlights;
