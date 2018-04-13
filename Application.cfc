
component accessors=true output=false {

    property name='$';

    include 'plugin/settings.cfm';

    local.pluginPath = GetDirectoryFromPath(GetCurrentTemplatePath());
    local.muraroot = Left(local.pluginPath, Find('plugins', local.pluginPath) - 1);
    local.depth = ListLen(RemoveChars(local.pluginPath, 1, Len(local.muraroot)), '\/');  
    local.includeroot = RepeatString('../', local.depth);

    if (DirectoryExists(local.muraroot & 'core')) {
        // Using 7.1
        this.muraAppConfigPath = local.includeroot & 'core/';
        include this.muraAppConfigPath & 'appcfc/applicationSettings.cfm';
    } else {
        // Pre 7.1
        this.muraAppConfigPath = local.includeroot & 'config/';
        include local.includeroot & 'config/applicationSettings.cfm';
        include local.includeroot & 'config/mappings.cfm';
        include local.includeroot & 'plugins/mappings.cfm';
    }


    public any function onApplicationStart() {
        include this.muraAppConfigPath & 'appcfc/onApplicationStart_include.cfm';
        return true;
    }

    public any function onRequestStart(required string targetPage) {
        include this.muraAppConfigPath & 'appcfc/onRequestStart_include.cfm';

        if (
            (
                StructKeyExists(variables.settings, 'reloadApplicationOnEveryRequest')
                && variables.settings.reloadApplicationOnEveryRequest
            )
            || !StructKeyExists(application, 'appInitializedTime')
        ) {
            onApplicationStart();
        }

        if ( isSessionExpired() ) {
            lock scope='session' type='exclusive' timeout=10 {
                setupSession();
            }
        }

        // You may want to change the methods being used to secure the request
        secureRequest();
        return true;
    }

    public void function onRequest(required string targetPage) {
        var $ = get$();
        var pluginConfig = $.getPlugin(variables.settings.pluginName);
        include arguments.targetPage;
    }

    public void function onSessionStart() {
        include this.muraAppConfigPath & 'appcfc/onSessionStart_include.cfm';
        setupSession();
    }

    public void function onSessionEnd() {
        include this.muraAppConfigPath & 'appcfc/onSessionEnd_include.cfm';
    }


    // ----------------------------------------------------------------------
    // HELPERS

    private struct function get$() {
        if ( !StructKeyExists(arguments, '$') ) {
            var siteid = StructKeyExists(session, 'siteid') ? session.siteid : 'default';

            arguments.$ = StructKeyExists(request, 'murascope')
                ? request.murascope
                : StructKeyExists(application, 'serviceFactory')
                    ? application.serviceFactory.getBean('$').init(siteid)
                    : {};
        }

        return arguments.$;
    }

    public any function secureRequest() {
        var $ = get$();
        return !inPluginDirectory() || $.currentUser().isSuperUser()
            ? true
            : ( inPluginDirectory() && !StructKeyExists(session, 'siteid') )
                || ( inPluginDirectory() && !$.getBean('permUtility').getModulePerm($.getPlugin(variables.settings.pluginName).getModuleID(),session.siteid) )
                ? goToLogin()
                : true;
    }

    public boolean function inPluginDirectory() {
        var uri = getPageContext().getRequest().getRequestURI();
        return ListFindNoCase(uri, 'plugins', '/') && ListFindNoCase(uri, variables.settings.package,'/');
    }

    private void function goToLogin() {
        var $ = get$();
        location(url='#$.globalConfig('context')#/admin/index.cfm?muraAction=clogin.main&returnURL=#$.globalConfig('context')#/plugins/#$.getPlugin(variables.settings.pluginName).getPackage()#/', addtoken=false);
    }

    private boolean function isSessionExpired() {
        var p = variables.settings.package;
        return !StructKeyExists(session, p)
                || DateCompare(now(), session[p].expires, 's') == 1
                || DateCompare(application.appInitializedTime, session[p].created, 's') == 1;
    }

    private void function setupSession() {
        var p = variables.settings.package;
        StructDelete(session, p);
        // Expires - s:seconds, n:minutes, h:hours, d:days
        session[p] = {
            created = Now()
            , expires = DateAdd('d', 1, Now())
            , sessionid = Hash(CreateUUID())
        };
    }

}
