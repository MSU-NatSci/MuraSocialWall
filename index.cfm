<cfscript>
    import model.socialwallconfig;

    siteid = $.siteConfig('siteId');
    message = {};
    action($);

    if (isDefined('message.type')) {
        twitterOAuthConsumerKey = form.twitterOAuthConsumerKey;
        twitterOAuthConsumerSecret = form.twitterOAuthConsumerSecret;
        twitterScreenName = form.twitterScreenName;
        facebookAppID = form.facebookAppID;
        facebookAppSecret = form.facebookAppSecret;
        facebookUserId = form.facebookUserId;
        instagramAccessToken = form.instagramAccessToken;
        options = form.options;
        cacheTime = form.cacheTime;
    } else {
        config = $.getBean('socialwallconfig').loadBy(siteId=siteid);
        twitterOAuthConsumerKey = config.get('twitterOAuthConsumerKey');
        twitterOAuthConsumerSecret = config.get('twitterOAuthConsumerSecret');
        twitterScreenName = config.get('twitterScreenName');
        facebookAppID = config.get('facebookAppID');
        facebookAppSecret = config.get('facebookAppSecret');
        facebookUserId = config.get('facebookUserId');
        instagramAccessToken = config.get('instagramAccessToken');
        options = config.get('options');
        if (options == '')
            options = 'Twitter:twitter|Facebook:facebook|Instagram:instagram|All:twitter,facebook,instagram';
        cacheTime = config.get('cacheTime');
        if (cacheTime == '')
            cacheTime = 10;
    }

    function action($) {
        var action = $.event('action');
        if (action == 'save_config') {
            message = saveConfig($);
        }
    }

    function saveConfig($) {
        var message = {};
        if ($.validateCSRFTokens(context='sw_config')) {
            try {
                var config = $.getBean('socialwallconfig').loadBy(siteId=siteid);
                var newConfig = config.getIsNew();
                config.set('siteId', siteid);
                config.set('twitterOAuthConsumerKey', form.twitterOAuthConsumerKey);
                config.set('twitterOAuthConsumerSecret', form.twitterOAuthConsumerSecret);
                config.set('twitterScreenName', form.twitterScreenName);
                config.set('facebookAppID', form.facebookAppID);
                config.set('facebookAppSecret', form.facebookAppSecret);
                config.set('facebookUserId', form.facebookUserId);
                config.set('instagramAccessToken', form.instagramAccessToken);
                config.set('options', form.options);
                var cacheTime = form.cacheTime;
                if (!(isSimpleValue(cacheTime) && cacheTime.reFind('^[0-9]{1,5}$') == 1)) {
					message = {
						type = 'error',
						content = "The cache time must be an integer."
					};
                    return message;
                }
                config.set('cacheTime', cacheTime);
                
                var result = config.save();

                var errors = result.get('errors');
				if (isDefined('errors') && structCount(errors)) {
					var messageContent = '<ul>';
					for (var errorKey in errors)
						messageContent &= '<li>#errors[errorKey]#</li>';
					messageContent &= '</ul>';
					message = {
						type = 'error',
						content = messageContent
					};
				} else {
                    message = {
                        type = 'success',
                        content = (newConfig ? "Created" : "Updated") & " config."
                    };
                }
            } catch (any e) {
                message = {
                    type = 'error',
                    content = e.message
                };
            }
        } else {
            message = {
                type = 'error',
                content = "Unable to save due to invalid CSRF token."
            };
        }
        return message;
    }
    
</cfscript>

<cfsavecontent variable="body"><cfoutput>
    <cfif isDefined('message.type')>
        <div class="alert alert-#message.type#" role="alert">
            <div>
                <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
                <strong>#message.content#</strong>
            </div>
        </div>
    </cfif>
    <div class="mura-header">
        <h1>#HTMLEditFormat(pluginConfig.getName())#</h1>
    </div>
    <div class="block block-bordered">
        <div class="block-content">
            <form name="config" action=".?action=save_config" method="POST">
                <div class="mura-control-group">
                    <label>Twitter OAuth Consumer Key</label>
                    <input type="text" name="twitterOAuthConsumerKey" value="#twitterOAuthConsumerKey#">
                </div>
                <div class="mura-control-group">
                    <label>Twitter OAuth Consumer Secret</label>
                    <input type="text" name="twitterOAuthConsumerSecret" value="#twitterOAuthConsumerSecret#">
                </div>
                <div class="mura-control-group">
                    <label>Twitter Screen Name</label>
                    <input type="text" name="twitterScreenName" value="#twitterScreenName#">
                </div>
                <div class="mura-control-group">
                    <label>Facebook App ID</label>
                    <input type="text" name="facebookAppID" value="#facebookAppID#">
                </div>
                <div class="mura-control-group">
                    <label>Facebook App Secret</label>
                    <input type="text" name="facebookAppSecret" value="#facebookAppSecret#">
                </div>
                <div class="mura-control-group">
                    <label>Facebook User Id</label>
                    <input type="text" name="facebookUserId" value="#facebookUserId#">
                </div>
                <div class="mura-control-group">
                    <label>Instagram Acess Token</label>
                    <input type="text" name="instagramAccessToken" value="#instagramAccessToken#">
                </div>
                <div class="mura-control-group">
                    <label>Options</label>
                    <input type="text" name="options" value="#options#" maxlength="255">
                </div>
                <div class="mura-control-group">
                    <label>Cache time (in minutes)</label>
                    <input type="text" name="cacheTime" value="#cacheTime#">
                </div>
                #$.renderCSRFTokens(format='form', context='sw_config')#
                <div class="mura-actions">
                    <div class="form-actions">
                        <button type="submit" class="btn mura-primary"><i class="mi-check-circle"></i>Update</button>
                    </div>
                </div>
            </form>
        </div>
    </div>
</cfoutput></cfsavecontent>
<cfoutput>
    #$.getBean('pluginManager').renderAdminTemplate(body=body, pageTitle=pluginConfig.getName())#    
</cfoutput>
