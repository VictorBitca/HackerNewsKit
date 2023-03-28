# HackerNewsKit for Hacker News

**HackerNewsKit** is a Hacker News package that wraps up the awkward [public hacker news API](https://github.com/HackerNews/API) and extends it with some features that are available only on the website and then some, it's the main package powering the [HN Lens app](https://github.com/VictorBitca/hacker-news-lens).

Internally it uses Firebase to access the public part of the API and for the private functionality (the one that isn't available through Firebase) it uses web requests to the good old `https://news.ycombinator.com` and parses the HTML.

Features
-------
 
- Logging in with an existing account.
- Basic stories and comments browsing.
- Site thumbnail/image preview generation from URLs.
- Instantaneous comment stream. 
- Converts the HN HTML comments into NSAttributedString.
- Search functionality for stories.
- Replying to comments and stories.
- Adding comments and stories to favorites.
- Upvoting comments and stories.
- Browsing favorite and upvoted stories and comments.

Building and running
-------

**HackerNewsKit** uses Firebase to access the public HN API, therefore the project requires a `GoogleServices.plist` config file in the root of the parent project folder.
[See how to generate and download the Firebase config file](https://support.google.com/firebase/answer/7015592?hl=en#ios)
The most important step is to add the database URL in plist:
```
    ...
    <key>DATABASE_URL</key>
    <string>https://hacker-news.firebaseio.com</string>
    ...
```

# Licence
**HackerNewKit** is free software available under Version 3 of the GNU General Public License. See COPYING for details.
