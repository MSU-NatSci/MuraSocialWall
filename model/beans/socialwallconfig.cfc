component
    extends="mura.bean.beanORM"
    table="socialwallconfig"
    entityname="socialwallconfig"
    bundleable="true"
    displayname="Social Wall Config"
    public=false
    orderby="siteId" {

    // primary key
    property name="id" fieldtype="id";

    // attributes
    property name="siteId" datatype="varchar" length="255" required=true
        message="The siteId field is required.";
    property name="twitterOAuthConsumerKey" datatype="varchar" length="255";
    property name="twitterOAuthConsumerSecret" datatype="varchar" length="255";
    property name="twitterScreenName" datatype="varchar" length="255";
    property name="facebookAppID" datatype="varchar" length="255";
    property name="facebookAppSecret" datatype="varchar" length="255";
    property name="facebookUserId" datatype="varchar" length="255";
    property name="instagramAccessToken" datatype="varchar" length="255";

}
