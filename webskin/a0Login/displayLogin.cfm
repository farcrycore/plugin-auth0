<cfsetting enablecfoutputonly="Yes">
<!--- @@Copyright: Daemon Pty Limited 2002-2008, http://www.daemon.com.au --->
<!--- @@License:
    This file is part of FarCry.

    FarCry is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    FarCry is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with FarCry.  If not, see <http://www.gnu.org/licenses/>.
--->
<!--- @@displayname: Farcry UD login form --->
<!--- @@description:   --->
<!--- @@author: Matthew Bryant (mbryant@daemon.com.au) --->


<!------------------
FARCRY IMPORT FILES
 ------------------>
<cfimport taglib="/farcry/core/tags/formtools/" prefix="ft" />
<cfimport taglib="/farcry/core/tags/security/" prefix="sec" />
<cfimport taglib="/farcry/core/tags/webskin/" prefix="skin" />



<!------------------
START WEBSKIN
 ------------------>

<skin:view typename="farLogin" template="displayHeaderLogin" />


<cfoutput><div class="loginInfo"></cfoutput>

<ft:form>

	<sec:selectProject />

	<cfset url.ud = "AUTH0" />
	<sec:SelectUDLogin />

	<cfif application.security.userdirectories.auth0.isEnabled()>
		<!--- run authenticate function? --->
		<cfif isdefined("url.logout")>
			<cfoutput><p class="error">You are logged out. <a href="/index.cfm?type=gudLogin&view=displayLogin">Login again</a></p></cfoutput>
		<cfelseif isdefined("url.code") and isdefined("session.testAuth0")>
			<cflocation url="/webtop/index.cfm?id=admin.security.auth0ud.status&testlogin=2&code=#url.code#" />
		<cfelseif isdefined("url.code") and not isdefined("arguments.stParam.message")>
			<cfset arguments.stParam = application.security.processLogin() />
			<cfif arguments.stParam.authenticated and not request.mode.profile>
				<cflocation url="#URLDecode(arguments.stParam.loginReturnURL)#" addtoken="false" />
			<cfelse>
				<cfoutput><p class="error">#arguments.stParam.message# <a href="/index.cfm?type=gudLogin&view=displayLogin">Retry</a></p></cfoutput>
			</cfif>
		<cfelse>
			<cflocation url="#application.security.userdirectories.auth0.getAuthorisationURL(clientID=application.fapi.getConfig('GUD', 'clientid'),redirectURL=application.security.userdirectories.auth0.getRedirectURL())#" addtoken="false" />
		</cfif>
	<cfelse>
		<cfoutput>
			<p>The Auth0 Directory is not set up yet.</p>
		</cfoutput>
	</cfif>

</ft:form>

<cfoutput></div></cfoutput>


<skin:view typename="farLogin" template="displayFooterLogin" />

<cfsetting enablecfoutputonly="false">