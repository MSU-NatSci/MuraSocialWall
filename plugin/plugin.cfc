
component accessors=true extends='mura.plugin.plugincfc' output=false {

	// pluginConfig is automatically available as variables.pluginConfig
	include 'settings.cfm';

/*
	public void function install() {
		// Do custom installation stuff
	}

	public void function update() {
		// Do custom update stuff
	}
*/

	public void function delete() {
		// delete the config table if the plugin is uninstalled
		getBean('dbUtility').dropTable(table=getBean('socialwallconfig').getTable());
	}

	// access to the pluginConfig should available via variables.pluginConfig
	public any function getPluginConfig() {
		return StructKeyExists(variables, 'pluginConfig') ? variables.pluginConfig : {};
	}

}
