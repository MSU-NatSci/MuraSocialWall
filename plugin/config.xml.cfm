
<cfscript>
	include 'settings.cfm';
</cfscript>
<cfoutput>
    <plugin>
        <name>#variables.settings.pluginName#</name>
        <package>#variables.settings.package#</package>
        <directoryFormat>packageOnly</directoryFormat>
        <loadPriority>#variables.settings.loadPriority#</loadPriority>
        <version>#variables.settings.version#</version>
        <provider>#variables.settings.provider#</provider>
        <providerURL>#variables.settings.providerURL#</providerURL>
        <category>#variables.settings.category#</category>
		<eventHandlers>
			<eventHandler event="onApplicationLoad" component="model.handlers.eventHandler" persist="false"/>
		</eventHandlers>
        <mappings />
        <settings />
        <extensions />
    </plugin>
</cfoutput>
