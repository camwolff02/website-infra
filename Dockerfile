FROM node:20-alpine

RUN apk add --no-cache git git-lfs openssh-client
RUN npm i -g serve

ENV SITE_REPO="https://github.com/camwolff02/website-infra.git"
ENV SITE_BRANCH="main"
ENV SERVE_SUBDIR=""     
ENV LISTEN_PORT="3000"

RUN cat > /entrypoint.sh << 'EOF'
#!/bin/sh
set -eu

SITE_DIR="/site"
mkdir -p "$SITE_DIR"

git lfs install --system >/dev/null 2>&1 || true

if [ ! -d "$SITE_DIR/.git" ]; then
rm -rf "${SITE_DIR:?}"/*
git clone --depth 1 --branch "$SITE_BRANCH" "$SITE_REPO" "$SITE_DIR"
else
cd "$SITE_DIR"
git fetch origin "$SITE_BRANCH" --depth 1
git reset --hard "origin/$SITE_BRANCH"
fi

cd "$SITE_DIR"
git lfs pull || (git lfs fetch origin "$SITE_BRANCH" && git lfs checkout)

SERVE_DIR="$SITE_DIR"
if [ -n "$SERVE_SUBDIR" ]; then
SERVE_DIR="$SITE_DIR/$SERVE_SUBDIR"
fi

# Note: don't use `serve -s` for Godot while debugging; it can mask missing-file problems.
exec serve "$SERVE_DIR" -l "$LISTEN_PORT"
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]
