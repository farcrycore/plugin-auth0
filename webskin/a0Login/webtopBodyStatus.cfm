<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">
<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />


<cfset redirectURL = application.security.userdirectories.auth0.getRedirectURL() />
<cfset homeURL = application.fapi.getLink(alias='home', includeDomain=true, bSecure=true) />

<cfif structKeyExists(url, "testlogin") and url.testlogin eq 1>
    <cfset session.testAuth0 = {} />
    <cfset loginURL = application.security.userdirectories.auth0.getAuthorisationURL(
        clientID = application.fapi.getConfig('GUD', 'clientid'),
        redirectURL = application.security.userdirectories.auth0.getRedirectURL(),
        scope = 'https://buy-nsw.au.auth0.com/userinfo.profile email user id',
        state = ''
    ) />
    <cflocation url="#loginURL#" addtoken="false">
</cfif>
<cfif structKeyExists(url, "testlogin") and url.testlogin eq 2>
    <cfset session.testAuth0 = application.fc.lib.auth0.exchangeAuthorizationCode(code=url.code, redirectURL=application.security.userdirectories.auth0.getRedirectURL()) />
    <cflocation url="#application.fapi.fixURL(addValues='testlogin=3', removevalues='code')#" addtoken="false">
</cfif>


<cfoutput><h1>Auth0 Status</h1></cfoutput>

<cfif not application.security.userdirectories.auth0.isEnabled()>
    <cfoutput>
        <div class="alert alert-warning">The Auth0 plugin has not been configured.</div>
    </cfoutput>

    <cfexit>
</cfif>

<cfoutput>
    <h2>Auth0 configuration</h2>
    <p>
        <strong>Allowed Callback URLs</strong>: #redirectURL#<br>
        <strong>Allowed Logout URLs</strong>: #homeURL#<br>
        <strong>Allowed Web Origins</strong>: #mid(homeURL, 1, len(homeURL)-1)#<br>
    </p>
</cfoutput>

<cfoutput>
    <h2>Test login</h2>
    <p>This redirects the user to Auth0 for login, then back to this site for confirmation.</p>
</cfoutput>
<ft:buttonPanel>
    <ft:button value="Log in" url="#application.fapi.fixURL(addValues='testlogin=1')#" />
</ft:buttonPanel>
<cfif structKeyExists(url, "testlogin") and url.testlogin eq 3>
    <cfdump var="#session.testAuth0#">
</cfif>

<cfoutput>
    <h2>Test username / password</h2>
    <p>This makes a server side API call. Requires the application be set up with a default connection (Auth0 Admin > Settings > API Authorizatoin Settings > Default Directory).</p>
</cfoutput>
<ft:processForm action="Log in">
    <cfset result = application.fc.lib.auth0.testUserPassword(username=form.username, password=form.password)>
    <cfoutput><div class="alert alert-info">#result#</div></cfoutput>
</ft:processForm>
<ft:form>
    <ft:field label="Username">
        <cfoutput><input type="text" name="username"></cfoutput>
    </ft:field>
    <ft:field label="Password">
        <cfoutput><input type="password" name="password"></cfoutput>
    </ft:field>
    <ft:buttonPanel>
        <ft:button value="Log in" />
    </ft:buttonPanel>
</ft:form>

<cfset aGroups = application.fc.lib.auth0.getGroups() />
<cfoutput>
    <h2>Roles</h2>
    <table class="table table-striped">
        <thead>
            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Description</th>
            </tr>
        </thead>
        <tbody>
</cfoutput>
<cfloop array="#aGroups#" item="group">
    <cfoutput>
        <tr>
            <td>#group.id#</td>
            <td>#group.name#</td>
            <td>#group.description#</td>
        </tr>
    </cfoutput>
</cfloop>
<cfoutput>
        </tbody>
    </table>
</cfoutput>

<cfparam name="url.user_email" default="">
<cfif len(url.user_email)>
    <cfset aUsers = application.fc.lib.auth0.getUsersByEmail(email=url.user_email) />
<cfelse>
    <cfset aUsers = application.fc.lib.auth0.getUsers() />
</cfif>
<cfoutput>
    <h2>Users</h2>
    <form action="#application.fapi.fixURL()#" method="GET">
        <input type="hidden" name="id" value="#url.id#">
        <input type="text" name="user_email" value="#encodeForHTMLAttribute(url.user_email)#" placeholder="user@email.com">
        <button class="btn" type="submit">Search</button>
    </form>
    <table class="table table-striped">
        <thead>
            <tr>
                <th>ID</th>
                <th>Email</th>
                <th>Email Verified</th>
                <th>Multifactor</th>
                <th>Name</th>
                <th>Created</th>
                <th>Last Login</th>
                <th>Last IP</th>
                <th>Logins</th>
            </tr>
        </thead>
        <tbody>
</cfoutput>
<cfloop array="#aUsers#" item="user">
    <cfoutput>
        <tr>
            <td>#user.user_id#</td>
            <td>#user.email#</td>
            <td>#yesNoFormat(user.email_verified)#</td>
            <td><cfif structKeyExists(user, "multifactor")>#arrayToList(user.multifactor, ', ')#</cfif></td>
            <td>#user.name#</td>
            <td>#user.created_at#</td>
            <td><cfif structKeyExists(user, "last_login")>#user.last_login#</cfif></td>
            <td><cfif structKeyExists(user, "last_ip")>#user.last_ip#</cfif></td>
            <td><cfif structKeyExists(user, "logins_count")>#user.logins_count#</cfif></td>
        </tr>
    </cfoutput>
</cfloop>
<cfoutput>
        </tbody>
    </table>
</cfoutput>

<!--- <cfoutput>
    <h2>Delete all users from auth0</h2>
</cfoutput>
<ft:processForm action="Delete Users">
    <cfset aDeleteAuth0Users=application.fc.lib.auth0.deleteAuth0Users() />
    <cfdump var="#aDeleteAuth0Users#">
</ft:processForm>
<ft:form>
    <ft:buttonPanel>
        <ft:button value="Delete Users"  onclick="if (!confirm('Are you sure you want to delete all accounts on auth0?')) return false;"/>
    </ft:buttonPanel>
</ft:form> --->

<cfoutput>
    <h2>Delete Bad Auth0 Accounts</h2>
</cfoutput>
<ft:processForm action="Delete Bad Accounts">
    <cfset aDeleteBadAuth0Users=application.fc.lib.auth0.deleteBadAuth0Users() />
    <cfdump var="#aDeleteBadAuth0Users#">
</ft:processForm>
<ft:form>
    <ft:buttonPanel>
        <ft:button value="Delete Bad Accounts" onclick="if (!confirm('Are you sure you want to delete bad accounts on auth0?')) return false;"/>
    </ft:buttonPanel>
</ft:form>


<cfset aGroups = application.security.userdirectories.clientud.getAllGroups() />
<cfparam name="url.migratable_group" default="">
<cfoutput>
    <h2 id="migratableusers">Migratable users</h2>
    <form action="#application.fapi.fixURL(removeValues='logintest,user_email,code')#" method="GET">
        <input type="hidden" name="id" value="#url.id#">
        <select name="migratable_group">
            <option value="">-- select --</option>
            <option value="-none-" <cfif '-none-' eq url.migratable_group>selected</cfif>>No group</option>
            <cfloop array="#aGroups#" item="group"><option <cfif group eq url.migratable_group>selected</cfif>>#group#</option></cfloop>
        </select>
        <button type="submit" class="btn">Find users</button><br>
        <cfif len(url.migratable_group)>
            <button type="submit" class="btn" name="migrate" value="one">Migrate one user</button>
            <button type="submit" class="btn" name="migrate" value="ten">Migrate ten users</button>
            <button type="submit" class="btn" name="migrate" value="all">Migrate all users</button>
        </cfif>
    </form>
</cfoutput>
<cfif structKeyExists(url, "migrate")>
    <cfswitch expression="#url.migrate#">
        <cfcase value="one"><cfset qMigratableUsers = application.fc.lib.auth0.getMigratableUsers(oldGroupID=url.migratable_group, maxrows=1) /></cfcase>
        <cfcase value="ten"><cfset qMigratableUsers = application.fc.lib.auth0.getMigratableUsers(oldGroupID=url.migratable_group, maxrows=10) /></cfcase>
        <cfcase value="all"><cfset qMigratableUsers = application.fc.lib.auth0.getMigratableUsers(oldGroupID=url.migratable_group, maxrows=-1) /></cfcase>
    </cfswitch>
    
    <!--- Initialize migration tracking structure in session scope if not exists --->
    <cfif NOT structKeyExists(session, "migrationInProgress")>
        <cfset session.migrationInProgress = StructNew()>
    </cfif>

    <!--- Check if the migration for this group is already in progress in this session --->
    <cfif NOT structKeyExists(session.migrationInProgress, url.migratable_group)>
        <!--- Set the flag to indicate migration is in progress for this session --->
        <cfset session.migrationInProgress[url.migratable_group] = true>

        <!--- Run the migration --->
        <cftry>
            <cfset application.fc.lib.auth0.runMigration(oldGroupName=url.migratable_group, qUsers=qMigratableUsers, emailVerified=true) />

            <!--- Clear the flag after successful migration --->
            <cfset StructDelete(session.migrationInProgress, url.migratable_group)>

            <cfcatch type="any">
                <!--- Clear the flag in case of error so it can be retried --->
                <cfset StructDelete(session.migrationInProgress, url.migratable_group)>
            </cfcatch>
        </cftry>
    </cfif>
    
    <cflocation url="#application.fapi.fixURL(removeValues='migrate', anchor='migrateusers')#" addtoken="false">
</cfif>
<cfif len(url.migratable_group)>
    <cfset qMigratableUsers = application.fc.lib.auth0.getMigratableUsers(oldGroupID=url.migratable_group, maxrows=10) />

    <cfoutput>
        <p>Showing up to 10 of #qMigratableUsers.recordcount# users:</p>
        <table class="table table-striped">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Email</th>
                    <th>Name</th>
                    <th>Given name</th>
                    <th>Family name</th>
                </tr>
            </thead>
            <tbody>
    </cfoutput>
    <cfloop query="#qMigratableUsers#">
        <cfoutput>
            <tr>
                <td>#qMigratableUsers.user_id#</td>
                <td>#qMigratableUsers.email#</td>
                <td>#qMigratableUsers.name#</td>
                <td>#qMigratableUsers.given_name#</td>
                <td>#qMigratableUsers.family_name#</td>
            </tr>
        </cfoutput>
    </cfloop>
    <cfoutput>
            </tbody>
        </table>
    </cfoutput>
</cfif>

<cfset aJobs = application.fc.lib.auth0.getJobStatuses() />
<cfif arrayLen(aJobs)>
    <cfoutput><h2>Import jobs</h2></cfoutput>
    <cfdump var="#aJobs#">
</cfif>

<cfparam name="url.userid" default="">
<cfif len(url.userid)>
    <cfset qReverseMigratableUsers = application.fc.lib.auth0.getReverseMigratableUsers(userIDs = url.userid, maxRows=-1) />
<cfelse>
<cfset qReverseMigratableUsers = application.fc.lib.auth0.getReverseMigratableUsers(userIDs = "", maxRows=10) />
</cfif>
<cfoutput>
    <h2>Reverse migration</h2>
    <div class="alert alert-warning">This process converts all profiles linked to an Auth0 user back to the local farUser record.</div>
    <p>Below are examples of users found in Auth0 and the corresponding farUser record that would be re-enabled.</p>
</cfoutput>
<cfoutput>
    <form action="#application.fapi.fixURL()#" method="GET">
        <input type="hidden" name="id" value="#url.id#">
        <input type="text" name="userid" value="#encodeForHTMLAttribute(url.userid)#" placeholder="user@email.com">
        <button class="btn" type="submit">Search</button>
    </form>
    <table class="table table-striped">
        <thead>
            <tr>
                <th>ID</th>
                <th>Email</th>
                <th>Name</th>
                <th>Given name</th>
                <th>Family name</th>
            </tr>
        </thead>
        <tbody>
</cfoutput>
<cfloop query="#qReverseMigratableUsers#">
    <cfoutput>
        <tr>
            <td>#qReverseMigratableUsers.user_id#</td>
            <td>#qReverseMigratableUsers.email#</td>
            <td>#qReverseMigratableUsers.name#</td>
            <td>#qReverseMigratableUsers.given_name#</td>
            <td>#qReverseMigratableUsers.family_name#</td>
        </tr>
    </cfoutput>
</cfloop>
<cfoutput>
        </tbody>
    </table>
</cfoutput>
<ft:processForm action="Reverse migration" Exit="true">
<cfif len(url.userid)>
    <cfset application.fc.lib.auth0.reverseMigration(qUsers=application.fc.lib.auth0.getReverseMigratableUsers(userIDs = url.userid, maxRows=-1)) />
<cfelse>
    <cfset application.fc.lib.auth0.reverseMigration(qUsers=application.fc.lib.auth0.getReverseMigratableUsers(userIDs = "", maxRows=-1)) />
</cfif>
</ft:processForm>
<ft:form>
    <ft:buttonPanel>
        <ft:button value="Reverse migration" />
    </ft:buttonPanel>
</ft:form>

<cfsetting enablecfoutputonly="false">