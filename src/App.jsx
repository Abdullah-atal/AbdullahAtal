import React,{useEffect,useState} from "react";
import {supabase,supabaseConfigured} from "./lib/supabaseClient";

const demo=[{id:"d1",name:"Studio Wireless Headphones",category:"Electronics",price:79,stock:18,emoji:"🎧",seller:"NovaSound Store"},{id:"d2",name:"Smart Watch Pro",category:"Electronics",price:59,stock:24,emoji:"⌚",seller:"Orbit Tech"},{id:"d3",name:"Everyday Runner Sneakers",category:"Fashion",price:64,stock:9,emoji:"👟",seller:"StepUp"},{id:"d4",name:"Urban Travel Backpack",category:"Fashion",price:42,stock:31,emoji:"🎒",seller:"Nomad Goods"}];

export default function App(){
  const[session,setSession]=useState(null),
 [tab,setTab]=useState("shop"),
 [products,setProducts]=useState([]),
 [cart,setCart]=useState([]),
 [email,setEmail]=useState(""),
 [password,setPassword]=useState(""),
 [fullName,setFullName]=useState(""),
 [mode,setMode]=useState("signin"),
 [message,setMessage]=useState(""),
 [adminProducts,setAdminProducts]=useState([]),
 [adminStores,setAdminStores]=useState([]),
 [isAdmin,setIsAdmin]=useState(false),
 [loading,setLoading]=useState(false),
 [store,setStore]=useState(null),
 [orders,setOrders]=useState([]),
 [checkout,setCheckout]=useState({name:"",phone:"",address:""}),
 [newProduct,setNewProduct]=useState({name:"",price:"",stock:"",description:""}),
 [image,setImage]=useState(null),
 [query,setQuery]=useState(""),
 [category,setCategory]=useState(""),
 [favorites,setFavorites]=useState([]),
 [tickets,setTickets]=useState([]),
 [delivery,setDelivery]=useState([]),
 [shipping,setShipping]=useState([]),
 [selectedShipping,setSelectedShipping]=useState(""),
 [returns,setReturns]=useState([]),
 [notifications,setNotifications]=useState([]),
 [analytics,setAnalytics]=useState(null);
 useEffect(()=>{if(!supabaseConfigured){setProducts(demo);return}supabase.auth.getSession().then(({data})=>setSession(data.session));const{data:l}=supabase.auth.onAuthStateChange((_e,s)=>setSession(s));loadProducts();return()=>l.subscription.unsubscribe()},[]);
 useEffect(()=>{if(session&&supabaseConfigured){loadStore();loadCart();loadOrders();loadAdmin();loadNotifications();loadShipping();loadReturns();loadDelivery();loadFavorites();loadTickets();loadDelivery()}},[session]);
 async function loadFavorites(){const{data}=await supabase.from("favorites").select("product_id");setFavorites((data||[]).map(x=>x.product_id))}
 async function toggleFavorite(id){if(!session){setMessage("Please sign in first.");return}if(favorites.includes(id)){await supabase.from("favorites").delete().eq("product_id",id).eq("user_id",session.user.id);setFavorites(favorites.filter(x=>x!==id))}else{await supabase.from("favorites").insert({product_id:id,user_id:session.user.id});setFavorites([...favorites,id])}}
 async function loadTickets(){const{data}=await supabase.from("support_tickets").select("*").order("created_at",{ascending:false});setTickets(data||[])}
 async function createTicket(){const subject=window.prompt("Support subject?");if(!subject)return;const body=window.prompt("Describe the issue?");if(!body)return;const{error}=await supabase.rpc("create_support_ticket",{p_subject:subject,p_body:body,p_priority:"normal"});setMessage(error?.message||"Support ticket created.");loadTickets()}
 async function loadDelivery(){const{data}=await supabase.from("delivery_events").select("*").order("event_time",{ascending:false}).limit(30);setDelivery(data||[])}
 async function createPayout(){if(!store)return;const{data,error}=await supabase.rpc("create_payout_batch",{p_store:store.id});setMessage(error?.message||`Payout batch ${data} created.`)}
 async function loadShipping(){const{data}=await supabase.from("shipping_methods").select("*").order("price");setShipping(data||[]);if(data?.[0])setSelectedShipping(data[0].id)}
 async function loadReturns(){const{data}=await supabase.from("returns").select("*").order("created_at",{ascending:false});setReturns(data||[])}
 async function requestReturn(orderId){const reason=window.prompt("Reason for return?");if(!reason)return;const{error}=await supabase.rpc("request_return",{p_order:orderId,p_reason:reason,p_details:null});setMessage(error?.message||"Return requested.");loadReturns();loadNotifications()}
 async function loadNotifications(){const{data}=await supabase.from("notifications").select("*").is("read_at",null).order("created_at",{ascending:false}).limit(10);setNotifications(data||[])}
 async function search(){if(!supabaseConfigured)return;const{data,error}=await supabase.rpc("search_products",{p_query:query,p_category:category||null});if(error){setMessage(error.message);return}setProducts((data||[]).map(p=>({...p,category:p.category_name||"Marketplace",seller:p.store_name||"Seller",emoji:"🛍️"})))}
 async function loadAnalytics(){if(!store)return;const{data,error}=await supabase.rpc("seller_analytics",{p_store:store.id});if(!error)setAnalytics(data?.[0]||null)}
 async function markNotification(id){await supabase.from("notifications").update({read_at:new Date().toISOString()}).eq("id",id);loadNotifications()}
 async function loadAdmin(){const{data:p}=await supabase.from("products").select("id,name,is_active,stores(name)").order("created_at",{ascending:false}).limit(50);const{data:s}=await supabase.from("stores").select("id,name,is_verified").order("created_at",{ascending:false}).limit(50);setAdminProducts(p||[]);setAdminStores(s||[]);const{data:me}=await supabase.from("profiles").select("role,is_suspended").eq("id",session.user.id).single();setIsAdmin(me?.role==="admin"&&!me?.is_suspended)}
 async function adminStore(id,value){const{error}=await supabase.rpc("admin_set_store_verified",{p_store:id,p_value:value});setMessage(error?.message||"Store updated.");loadAdmin()}
 async function adminReturn(id,status){const{error}=await supabase.rpc("admin_update_return",{p_return:id,p_status:status});setMessage(error?.message||"Return updated.");loadReturns()}
 async function adminProduct(id,value){const{error}=await supabase.rpc("admin_set_product_active",{p_product:id,p_value:value});setMessage(error?.message||"Product updated.");loadAdmin();loadProducts()}
 async function payOrder(id){const{data,error}=await supabase.functions.invoke("create-payment-session",{body:{order_id:id}});if(error){setMessage(error.message);return}if(data?.url)window.location.href=data.url}
 async function loadOrders(){
  const{data,error}=await supabase
    .from("orders")
    .select(`
      id,
      status,
      total,
      payment_status,
      shipping_name,
      shipping_address,
      created_at,
      order_items(
        product_name,
        unit_price,
        quantity,
        store_id
      )
    `)
    .order("created_at",{ascending:false});

  if(error){
    setMessage("Orders error: "+error.message);
    console.error(error);
    return;
  }

  setOrders(data||[]);
}
 async function loadProducts(){const{data,error}=await supabase.from("products").select("id,name,description,price,stock,image_url,stores(name),categories(name)").eq("is_active",true).order("created_at",{ascending:false});if(error){setMessage(error.message);return}setProducts((data||[]).map(p=>({...p,category:p.categories?.name||"Marketplace",seller:p.stores?.name||"Seller",emoji:"🛍️"})))}
 async function loadStore(){const{data}=await supabase.from("stores").select("*").eq("owner_id",session.user.id).limit(1).maybeSingle();setStore(data)}
 async function loadCart(){const{data}=await supabase.from("carts").select("id,cart_items(id,quantity,product_id,products(name,price,image_url))").eq("user_id",session.user.id).maybeSingle();setCart(data?.cart_items||[])}
 async function auth(e){e.preventDefault();setLoading(true);setMessage("");if(!supabaseConfigured){setMessage("Connect Supabase using README.md first.");setLoading(false);return}let r=mode==="signup"?await supabase.auth.signUp({email,password,options:{data:{full_name:fullName}}}):await supabase.auth.signInWithPassword({email,password});setMessage(r.error?r.error.message:mode==="signup"?"Account created. Check email if confirmation is enabled.":"Signed in.");setLoading(false)}
 async function signOut(){await supabase.auth.signOut();setSession(null);setTab("shop");setMessage("Signed out.")}
 async function addToCart(p){if(!session){setMessage("Sign in to save items to your real cart.");return}const{data:c}=await supabase.from("carts").select("id").eq("user_id",session.user.id).single();if(!c)return;const old=cart.find(x=>x.product_id===p.id);if(old)await supabase.from("cart_items").update({quantity:old.quantity+1}).eq("id",old.id);else await supabase.from("cart_items").insert({cart_id:c.id,product_id:p.id,quantity:1});loadCart();setTab("cart")}
 async function createStore(e){e.preventDefault();if(!session)return;const n=e.target.name.value;const slug=n.toLowerCase().trim().replace(/[^a-z0-9]+/g,"-")+"-"+Date.now();const{data,error}=await supabase.from("stores").insert({owner_id:session.user.id,name:n,slug,description:e.target.description.value}).select().single();setMessage(error?.message||"Store created.");if(data)setStore(data)}
 async function uploadProduct(e){e.preventDefault();if(!store){setMessage("Create your seller store first.");return}let imageUrl=null;if(image){const path=`${session.user.id}/${Date.now()}-${image.name.replace(/\s+/g,"-")}`;const{error}=await supabase.storage.from("product-images").upload(path,image,{contentType:image.type,upsert:false});if(error){setMessage(error.message);return}imageUrl=supabase.storage.from("product-images").getPublicUrl(path).data.publicUrl}const slug=newProduct.name.toLowerCase().trim().replace(/[^a-z0-9]+/g,"-")+"-"+Date.now();const{error}=await supabase.from("products").insert({store_id:store.id,name:newProduct.name,slug,price:Number(newProduct.price),stock:Number(newProduct.stock||0),description:newProduct.description,image_url:imageUrl});setMessage(error?.message||"Product published.");if(!error){setNewProduct({name:"",price:"",stock:"",description:""});setImage(null);loadProducts()}}
 const subtotal=cart.reduce((s,x)=>s+Number(x.products?.price||0)*x.quantity,0); const ship=Number(shipping.find(s=>s.id===selectedShipping)?.price||0); const total=subtotal+ship;
 async function checkoutNow(e){e.preventDefault();if(!session)return;setLoading(true);const{data,error}=await supabase.rpc("checkout_cart_v12",{p_shipping_name:checkout.name,p_shipping_phone:checkout.phone,p_shipping_address:checkout.address,p_shipping_method:selectedShipping,p_idempotency_key:crypto.randomUUID()});setMessage(error?.message||"Order placed successfully.");if(!error){setCheckout({name:"",phone:"",address:""});await loadCart();await loadOrders();setTab("orders")}setLoading(false)}
 async function sellerStatus(orderId,status){const{error}=await supabase.from("orders").update({status}).eq("id",orderId);setMessage(error?.message||"Order status updated.");loadOrders()}
 return <><header><div className="brand"><span>A</span>AbdullahAtal</div><div className="headActions">{session?<><button onClick={()=>setTab("account")}>👤</button><button onClick={()=>setTab("cart")}>🛒 {cart.reduce((n,x)=>n+x.quantity,0)}</button></>:<button onClick={()=>setTab("account")}>Sign in</button>}</div></header>
 <nav className="nav"><button className={tab==="shop"?"active":""} onClick={()=>setTab("shop")}>⌂<small>Shop</small></button>{session&&<><button className={tab==="cart"?"active":""} onClick={()=>setTab("cart")}>🛒<small>Cart</small></button><button className={tab==="sell"?"active":""} onClick={()=>setTab("sell")}>＋<small>Sell</small></button><button className={tab==="orders"?"active":""} onClick={()=>setTab("orders")}>📦<small>Orders</small></button><button className={tab==="returns"?"active":""} onClick={()=>setTab("returns")}>↩<small>Returns</small></button><button className={tab==="support"?"active":""} onClick={()=>setTab("support")}>?</button>{isAdmin&&<button className={tab==="admin"?"active":""} onClick={()=>setTab("admin")}>🛡️<small>Admin</small></button>}</>}<button className={tab==="account"?"active":""} onClick={()=>setTab("account")}>●<small>Account</small></button></nav>
 <main>
 {tab==="shop"&&<><section className="hero"><p className="eyebrow">V5 • MARKETPLACE</p><h1>Discover more.<br/><em>Buy better.</em></h1><p>A unique marketplace where customers discover independent sellers and sellers build their own businesses.</p></section><section className="section"><div className="sectionHead"><div><p className="eyebrow">DISCOVER</p><h2>Products</h2></div></div><div className="searchbar"><input placeholder="Search products…" value={query} onChange={e=>setQuery(e.target.value)} onKeyDown={e=>e.key==="Enter"&&search()}/><select value={category} onChange={e=>{setCategory(e.target.value);setTimeout(search,0)}}><option value="">All categories</option><option value="electronics">Electronics</option><option value="fashion">Fashion</option><option value="home-living">Home & Living</option><option value="beauty">Beauty</option><option value="grocery">Grocery</option></select><button onClick={search}>Search</button></div><div className="products">{products.map(p=><article className="product" key={p.id}><div className="pimg">{p.image_url?<img src={p.image_url} alt=""/>:p.emoji}</div><small>{p.category}</small><h3>{p.name}</h3><p>by {p.seller}</p><strong>${Number(p.price).toFixed(2)}</strong><button className="add" onClick={()=>addToCart(p)}>Add to cart</button></article>)}</div></section></>}
 {tab==="account"&&<section className="panel">{session?<><p className="eyebrow">ACCOUNT</p><h2>Welcome back</h2><p>{session.user.email}</p><div className="notice">{notifications.length>0&&notifications.map(n=><button key={n.id} onClick={()=>markNotification(n.id)}>🔔 <b>{n.title}</b><small>{n.body}</small></button>)}</div><div className="tiles"><button onClick={()=>setTab("cart")}>🛒<b>My cart</b><small>Saved across sessions</small></button><button onClick={()=>setTab("sell")}>🏪<b>Seller center</b><small>{store?"Manage your store":"Start selling"}</small></button></div><button className="primary" onClick={signOut}>Sign out</button></>:<><p className="eyebrow">YOUR ACCOUNT</p><h2>{mode==="signup"?"Create account":"Sign in"}</h2><div className="tabs"><button className={mode==="signin"?"active":""} onClick={()=>setMode("signin")}>Sign in</button><button className={mode==="signup"?"active":""} onClick={()=>setMode("signup")}>Create</button></div><form onSubmit={auth}>{mode==="signup"&&<input placeholder="Full name" value={fullName} onChange={e=>setFullName(e.target.value)} required/>}<input type="email" placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)} required/><input type="password" minLength="6" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)} required/><button className="primary">{loading?"Working…":mode==="signup"?"Create account":"Sign in"}</button></form></>}</section>}
 {tab==="cart"&&<section className="panel"><p className="eyebrow">YOUR CART</p><h2>Cart</h2>{!cart.length?<p className="muted">Your real database cart is empty.</p>:<>{cart.map(x=><div className="cartRow" key={x.id}><span>{x.products?.name}</span><b>{x.quantity} × ${Number(x.products?.price).toFixed(2)}</b></div>)}<div className="total"><b>Total</b><strong>${total.toFixed(2)}</strong></div><h3>Delivery details</h3><select value={selectedShipping} onChange={e=>setSelectedShipping(e.target.value)}>{shipping.map(s=><option key={s.id} value={s.id}>{s.name} — ${Number(s.price).toFixed(2)} ({s.estimated_days} days)</option>)}</select><form onSubmit={checkoutNow}><input required placeholder="Full name" value={checkout.name} onChange={e=>setCheckout({...checkout,name:e.target.value})}/><input required placeholder="Phone" value={checkout.phone} onChange={e=>setCheckout({...checkout,phone:e.target.value})}/><textarea required placeholder="Delivery address" value={checkout.address} onChange={e=>setCheckout({...checkout,address:e.target.value})}/><button className="primary" disabled={loading}>{loading?"Placing order…":"Place order"}</button></form></>}</section>}
 {tab==="orders"&&<section className="panel"><p className="eyebrow">ORDERS</p><h2>Orders</h2>{!orders.length?<p className="muted">No orders yet.</p>:orders.map(o=><article className="order" key={o.id}><div><b>#{String(o.id).slice(0,8)}</b><small>{new Date(o.created_at).toLocaleString()}</small></div><strong>${Number(o.total).toFixed(2)}</strong><span className="badge">{o.status} · {o.payment_status}</span>{o.payment_status!=="paid"&&<><button className="pay" onClick={()=>payOrder(o.id)}>Pay securely</button><button className="secondary" onClick={()=>requestReturn(o.id)}>Request return</button></>}<div className="delivery">{delivery.filter(d=>d.order_id===o.id).slice(0,3).map(d=><span key={d.id}>🚚 {d.status}{d.tracking_number?` · ${d.tracking_number}`:""}</span>)}</div><div className="orderItems">{o.order_items?.map(i=><span key={i.product_name}>{i.product_name} × {i.quantity}</span>)}</div>{store&&o.order_items?.some(i=>i.store_id===store.id)&&<div className="sellerActions"><button onClick={()=>sellerStatus(o.id,"processing")}>Processing</button><button onClick={()=>sellerStatus(o.id,"shipped")}>Shipped</button><button onClick={()=>sellerStatus(o.id,"delivered")}>Delivered</button></div>}</article>)}</section>}
 {tab==="returns"&&<section className="panel"><p className="eyebrow">AFTER-SALES</p><h2>Returns</h2>{!returns.length?<p className="muted">No return requests.</p>:returns.map(r=><div className="adminRow" key={r.id}><span><b>{r.reason}</b><small>Order #{String(r.order_id).slice(0,8)}</small></span><em className="badge2">{r.status}</em></div>)}</section>}
 {tab==="support"&&<section className="panel"><p className="eyebrow">HELP CENTER</p><h2>Support</h2><button className="primary" onClick={createTicket}>Create support ticket</button>{tickets.map(t=><div className="adminRow" key={t.id}><span><b>{t.subject}</b><small>{t.status} · {t.priority}</small></span></div>)}</section>}
 {tab==="admin"&&isAdmin&&<section className="panel wide"><p className="eyebrow">ADMIN CONTROL</p><h2>Marketplace moderation</h2><h3>Stores</h3>{adminStores.map(s=><div className="adminRow" key={s.id}><span>{s.name}</span><button onClick={()=>adminStore(s.id,!s.is_verified)}>{s.is_verified?"Unverify":"Verify"}</button></div>)}<h3>Returns</h3>{returns.map(r=><div className="adminRow" key={"r"+r.id}><span><b>{r.reason}</b><small>Order #{String(r.order_id).slice(0,8)} · {r.status}</small></span><span><button onClick={()=>adminReturn(r.id,"approved")}>Approve</button> <button onClick={()=>adminReturn(r.id,"rejected")}>Reject</button></span></div>)}<h3>Products</h3>{adminProducts.map(p=><div className="adminRow" key={p.id}><span>{p.name}<small>{p.stores?.name||"Seller"}</small></span><button onClick={()=>adminProduct(p.id,!p.is_active)}>{p.is_active?"Hide":"Publish"}</button></div>)}</section>}
 {tab==="sell"&&<section className="panel"><p className="eyebrow">SELLER CENTER</p><h2>{store?store.name:"Start your store"}</h2>{!store?<form onSubmit={createStore}><input name="name" placeholder="Store name" required/><textarea name="description" placeholder="What makes your store special?"/><button className="primary">Create store</button></form>:<><p className="muted">{store.description||"Your AbdullahAtal store."}</p><button className="secondary" onClick={loadAnalytics}>Refresh analytics</button>{analytics&&<><button className="secondary" onClick={createPayout}>Create payout batch</button><div className="stats"><div><b>{analytics.total_products}</b><small>Products</small></div><div><b>{analytics.total_stock}</b><small>Stock</small></div><div><b>{analytics.total_order_items}</b><small>Paid units</small></div><div><b>${Number(analytics.revenue||0).toFixed(2)}</b><small>Revenue</small></div></div><h3>Add a product</h3><form onSubmit={uploadProduct}><input placeholder="Product name" value={newProduct.name} onChange={e=>setNewProduct({...newProduct,name:e.target.value})} required/><input type="number" min="0" step=".01" placeholder="Price" value={newProduct.price} onChange={e=>setNewProduct({...newProduct,price:e.target.value})} required/><input type="number" min="0" placeholder="Stock" value={newProduct.stock} onChange={e=>setNewProduct({...newProduct,stock:e.target.value})}/><textarea placeholder="Description" value={newProduct.description} onChange={e=>setNewProduct({...newProduct,description:e.target.value})}/><label className="file">📷 Product image<input type="file" accept="image/*" onChange={e=>setImage(e.target.files?.[0]||null)}/></label><button className="primary">Publish product</button></form></>}</>}</section>}
 {message&&<div className="toast">{message}</div>}
 </main></>}
