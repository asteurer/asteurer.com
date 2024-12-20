FROM alpine:3.21
WORKDIR /app

RUN apk update && apk add \
    hugo \
    git \
    nodejs \
    npm \
    neovim

RUN hugo new site .

RUN npm i -g postcss postcss-cli autoprefixer

RUN git clone https://github.com/victoriadrake/hugo-theme-introduction.git themes/introduction

COPY ./app/ .

ENTRYPOINT [ "hugo", "serve", "--bind=0.0.0.0", "--noHTTPCache" ]