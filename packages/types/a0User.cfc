<cfcomponent displayname="Auth0 User" hint="User model for the Auth0." extends="farcry.core.packages.types.types" output="false" description="" bObjectBroker="true">

	<cfproperty ftLabel="UserID"
				name="userid" type="string" default="" hint="The userid to use in FarCry"
				ftType="string" />

	<cfproperty ftLabel="Refresh Token"
				name="refreshToken" type="string" default="" />


	<cffunction name="getByUserID" access="public" output="false" returntype="struct" hint="Returns the data struct for the specified user id">
		<cfargument name="userid" type="string" required="true" hint="The user id" />

		<cfset var stResult = structnew() />
		<cfset var qUser = "" />

		<cfquery datasource="#application.dsn#" name="qUser">
			select	*
			from	#application.dbowner#a0User
			where	lower(userid)=<cfqueryparam cfsqltype="cf_sql_varchar" value="#lcase(arguments.userid)#" />
		</cfquery>

		<cfif qUser.recordcount>
			<cfset stResult = getData(qUser.objectid) />
		</cfif>

		<cfreturn stResult />
	</cffunction>

</cfcomponent>