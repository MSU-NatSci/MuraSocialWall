<cfscript>
	include '../../plugin/settings.cfm';

    // Each social media app has a limit on the number of queries, so caching is very important here.
    // 10 minutes harcoded here (this could be a configuration parameter).
    cf_CacheOMatic(timespan=createTimeSpan(0,0,10,0)) {
        res = getPosts($);
        template($, res.smedia, res.posts);
    }

    public struct function getPosts($) {
        var siteid = $.siteConfig('siteId');
        var config = $.getBean('socialwallconfig').loadBy(siteId=siteid);
        var twitterOAuthConsumerKey = config.get('twitterOAuthConsumerKey');
        var twitterOAuthConsumerSecret = config.get('twitterOAuthConsumerSecret');
        var twitterScreenName = config.get('twitterScreenName');
        var facebookAppID = config.get('facebookAppID');
        var facebookAppSecret = config.get('facebookAppSecret');
        var facebookUserId = config.get('facebookUserId');
        var instagramAccessToken = config.get('instagramAccessToken');
        
        var smedia = [];
        var posts = [];
        
        if (twitterOAuthConsumerKey != '' && twitterOAuthConsumerSecret != '' && twitterScreenName != '') {
            smedia.append('twitter');
            posts.append(getTwitterPosts(twitterOAuthConsumerKey, twitterOAuthConsumerSecret, twitterScreenName), true);
        }
        
        if (facebookAppID != '' && facebookAppSecret != '' && facebookUserId != '') {
            smedia.append('facebook');
            posts.append(getFacebookPosts(facebookAppID, facebookAppSecret, facebookUserId), true);
        }

        if (instagramAccessToken != '') {
            smedia.append('instagram');
            posts.append(getInstagramPosts(instagramAccessToken), true);
        }

        // sort by date
        posts.sort(function(p1, p2) {
            return -compare(p1.date, p2.date);
        });

        return {
            smedia: smedia,
            posts: posts
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
            writeLog("api.twitter.com: #result.statusCode#");
            writeLog(result.errorDetail);
        }
        if (accessToken != '') {
            httpService = new http(method="GET", charset="UTF-8",
                url="https://api.twitter.com/1.1/statuses/user_timeline.json");
            httpService.addParam(type="header", name="Authorization", value='Bearer ' & accessToken);
            httpService.addParam(type="formfield", name="screen_name", value=twitterScreenName);
            httpService.addParam(type="formfield", name="tweet_mode", value="extended");
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
                writeLog("api.twitter.com: #result.statusCode#");
                writeLog(result.errorDetail);
            }
        }
        return posts;
    }

    public array function getFacebookPosts(facebookAppID, facebookAppSecret, facebookUserId) {
        // see https://developers.facebook.com/docs/graph-api/
        var posts = [];
        var httpService = new http(method="GET", charset="UTF-8",
            url="https://graph.facebook.com/#facebookUserId#/posts");
        httpService.addParam(type="formfield", name="limit", value="20");
        httpService.addParam(type="formfield", name="fields", value="message,created_time,full_picture,link");
        httpService.addParam(type="formfield", name="access_token", value="#facebookAppID#|#facebookAppSecret#");
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
                    var message = fbpost.message;
                    message = message.reReplace('##(\w+)', '<a href="https://www.facebook.com/hashtag/\1">##\1</a>', 'all');
                    message = message.reReplace('([^"])(https?://[\w.\-]+/[\w+/\-%?=+]+)',
                        '\1<a href="\2">\2</a>', 'all');
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
            writeLog("graph.facebook.com: #result.statusCode#");
            writeLog(result.errorDetail);
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
        httpService.addParam(type="formfield", name="access_token", value=instagramAccessToken);
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
                    var message = ipost.caption.text;
                    message = message.reReplace('##(\w+)',
                        '<a href="https://www.instagram.com/explore/tags/\1">##\1</a>', 'all');
                    post.images = [ipost.images.standard_resolution.url];
                    post.link = ipost.link;
                    post.content = message;
                    posts.append(post);
                }
            }
        } else {
            writeLog("api.instagram.com: #result.statusCode#");
            writeLog(result.errorDetail);
        }
        return posts;
    }
</cfscript>

<cffunction name="template" output="true">
    <cfargument name="$" type="struct" required="yes">
    <cfargument name="smedia" type="array" required="yes">
    <cfargument name="posts" type="array" required="yes">
    <cfif smedia.len() eq 0>
        <p>The Social Media Wall plugin has not been configured yet.</p>
    </cfif>
    <cfif smedia.len() gte 2>
        <div class="sw_selector_container">
            <p><label for="sw_selector">Display posts from</label> <select id="sw_selector">
                <cfset first = smedia[1]>
                <cfloop index="sm" array="#smedia#">
                    <option value="#sm#"<cfif sm eq first> selected</cfif>>#sm.mid(1,1).uCase() & sm.mid(2,sm.len()-1)#</option>
                </cfloop>
                <option value="all">All</option>
            </select></p>
        </div>
    </cfif>
    <div class="sw_container">
        <cfloop index="post" array="#posts#">
            <div class="sw_post #post.type#_post">
                <div class="sw_head">
                    <span class="sw_date">#post.date.dateFormat('short')#</span>
                    <span class="sw_type"><span class="fa fa-#post.type#">&nbsp;</span><span class="sr-only">#post.type#</span></span>
                </div>
                #post.content#
                <cfif structKeyExists(post, 'link')>
                    <cfoutput> </cfoutput><a href="#post.link#">more...</a>
                </cfif>
                <cfloop index="imageURL" array="#post.images#">
                    <cfif structKeyExists(post, 'link')>
                        <a href="#post.link#"><img src="#imageURL#"></a>
                    <cfelse>
                        <img src="#imageURL#">
                    </cfif>
                </cfloop>
            </div>
        </cfloop>
    </div>
    <cfset pluginsPath = $.siteConfig().getPluginsPath()>
    <cfset pluginDir = variables.settings.package>
    <script>
        Mura(function(m) {
            m.loader()
            .loadcss('#pluginsPath#/#pluginDir#/assets/css/social_wall.css')
            .loadjs('#pluginsPath#/#pluginDir#/assets/js/social_wall.js');
        });
    </script>
</cffunction>
