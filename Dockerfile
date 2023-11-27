FROM elixir as builder

RUN apt-get update -y \
  && apt-get install -y build-essential git \
  && apt-get clean

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force
ADD ../../ /app

WORKDIR /app
RUN mix compile

WORKDIR /app/example
RUN mix release
CMD [ "_build/prod/rel/example/bin/example", "start", "--sname", "service", "--no-halt" ]
