<cfparam name="objectparams.maxPosts" default="50" />
<cfscript>
    include '../../plugin/settings.cfm';

    // Each social media app has a limit on the number of queries, so caching is very important here.
    siteid = $.siteConfig('siteId');
    config = $.getBean('socialwallconfig').loadBy(siteId=siteid);
    cacheTime = config.get('cacheTime');
    if (cacheTime == '')
        cacheTime = 10;
    maxPosts = objectparams.maxPosts;
    /* Lucee does not support that syntax
    cf_CacheOMatic(timespan=createTimeSpan(0,0,cacheTime,0)) {
        start();
    }
    */
    startWithCache();

    public void function start() {
        res = getPosts(config);
        template($, res.options, res.posts, res.configured);
    }

    public struct function getPosts(config) {
        var twitterOAuthConsumerKey = config.get('twitterOAuthConsumerKey');
        var twitterOAuthConsumerSecret = config.get('twitterOAuthConsumerSecret');
        var twitterScreenName = config.get('twitterScreenName');
        var facebookAppID = config.get('facebookAppID');
        var facebookAppSecret = config.get('facebookAppSecret');
        var facebookUserId = config.get('facebookUserId');
        var instagramAccessToken = config.get('instagramAccessToken');
        var options = config.get('options');
        if (options == '')
            options = 'Twitter:twitter|Facebook:facebook|Instagram:instagram|All:twitter,facebook,instagram';
        
        var confMedia = [];
        var posts = [];
        var configured = false;
        
        if (twitterOAuthConsumerKey != '' && twitterOAuthConsumerSecret != '' && twitterScreenName != '') {
            confMedia.append('twitter');
            posts.append(getTwitterPosts(twitterOAuthConsumerKey, twitterOAuthConsumerSecret, twitterScreenName), true);
            configured = true;
        }
        
        if (facebookAppID != '' && facebookAppSecret != '' && facebookUserId != '') {
            confMedia.append('facebook');
            posts.append(getFacebookPosts(facebookAppID, facebookAppSecret, facebookUserId), true);
            configured = true;
        }

        if (instagramAccessToken != '') {
            confMedia.append('instagram');
            posts.append(getInstagramPosts(instagramAccessToken), true);
            configured = true;
        }

        // sort by date
        posts.sort(function(p1, p2) {
            return -compare(p1.date, p2.date);
        });

        if (confMedia.len() < 2) {
            // clear options if there is less than 2 configured media
            options = '';
        } else {
            // remove options without the required information
            var newoptions = '';
            for (var option in listToArray(options, '|')) {
                var medias = listLast(option, ':');
                var foundOne = false;
                for (media in listToArray(medias, ',')) {
                    if (confMedia.find(media) > 0) {
                        foundOne = true;
                        break;
                    }
                }
                if (foundOne)
                    newoptions = listAppend(newoptions, option, '|');
            }
            options = newoptions;
        }

        return {
            options: options,
            posts: posts,
            configured: configured
        };
    }

    public array function getTwitterPosts(twitterOAuthConsumerKey, twitterOAuthConsumerSecret, twitterScreenName) {
        var posts = [];
        // see https://developer.twitter.com/en/docs/basics/authentication/overview/application-only
        // get a bearer token
        var encodedKey = toBase64(twitterOAuthConsumerKey & ':' & twitterOAuthConsumerSecret);
        var httpService = new http(method="POST", charset="UTF-8",
            url="https://api.twitter.com/oauth2/token");
        httpService.addParam(type="body", value="grant_type=client_credentials");
        httpService.addParam(type="header", name="Content-Type", value="application/x-www-form-urlencoded;charset=UTF-8");
        httpService.addParam(type="header", name="Authorization", value='Basic ' & encodedKey);
        var result = httpService.send().getPrefix();
        var accessToken = '';
        if (result.statusCode == '200 OK') {
            var json = '';
            try {
                json = deserializeJSON(result.fileContent);
            } catch (any e) {
                writeLog('Deserializing data from api.twitter.com: ' & e.message);
            }
            if (isStruct(json) && json.token_type == 'bearer') {
                accessToken = json.access_token;
            }
        } else {
            writeLog("api.twitter.com: #result.statusCode#. #result.errorDetail#");
            if (result.fileContent != '' && result.fileContent.len() < 500)
                writeLog(result.fileContent);
        }
        if (accessToken != '') {
            httpService = new http(method="GET", charset="UTF-8",
                url="https://api.twitter.com/1.1/statuses/user_timeline.json");
            httpService.addParam(type="header", name="Authorization", value='Bearer ' & accessToken);
            httpService.addParam(type="URL", name="screen_name", value=twitterScreenName);
            httpService.addParam(type="URL", name="tweet_mode", value="extended");
            result = httpService.send().getPrefix();
            if (result.statusCode == '200 OK') {
                var statuses = '';
                try {
                    statuses = deserializeJSON(result.fileContent);
                } catch (any e) {
                    writeLog('Deserializing data from api.twitter.com: ' & e.message);
                }
                if (isArray(statuses)) {
                    for (var status in statuses) {
                        if (status.retweeted)
                            continue;
                        var post = {};
                        post.type = 'twitter';
                        post.images = [];
                        if (structKeyExists(status.entities, 'media')) {
                            var medias = status.entities.media;
                            for (var media in medias) {
                                if (media.type == 'photo' || media.type == 'animated_gif')
                                    post.images.append(media.media_url_https);
                            }
                        }
                        // example time: 'Wed Aug 27 13:08:45 +0000 2008'
                        post.date = lsParseDateTime(status.created_at, 'en', 'EEE MMM dd HH:mm:ss Z yyyy');
                        post.user = status.user.name;
                        var text = status.full_text;
                        var urlEntities = status.entities.urls;
                        var urlEntityArray = [];
                        for (var urlEntity in urlEntities)
                            urlEntityArray.append(urlEntity);
                        var urlEntityReversed = [];
                        for (var i=urlEntityArray.len(); i>=1; i--)
                            urlEntityReversed.append(urlEntityArray[i]);
                        for (var urlEntity in urlEntityReversed) {
                            var start = urlEntity.indices[1];
                            var end = urlEntity.indices[2];
                            text = text.mid(1, start) & '<a href="' & urlEntity.url & '">' &
                                urlEntity.display_url & '</a>' &
                                text.mid(end + 1, text.len() - end);
                        }
                        text = text.reReplace('##(\w+)', '<a href="https://twitter.com/hashtag/\1">##\1</a>', 'all');
                        text = text.reReplace('@(\w+)', '<a href="https://twitter.com/\1">@\1</a>', 'all');
                        repos = text.reFind('[^"](https?://t.co/\w+)', 1, true);
                        if (arrayLen(repos.pos) > 1) {
                            var pos = repos.pos[2];
                            var length = repos.len[2];
                            post.link = text.mid(pos, length);
                            text = text.mid(1, pos - 1) & text.mid(pos + length, text.len() - (pos + length) + 1);
                        }
                        post.content = text;
                        posts.append(post);
                    }
                }
            } else {
                writeLog("api.twitter.com: #result.statusCode#. #result.errorDetail#");
                if (result.fileContent != '' && result.fileContent.len() < 500)
                    writeLog(result.fileContent);
            }
        }
        return posts;
    }

    public array function getFacebookPosts(facebookAppID, facebookAppSecret, facebookUserId) {
        // see https://developers.facebook.com/docs/graph-api/
        var posts = [];
        var httpService = new http(method="GET", charset="UTF-8",
            url="https://graph.facebook.com/#facebookUserId#/posts");
        httpService.addParam(type="URL", name="limit", value="20");
        httpService.addParam(type="URL", name="fields", value="message,description,created_time,full_picture,link");
        // this no longer works with CF 11 U 16, because of a CF bug (it's not encoding the pipe)
        // httpService.addParam(type="URL", name="access_token", value="#facebookAppID#|#facebookAppSecret#");
        httpService.addParam(type="URL", name="access_token",
            value="#facebookAppID#%7C#facebookAppSecret#");
        var result = httpService.send().getPrefix();
        if (result.statusCode == '200 OK') {
            var json = '';
            try {
                json = deserializeJSON(result.fileContent);
            } catch (any e) {
                writeLog('Deserializing data from graph.facebook.com: ' & e.message);
            }
            if (isStruct(json) && structKeyExists(json, 'data')) {
                var data = json.data;
                for (var fbpost in data) {
                    var post = {};
                    post.type = 'facebook';
                    // by default facebook returns an ISO 8601 date, eg 2017-12-28T14:36:23+0000
                    post.date = lsParseDateTime(fbpost.created_time, 'en', "yyyy-MM-dd'T'HH:mm:ssZ");
                    var message = '';
                    if (structKeyExists(fbpost, 'message'))
                        message = fbpost.message;
                    else if (structKeyExists(fbpost, 'description'))
                        message = fbpost.description;
                    message = message.reReplace('##(\w+)', '<a href="https://www.facebook.com/hashtag/\1">##\1</a>', 'all');
                    message = message.reReplace('([^"])(https?://[\w.\-]+/[\w+/\-%?=+]*)',
                        '\1<a href="\2">\2</a>', 'all');
                    message = message.reReplace('(\s)(bit\.ly/[\w]+)',
                        '\1<a href="https://\2">\2</a>', 'all');
                    var imgURL = '';
                    if (structKeyExists(fbpost, 'full_picture'))
                        imgURL = fbpost.full_picture;
                    post.images = [];
                    if (imgURL != '')
                        post.images.append(imgURL);
                    if (structKeyExists(fbpost, 'link'))
                        post.link = fbpost.link;
                    post.content = message;
                    posts.append(post);
                }
            }
        } else {
            writeLog("graph.facebook.com: #result.statusCode#. #result.errorDetail#");
            if (result.fileContent != '' && result.fileContent.len() < 500)
                writeLog(result.fileContent);
        }
        return posts;
    }

    public array function getInstagramPosts(instagramAccessToken) {
        var posts = [];
        // see https://www.instagram.com/developer/
        // access token can be retrieved by temporarily using implicit authentication with the following URL,
        // and copying the access code from the redirected URL
        // https://www.instagram.com/oauth/authorize/?client_id=CLIENT_ID&redirect_uri=REDIRECT_URL&response_type=token
        var httpService = new http(method="GET", charset="UTF-8",
            url="https://api.instagram.com/v1/users/self/media/recent/");
        httpService.addParam(type="URL", name="access_token", value=instagramAccessToken);
        var result = httpService.send().getPrefix();
        if (result.statusCode == '200 OK') {
            var json = '';
            try {
                json = deserializeJSON(result.fileContent);
            } catch (any e) {
                writeLog('Deserializing data from instagram.com: ' & e.message);
            }
            if (isStruct(json) && structKeyExists(json, 'data')) {
                var data = json.data;
                for (var ipost in data) {
                    var post = {};
                    post.type = 'instagram';
                    post.date = dateAdd('s', ipost.created_time, createDate(1970, 1, 1));
                    var message = '';
                    if (structKeyExists(ipost, 'caption') && structKeyExists(ipost.caption, 'text'))
                        message = ipost.caption.text;
                    message = message.reReplace('##(\w+)',
                        '<a href="https://www.instagram.com/explore/tags/\1">##\1</a>', 'all');
                    message = message.reReplace('([^"])(https?://[\w.\-]+/[\w+/\-%?=+]*)',
                        '\1<a href="\2">\2</a>', 'all');
                    message = message.reReplace('@(\w+)',
                        '<a href="https://www.instagram.com/\1/">@\1</a>', 'all');
                    post.images = [ipost.images.standard_resolution.url];
                    post.link = ipost.link;
                    post.content = message;
                    posts.append(post);
                }
            }
        } else {
            writeLog("api.instagram.com: #result.statusCode#. #result.errorDetail#");
            if (result.fileContent != '' && result.fileContent.len() < 500)
                writeLog(result.fileContent);
        }
        return posts;
    }
</cfscript>

<cffunction name="startWithCache" output="true">
    <cf_CacheOMatic timespan="#createTimeSpan(0, 0, cacheTime, 0)#">
        <cfset start()>
    </cf_CacheOMatic>
</cffunction>

<cffunction name="template" output="true">
    <cfargument name="$" type="struct" required="yes">
    <cfargument name="options" type="string" required="yes">
    <cfargument name="posts" type="array" required="yes">
    <cfargument name="configured" type="boolean" required="yes">
    <cfif !configured>
        <p>The Social Media Wall plugin has not been configured yet.</p>
    <cfelse>
        <cfif listLen(options, '|') gt 1>
            <div class="sw_selector_container">
                <p><label for="sw_selector">Display posts </label> <select id="sw_selector">
                    <cfset first = listFirst(options, '|')>
                    <cfloop index="option" list="#options#" delimiters="|">
                        <cfset title = listFirst(option, ':')>
                        <cfset medias = listLast(option, ':')>
                        <option value="#medias#"<cfif option eq first> selected</cfif>>#title#</option>
                    </cfloop>
                </select></p>
            </div>
        </cfif>
    </cfif>
    <div class="sw_container">
        <cfloop index="post" array="#posts#">
            <div class="sw_post #post.type#_post">
                <div class="sw_head">
                    <span class="sw_date">#post.date.dateFormat('short')#</span>
                    <span class="sw_type"><span class="fa fa-#post.type#">&nbsp;</span><span class="sr-only">#post.type#</span></span>
                </div>
                <span class="sw_text">#post.content#</span>
                <cfif structKeyExists(post, 'link')>
                    <span> </span><a class="sw_more_link" href="#post.link#">more...</a>
                </cfif>
                <cfloop index="imageURL" array="#post.images#">
                    <cfif structKeyExists(post, 'link')>
                        <a class="sw_image" href="#post.link#"><img alt="Social Media Image" src="#imageURL#"></a>
                    <cfelse>
                        <img alt="Social Media Image" class="sw_image" src="#imageURL#">
                    </cfif>
                </cfloop>
            </div>
        </cfloop>
    </div>
    <cfset pluginsPath = $.siteConfig().getPluginsPath()>
    <cfset pluginDir = variables.settings.package>
    <script>
        var maxPosts = #maxPosts#;
        Mura(function(m) {
            m.loader()
            .loadcss('#pluginsPath#/#pluginDir#/assets/css/social_wall.css')
            .loadjs('#pluginsPath#/#pluginDir#/assets/js/social_wall.js');
        });
    </script>
</cffunction>
