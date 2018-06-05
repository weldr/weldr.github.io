# Stylin'

Notes for weldrists writing for weldr.io.

## Testing locally using containers

This will build a container, install the needed fedora packages and mount the current directory as
your user id (so that you can edit from within the container without making everything owned by root).

    sudo docker build -t weldr/jekyll .
    sudo docker run -it --name=jekyll --security-opt="label=disable" -v "$PWD:/weldr.io/" --env LOCAL_UID=`id -u` -p 4000:4000 weldr/jekyll /usr/bin/bash
    bundle install --binstubs=/tmp/bin/
    bundle exec /tmp/bin/jekyll serve --host=0.0.0.0 --incremental

...then just open http://localhost:4000/ and you're off. On subsequent runs you can reuse the container with:

    sudo docker start -i jekyll

## Testing locally

See README.md as well, but here's the quick version:

    sudo dnf install rubygem-bundler ruby-devel kernel-headers
    bundle install
    bundle exec jekyll serve

...then just open http://localhost:4000/ and you're off.

### Drafts

You can add draft posts under `_drafts/` without a date prefix, like:

    _drafts/Now-Thats-What-I-Call-Blogging.md

Drafts won't get shown unless you run jekyll with `--drafts`:

    bundle exec jekyll serve --drafts

This is helpful for sharing posts with the team before publishing them _and_
making sure you don't accidentally delete/lose your post before it's finished.

## Author info

Add a page for yourself in `_authors/`, like so:

    ---
    userid: wwoods
    name: Will Woods
    email: wwoods@redhat.com
    github: wgwoods
    ---
    
    THIS IS MY AUTHOR PAGE, WOW

Now when you're writing a post, you can add something like:

    author: wwoods

to the "front matter", and then we'll have a reference to info about whoever
wrote the post.

(Be sure to include the `github` username, because we might grab the github
user avatar to use an avatar for you on the page.)

## Categories, tags, and fedoraplanet.org

We currently aren't using categories for anything, so don't bother.

Go ahead and add tags - everyone loves metadata, right? They'll show up in the
footer of your post, and each tag links to the tag summary page (/tags/),
which shows a list of all known tags and a list of posts for each tag.

If you use the tag "fedoraplanet", it'll show up on http://fedoraplanet.org/
so people in the Fedora community can see it. If you don't want that.. don't
do that.
