# ── Stage: build image ──────────────────────────────────────────
FROM python:3.12-slim

# Set working directory di dalam container
WORKDIR /app

# Copy requirements dulu (biar layer cache optimal)
COPY app/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code app
COPY app/ .

# Expose port yang dipakai Flask
EXPOSE 5000

# Jalankan pakai gunicorn (production-grade WSGI server)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "main:app"]

