[Searchiscope](http://searchiscope.appspot.com)
==============
Latest tweets from anywhere in the world!

Radius is 10 km, up to 15 tweets are shown, search is 6-7 days deep.

Built with [Elm](http://elm-lang.org/), [Go](https://golang.org/),
[Google Maps API](https://developers.google.com/maps/documentation/javascript/),
[Twitter Search API](https://dev.twitter.com/rest/public/search) during the Hackweek 2015 at Twitter.

How to start your own instance
------------------------------
Install [Elm](http://elm-lang.org/install) and [Google App Engine SDK for Go](https://cloud.google.com/appengine/docs/go/).

First, compile Elm code to elm.js with elm-make:

    $ pushd elm && elm-make TwitterSearch.elm --output ../js/elm.js && popd

[Create a Twitter app](https://apps.twitter.com/), obtain its API consumer key and secret, and put them in `config/twitter_credentials.json` in this format:

    {
      "key": "0123456789ABCDEF",
      "secret": "0123456789ABCDEF0123456789ABCDEF"
    }

Then, start a local instance:

    $ goapp serve

Or, deploy to Google App Engine:

    $ goapp deploy

TODO
----
- Configurable radius
- Permalinks
- Display local timezone instead of UTC
