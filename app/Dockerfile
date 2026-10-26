FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt /tmp/requirements.txt
RUN apt-get update && apt-get install -y --no-install-recommends openssl \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir -r /tmp/requirements.txt \
 && useradd -u 10001 -M -s /usr/sbin/nologin appuser
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
# el código se monta en /app (solo lectura) desde docker compose
