#########################################################
# Builder
#########################################################
FROM node:22.23.1 AS builder

WORKDIR /app

COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline

COPY . .
RUN npm run build
RUN npm prune --production

#########################################################
# Runner
#########################################################
FROM node:22.23.1-slim

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=4000

# El runtime arranca con `node` directo, así que npm y yarn nunca se usan acá.
# Se eliminan porque sus dependencias internas (tar, brace-expansion, sigstore...)
# aportan CVEs Critical/High que harían fallar el gate del CI sin razón real.
RUN rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/bin/npm \
           /usr/local/bin/npx \
           /opt/yarn-v* \
           /usr/local/bin/yarn \
           /usr/local/bin/yarnpkg

RUN chown -R node:node /app

COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package.json ./package.json
COPY --from=builder --chown=node:node /app/public ./public

USER node

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:4000/api/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "dist/main.js"]
