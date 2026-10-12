// Stripe calls this when a payment succeeds or fails. It marks the order
// paid (and takes the items out of stock), or cancels it.
//
// Secrets (set in Supabase, never in the app):
//   STRIPE_SECRET_KEY
//   STRIPE_WEBHOOK_SECRET   (from Stripe: Developers -> Webhooks -> Signing secret)
//
// Deploy with "Verify JWT" turned OFF: Stripe is not a signed-in user. The
// signature check below is what proves the call really came from Stripe.

import Stripe from "npm:stripe@17";
import { createClient } from "npm:@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "");
const cryptoProvider = Stripe.createSubtleCryptoProvider();

Deno.serve(async (req) => {
  const signature = req.headers.get("Stripe-Signature");
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!signature || !secret) return new Response("Missing signature", { status: 400 });

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(await req.text(), signature, secret, undefined, cryptoProvider);
  } catch (error) {
    console.error("Bad signature", error);
    return new Response("Bad signature", { status: 400 });
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  if (event.type === "payment_intent.succeeded") {
    const intent = event.data.object as Stripe.PaymentIntent;
    // Only an order still waiting for payment is marked paid, so a repeated
    // call from Stripe can't take stock out twice.
    const { data: updated } = await admin
      .from("orders")
      .update({ status: "paid" })
      .eq("stripe_payment_intent_id", intent.id)
      .eq("status", "pending_payment")
      .select("id");
    for (const order of updated ?? []) {
      await admin.rpc("decrement_stock", { p_order: order.id });
    }
  } else if (event.type === "payment_intent.payment_failed" || event.type === "payment_intent.canceled") {
    const intent = event.data.object as Stripe.PaymentIntent;
    if (event.type === "payment_intent.canceled") {
      await admin
        .from("orders")
        .update({ status: "cancelled" })
        .eq("stripe_payment_intent_id", intent.id)
        .eq("status", "pending_payment");
    }
  } else if (event.type === "charge.refunded") {
    const charge = event.data.object as Stripe.Charge;
    if (charge.refunded && charge.payment_intent) {
      await admin
        .from("orders")
        .update({ status: "refunded" })
        .eq("stripe_payment_intent_id", String(charge.payment_intent));
    }
  }

  return new Response(JSON.stringify({ received: true }), { headers: { "Content-Type": "application/json" } });
});
