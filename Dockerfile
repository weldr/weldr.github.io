# Copied from the template at https://hub.docker.com/_/ruby/
# Use Ruby 2.4 since that's what's in .ruby-version at https://github.com/github/pages-gem
FROM ruby:2.4

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /weldr.io/

COPY Gemfile Gemfile.lock ./
RUN bundle install

# Run as user passed in with --env LOCAL_UID=`id -u`
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
