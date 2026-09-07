import Stripe from "npm:stripe@^22";
import { createClient } from "npm:@supabase/supabase-js@^2";
const stripe=new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!,{apiVersion:"2025-06-30.basil"});
Deno.serve(async(req)=>{
 const signature=req.headers.get("Stripe-Signature"); const body=await req.text();
 if(!signature)return new Response("Missing signature",{status:400});
 try{
  const event=await stripe.webhooks.constructEventAsync(body,signature,Deno.env.get("STRIPE_WEBHOOK_SIGNING_SECRET")!,undefined,Stripe.createSubtleCryptoProvider());
  const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SECRET_KEY")!);
  if(event.type==="checkout.session.completed"){
   const s=event.data.object as Stripe.Checkout.Session; const id=s.metadata?.order_id;
   if(id)await sb.from("orders").update({payment_status:"paid",status:"confirmed",payment_reference:s.id}).eq("id",id);
  }
  if(event.type==="charge.refunded"){
   const charge=event.data.object as Stripe.Charge; const id=charge.metadata?.order_id;
   if(id)await sb.from("orders").update({payment_status:"refunded"}).eq("id",id);
  }
  return Response.json({received:true});
 }catch(e){console.error(e);return new Response("Invalid signature",{status:400})}
});