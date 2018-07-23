# Mura Social Wall
A Mura 7 plugin with a display object listing recent posts from Twitter, Facebook and Instagram.

## Description
Once the plugin is configured with the respective social media application keys, the display object can simply be drag&dropped anywhere with inline edit. It will display a chooser if more than one social media has been configured. The chooser lets the end user select a list of social media to be displayed, as configured in administration. All the recent posts from the user are displayed with a wall view, sorted by date. It adapts to the available width, using one to three columns.

## Configuration
An application needs to be created for each of the social media used. These applications do not need to be public, and a sandbox mode should work. Limiting them to read-only permissions is a good idea as the plugin does not need anything else. To optimize speed and limit the number of requests, the display object uses a 10 minutes cache if site caching is enabled. Adding `?purgeCache=1` to the URL will purge the cache.

- Twitter

  A twitter app can be created at <https://apps.twitter.com/>. The plugin will need the consumer key and the consumer secret. The application owner should match the twitter screen name.

- Facebook

  A facebook app can be created at <https://developers.facebook.com/apps/>. The plugin will need the app ID and secret.

- Instagram

  An Instagram client can be created at <https://www.instagram.com/developer/clients/manage/>. The plugin will need an access token, which is not available directly from the configuration page. An access token can be retrieved by temporarily enabling implicit authentication and using the following URL: `https://www.instagram.com/oauth/authorize/?client_id=CLIENT_ID&redirect_uri=REDIRECT_URL&response_type=token` (replace `CLIENT_ID` and `REDIRECT_URL` by the matching fields in the app configuration). This will redirect you to the given redirect URL, with an additional query parameter containing an access token. Simply copy that access token value into the plugin configuration.

### Options
The social wall menu to select a display and the default selection of social media can be configured with the following syntax. Menu entries are separated by a `|`. The first entry is the default one. Each menu entry is composed of a title, a `:`, and the comma-separated lowercase list of social media to display.

For instance, to add a "Showcase" menu to display only Facebook and Instagram as the default, on top of the other menus, the following can be used:

`Showcase:facebook,instagram|Facebook only:facebook|Instagram only:instagram|Twitter only:twitter|All:twitter,facebook,instagram`
