# Stylin'

Notes for weldrists writing for weldr.io.

## Testing locally

See README.md as well, but here's the quick version:

    sudo dnf install rubygem-bundler ruby-devel
    bundle install
    bundle exec jekyll serve

...then just open http://localhost:4000/ and you're off.

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
