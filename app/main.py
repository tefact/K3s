from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

@app.route("/")
def home():
    return f"""
    <html>
    <head>
        <title>Debug Life - K8s Workshop</title>
        <style>
            body {{
                background: #0d0d0d;
                color: #ffffff;
                font-family: monospace;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
            }}
            .card {{
                border: 1px solid #ff6b00;
                padding: 40px;
                max-width: 500px;
                text-align: center;
            }}
            h1 {{ color: #ff6b00; }}
            .badge {{
                background: #ff6b00;
                color: #000;
                padding: 4px 12px;
                font-weight: bold;
                margin-top: 16px;
                display: inline-block;
            }}
            .info {{ color: #aaaaaa; margin-top: 12px; font-size: 13px; }}
        </style>
    </head>
    <body>
        <div class="card">
            <h1>&#x2713; Deploy Berhasil!</h1>
            <p>App kamu sudah jalan di Kubernetes.</p>
            <div class="badge">STATUS: RUNNING</div>
            <p class="info">Pod: {socket.gethostname()}</p>
            <p class="info">Version: {os.getenv("APP_VERSION", "v1.0.0")}</p>
            <p class="info">inspect &middot; reflect &middot; refactor</p>
        </div>
    </body>
    </html>
    """

@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "pod": socket.gethostname(),
        "version": os.getenv("APP_VERSION", "v1.0.0")
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
