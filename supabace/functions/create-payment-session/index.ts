import Stripe from "npm:stripe@^22";
import { createClient } from "npm:@supabase/supabase-js@^2";
const stripe=new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!,{apiVersion:"2025-06-30.basil"});
Deno.serve(async(req)=>{
 try{
  const auth=req.headers.get("Authorization"); if(!auth)return new Response("Unauthorized",{status:401});
  const sb=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!,{global:{headers:{Authorization:auth}}});
  const {data:{user},error:ue}=await sb.auth.getUser(); if(ue||!user)return new Response("Unauthorized",{status:401});
  const {order_id}=await req.json();
  const {data:o,error}=await sb.from("orders").select("id,total,payment_status").eq("id",order_id).eq("user_id",user.id).single();
  if(error||!o)return new Response("Order not found",{status:404});
  if(o.payment_status==="paid")return Response.json({error:"Already paid"},{status:409});
  const amount=Math.round(Number(o.total)*100);
  const session=await stripe.checkout.sessions.create({mode:"payment",line_items:[{price_data:{currency:"usd",product_data:{name:`AbdullahAtal order ${o.id.slice(0,8)}`},unit_amount:amount},quantity:1}],metadata:{order_id:o.id,user_id:user.id},success_url:`${Deno.env.get("SITE_URL")}/?payment=success&order=${o.id}`,cancel_url:`${Deno.env.get("SITE_URL")}/?payment=cancelled&order=${o.id}`});
  await sb.from("orders").update({payment_status:"pending",payment_provider:"stripe",payment_reference:session.id}).eq("id",o.id);
  return Response.json({url:session.url});
 }catch(e){console.error(e);return new Response("Payment session failed",{status:500})}
});