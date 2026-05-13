# ---- builder --------------------------------------------------------
# Installs build tools and compiles Python wheels into a venv.
# Nothing from this stage ships in the final image.
FROM python:3.11-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libpq-dev \
    && rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/venv
RUN python -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY requirements.txt .
# Strip the "# --- test-only ---" block so test deps don't ship in the image.
RUN sed '/# --- test-only ---/,$ d' requirements.txt > /tmp/requirements-prod.txt \
    && pip install --no-cache-dir -r /tmp/requirements-prod.txt

# ---- runtime --------------------------------------------------------
# Slim image with only the venv copied in — no compiler, no libpq-dev.
# psycopg2-binary bundles libpq, so no extra system lib needed at runtime.
FROM python:3.11-slim AS runtime

# All stable config consolidated before the frequently-changing COPY below.
ENV VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH" \
    PORT=3000 \
    PYTHONUNBUFFERED=1

COPY --from=builder $VIRTUAL_ENV $VIRTUAL_ENV

WORKDIR /app
COPY . /app

EXPOSE 3000

CMD ["python", "-m", "src.main"]
