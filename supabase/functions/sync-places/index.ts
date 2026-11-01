import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: request.headers.get("Authorization") ?? "" } } },
  );
  const { data: user } = await supabase.auth.getUser();
  if (!user.user) return json({ error: "Unauthorized" }, 401);

  const { data: profile } = await supabase
    .from("user_profiles")
    .select("role")
    .eq("id", user.user.id)
    .maybeSingle();
  if (profile?.role !== "admin") return json({ error: "Admin role required" }, 403);

  const googleKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!googleKey || !serviceRole) {
    return json({ error: "Missing server configuration" }, 500);
  }

  const placesResponse = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": googleKey,
      "X-Goog-FieldMask":
        "places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.priceLevel,places.primaryType,places.editorialSummary,places.regularOpeningHours.weekdayDescriptions",
    },
    body: JSON.stringify({
      textQuery: "tempat makan Purwokerto Banyumas",
      locationBias: {
        circle: { center: { latitude: -7.4244, longitude: 109.2304 }, radius: 15000 },
      },
      languageCode: "id",
      maxResultCount: 20,
    }),
  });
  if (!placesResponse.ok) return json({ error: "Google Places request failed" }, 502);

  const googleData = await placesResponse.json();
  const rows = (googleData.places ?? []).map((place: Record<string, unknown>) => {
    const name = (place.displayName as Record<string, string> | undefined)?.text ?? "Tempat makan";
    const location = (place.location as Record<string, number> | undefined) ?? {};
    const rating = Number(place.rating ?? 0);
    const reviewCount = Number(place.userRatingCount ?? 0);
    return {
      id: `google-${place.id}`,
      google_place_id: place.id,
      name,
      city: "Purwokerto Kota",
      category: "Restoran",
      rating,
      review_count: reviewCount,
      address: place.formattedAddress ?? "",
      description:
        (place.editorialSummary as Record<string, string> | undefined)?.text ??
        "Data tempat dari Google Maps.",
      open_hours:
        ((place.regularOpeningHours as Record<string, unknown> | undefined)
          ?.weekdayDescriptions as string[] | undefined)?.join("; ") ??
        "Jam buka tidak tersedia di Google Maps",
      latitude: Number(location.latitude ?? -7.4244),
      longitude: Number(location.longitude ?? 109.2304),
      google_snapshot: place,
      google_synced_at: new Date().toISOString(),
      data_source: "google",
    };
  });

  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceRole,
  );
  const { data: existing } = await adminClient
    .from("places")
    .select("id, override_fields")
    .in("id", rows.map((row) => row.id));
  const overrides = new Map(
    (existing ?? []).map((row) => [row.id, row.override_fields ?? {}]),
  );
  const mergedRows = rows.map((row) => ({
    ...row,
    ...(overrides.get(row.id) as Record<string, unknown> | undefined),
  }));
  const { error } = await adminClient
    .from("places")
    .upsert(mergedRows, { onConflict: "id", ignoreDuplicates: false });
  if (error) return json({ error: error.message }, 500);
  return json({ synced: mergedRows.length });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
