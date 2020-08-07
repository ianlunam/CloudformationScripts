#!/usr/bin/env bash

# ParameterNames: List of valid parameters for template. Example:
# export ParameterNames="""AlertLogicHost AlertLogicKey AmiId CreateCrons CreateScaling
#         DesiredCapacity DockerVolumeSize InstanceType MaxSize MinSize
#         NewRelicLicenseKey RootDomain RootVolumeSize SshKeyName SslCertificateId"""


# Optional variables
: ${AWS_DEFAULT_REGION:=eu-west-1}
: ${ParameterNames:=""}
: ${PropertiesFile:=""}

export AWS_DEFAULT_REGION

# Mandatory variables
: ${StackName:?Variable Not Set. StackName is Mandatory}
: ${TemplateFile:?Variable Not Set. TemplateFile is Mandatory}

# Convert any supplied parameters into Key/Value blocks
cfn_params=""
for pname in ${ParameterNames}; do
    if [[ ! -z "$(eval echo \$$pname)" ]]; then
        cfn_params="$cfn_params ParameterKey=$pname,ParameterValue='$(eval echo \$$pname)'"
    fi
done

# If there are parameters, use --parameters parameter
parameter_command="--parameters ${cfn_params}"
if [[ "${cfn_params}" == "" ]]; then
    parameter_command=""
fi

# If there is a properties file, use --parameters parameter
properties_command="--parameters file://${PropertiesFile}"
if [[ "${PropertiesFile}" == "" ]]; then
    properties_command=""
fi

CnfTemplate=file://${TemplateFile}

# Determine if we are going to create or update
create_command="create-stack"
complete_look_for="CREATE_COMPLETE"
progress_look_for="CREATE_IN_PROGRESS"
aws cloudformation describe-stacks --stack-name ${StackName} 1>/dev/null 2>&1
if [[ $? == 0 ]]; then
    create_command="update-stack"
    complete_look_for="UPDATE_COMPLETE"
    progress_look_for="UPDATE_IN_PROGRESS"
fi

# Execute command to create/update stack
echo "Running ${create_command} for stack ${StackName}"
echo "Template Parameters: ${parameter_command}"
echo "Template Properties: ${properties_command}"
StackId=$(aws cloudformation ${create_command} --stack-name ${StackName} --capabilities CAPABILITY_IAM \
        ${parameter_command} ${properties_command} --template-body ${CnfTemplate} \
        --query StackId --output text 2>&1)

echo "${StackId}"

if [[ "${StackId}"  =~ "No updates are to be performed" ]]; then
    echo "Stack already up to date"
    exit 0
fi

if [[ "${StackId}"  =~ "ValidationError" ]]; then
    echo "Stack validation failed: ${StackId}"
    exit 1
fi

if [[ -z "${StackId}" ]]; then
    # Failure.
    echo "Failed. See above."
    exit 3
fi

# Wait for create / update to complete
while true; do
    stack_status=$(aws cloudformation describe-stacks --stack-name ${StackName} \
                        --query 'Stacks[*].StackStatus' --output text)
    if [[ "${stack_status}" =~ "${complete_look_for}" ]]
    then
        # It's complete. Describe and exit
        aws cloudformation describe-stacks --stack-name ${StackName}
        exit 0
    else
        if [[ "${stack_status}" =~ "${progress_look_for}" ]]
        then
            # Still waiting. Sleep and check again
            echo "waiting ..."
            sleep 10
            continue
        else
            # Failure. Print state and exit
            echo "Failed. Status is ${stack_status}. See above"
            exit 2
        fi
    fi
done

# Should never get to here
exit 0
