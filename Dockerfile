FROM akorn/luarocks:lua5.1-alpine AS builder
RUN apk add --no-cache --update unzip && \
    luarocks install kong-oidc

FROM scratch
# if we were to include the luarocks package
# COPY --from=builder /usr/local/lib/luarocks/rocks-5.1/kong-oidc/1.1.0-0 \
#                     /usr/local/lib/luarocks/rocks-5.1/kong-oidc/1.1.0-0
COPY --from=builder /usr/local/share/lua/5.1/kong/plugins/oidc \
                    /opt/kong/plugins/oidc
