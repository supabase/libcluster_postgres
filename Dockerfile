FROM elixir as builder

RUN apt-get update -y \
  && apt-get install -y build-essential git \
  && apt-get clean

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force
ADD ../../ /app

WORKDIR /app
RUN mix deps.get && mix compile

WORKDIR /app/example
RUN mix deps.get && mix compile
CMD [ "elixir", "--sname", "service", "--cookie", "secret", "-S", "mix", "run", "--no-halt" ]
