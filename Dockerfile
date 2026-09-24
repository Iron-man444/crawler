FROM ruby:3.4-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev ca-certificates && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install && useradd --create-home --uid 10001 radar
COPY --chown=radar:radar . .
USER radar
CMD ["ruby", "bin/radar", "run"]
