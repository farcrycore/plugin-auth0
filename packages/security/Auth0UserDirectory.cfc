component displayname="Auth0 User Directory" extends="farcry.core.packages.security.UserDirectory" output="false" key="AUTH0" {

	public any function getLoginForm() {
        
        return "a0Login";
    }

	public struct function authenticate() {
		var oUser = application.fapi.getContentType("a0User");
        var stResult = {};

		if (structkeyexists(url,"error")) {

			return {
                "userid" = "",
                "authenticated" = false,
                "message" = url.error
            };
        }

        if (not structkeyexists(url, "type") or url.type neq "a0Login" or not structkeyexists(url,"code")) {

            return {};
        }

        try {
            var stTokens = application.fc.lib.auth0.exchangeAuthorizationCode(code=url.code, redirectURL=getRedirectURL());

            cfparam(name="session.security.auth0", default=structnew());
            session.security.auth0[hash(stTokens.user_info.sub)] = stTokens;

            stResult.authenticated = "false";
            stResult.userid = stTokens.user_info.sub;
            stResult.ud = "Auth0";

            if (not stTokens.profile_info.email_verified) {
				// User is locked out due to not being verified
				stResult.message = "Your account email address has not been verified";
                return stResult;
			}

            // If there isn't a a0User record, create one
            var stUser = oUser.getByUserID(stTokens.user_info.sub);
            if (structisempty(stUser)) {
                stUser = oUser.getData(createuuid());
                stUser.userid = stTokens.user_info.sub;
                if (structkeyexists(stTokens,"refresh_token")) {
                    stUser.refreshToken = stTokens.refresh_token;
                }
                oUser.setData(stProperties=stUser);
            }
            else {
                session.security.auth0[hash(stTokens.user_info.sub)].refresh_token = stUser.refreshToken;
            }

            stResult.authenticated = "true";
        } catch (err) {
            application.fc.lib.error.logData(application.fc.lib.error.normalizeError(cfcatch));
            stResult.authenticated = "false";
            stResult.userid = "";
            stResult.message = "Error while logging into Auth0: #err.message#";
        }

		return stResult;
    }

	public string function getAuthorisationURL(string email="", required string redirectURL) {
		
		return application.fc.lib.auth0.getLoginURL(argumentCollection=arguments);
	}
	
	public array function getUserGroups(required string userID) {
        var aGroups = application.fc.lib.auth0.getUserGroups(arguments.userID);

        var aResult = [];
        for (var i=1; i<=arrayLen(aGroups); i++) {
            arrayAppend(aResult, aGroups[i].name);
        }

        return aResult;
    }

    public array function getAllGroups() {
        var aGroups = application.fc.lib.auth0.getGroups();

        var aResult = [];
        for (var i=1; i<=arrayLen(aGroups); i++) {
            arrayAppend(aResult, aGroups[i].name);
        }

        return aResult;
    }

    public array function getGroupUsers(required string group) {
        var aGroups = application.fc.lib.auth0.getGroups(arguments.group);
        if (arrayLen(aGroups) eq 0) return [];

        var aUsers = application.fc.lib.auth0.getGroupUsers(aGroups[1].id);

        var aResult = [];
        for (var i=1; i<=arrayLen(aUsers); i++) {
            arrayAppend(aResult, aUsers[i].id);
        }

        return aResult;
    }

    public struct function getProfile(required string userID, struct currentProfile) {
        var stProfile = {};
        var userIDHash = hash(arguments.userID);

        var stData = application.fc.lib.auth0.getUser(arguments.userID);

        if (isDefined("session.security.auth0.#userIDHash#") and not isDefined("session.security.auth0.#userIDHash#.profile")) {
            session.security.auth0[userIDHash].profile = stData;
        }

        return {
            "firstname" = structKeyExists(stData, "given_name") ? stData.given_name : "",
            "lastname" = structKeyExists(stData, "family_name") ? stData.family_name : "",
            "emailaddress" = stData.email,
            "label" = stData.name,
            "avatar" = stData.picture,
            "override" = true
        };
    }

	public boolean function isEnabled() {

		return len(application.fapi.getConfig('auth0', 'domain', ''))
            and len(application.fapi.getConfig('auth0', 'clientID', ''))
            and len(application.fapi.getConfig('auth0', 'clientSecret', ''))
            and len(application.fapi.getConfig('auth0', 'connection', ''));
	}

	public string function getRedirectURL() {

		return "#application.fc.lib.seo.getCanonicalProtocol()#://#cgi.http_host##application.url.webroot#/index.cfm?type=a0Login&view=displayLogin";
	}

}