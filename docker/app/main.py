# ─── Flask Shoe Store App — MyShoe Premium ───────────────────────────
import os, logging
from flask import Flask, jsonify, request, render_template_string
import pymysql
app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
DB_HOST=os.environ.get("DB_HOST","localhost")
DB_PORT=int(os.environ.get("DB_PORT",3306))
DB_USER=os.environ.get("DB_USER","admin")
DB_PASSWORD=os.environ.get("DB_PASSWORD","")
DB_NAME=os.environ.get("DB_NAME","myshoe")
def get_db():
    return pymysql.connect(host=DB_HOST,port=DB_PORT,user=DB_USER,password=DB_PASSWORD,database=DB_NAME,autocommit=True)
def init_db():
    conn=get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("""CREATE TABLE IF NOT EXISTS shoes (
                id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(128) NOT NULL, brand VARCHAR(64) NOT NULL,
                size VARCHAR(8) NOT NULL, color VARCHAR(64) NOT NULL, price DECIMAL(10,2) NOT NULL,
                image_url VARCHAR(512), stock INT NOT NULL DEFAULT 0, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)""")
            cur.execute("""CREATE TABLE IF NOT EXISTS cart (
                id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, shoe_id INT NOT NULL,
                quantity INT NOT NULL DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (shoe_id) REFERENCES shoes(id))""")
            cur.execute("SELECT COUNT(*) FROM shoes")
            if cur.fetchone()[0]==0:
                shoes=[("Running Pro X","Myshoe","9","Midnight Black",4999,"https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&q=80",50),
                       ("Air Stride 3000","Myshoe","10","Ocean Blue",7499,"https://images.unsplash.com/photo-1608231387042-66d1773070a5?w=600&q=80",30),
                       ("Classic Leather Lace","Myshoe","8","Wheat",5999,"https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=600&q=80",40),
                       ("Trail Blazer Hike","Myshoe","11","Forest Green",8999,"https://images.unsplash.com/photo-1606107557195-0e29a4b5b4aa?w=600&q=80",20),
                       ("Urban Sprint Low","Myshoe","9","Stark White",4499,"https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?w=600&q=80",60),
                       ("Neon Runner Elite","Myshoe","10","Neon Lime",6799,"https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?w=600&q=80",35),
                       ("Heritage Brogue","Myshoe","8","Cognac Brown",8299,"https://images.unsplash.com/photo-1614252369475-531eba835eb1?w=600&q=80",22),
                       ("Cloud Step Air","Myshoe","9","Cloud Grey",5599,"https://images.unsplash.com/photo-1529810313688-44ea1c2d81d3?w=600&q=80",45)]
                cur.executemany("INSERT INTO shoes (name,brand,size,color,price,image_url,stock) VALUES (%s,%s,%s,%s,%s,%s,%s)",shoes)
                logger.info("Seeded %d shoes",len(shoes))
    finally: conn.close()
init_db()
@app.route("/health")
def health():
    try:
        conn=get_db(); conn.ping(reconnect=True); conn.close()
        return jsonify({"status":"healthy","db":"connected"}),200
    except Exception as e:
        logger.error("Health check failed: %s",e)
        return jsonify({"status":"unhealthy","db":"disconnected"}),503
PAGE="""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MyShoe — Step Into Future</title>
<script src="https://cdn.tailwindcss.com"></script>
<link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet">
<style>@import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap');*{font-family:'Outfit',sans-serif}</style>
</head>
<body class="bg-[#0a0a0a] text-white">
<nav class="sticky top-0 z-50 bg-black/70 backdrop-blur border-b border-white/10">
  <div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
    <div class="flex items-center gap-3"><div class="w-9 h-9 bg-gradient-to-br from-violet-600 to-fuchsia-600 rounded-xl grid place-items-center font-black">M</div><span class="text-xl font-extrabold tracking-tight">MyShoe</span><span class="hidden md:inline text-xs bg-white/10 px-2 py-1 rounded-full ml-2">ap-south-1 • myshoe.sytes.net</span></div>
    <div class="flex items-center gap-4 text-sm"><a href="#collection" class="hover:text-violet-400">Collection</a><a href="/api/shoes" target="_blank" class="hover:text-violet-400"><i class="fa-solid fa-code mr-1"></i>API</a><a href="/health" target="_blank" class="hover:text-violet-400">Health</a><button onclick="viewCart()" class="bg-white text-black px-4 py-2 rounded-full font-semibold hover:bg-zinc-200"><i class="fa-solid fa-bag-shopping mr-1"></i> Cart <span id="cartCount" class="bg-black text-white px-1.5 py-0.5 rounded-full text-xs">0</span></button></div>
  </div>
</nav>
<section class="relative overflow-hidden">
  <div class="absolute inset-0 bg-gradient-to-br from-violet-900 via-fuchsia-900 to-black opacity-70"></div>
  <div class="absolute -top-24 -right-24 w-96 h-96 bg-fuchsia-600 rounded-full blur-[120px] opacity-30"></div>
  <div class="relative max-w-7xl mx-auto px-6 py-16 md:py-24 grid md:grid-cols-2 gap-10 items-center">
    <div>
      <p class="text-violet-300 text-sm tracking-[0.3em] uppercase mb-3">Design. Build. Automate. Deploy.</p>
      <h1 class="text-5xl md:text-6xl font-black leading-[0.9]">Step Into <span class="bg-gradient-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">Future</span></h1>
      <p class="mt-4 text-zinc-300 max-w-xl">Premium shoes crafted for runners, hikers, and street icons. Secure checkout, 2-day delivery in India, and a real Cloud & DevOps platform behind every pair.</p>
      <div class="mt-6 flex gap-3"><a href="#collection" class="bg-white text-black px-6 py-3 rounded-full font-bold">Shop Collection →</a><span class="inline-flex items-center gap-2 text-sm text-zinc-300"><span class="w-2 h-2 bg-emerald-500 rounded-full animate-pulse"></span>Live on myshoe.sytes.net • RDS MySQL • Docker • K8s</span></div>
      <div class="mt-8 grid grid-cols-3 gap-4 text-center text-sm"><div class="bg-white/5 border border-white/10 rounded-2xl p-4"><div class="text-2xl font-black">8</div><div class="text-zinc-400">Premium Models</div></div><div class="bg-white/5 border border-white/10 rounded-2xl p-4"><div class="text-2xl font-black">4.9★</div><div class="text-zinc-400">1.2k Reviews</div></div><div class="bg-white/5 border border-white/10 rounded-2xl p-4"><div class="text-2xl font-black">2-Day</div><div class="text-zinc-400">India Delivery</div></div></div>
    </div>
    <div class="relative"><img src="https://images.unsplash.com/photo-1600269452121-4f2416e55c28?w=800&q=80" class="rounded-[2rem] border border-white/10 shadow-2xl"><div class="absolute -bottom-6 -left-6 bg-white text-black rounded-2xl p-4 shadow-xl"><div class="text-xs text-zinc-500">Starting from</div><div class="text-2xl font-black">₹4,499</div><div class="text-xs">Free returns • 12M warranty</div></div></div>
  </div>
</section>
<section id="collection" class="max-w-7xl mx-auto px-6 py-12">
  <div class="flex items-end justify-between mb-6"><h2 class="text-3xl font-black">Collection</h2><div class="text-sm text-zinc-400">{{ shoes|length }} models • MyShoe • ap-south-1</div></div>
  <div class="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
  {% for s in shoes %}
    <div class="group bg-zinc-900 border border-white/10 rounded-3xl overflow-hidden hover:border-violet-500/30 hover:shadow-2xl transition">
      <div class="relative h-52 overflow-hidden"><img src="{{ s.image_url }}" alt="{{ s.name }}" class="w-full h-full object-cover group-hover:scale-105 transition duration-500"><span class="absolute top-3 left-3 bg-black/70 backdrop-blur px-2 py-1 rounded-full text-xs">{{ s.brand }} • {{ s.size }}</span><span class="absolute top-3 right-3 bg-emerald-500 text-black text-xs font-bold px-2 py-1 rounded-full">In stock {{ s.stock }}</span></div>
      <div class="p-4"><h3 class="font-bold leading-tight">{{ s.name }}</h3><p class="text-xs text-zinc-400">{{ s.color }} • Size {{ s.size }}</p><div class="mt-3 flex items-center justify-between"><span class="text-xl font-black">₹{{ "{:,.0f}".format(s.price) }}</span><button onclick="addToCart({{ s.id }}, '{{ s.name }}')" class="bg-white text-black px-4 py-2 rounded-full text-sm font-bold hover:bg-zinc-200">Add <i class="fa-solid fa-plus ml-1"></i></button></div></div>
    </div>
  {% endfor %}
  </div>
</section>
<section class="max-w-7xl mx-auto px-6 pb-12">
  <div class="bg-gradient-to-r from-violet-600 to-fuchsia-600 rounded-3xl p-8 md:p-10 flex flex-col md:flex-row items-center justify-between gap-6">
    <div><h3 class="text-2xl font-black">Cloud & DevOps Capstone — Live</h3><p class="text-white/80 text-sm mt-1">VPC • EC2 • RDS MySQL • S3 • ECR • ALB • Ansible • Docker • Kubernetes • Terraform • Prometheus/Grafana</p></div>
    <div class="flex gap-2 text-sm"><a href="/health" class="bg-white text-black px-4 py-2 rounded-full font-bold">/health</a><a href="/api/shoes" class="bg-black text-white px-4 py-2 rounded-full">/api/shoes</a></div>
  </div>
</section>
<footer class="border-t border-white/10 py-8 text-center text-xs text-zinc-500">© MyShoe • myshoe.sytes.net • ap-south-1 • Built for IPSR Capstone — Design. Build. Automate. Deploy. Monitor. Succeed.</footer>
<div id="toast" class="fixed bottom-6 left-1/2 -translate-x-1/2 bg-white text-black px-4 py-2 rounded-full shadow-xl hidden"></div>
<script>
let cart=0;
function addToCart(id,name){
  cart++; document.getElementById('cartCount').innerText=cart;
  fetch('/api/cart',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({user_id:1,shoe_id:id,quantity:1})});
  const t=document.getElementById('toast'); t.innerText='Added ' + name + ' to cart'; t.classList.remove('hidden'); setTimeout(()=>t.classList.add('hidden'),1800);
}
function viewCart(){ alert('Cart: '+cart+' items — checkout wiring is at POST /api/cart'); }
</script>
</body></html>
"""
@app.route("/")
def index(): return render_template_string(PAGE, shoes=get_all_shoes())
def get_all_shoes():
    conn=get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id,name,brand,size,color,price,image_url,stock FROM shoes")
            cols=[d[0] for d in cur.description]
            return [dict(zip(cols,r)) for r in cur.fetchall()]
    finally: conn.close()
@app.route("/api/shoes", methods=["GET"])
def api_shoes(): return jsonify(get_all_shoes())
@app.route("/api/shoes/<int:shoe_id>", methods=["GET"])
def api_shoe(shoe_id):
    conn=get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id,name,brand,size,color,price,image_url,stock FROM shoes WHERE id=%s",(shoe_id,))
            row=cur.fetchone()
            if not row: return jsonify({"error":"not found"}),404
            cols=[d[0] for d in cur.description]
            return jsonify(dict(zip(cols,row)))
    finally: conn.close()
@app.route("/api/cart", methods=["POST"])
def api_cart_add():
    data=request.get_json(force=True); user_id=data.get("user_id"); shoe_id=data.get("shoe_id"); quantity=data.get("quantity",1)
    if not user_id or not shoe_id: return jsonify({"error":"user_id and shoe_id required"}),400
    conn=get_db()
    try:
        with conn.cursor() as cur: cur.execute("INSERT INTO cart (user_id,shoe_id,quantity) VALUES (%s,%s,%s)",(user_id,shoe_id,quantity)); return jsonify({"message":"added to cart","cart_id":cur.lastrowid}),201
    finally: conn.close()
if __name__=="__main__": app.run(host="0.0.0.0",port=8000)
