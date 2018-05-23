<cfparam name="objectParams.maxPosts" default="50" />

<cf_objectconfigurator> <!--- cf_objectconfigurator adds default inputs --->
    <cfoutput>
        <div class="mura-control-group">
            <label>Maximum number of posts</label>
            <select class="objectParam" name="maxPosts">
                <cfloop index="i" from="1" to="10">
                    <cfset nb = i*5>
                    <option value="#nb#"<cfif objectParams.maxPosts is '#nb#'> selected</cfif>>#nb#</option>
                </cfloop>
            </select>
        </div>
    </cfoutput>
</cf_objectconfigurator>
