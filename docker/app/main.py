# ─── Flask Shoe Store App ─────────────────────────────────────────────
# A minimal e-commerce backend for a shoe brand.
# Expand with real templates, Stripe checkout, admin panel, etc.

import os
import logging
from flask import Flask, jsonify, request, render_template_string
import pymysql

app = Flask(__name__)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ─── DB connection (from env, injected by K8s ConfigMap/Secret) ──────
DB_HOST     = os.environ.get("DB_HOST", "localhost")
DB_PORT     = int(os.environ.get("DB_PORT", 3306))
DB_USER     = os.environ.get("DB_USER", "admin")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
DB_NAME     = os.environ.get("DB_NAME", "myshoe")


def get_db():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        autocommit=True,
    )


# ─── Init DB tables ───────────────────────────────────────────────────
def init_db():
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS shoes (
                    id         INT AUTO_INCREMENT PRIMARY KEY,
                    name       VARCHAR(128) NOT NULL,
                    brand      VARCHAR(64)  NOT NULL,
                    size       VARCHAR(8)   NOT NULL,
                    color      VARCHAR(64)  NOT NULL,
                    price      DECIMAL(10,2) NOT NULL,
                    image_url  VARCHAR(512),
                    stock      INT          NOT NULL DEFAULT 0,
                    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS cart (
                    id         INT AUTO_INCREMENT PRIMARY KEY,
                    user_id    INT          NOT NULL,
                    shoe_id    INT          NOT NULL,
                    quantity   INT          NOT NULL DEFAULT 1,
                    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (shoe_id) REFERENCES shoes(id)
                )
            """)

            # Seed sample data if empty
            cur.execute("SELECT COUNT(*) FROM shoes")
            if cur.fetchone()[0] == 0:
                shoes = [
                    ("Running Pro X", "Myshoe", "9", "Midnight Black", 4999, "/assets/running-pro-x.jpg", 50),
                    ("Air Stride 3000", "Myshoe", "10", "Ocean Blue", 7499, "/assets/air-stride.jpg", 30),
                    ("Classic Leather Lace", "Myshoe", "8", "Wheat", 5999, "/assets/classic-leather.jpg", 40),
                    ("Trail Blazer Hike", "Myshoe", "11", "Forest Green", 8999, "/assets/trail-blazer.jpg", 20),
                    ("Urban Sprint Low", "Myshoe", "9", "Stark White", 4499, "/assets/urban-sprint.jpg", 60),
                ]
                cur.executemany(
                    "INSERT INTO shoes (name, brand, size, color, price, image_url, stock) VALUES (%s,%s,%s,%s,%s,%s,%s)",
                    shoes,
                )
                logger.info("Seeded %d shoes", len(shoes))
    finally:
        conn.close()


# Run DB init once at startup
init_db()


# ─── Routes ────────────────────────────────────────────────────────────

@app.route("/health")
def health():
    try:
        conn = get_db()
        conn.ping(reconnect=True)
        conn.close()
        return jsonify({"status": "healthy", "db": "connected"}), 200
    except Exception as e:
        logger.error("Health check failed: %s", e)
        return jsonify({"status": "unhealthy", "db": "disconnected"}), 503


@app.route("/")
def index():
    return render_template_string("""
        <!DOCTYPE html>
        <html>
        <head><title>Myshoe — 프리미엄 슈즈</title></head>
        <body style="font-family:sans-serif;max-width:800px;margin:40px auto;">
            <h1>👟 Myshoe</h1>
            <p>프리미엄 슈즈 셀렉션 — 달리기부터 정장까지.</p>
            <ul>
            {% for shoe in shoes %}
              <li>
                <strong>{{ shoe.name }}</strong> — {{ shoe.size }} / {{ shoe.color }}<br>
                <span style="color:#b00;font-weight:bold;">₹{{ "{:,.0f}".format(shoe.price) }}</span>
                | 재고: {{ shoe.stock }}켤레
              </li>
            {% endfor %}
            </ul>
        </body>
        </html>
    """, shoes=get_all_shoes())


def get_all_shoes():
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, brand, size, color, price, image_url, stock FROM shoes")
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]
    finally:
        conn.close()


@app.route("/api/shoes", methods=["GET"])
def api_shoes():
    return jsonify(get_all_shoes())


@app.route("/api/shoes/<int:shoe_id>", methods=["GET"])
def api_shoe(shoe_id):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, name, brand, size, color, price, image_url, stock FROM shoes WHERE id=%s",
                (shoe_id,),
            )
            row = cur.fetchone()
            if not row:
                return jsonify({"error": "not found"}), 404
            cols = [desc[0] for desc in cur.description]
            return jsonify(dict(zip(cols, row)))
    finally:
        conn.close()


@app.route("/api/cart", methods=["POST"])
def api_cart_add():
    data = request.get_json(force=True)
    user_id  = data.get("user_id")
    shoe_id  = data.get("shoe_id")
    quantity = data.get("quantity", 1)

    if not user_id or not shoe_id:
        return jsonify({"error": "user_id and shoe_id required"}), 400

    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO cart (user_id, shoe_id, quantity) VALUES (%s,%s,%s)",
                (user_id, shoe_id, quantity),
            )
            return jsonify({"message": "added to cart", "cart_id": cur.lastrowid}), 201
    finally:
        conn.close()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
