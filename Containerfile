ARG BASE_VERSION=15
FROM ghcr.io/daemonless/base:${BASE_VERSION} AS builder

# Install build dependencies - Python 3.12 with build tools for pip compilation
RUN pkg update && \
    pkg install -y \
    coreutils \
    python312 \
    py312-wheel \
    py312-setuptools \
    rust \
    gcc \
    gmake \
    cmake \
    pkgconf \
    libffi \
    webp \
    libxslt \
    libxml2 \
    libjpeg-turbo \
    libheif \
    openjpeg \
    lcms2 \
    freetype2 \
    harfbuzz \
    openldap26-client \
    postgresql17-client \
    node24 \
    npm-node24 \
    yarn-node24 \
    git \
    ca_root_nss && \
    ln -sf /usr/local/bin/greadlink /usr/bin/readlink && \
    ln -sf /usr/local/bin/gdirname /usr/bin/dirname && \
    ln -sf /usr/local/bin/gcc14 /usr/local/bin/cc

# Set Python/build environment
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    CFLAGS="-I/usr/local/include" \
    LDFLAGS="-L/usr/local/lib"

# Download Mealie v3.7.x
ARG MEALIE_VERSION=v3.7.0
RUN fetch -qo /tmp/mealie.tar.gz \
    "https://github.com/mealie-recipes/mealie/archive/refs/tags/${MEALIE_VERSION}.tar.gz" && \
    mkdir -p /app && \
    tar -xzf /tmp/mealie.tar.gz -C /app --strip-components=1 && \
    rm /tmp/mealie.tar.gz

WORKDIR /app

# Build frontend
# Replace sass-embedded with pure JS sass (sass-embedded requires native Dart binaries not available on FreeBSD)
RUN cd /app/frontend && \
    sed -i '' 's/"sass-embedded":.*/"sass": "^1.85.0",/' package.json && \
    yarn install && \
    yarn generate

# Ensure pip is available and create Python virtual environment
RUN python3.12 -m ensurepip --upgrade && \
    python3.12 -m venv /opt/mealie && \
    /opt/mealie/bin/pip install --upgrade pip wheel setuptools && \
    /opt/mealie/bin/pip install \
    # Core web framework
    fastapi \
    uvicorn[standard] \
    # Database
    sqlalchemy \
    alembic \
    psycopg2-binary \
    # Data validation
    pydantic \
    pydantic-settings \
    # Image processing
    pillow \
    pillow-heif \
    # Web scraping
    lxml \
    beautifulsoup4 \
    recipe-scrapers \
    extruct \
    html2text \
    # HTTP clients
    requests \
    httpx \
    aiofiles \
    # Security
    bcrypt \
    pyjwt \
    authlib \
    python-ldap \
    # Utilities
    python-dotenv \
    python-slugify \
    python-dateutil \
    pyyaml \
    orjson \
    jinja2 \
    appdirs \
    apprise \
    pyhumps \
    tzdata \
    isodate \
    text-unidecode \
    paho-mqtt \
    aniso8601 \
    itsdangerous \
    nltk \
    regex \
    openai && \
    /opt/mealie/bin/pip install --no-deps /app

# Download NLTK data for ingredient parsing
RUN /opt/mealie/bin/python -c "import nltk; nltk.download('averaged_perceptron_tagger_eng', download_dir='/opt/mealie/nltk_data')"

# Production image
FROM ghcr.io/daemonless/base:${BASE_VERSION}

ARG MEALIE_VERSION=v3.7.0

ARG FREEBSD_ARCH=amd64
ARG PACKAGES="python312 libffi webp libxslt libxml2 libjpeg-turbo libheif openjpeg lcms2 freetype2 harfbuzz openldap26-client postgresql17-server postgresql17-client ca_root_nss"

LABEL org.opencontainers.image.title="Mealie" \
    org.opencontainers.image.description="Mealie Recipe Manager on FreeBSD with PostgreSQL" \
    org.opencontainers.image.source="https://github.com/daemonless/mealie" \
    org.opencontainers.image.url="https://mealie.io/" \
    org.opencontainers.image.documentation="https://docs.mealie.io/" \
    org.opencontainers.image.licenses="AGPL-3.0-only" \
    org.opencontainers.image.vendor="daemonless" \
    org.opencontainers.image.authors="daemonless" \
    io.daemonless.port="9000" \
    io.daemonless.arch="${FREEBSD_ARCH}" \
    io.daemonless.wip="true" \
    io.daemonless.category="Utilities" \
    io.daemonless.upstream-mode="github" \
    io.daemonless.upstream-repo="mealie-recipes/mealie" \
    io.daemonless.packages="${PACKAGES}"

# Install runtime dependencies (no Python packages - all in venv)
RUN pkg update && \
    pkg install -y \
    ${PACKAGES} && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* /var/db/pkg/repos/*

# Copy virtual environment from builder
COPY --from=builder /opt/mealie /opt/mealie

# Copy built frontend
COPY --from=builder /app/frontend/.output /app/frontend/.output

# Copy application code (alembic is inside mealie directory in v3.x)
COPY --from=builder /app/mealie /app/mealie

# Create directories and version file
RUN mkdir -p /app/data /var/db/postgres/data17 /var/run/postgresql && \
    echo "${MEALIE_VERSION}" > /app/version && \
    chown -R bsd:bsd /app /opt/mealie && \
    chown -R bsd:bsd /var/db/postgres /var/run/postgresql

# Copy service definitions and init scripts
COPY root/ /

# Make scripts executable
RUN chmod +x /etc/services.d/*/run /etc/cont-init.d/* 2>/dev/null || true

# Set up s6 service links

# Environment
ENV PYTHONPATH=/app \
    NLTK_DATA=/opt/mealie/nltk_data \
    PATH="/opt/mealie/bin:$PATH"

EXPOSE 9000
VOLUME /app/data /var/db/postgres/data17


