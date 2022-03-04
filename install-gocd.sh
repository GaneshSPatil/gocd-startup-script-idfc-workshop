#!/bin/bash

set -e

#echo "Installing jq"
#brew install jq;

echo "Starting GoCD"
export GOCD_SERVER_NAME=idfc_gocd_server
export GOCD_ALPINE_AGENT=idfc_gocd_agent_alpine
export GOCD_JAVA_8_AGENT=idfc_gocd_agent_java_8
export GOCD_JAVA_11_AGENT=idfc_gocd_agent_java_11
export GOCD_NODEJS_AGENT=idfc_gocd_agent_nodejs

echo "Start pulling required docker images..."
#docker image pull gocd/gocd-server:v21.4.0
#docker image pull gocddev/gocd-dev-build:centos-8-v3.4.2
#docker image pull  gocd/gocd-agent-alpine-3.12:v21.4.0
echo "Done..."

echo "Stopping existing containers..."
docker container rm -f $GOCD_SERVER_NAME
docker container rm -f $GOCD_ALPINE_AGENT
echo "Done..."

export GOCD_GODATA_FOLDER="/Users/$(whoami)/.gocd/godata"
rm -rf $GOCD_GODATA_FOLDER
mkdir -p $GOCD_GODATA_FOLDER

echo "Starting $GOCD_SERVER_NAME container..."
docker container run -v $GOCD_GODATA_FOLDER:/godata -d -p8153:8153 --name  $GOCD_SERVER_NAME gocd/gocd-server:v21.4.0

API_RESPONSE=0
while [ $API_RESPONSE -ne 200 ]
do
  echo "Waiting for GoCD Server to Start..."
  sleep 10
  API_RESPONSE=$(curl --write-out '%{http_code}' --silent --output /dev/null 'http://localhost:8153/go/api/v1/health')
done
echo "GoCD Server Started..."

echo "Locating Agent Auto Register Key"
AGENT_AUTO_REGISTER_KEY=$(echo 'cat //cruise/server/@agentAutoRegisterKey' | xmllint --shell $GOCD_GODATA_FOLDER/config/cruise-config.xml  | grep -v ">" | cut -f 2 -d "=" | tr -d \")
echo "AGENT_AUTO_REGISTER_KEY is $AGENT_AUTO_REGISTER_KEY"

echo "Starting $GOCD_GOCD_ALPINE_AGENT container..."
docker run --name $GOCD_ALPINE_AGENT -d -e AGENT_AUTO_REGISTER_KEY=$AGENT_AUTO_REGISTER_KEY -e AGENT_AUTO_REGISTER_RESOURCES="foo,bar" -e AGENT_AUTO_REGISTER_HOSTNAME=$GOCD_ALPINE_AGENT -e GO_SERVER_URL=http://$(docker inspect --format='{{(index (index .NetworkSettings.IPAddress))}}' $GOCD_SERVER_NAME):8153/go gocd/gocd-agent-alpine-3.12:v21.4.0

