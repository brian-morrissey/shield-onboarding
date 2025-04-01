#!/bin/bash

# Check if the namespace argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <namespace>"
    exit 1
fi

# Set the namespace from the command line argument
namespace="$1"

kubectl get pods -n "$namespace" -l app.kubernetes.io/instance=shield

podNameList=`kubectl get pods -n "$namespace" -l sysdig/component=host --no-headers -o custom-columns=":metadata.name"`
for podName in $podNameList
do
	echo "========== " $podName
        kubectl logs -n "$namespace" $podName | grep Error,
done

podNameList=`kubectl get pods -n "$namespace" -l sysdig/component=cluster --no-headers -o custom-columns=":metadata.name"`
for podName in $podNameList
do
	echo "========== " $podName
        kubectl logs -n "$namespace" $podName | grep 'level\":\"ERROR\"'
done
