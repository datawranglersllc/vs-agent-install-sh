This shell script executes commands in Bash to install the VaultSpeed agent in an Ubuntu Linux compute environment. To run it, execute this command in the directory containing the shell script file:
'''
  bash api_agent_install.sh xxxxxx@xxxxxx xxxxxxx ubuntu 'snowflaketrial.url=jdbc:snowflake://dactyter-xyx0001999.snowflakecomputing.com?user=snowflaketrial&password=XxXxXxXxXxXxX&warehouse=COMPUTE_WH&db=DBNAME' app
'''

Here are descriptions of the 5 parameters:

1. VaultSpeed Subscription Username
2. VaultSpeed Subscription Password
3. Name of the Ubuntu user that owns the VS agent directories and files
4. URL of JDBC connection string for the target database
5. Environment of VaultSpeed Subscription (training-eu, app [PROD], test [UA])

This routine gets the bearer token for the provided VaultSpeed subscription and:

- Downloads the VaultSpeed agent (java)
- Unzips the agent files to proper directory
- Grants ownership of the files to the provided Ubuntu user
- Changes the path for the agent directory from the home directory to the new agent directory for each reference in client.properties
- Changes the path for the agent directory from the home directory to the new agent directory for each reference in logging.properties
- Adds the connections string URL provided in the parameters
- Starts the VaultSpeed agent in the background
- Creates the db_link associate with the connection URL
- Tested the db_link for connectivity


