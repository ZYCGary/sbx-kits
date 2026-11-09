# syntax=docker/dockerfile:1
FROM node:24-trixie-slim AS build
# The workload sets NPM_CONFIG_PREFIX=/usr/local/share/npm-global (already on PATH)
# but does not create it; agent-owned so `npm install -g` works without sudo.
RUN mkdir -p /out/usr/local/bin /out/usr/local/lib /out/usr/local/share/npm-global \
 && cp -a /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack /out/usr/local/bin/ \
 && cp -a /usr/local/lib/node_modules /out/usr/local/lib/ \
 && chown 1000:1000 /out/usr/local/share/npm-global

FROM scratch
COPY --from=build /out /
