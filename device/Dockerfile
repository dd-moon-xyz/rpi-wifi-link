FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-dbus python3-gi python3-cryptography \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY protocol.py server.py wifi.py ./
ENV PYTHONDONTWRITEBYTECODE=1
CMD ["/usr/bin/python3", "server.py"]
