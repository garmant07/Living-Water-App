// Deletes the signed-in person's account, as Apple requires.
//
// Their profile and sign-in are removed completely. Past orders are kept for
// accounting, but with the name, address, email and phone wiped and the link
// to the account cut, so the order can no longer be tied to a person.

import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (status: number, body: unknown) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: { user } } = await asUser.auth.getUser();
    if (!user) return json(401, { error: "Please sign in first." });

    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const { error: ordersError } = await admin
      .from("orders")
      .update({
        user_id: null,
        shipping_name: null,
        shipping_line1: null,
        shipping_line2: null,
        shipping_city: null,
        shipping_state: null,
        shipping_postal_code: null,
        contact_email: null,
        contact_phone: null,
      })
      .eq("user_id", user.id);
    if (ordersError) throw ordersError;

    // Removing the sign-in also removes the profile row.
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    return json(200, { deleted: true });
  } catch (error) {
    console.error(error);
    return json(500, { error: "We couldn't delete the account. Please try again." });
  }
});
