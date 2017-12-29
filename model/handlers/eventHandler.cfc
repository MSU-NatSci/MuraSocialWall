
component accessors=true extends='mura.plugin.pluginGenericEventHandler' output=false {

    include '../../plugin/settings.cfm';

    /**
     * This registers the model/beans directory on application load.
     */
    public any function onApplicationLoad(required struct m) {
        variables.pluginConfig.addEventHandler(this);
        arguments.m.globalConfig().registerBeanDir('/#variables.settings.package#/model/beans/');
    }

}
