FROM node:20-alpine

# Tools needed to pull your website repo
RUN apk add --no-cache git openssh-client

# Install serve globally (like npx serve, but installed in the image)
RUN npm i -g serve

# Defaults (override in docker-compose.yml)
ENV SITE_REPO="https://github.com/camwolff02/website-infra.git"
ENV SITE_BRANCH="main"
ENV POLL_SECONDS="60"
ENV SERVE_SUBDIR=""
ENV LISTEN_PORT="3000"

# Create an entrypoint script inside the image
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/sh
set -eu

SITE_DIR="/site"
REPO="${SITE_REPO}"
BRANCH="${SITE_BRANCH}"
POLL="${POLL_SECONDS}"
SUBDIR="${SERVE_SUBDIR}"
PORT="${LISTEN_PORT}"

mkdir -p "${SITE_DIR}"

# Initial clone (or reset to remote if volume already has a repo)
if [ ! -d "${SITE_DIR}/.git" ]; then
rm -rf "${SITE_DIR:?}"/*
git clone --depth 1 --branch "${BRANCH}" "${REPO}" "${SITE_DIR}"
else
cd "${SITE_DIR}"
git fetch origin "${BRANCH}" --depth 1
git reset --hard "origin/${BRANCH}"
fi

# Where to serve from (repo root by default, or a subdir like dist/)
SERVE_DIR="${SITE_DIR}"
if [ -n "${SUBDIR}" ]; then
SERVE_DIR="${SITE_DIR}/${SUBDIR}"
fi

# Run the server as PID 1
exec serve -s "${SERVE_DIR}" -l "${PORT}"
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]
