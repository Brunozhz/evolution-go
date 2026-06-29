FROM golang:1.25.0-alpine AS build

RUN apk update && apk add --no-cache git build-base libjpeg-turbo-dev libwebp-dev

WORKDIR /build

COPY . .

ARG WHATSMEOW_REF=0923702fb3fac8525241f15331b92116485d69eb

# O go.mod usa replace para ./whatsmeow-lib. Se o deploy nao baixar submodulos,
# clonamos a mesma revisao registrada no repositorio principal.
RUN if [ ! -f whatsmeow-lib/go.mod ]; then \
      rm -rf whatsmeow-lib && \
      git clone https://github.com/EvolutionAPI/whatsmeow.git whatsmeow-lib && \
      git -C whatsmeow-lib checkout "$WHATSMEOW_REF"; \
    fi

RUN go mod tidy && go mod download

ARG VERSION=dev
RUN CGO_ENABLED=1 go build -ldflags "-X main.version=${VERSION}" -o server ./cmd/evolution-go

FROM alpine:3.19.1 AS final

RUN apk update && apk add --no-cache tzdata ffmpeg libjpeg-turbo libwebp

WORKDIR /app

COPY --from=build /build/server .
COPY --from=build /build/manager/dist ./manager/dist
COPY --from=build /build/public ./public
COPY --from=build /build/VERSION ./VERSION

ENV TZ=America/Sao_Paulo

ENTRYPOINT ["/app/server"]
