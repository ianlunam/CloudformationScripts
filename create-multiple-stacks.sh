#!/usr/bin/env bash

# Mandatory vars
: ${ENVIRONMENT:?Please supply ENVIRONMENT variable/parameter}
: ${LAYER:?Please supply LAYER variable/parameter}

# Optional vars
: ${FILETYPE:=.json}

# AWS Vars, exported because needed by called script
: ${AWS_ACCESS_KEY_ID:?Please supply AWS_ACCESS_KEY_ID variable}
: ${AWS_SECRET_ACCESS_KEY:?Please supply AWS_SECRET_ACCESS_KEY variable}
: ${AWS_DEFAULT_REGION:=eu-west-1}
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

PropertiesDirectory=cloudformation/${LAYER}/${ENVIRONMENT}/properties
echo "Looking for properties files in ${PropertiesDirectory}"

for PropertiesFile in $(find ${PropertiesDirectory} -type f -name "*${FILETYPE}")
do
    StackName=$(basename ${PropertiesFile} ${FILETYPE})
    echo "Properties file for stack ${StackName} is ${PropertiesFile}"

    tpath=$(dirname ${PropertiesFile} | sed 's/properties/templates/')
    TemplateFile=$(find ${tpath} -type f -name "*${FILETYPE}" | head -1)
    echo "Template file for stack ${StackName} is ${TemplateFile}"

    # Export vars needed by called script
    export StackName TemplateFile PropertiesFile
    $(dirname $0)/create-stack.sh
    status=$?
    if [[ $status != 0 ]]
    then
        exit $status
    fi

done
