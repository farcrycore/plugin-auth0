component {

    public any function init() {
		this.scope = "read:users read:users_app_metadata update:users update:users_app_metadata delete:users create:users create:users_app_metadata read:roles create:role_members read:role_members delete:role_members";
		this.state = "";
		this.persist_id_token = true;
		this.persist_access_token = false;
		this.persist_refresh_token = false;

        this.importJobs = [];
        this.groupIDs = [];

        return this;
    }
    public string function getMfaEnrollURL(string email="", required string redirectURL) {
        var domain = application.fapi.getConfig("auth0", "domain");
        var clientID = application.fapi.getConfig("auth0", "clientID");
        var identifier = application.fapi.getConfig("auth0", "identifier");

        var mfaEnrollURL = "https://#domain#/authorize"
            & "?audience=#identifier#"
            & "&scope=openid%20user_id%20profile%20offline_access"
            & "&response_type=code"
            & "&client_id=#clientID#"
            & "&state=#this.state#"
            & "&redirect_uri=#encodeForURL(arguments.redirectURL)#"
            & "&acr_values=http://schemas.openid.net/pape/policies/2007/06/multi-factor";

        return mfaEnrollURL;
    }

    public string function getLoginURL(string email="", required string redirectURL, string stateValue) {
        var domain = application.fapi.getConfig("auth0", "domain");
        var clientID = application.fapi.getConfig("auth0", "clientID");
        var identifier = application.fapi.getConfig("auth0", "identifier");

        var loginURL = "https://#domain#/authorize"
            & "?audience=#identifier#"
            & "&scope=openid%20user_id%20profile%20offline_access"
            & "&response_type=code"
            & "&client_id=#clientID#"
            & "&redirect_uri=#encodeForURL(arguments.redirectURL)#"
            & "&state=#encodeForURL(arguments.stateValue)#";

        if (len(arguments.email)) {
            loginURL = loginURL & "&login_hint=#encodeForURL(arguments.email)#";
        }

        return loginURL;
    }

    public string function getLogoutURL(string returnTo=application.fapi.getLink(alias="home", includeDomain=true)) {
        var domain = application.fapi.getConfig("auth0", "domain");
        var clientID = application.fapi.getConfig("auth0", "clientID");
        var identifier = application.fapi.getConfig("auth0", "identifier");
        var scope = "openid profile";

        var logoutURL = "https://#domain#/v2/logout"
            & "?audience=#identifier#"
            & "&scope=#encodeForURL(scope)#"
            & "&client_id=#clientID#"
            & "&returnTo=#encodeForURL(returnTo)#";

        return logoutURL
    }

    public struct function exchangeAuthorizationCode(required string code, required string redirectURL) {
        var clientID = application.fapi.getConfig("auth0", "clientID");
        var clientSecret = application.fapi.getConfig("auth0", "clientSecret");

        var stAuth = makeRequest(
            method = "POST",
            endpoint = "/oauth/token",
            form = {
                "grant_type"    : "authorization_code",
                "client_id"     : clientID,
                "client_secret" : clientSecret,
                "code"          : arguments.code,
                "redirect_uri"  : arguments.redirectURL
            }
        );

        stAuth["user_info"] = makeRequest(
            method = "GET",
            endpoint = "/userinfo",
            token = stAuth.access_token
        )

        stAuth["profile_info"] = getUser(stAuth.user_info.sub);

        return stAuth;
    }

    public struct function exchangeUserPassword(required string username, required string password) {
        var clientID = application.fapi.getConfig("auth0", "clientID");
        var clientSecret = application.fapi.getConfig("auth0", "clientSecret");

        var stAuth = makeRequest(
            method = "POST",
            endpoint = "/oauth/token",
            form = {
                "grant_type"    : "password",
                "client_id"     : clientID,
                "client_secret" : clientSecret,
                "username"      : arguments.username,
                "password"      : arguments.password,
                "audience"      : "",
                "scope"         : "openid user_id profile"
            }
        );

        stAuth["user_info"] = makeRequest(
            method = "GET",
            endpoint = "/userinfo",
            token = stAuth.access_token
        )

        stAuth["profile_info"] = getUser(stAuth.user_info.sub);

        return stAuth;
    }

    // Wrong email or password.
    // Multifactor authentication required
    // Success
    public boolean function testUserPassword(required string username, required string password, string successResults="Success,Multifactor authentication required") {
        var clientID = application.fapi.getConfig("auth0", "clientID");
        var clientSecret = application.fapi.getConfig("auth0", "clientSecret");

        var stAuth = makeRequest(
            method = "POST",
            endpoint = "/oauth/token",
            form = {
                "grant_type"    : "password",
                "client_id"     : clientID,
                "client_secret" : clientSecret,
                "username"      : arguments.username,
                "password"      : arguments.password,
                "audience"      : "",
                "scope"         : "openid user_id profile"
            },
            returnResponse = true
        );
        
        var stData = deserializeJSON(stAuth.filecontent);
        var message = "Success";

        if (isDefined("stData.error_description")) {
            message = stData.error_description;
        }

        return listFindNoCase(arguments.successResults, message) gt 0;
    }

    public string function getAuthToken() {
        if (structKeyExists(request, "auth0Token") and now() gte request.auth0Token.expires) {
            structDelete(request, "auth0Token");
        }
        if (not structKeyExists(request, "auth0Token")) {
            var domain = application.fapi.getConfig("auth0", "domain");
            var clientID = application.fapi.getConfig("auth0", "clientID");
            var clientSecret = application.fapi.getConfig("auth0", "clientSecret");
            var identifier = application.fapi.getConfig("auth0", "identifier");
            var stResult = makeRequest(
                method = "POST",
                endpoint = "/oauth/token",
                body = {
                    "grant_type" = "client_credentials",
                    "client_id" = clientID,
                    "client_secret" = clientSecret,
                    "audience" = identifier
                }
            );

            stResult.expires = dateAdd("s", stResult.expires_in, now());
            request.auth0Token = stResult;
        }

        return request.auth0Token.access_token;
    }

    public string function getPasswordChangeLink(required string email) {
        var token = getAuthToken();
        var connection = application.fapi.getConfig("auth0", "connection");
        var stConnection = getConnection(connection);
        var body = {
            "email": arguments.email,
            "connection_id": stConnection.id
        };
    
        var result = makeRequest(
            method = "POST",
            endpoint = "/api/v2/tickets/password-change",
            body=body,
            token = token
        );
        return result.ticket;
    }

    public array function getUserByEmail(required string email) {
        var token = getAuthToken();
        
        var result = makeRequest(
            method = "GET",
            endpoint = "/api/v2/users-by-email?email=#arguments.email#",
            token = token
        );

        return result;
    }

    public any function listMFA(required string email) {
        var token = getAuthToken();
        var auth0user = getUserByEmail(arguments.email)
        var result = {};
        if (ArrayLen(auth0user) > 0) {
            var userId = auth0user[1].user_id;
            try {
            result = makeRequest(
                method = "GET",
                endpoint = "/api/v2/users/#userID#/authentication-methods",
                token = token
            );
            } catch (any e) {

            }
        }else {
            // If the user does not exist in Auth0
            return { "error": true, "message": "noUser" };
        }
        return result;
    }

    public any function deleteMFA(required string mfaId) {
        var token = getAuthToken();
        
        var result = makeRequest(
            method = "DELETE",
            endpoint = "/api/v2/guardian/enrollments/#arguments.mfaId#",
            token = token
        );
        return; 
    }

    public struct function getUser(required string userID) {
        var token = getAuthToken();

        var result = makeRequest(
            method = "GET",
            endpoint = "/api/v2/users/#arguments.userID#",
            token = token
        );

        return result;
    }

    public struct function createUser(required string email, required string password, string objectid, string username, string phoneNumber, boolean emailVerified, boolean verifyEmail, struct userMetadata={}, struct appMetadata={}) {
        var token = getAuthToken();
        var connection = application.fapi.getConfig("auth0", "connection");
        var connectionName= makeRequest(
            method="GET",
            endpoint="/api/v2/connections/"&connection,
            token = token
        );
        var user_id = (len(arguments.objectid) ? Replace(arguments.objectid, "-", "", "all") : arguments.email);
        var body = {
            "user_id" = user_id,
            "connection" = connectionName.name,
            "email" = arguments.email,
            "password" = arguments.password,
        };

        if (structKeyExists(arguments, "username")) body["username"] = arguments.username;
        if (structKeyExists(arguments, "phoneNumber")) body["phone_number"] = arguments.phoneNumber;
        if (structKeyExists(arguments, "userMetadata")) body["user_metadata"] = arguments.userMetadata;
        if (structKeyExists(arguments, "emailVerified")) body["email_verified"] = arguments.emailVerified;
        if (structKeyExists(arguments, "verifyEmail")) body["verify_email"] = arguments.verifyEmail;
        if (structKeyExists(arguments, "appMetadata")) body["app_metadata"] = arguments.appMetadata;

        var result = makeRequest(
            method="POST",
            endpoint="/api/v2/users",
            body=body,
            token=token
        );

        return result;
    }

    public struct function updateUser(required string userID, boolean blocked, boolean emailVerified, string email, boolean verifyEmail, string phoneNumber, boolean phoneVerified, boolean verifyPhoneNumber, string password, string verifyPassword, struct userMetadata, struct appMetadata, string name) {
        var token = getAuthToken();
        var clientID = application.fapi.getConfig("auth0", "clientID");
        var connection = application.fapi.getConfig("auth0", "connection");
        var connectionName= makeRequest(
            method="GET",
            endpoint="/api/v2/connections/"&connection,
            token = token
        );
        var body = {
            "connection" = connectionName.name,
            "client_id" = clientID
        };

        // optional parameters
        if (structKeyExists(arguments, "blocked")) body["blocked"] = arguments.blocked;
        if (structKeyExists(arguments, "emailVerified")) body["email_verified"] = arguments.emailVerified;
        if (structKeyExists(arguments, "email")) body["email"] = arguments.email;
        if (structKeyExists(arguments, "verifyEmail")) body["verify_email"] = arguments.verifyEmail;
        if (structKeyExists(arguments, "phoneNumber")) body["phone_number"] = arguments.phoneNumber;
        if (structKeyExists(arguments, "phoneVerified")) body["phone_verified"] = arguments.phoneVerified;
        if (structKeyExists(arguments, "verifyPhoneNumber")) body["verify_phone_number"] = arguments.verifyPhoneNumber;
        if (structKeyExists(arguments, "password")) body["password"] = arguments.password;
        if (structKeyExists(arguments, "verifyPassword")) body["verify_password"] = arguments.verifyPassword;
        if (structKeyExists(arguments, "userMetadata")) body["user_metadata"] = arguments.userMetadata;
        if (structKeyExists(arguments, "appMetadata")) body["app_metadata"] = arguments.appMetadata;
        if (structKeyExists(arguments, "name")) body["name"] = arguments.name;
        try {
            var result = makeRequest(
                method = "PATCH",
                endpoint = "/api/v2/users/#arguments.userID#",
                body = body,
                token = token
            );
        } catch (any e) {
            return deserializeJSON(e.Detail);
        }

        return result;
    }

    public struct function getConnection(required string connection) {
        var token = getAuthToken();

        var result = reFind("^con_", arguments.connection)
            ? makeRequest(
                method = "GET",
                endpoint = "/api/v2/connections/#arguments.connection#",
                token = token
            )
            : makeRequest(
                method = "GET",
                endpoint = "/api/v2/connections",
                parameters = {
                    "name" = arguments.connection
                },
                token = token
            )[1];

        return result;
    }

    /* import query with email, user_id, and password_hash; the following fields are also set if present: email,email_verified,given_name,family_name,name,nickname,picture,blocked */
    public array function createImportUsersArray(required query qUsers) {
        var data = [];
        var item = {};
        for (var row in arguments.qUsers) {
            item = {
                "email" = row.email,
                "email_verified" = true,
                "user_id" = row.user_id,
                "custom_password_hash": {
                    "algorithm": "bcrypt",
                    "hash": {
                        "value": row.password_hash
                    }
                }
            };

            for (var col in arguments.qUsers.columnList) {
                if (listFindNoCase("email,email_verified,given_name,family_name,name,nickname,picture,blocked", col)) {
                    item[col] = row[col];
                }
            }

            arrayAppend(data, item);
        }

        return data;
    }

    /* see createImportUsersArray for expected format of query */
    public struct function importUsers(required query qUsers, boolean sendCompletion=true, waitForCompletion=false) {
        var data = createImportUsersArray(arguments.qUsers);

        var timestamp = getTickCount();
        var tmpFile = getTempDirectory() & timestamp & ".json";
        fileWrite(tmpFile, serializeJSON(data));

        var connection = application.fapi.getConfig("auth0", "connection");
        var stConnection = getConnection(connection);

        var token = getAuthToken();
        var stResult = makeRequest(
            method = "POST",
            endpoint = "/api/v2/jobs/users-imports",
            form = {
                "users" = { type="file", file=tmpFile, mimetype="application/json" },
                "connection_id" = stConnection.id,
                "upsert" = true,
                "external_id" = timestamp,
                "send_completion_email" = false
            },
            token = token
        )

        fileDelete(tmpFile);

        stResult = getJobStatus(stResult.id);

        arrayAppend(this.importJobs, stResult);

        if (arguments.waitForCompletion) {
            cfsetting(requestTimeout=50000);
            while (stResult.status eq "pending") {
                sleep(10000);
                stResult = getJobStatus(stResult.id);
            }
        }

        return stResult;
    }

    public struct function deleteAuth0Users() {
        var token = getAuthToken();
        var result = [];
        var deleteResult;
        var userId;
        var successCount = 0;
        var errors = [];
        var continueLoop = true;
    
        while (continueLoop) {
            result = makeRequest(
                method = "GET",
                endpoint = "/api/v2/users?fields=user_id",
                token = token
            );
    
            if (arrayLen(result)) {
                cfsetting(requestTimeout=50000);
                for (var user in result) {
                    try {
                        userId = user.user_id; 
                        deleteResult = makeRequest(
                            method = "DELETE",
                            endpoint = "/api/v2/users/" & userId,
                            token = token
                        );
                        successCount++;
                        sleep(500);
                    } catch (any e) {
                        application.fc.lib.error.logData(application.fc.lib.error.normalizeError(e));
                    }
                }
            } else {
                continueLoop = false;
            }
        }
    
        return {
            "successCount": successCount,
            "errors": errors
        };
    }
    
    
    public struct function deleteBadAuth0Users() {
        var token = getAuthToken();
        var qBadAuth0Users = [];
        var deleteResult;
        var userId;
        var successCount = 0;
        var errors = [];
    
        var qBadAuth0Users = queryExecute("
            SELECT u.userid, p.emailAddress
            FROM dmProfile_backup p 
            INNER JOIN bad_profiles b ON p.objectid = b.objectid
            INNER JOIN a0user u ON p.emailAddress = u.email
            WHERE NOT EXISTS (
                SELECT 1 FROM dmProfile d
                WHERE d.emailAddress = p.emailAddress
            );
        ",  { }, { datasource=application.dsn });

        if (qBadAuth0Users.recordCount > 0) {
            cfsetting(requestTimeout=50000);
            for (var user in qBadAuth0Users) {
                try {
                    userId = user.userid; 
                    deleteResult = makeRequest(
                        method = "DELETE",
                        endpoint = "/api/v2/users/" & userId,
                        token = token
                    );
                    queryExecute("
                        DELETE FROM a0User
                        WHERE   userid = :userID
                    ", { userID={ type="cf_sql_varchar", value=userId } }, { datasource=application.dsn });
                    successCount++;
                    sleep(500);
                } catch (any e) {
                    application.fc.lib.error.logData(application.fc.lib.error.normalizeError(e));
                }
            }
        } 
    
        return {
            "successCount": successCount,
            "errors": errors
        };
    }
    
      

    public struct function getJobStatus(required string jobID) {
        var token = getAuthToken();

        var result = makeRequest(
            method = "GET",
            endpoint = "/api/v2/jobs/#arguments.jobID#",
            token = token
        );

        result["step"] = "Import users into Auth0";

        if (result.status neq "pending") {
            result["error_details"] = makeRequest(
                method = "GET",
                endpoint = "/api/v2/jobs/#arguments.jobID#/errors",
                token = token
            );
        }

        return result;
    }

    // id, status, type, created_at, percentage_done, time_left_seconds
    public array function getJobStatuses() {
        for (var i=1; i<=arrayLen(this.importJobs);i++) {
            if (this.importJobs[i].status eq "pending") {
                this.importJobs[i] = getJobStatus(this.importJobs[i].id);
            }
        }

        return this.importJobs;
    }

    public void function updateJobStatusStep(required string id, required string step) {
        for (var i=1; i<=arrayLen(this.importJobs);i++) {
            if (this.importJobs[i].id eq arguments.id) {
                this.importJobs[i]["step"] = arguments.step;
            }
        }
    }

    public struct function getUser(required string userID) {
        var token = getAuthToken();
        if (!userID.startsWith("auth0|")) {
            userID = "auth0|" & userID;
        }
        var result = makeRequest(
            method = "GET",
            endpoint = "/api/v2/users/#arguments.userID#",
            token = token
        );

        return result;
    }

    public any function getUsers(numeric page, numeric perPage=100) {
        var token = getAuthToken();

        if (structKeyExists(arguments, "page")) {
            return makeRequest(
                method = "GET",
                endpoint = "/api/v2/users",
                parameters = {
                    "page" = arguments.page,
                    "per_page" = arguments.perPage,
                    "include_totals" = true
                },
                token = token
            );
        }
        else {
            return makeRequest(
                method = "GET",
                endpoint = "/api/v2/users",
                token = token
            );
        }
    }

    public array function getUsersByEmail(required string email) {
        var token = getAuthToken();
        var parameters = {
            "email" = lcase(arguments.email)
        };

        var result = makeRequest(
            method = "GET",
            endpoint = "/api/v2/users-by-email",
            parameters = parameters,
            token = token
        );

        return result;
    }

    public array function getUserGroups(required string userID) {
        var token = getAuthToken();
        if (!arguments.userID.startsWith("auth0|")) {
            arguments.userID = "auth0|" & arguments.userID;
        }
        var result = makeRequest(
            method = "GET",
            endpoint = "/api/v2/users/#arguments.userID#/roles",
            token = token
        )

        return result;
    }

    public array function getGroups(string name, boolean filterExact=false) {
        var token = getAuthToken();
        var parameters = {};

        if (structKeyExists(arguments, "name")) parameters["name_filter"] = arguments.name;

        var result = makeRequest(
            method = "GET",
            endpoint = "/api/v2/roles",
            parameters = parameters,
            token = token
        )

        if (structKeyExists(arguments, "name") and arguments.filterExact and arrayLen(result)) {
            for (var i=arrayLen(result); i>0; i--) {
                if (result[i].name neq arguments.name) {
                    arrayDeleteAt(result, i);
                }
            }
        }

        return result;
    }

    public struct function createGroup(required string name, required string description) {
        var token = getAuthToken();
        var body = {
            "name" = arguments.name,
            "description" = arguments.description
        };

        var result = makeRequest(
            method = "POST",
            endpoint = "/api/v2/roles",
            body = body,
            token = token
        )

        return result;
    }

    public struct function createGroupIfMissing(requried string name, required string description) {
        // create group in auth0 if necessary
        var auth0Group = getGroups(name=arguments.name, filterExact=true);

        if (arrayLen(auth0Group)) {
            return auth0Group[1];
        }

        return createGroup(name=arguments.name, description=arguments.description);
    }

    public array function getGroupUsers(required string groupID) {
        var token = getAuthToken();

        var result = makeRequest(
            method = "GET",
            endpoint = "/api/v2/roles/#arguments.groupID#/users",
            token = token
        )

        return result;
    }

    public array function resolveGroupIDs(required array groupIDs) {
        var result = duplicate(arguments.groupIDs);
        var aGroups = [];

        if (reFindNocase("^rol_\w+(,rol_\w+)+$", arrayToList(groupIDs)) eq 1) {
            var aGroups = getGroups();
            for (var i=1; i<=arrayLen(aGroups); i++) {
                this.groupIDs[aGroups[i].name] = aGroups[i].id;
            }
        }

        for (var i=1; i<=arrayLen(arguments.groupIDs); i++) {
            if (structKeyExists(this.groupIDs, arguments.groupIDs[i])) {
                result[i] = this.groupIDs[arguments.groupIDs[i]];
            }
        }

        return result;
    }

    public void function addUsersToGroup(required string groupID, required array userIDs) {
        var token = getAuthToken();

        var result = makeRequest(
            method = "POST",
            endpoint = "/api/v2/roles/#arguments.groupID#/users",
            body = {
                "users" = arguments.userIDs
            },
            token = token
        )
    }

    public void function addGroupsToUser(required string userID, required array groupIDs) {
        var token = getAuthToken();

        var result = makeRequest(
            method = "POST",
            endpoint = "/api/v2/users/#arguments.userID#/roles",
            body = {
                "roles" = resolveGroupIDs(arguments.groupIDs)
            },
            token = token
        )
    }

    public void function removeUserFromGroups(required string userID, required array groupIDs) {
        var token = getAuthToken();

        var result = makeRequest(
            method = "DELETE",
            endpoint = "/api/v2/users/#arguments.userID#/roles",
            body = {
                "roles" = arguments.groupIDs
            },
            token = token
        )
    }

    public struct function updateUserMetadata(required string userID, required string first_name, required string last_name) {
            var accessToken = getAccessToken();
            var stResult = {};

            cfhttp(method="PATCH", url="https://" & variables.instance.domain & "/api/v2/users/" & encodeForUrl(arguments.userID), result="stResult") {
                    cfhttpparam(type="header", name="Authorization", value="Bearer #accessToken#");
                    cfhttpparam(type="header", name="Content-Type", value="application/json");
                    cfhttpparam(type="body", value='{"user_metadata": {"firstname": "#arguments.first_name#", "lastname": "#arguments.last_name#"}}');
            }

            return stResult;
    }


    public any function makeRequest(required string method, required string endPoint, struct parameters, struct body, struct form, string token, boolean returnResponse=false) {
        var domain = application.fapi.getConfig("auth0", "domain");
        var httpURL = "https://#domain##arguments.endPoint#";

        if (structKeyExists(arguments, "parameters")) {
            var aParameters = [];

            for (var key in arguments.parameters) {
                arrayAppend(aParameters, "#key#=#encodeForURL(arguments.parameters[key])#");
            }

            httpURL = httpURL & "?" & arrayToList(aParameters, "&");
        }

        var stResponse = {};

        cfhttp(method=arguments.method, url=httpUrl, result="stResponse") {
            if (structKeyExists(arguments, "body")) {
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="body", value=serializeJSON(arguments.body));
            }
            if (structKeyExists(arguments, "form")) {
                for (var key in arguments.form) {
                    if (isStruct(arguments.form[key])) {
                        cfhttpparam(name=key, attributeCollection=arguments.form[key]);
                    }
                    else {
                        cfhttpparam(type="form", name=key, value=arguments.form[key]);
                    }
                }
            }

            if (structKeyExists(arguments, "token")) {
	            cfhttpparam(type="header", name="Authorization", value="Bearer #arguments.token#");
			}
        }

        if (arguments.returnResponse) {
            return stResponse;
        }

		if (not listFind("200,201,202,203,204", listFirst(stResponse.statuscode, " "))) {
			application.fapi.throw(
                message="Error accessing Auth0 API: #stResponse.statuscode#",
                detail=serializeJSON({
                    "domain"=domain,
                    "url"=httpUrl,
                    "response"=isJSON(stResponse.filecontent) ? deserializeJSON(stResponse.filecontent) : trim(stResponse.filecontent),
                    "args"=arguments
                })
            );
		}

        return deserializeJSON(stResponse.fileContent);
    }


	public query function getMigratableUsers(string oldGroupID, numeric maxRows=-1) {
        if (not isValid("uuid", arguments.oldGroupID)) {
            var qGroups = queryExecute("
                SELECT  objectid
                FROM    farGroup
                WHERE   title=:groupName
            ", { groupName=arguments.oldGroupID }, { datasource=application.dsn_read });

            arguments.oldGroupID = qGroups.objectid[1];
        }

        if (arguments.oldGroupID neq "" and arguments.oldGroupID neq "-none-") {
            return queryExecute("
                SELECT      p.objectid as profileID, u.objectid as userID, p.emailAddress as email, p.firstName as given_name, p.lastName as family_name, p.label as name, u.userID as user_id, u.password as password_hash, case when u.userstatus = 'pending' then 'false' else 'true' end as email_verified
                FROM        farUser u
                            INNER JOIN dmProfile p ON concat(u.userID, '_CLIENTUD')=p.username
                            INNER JOIN farUser_aGroups ug ON u.objectid=ug.parentid AND ug.data=:groupID
                WHERE 		u.userstatus IN ('active','pending') AND
                            p.emailAddress IS NOT NULL AND
                            p.emailAddress <> ''
                ORDER BY    p.lastLogin DESC
            ", { groupID=arguments.oldGroupID }, { datasource=application.dsn_read, maxRows=arguments.maxRows });
        }
        else {
            return queryExecute("
                SELECT      p.objectid as profileID, u.objectid as userID, p.emailAddress as email, p.firstName as given_name, p.lastName as family_name, p.label as name, u.userID as user_id, u.password as password_hash, case when u.userstatus = 'pending' then 'false' else 'true' end as email_verified
                FROM        farUser u
                            INNER JOIN dmProfile p ON concat(u.userID, '_CLIENTUD')=p.username
                WHERE 		u.userstatus IN ('active','pending') AND
                            (u.lGroups IS NULL OR u.lGroups = '') AND
                            u.userID <> 'root' AND
                            p.emailAddress IS NOT NULL AND
                            p.emailAddress <> ''
                ORDER BY    p.lastLogin DESC
            ", { }, { datasource=application.dsn_read, maxRows=arguments.maxRows });
        }
    }

	public query function getReverseMigratableUsers(string userIDs, numeric maxRows=-1) {
        var qAllUsers = queryNew("profileID, userID, email, given_name, family_name, name, user_id, password_hash, email_verified");
    
         var userCondition;
            if (arguments.userIDs.isEmpty()) {
                userCondition = "1=1"; // No user ID restriction
            } else {
                userCondition = "u.userID = '#trim(arguments.userIDs)#' "; // Filter user IDs using LIKE
            }
            
            // Query to fetch users
            var qTheseUsers = queryExecute("
                SELECT      p.objectid as profileID, 
                            u.objectid as userID, 
                            p.emailAddress as email, 
                            p.firstName as given_name, 
                            p.lastName as family_name, 
                            p.label as name, 
                            u.userID as user_id, 
                            u.password as password_hash, 
                            case when u.userstatus = 'pending' then 'false' else 'true' end as email_verified
                FROM        farUser u
                INNER JOIN  dmProfile p ON concat(u.userID, '_AUTH0') = p.username
                WHERE       #userCondition#
                ORDER BY    u.objectid ASC
            ",  { }, { datasource=application.dsn_read, maxRows=arguments.maxRows });
    
            // Add fetched users to qAllUsers
            for (stUser in qTheseUsers) {
                queryAddRow(qAllUsers, stUser);
            }
 
        return qAllUsers;
    }
    

    public void function createUserRecords(required query qUsers) {

        queryExecute("
            INSERT INTO a0User (datetimelastupdated, lockedBy, userid, lastupdatedby, createdby, datetimecreated, locked, ObjectID, label, ownedby)
            SELECT  datetimelastupdated, lockedBy, concat('auth0|', userid), lastupdatedby, createdby, datetimecreated, locked, ObjectID, label, ownedby
            FROM    farUser
            WHERE   objectid IN (:userIDs)
        ", { userIDs={ type="cf_sql_varchar", list=true, value=valueList(arguments.qUsers.userID) } }, { datasource=application.dsn });
    }

    public void function disableOldUsers(required query qUsers) {

        queryExecute("
            UPDATE  farUser
            SET     userstatus = 'inactive'
            WHERE   objectid IN (:userIDs)
        ", { userIDs={ type="cf_sql_varchar", list=true, value=valueList(arguments.qUsers.userID) } }, { datasource=application.dsn });
    }

    public void function enableOldUsers(required query qUsers) {

        queryExecute("
            UPDATE  farUser
            SET     userstatus = 'active'
            WHERE   objectid IN (:userIDs)
        ", { userIDs={ type="cf_sql_varchar", list=true, value=valueList(arguments.qUsers.userID) } }, { datasource=application.dsn });
    }
    public void function removeUserRecords(required query qUsers) {
        queryExecute("
            DELETE FROM a0User
            WHERE   objectid IN (:userIDs)
        ", { userIDs={ type="cf_sql_varchar", list=true, value=valueList(arguments.qUsers.userID) } }, { datasource=application.dsn });
    }
    public void function switchProfilesToNewUsers(required query qUsers, required string fromUD, required string toUD) {

        queryExecute("
            UPDATE  dmProfile
            SET     userdirectory = '#arguments.toUD#',
                    username = REGEXP_REPLACE(username, '_#arguments.fromUD#$', '_#arguments.toUD#')
            WHERE   objectid IN (:profileIDs)
        ", { profileIDs={ type="cf_sql_varchar", list=true, value=valueList(arguments.qUsers.profileID) } }, { datasource=application.dsn });
    }

    public void function switchContentOwnership(required query qUsers, required string fromUD, required string toUD) {
        var property = "";
        var typename = "";
        var usernames = reReplace(valueList(arguments.qUsers.user_id), "($|,)", "_#arguments.fromUD#");

		// Update user properties
		for (property in "createdby,lastupdatedby,lockedby") {
            for (typename in application.stCOAPI) {
                if (listfindnocase("type,rule",application.stCOAPI[typename].class) and structkeyexists(application.stCOAPI[typename].stProps, property)) {
                    queryExecute("
                        update	#application.dbowner##typename#
                        set		#property# = REGEXP_REPLACE(#property#, '_#arguments.fromUD#$', '_#arguments.toUD#')
                        where	#property# IN (:usernames)
                    ", { usernames={ type="cf_sql_varchar", list=true, value=usernames } }, { datasource=application.dsn });
                }
            }
		}
    }

    public void function runMigration(required string oldGroupName, required query qUsers, boolean sendCompletion) {
        var safeBatchSize = 300; 
        if (qUsers.recordCount <= 20) {
            try {
            processBatch(arguments.qUsers, arguments.oldGroupName, arguments.sendCompletion); 
            } catch (any e) {
                application.fc.lib.error.logData(application.fc.lib.error.normalizeError(e));
            }
        } else {
            var totalRows = qUsers.recordCount;
            var currentIndex = 1;
    
            while (currentIndex <= totalRows) {
                try {
                var endIndex = min(currentIndex + safeBatchSize - 1, totalRows);
                var batchQuery = createBatchQuery(qUsers, currentIndex, endIndex);
                processBatch(batchQuery, arguments.oldGroupName, arguments.sendCompletion);
                } catch (any e) {
                    application.fc.lib.error.logData(application.fc.lib.error.normalizeError(e));
                }
                currentIndex += safeBatchSize;
            }
        }
    }
    
    private query function createBatchQuery(required query qUsers, required numeric startIndex, required numeric endIndex) {
        var batchQuery = queryNew(qUsers.columnList);
        for (var i = startIndex; i <= endIndex; i++) {
            var row = {};
            for (var col in qUsers.columnList) {
                row[col] = qUsers[col][i];
            }
            queryAddRow(batchQuery, row);
        }
        return batchQuery;
    }

    private void function processBatch(required query batchQuery, required string oldGroupName, boolean sendCompletion) {
        // import users
        var stJob = importUsers(qUsers=arguments.batchQuery, sendCompletion=arguments.sendCompletion, waitForCompletion=true);
    
        // create new user records
        updateJobStatusStep(stJob.id, "Create a0User records");
        createUserRecords(qUsers=arguments.batchQuery);

        // switch profiles across
        updateJobStatusStep(stJob.id, "Switch dmProfile records");
        switchProfilesToNewUsers(qUsers=arguments.batchQuery, fromUD="CLIENTUD", toUD="AUTH0");

        // migrate existing data
        updateJobStatusStep(stJob.id, "Update type owner fields");
        switchContentOwnership(qUsers=arguments.batchQuery, fromUD="CLIENTUD", toUD="AUTH0");

        // disable old users
        updateJobStatusStep(stJob.id, "Disable farUser records");
        disableOldUsers(qUsers=arguments.batchQuery);

        updateJobStatusStep(stJob.id, "Done");
    }

    public void function reverseMigration(required query qUsers) {
        var safeBatchSize = 5000; 
        if (qUsers.recordCount <= 5000) {
            try {
                processReverseBatch(arguments.qUsers); 
            } catch (any e) {
                application.fc.lib.error.logData(application.fc.lib.error.normalizeError(e));
            }
        } else {
            var totalRows = qUsers.recordCount;
            var currentIndex = 1;
    
            while (currentIndex <= totalRows) {
                try {
                var endIndex = min(currentIndex + safeBatchSize - 1, totalRows);
                var batchQuery = createBatchQuery(qUsers, currentIndex, endIndex);
                processReverseBatch(arguments.qUsers); 
                } catch (any e) {
                    application.fc.lib.error.logData(application.fc.lib.error.normalizeError(e));
                }
                currentIndex += safeBatchSize;
            }
        }
    }
    public void function processReverseBatch(required query qUsers) {
        // remove new user records
        removeUserRecords(qUsers=arguments.qUsers);

        // switch profiles across
        switchProfilesToNewUsers(qUsers=arguments.qUsers, fromUD="AUTH0", toUD="CLIENTUD");

        // migrate existing data
        switchContentOwnership(qUsers=arguments.qUsers, fromUD="AUTH0", toUD="CLIENTUD");

        // enable old users
        enableOldUsers(qUsers=arguments.qUsers);
    }

}