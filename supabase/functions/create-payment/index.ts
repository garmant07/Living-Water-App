// Starts a purchase. The app sends only product ids and quantities; this
// function looks up the real prices, works out the total, records the order,
// and asks Stripe for a payment. Prices from the app are never trusted.
//
// Secrets (set in Supabase, never in the app):
//   STRIPE_SECRET_KEY
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided
// by Supabase automatically.

import { createClient } from "npm:@supabase/supabase-js@2";

// ---- Shipping and tax: the one place these are set. -----------------------
// TODO: confirm with the founders. For now: flat shipping, free over a threshold, no tax.
const FLAT_SHIPPING_CENTS = 0;
const FREE_SHIPPING_OVER_CENTS = 0;
function shippingFor(subtotalCents: number): number {
  if (FREE_SHIPPING_OVER_CENTS > 0 && subtotalCents >= FREE_SHIPPING_OVER_CENTS) return 0;
  return FLAT_SHIPPING_CENTS;
}
function taxFor(_subtotalCents: number): number {
  return 0;
}
// ---------------------------------------------------------------------------

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeKey) return reply(500, { error: "Payments are not set up yet." });

    // Who is asking? Checkout needs a signed-in account.
    const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: { user } } = await asUser.auth.getUser();
    if (!user) return reply(401, { error: "Please sign in to check out." });

    const body = await req.json();
    const items: { product_id: string; quantity: number }[] = body.items ?? [];
    const shipping = body.shipping ?? {};
    if (!Array.isArray(items) || items.length === 0) return reply(400, { error: "Your cart is empty." });
    for (const field of ["name", "line1", "city", "state", "postal_code", "country"]) {
      if (!String(shipping[field] ?? "").trim()) return reply(400, { error: "Please complete the shipping address." });
    }

    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Real prices and stock, straight from the database.
    const { data: products, error: productsError } = await admin
      .from("products")
      .select("id, name, price_cents, currency, stock_quantity, is_active")
      .in("id", items.map((i) => i.product_id));
    if (productsError) throw productsError;

    let subtotal = 0;
    const lines = [];
    for (const item of items) {
      const quantity = Math.floor(Number(item.quantity));
      const product = products?.find((p) => p.id === item.product_id);
      if (!product || !product.is_active) return reply(400, { error: "One of the items is no longer available." });
      if (!(quantity > 0) || quantity > 99) return reply(400, { error: "Please check the quantities in your cart." });
      if (product.stock_quantity !== null && product.stock_quantity < quantity) {
        return reply(400, { error: `Only ${product.stock_quantity} of ${product.name} left.` });
      }
      subtotal += product.price_cents * quantity;
      lines.push({
        product_id: product.id,
        product_name: product.name,
        unit_price_cents: product.price_cents,
        quantity,
      });
    }

    const shippingCents = shippingFor(subtotal);
    const taxCents = taxFor(subtotal);
    const total = subtotal + shippingCents + taxCents;
    if (total < 50) return reply(400, { error: "The order total is too small to charge." });

    const { data: order, error: orderError } = await admin
      .from("orders")
      .insert({
        user_id: user.id,
        status: "pending_payment",
        subtotal_cents: subtotal,
        shipping_cents: shippingCents,
        tax_cents: taxCents,
        total_cents: total,
        shipping_name: shipping.name,
        shipping_line1: shipping.line1,
        shipping_line2: shipping.line2 ?? null,
        shipping_city: shipping.city,
        shipping_state: shipping.state,
        shipping_postal_code: shipping.postal_code,
        shipping_country: shipping.country,
        contact_email: body.contact_email ?? user.email,
        contact_phone: body.contact_phone ?? null,
      })
      .select("id, order_number")
      .single();
    if (orderError) throw orderError;

    const { error: itemsError } = await admin
      .from("order_items")
      .insert(lines.map((line) => ({ ...line, order_id: order.id })));
    if (itemsError) throw itemsError;

    // Ask Stripe for a payment of exactly the total worked out above.
    const form = new URLSearchParams();
    form.set("amount", String(total));
    form.set("currency", "usd");
    form.set("automatic_payment_methods[enabled]", "true");
    form.set("metadata[order_id]", order.id);
    if (body.contact_email ?? user.email) form.set("receipt_email", body.contact_email ?? user.email);

    const stripeResponse = await fetch("https://api.stripe.com/v1/payment_intents", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${stripeKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form,
    });
    const intent = await stripeResponse.json();
    if (!stripeResponse.ok) {
      await admin.from("orders").update({ status: "cancelled" }).eq("id", order.id);
      console.error("Stripe error", intent);
      return reply(502, { error: "We couldn't start the payment. Please try again." });
    }

    await admin.from("orders").update({ stripe_payment_intent_id: intent.id }).eq("id", order.id);

    return reply(200, {
      client_secret: intent.client_secret,
      order_id: order.id,
      order_number: order.order_number,
      subtotal_cents: subtotal,
      shipping_cents: shippingCents,
      tax_cents: taxCents,
      total_cents: total,
    });
  } catch (error) {
    console.error(error);
    return reply(500, { error: "Something went wrong starting your order. Please try again." });
  }
});
