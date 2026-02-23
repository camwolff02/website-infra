FROM node:20-alpine

RUN apk add --no-cache git git-lfs openssh-client
RUN npm i -g serve

ENV SITE_REPO="https://github.com/camwolff02/website-infra.git"
ENV SITE_BRANCH="main"
ENV POLL_SECONDS="60"
ENV SERVE_SUBDIR=""
ENV LISTEN_PORT="3000"

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

# Ensure LFS is set up (important inside containers)
git lfs install --system >/dev/null 2>&1 || true

if [ ! -d "${SITE_DIR}/.git" ]; then
rm -rf "${SITE_DIR:?}"/*
git clone --depth 1 --branch "${BRANCH}" "${REPO}" "${SITE_DIR}"
else
cd "${SITE_DIR}"
git fetch origin "${BRANCH}" --depth 1
git reset --hard "origin/${BRANCH}"
fi

# Pull LFS objects (this is the critical part)
cd "${SITE_DIR}"
git lfs pull || (git lfs fetch origin "${BRANCH}" && git lfs checkout)

SERVE_DIR="${SITE_DIR}"
if [ -n "${SUBDIR}" ]; then
SERVE_DIR="${SITE_DIR}/${SUBDIR}"
fi

(
while true; do
sleep "${POLL}" || true
cd "${SITE_DIR}"
git fetch origin "${BRANCH}" --depth 1 || continue
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/${BRANCH}")"
if [ "${LOCAL}" != "${REMOTE}" ]; then
git reset --hard "${REMOTE}"
git lfs pull || (git lfs fetch origin "${BRANCH}" && git lfs checkout)
echo "[website] Updated to ${REMOTE}"
fi
done
) &

exec serve "${SERVE_DIR}" -l "${PORT}"
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]
