component extends="farcry.core.packages.forms.forms" displayname="Auth0 User Directory" hint="Settings for the Auth0 plugin" key="auth0" {

	property name="domain" type="string" required="false"
		ftSeq="1" ftWizardStep="" ftFieldset="Configuration" ftLabel="Domain";

	property name="identifier" type="string" required="false"
		ftSeq="2" ftWizardStep="" ftFieldset="Configuration" ftLabel="Identifier (Audience)";

	property name="clientID" type="string" required="false"
		ftSeq="3" ftWizardStep="" ftFieldset="Configuration" ftLabel="Client ID";

	property name="clientSecret" type="string" required="false"
		ftSeq="4" ftWizardStep="" ftFieldset="Configuration" ftLabel="Client Secret";

	property name="connection" type="string" required="false"
		ftSeq="5" ftWizardStep="" ftFieldset="Configuration" ftLabel="Connection";

}