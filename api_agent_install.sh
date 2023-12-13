#!/bin/bash
set -e

##################################################
## Arguments -Mapped to parameters at execution ##
##################################################

VS_USER=$1  #Username of VaultSpeed account
VS_PW=$2    #Password of VaultSpeed account
OWNER=$3    #Owner account in OS running VS agent
CONNSTR=$4  #JDBC connection string for database
ENVIR=$5    #VaultSpeed environment

##################################################
## Variables - change these for you environment ##
##################################################

AGENT_PARENT_FOLDER=/home/ubuntu                                #Parent folder where you will install the agent
DBLINK_NAME="${CONNSTR%%.*}"                                    #Name of DB Link to be created (string before ".url")
AGENT_ZIP_FILENAME=agent.zip                                    #Filename of agent ZIP file
AGENT_ZIP_FILEPATH=$AGENT_PARENT_FOLDER/$AGENT_ZIP_FILENAME     #File path of agent.zip after download
AGENT_FOLDER=agent                                              #Agent directory created when unzipping agent.zip
AGENT_FOLDER_PATH=$AGENT_PARENT_FOLDER/$AGENT_FOLDER            #Directory path of agent installation folder
HOME_FOLDER=/home                                               #Default home directory string to be replaced in agent configuration files
JAVA_CMD=java                                                   #Java command to start agent; This might need to be qualified if multiple Java versions are installed

#Get bearer token
echo ">>> Getting bearer token"
export VS_TOKEN=$(curl -s -X POST \
     -H 'Content-type: application/json' \
     -d "{ \"username\": \"${VS_USER}\", \"password\": \"${VS_PW}\" }" \
    https://${ENVIR}.vaultspeed.com/api/login | jq -r '.access_token')

#Download agent.zip file
echo ">>> Downloading ${AGENT_ZIP_FILENAME}"
curl -X GET \
    -H 'Content-type: application/json' \
    -H "Authorization: Bearer ${VS_TOKEN}" \
    https://$ENVIR.vaultspeed.com/api/agent/download -o $AGENT_ZIP_FILEPATH

#Unzip agent.zip contents to agent directory
echo ">>> Unzipping ${AGENT_ZIP_FILENAME}"
unzip -o $AGENT_ZIP_FILEPATH -d $AGENT_PARENT_FOLDER

#Grant ownership to agent directory and file
echo ">>> Granting ownership of agent files and directories"
chown $OWNER $AGENT_PARENT_FOLDER/$AGENT_FOLDER
chown -R $OWNER $AGENT_PARENT_FOLDER/$AGENT_FOLDER/*

#Replace default home directory with agent home directory for environment in client.properties
echo ">>> Replacing default home directory with agent home directory for environment in client.properties"
sed -i "s|$HOME_FOLDER|$AGENT_PARENT_FOLDER|" $AGENT_FOLDER_PATH/client.properties
#Replace default log directory with agent home directory for environment in logging.properties
echo ">>> Replacing default log directory with agent home directory for environment in logging.properties"
sed -i "s|./log|$AGENT_PARENT_FOLDER/agent/log|" $AGENT_FOLDER_PATH/logging.properties

#Add connection string url for local PostgreSQL database
echo ">>> Adding connection string url for database in connections.properties"
sed -i "$ a$CONNSTR" $AGENT_FOLDER_PATH/connections.properties

echo ">>> Starting agent in background"
nohup $JAVA_CMD -Djava.util.logging.config.file=$AGENT_FOLDER_PATH/logging.properties -jar $AGENT_FOLDER_PATH/vs-agent.jar propsfile=$AGENT_FOLDER_PATH/client.properties &

#Create postgres db_link
echo ">>> Creating Snowflake DB link"
export DBLINK_ID=$(curl -s -X POST -H \
    "Content-type: application/json" \
    -H "Authorization: Bearer ${VS_TOKEN}" \
    -d "{ \"database_link_name\": \"${DBLINK_NAME}\", \"link_url\": \"\", \"link_type\": \"agent\", \"database_type_id\": 9, \"link_url_object\": \"\" }" \
    https://$ENVIR.vaultspeed.com/api/db-link | jq -r '.database_link_id')
echo "DB_Link '${DBLINK_NAME}' has been created with ID ${DBLINK_ID}."

#Test DB_Link
#Request test-connection
echo ">>> Testing DB Link '${DBLINK_NAME}'"
export TASK_ID=$(curl -s -X POST -H \
    "Content-type: application/json" \
    -H "Authorization: Bearer ${VS_TOKEN}" \
    -d "{ \"database_link_id\": ${DBLINK_ID} }" \
    https://$ENVIR.vaultspeed.com/api/db-link/test-connection | jq -r '.task_set_id')

#Get task status
STATUS="starting"
i=0
#Check status until task is done, or until 12 tries are complete, or until it task errors
while [ "$STATUS" != "done" ] && [ $i -lt 12 ] && [ "$STATUS" != "error" ]
do
    STATUS=$(curl -s -X GET \
        -H 'Content-type: application/json' \
        -H "Authorization: Bearer ${VS_TOKEN}" \
        https://$ENVIR.vaultspeed.com/api/tasks/${TASK_ID}/status | jq -r '.task_status')
    #If the last digit of the counter value is 0 or 5, or if the status is "done",  print the task
    if [ ${i: -1} == "0" ] || [ ${i: -1} == "5" ] || [ "$STATUS" == "done" ]
    then echo "Test of DB Link '${DBLINK_NAME}' is ${STATUS}."
    fi
    ((i=i+1))
    sleep 5
done

#Print the result of the test
#Set variable for time in seconds
ts=$((i*5))
if [ "$STATUS" == "done" ] 
then
    echo "DB Link test was successful."
else
    #Cancel DB Link teast task
    echo "Canceling DB Link test"
    curl -s -X PATCH \
        -H "Authorization: Bearer ${VS_TOKEN}" \
        https://$ENVIR.vaultspeed.com/api/task/${TASK_ID}/cancel
    echo "DB Link test failed after ${ts} seconds."
fi

##Stop agent
#echo "Stopping agent"
#kill $(ps aux | grep '[D]java.util.logging.config.file' | awk '{print $2}')


exit 0