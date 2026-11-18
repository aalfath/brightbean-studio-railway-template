# BrightBean Studio for Railway.
# Upstream publishes no releases, tags or images, so this builds the app from a
# pinned upstream commit with digest-pinned official Python and Node bases.
# To update: change BRIGHTBEAN_COMMIT (and the base digests if needed) and add
# a CHANGELOG.md entry.
ARG BRIGHTBEAN_COMMIT=14b92fc18549de47d42e62054215b38b4d994449

# 1. Fetch the upstream source at the pinned commit.
FROM python:3.12.16-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b AS src
ARG BRIGHTBEAN_COMMIT
RUN python -c "import io,sys,tarfile,urllib.request; \
url='https://codeload.github.com/brightbeanxyz/brightbean-studio/tar.gz/'+sys.argv[1]; \
tarfile.open(fileobj=io.BytesIO(urllib.request.urlopen(url, timeout=120).read()), mode='r:gz').extractall('/tmp/x', filter='data')" "$BRIGHTBEAN_COMMIT" \
 && mv /tmp/x/brightbean-studio-* /src \
 && rm -r /src/.github /src/output /src/development_specs /src/tests

# 2. Build the Tailwind CSS.
FROM node:20.20.2-trixie-slim@sha256:abfbe12cc943141a0c9e8c0a57d710df1dadd95d35e8662cc02958b284d1f35b AS css
COPY --from=src /src /src
RUN cd /src/theme/static_src && npm ci --no-audit --no-fund && npm run build && rm -r node_modules

# 3. Runtime image.
FROM python:3.12.16-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b
ARG BRIGHTBEAN_COMMIT
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000 \
    BRIGHTBEAN_COMMIT=${BRIGHTBEAN_COMMIT}
WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg \
 && rm -r /var/lib/apt/lists/*
COPY --from=css /src/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY --from=css /src /app
RUN DJANGO_SETTINGS_MODULE=config.settings.production \
    SECRET_KEY=build-placeholder \
    DATABASE_URL=sqlite:///tmp/build.db \
    python manage.py collectstatic --noinput >/dev/null \
 && mkdir -p /app/media
COPY railway-start.sh railway-bootstrap.py /usr/local/bin/
RUN chmod +x /usr/local/bin/railway-start.sh
EXPOSE 8000
CMD ["/usr/local/bin/railway-start.sh"]
