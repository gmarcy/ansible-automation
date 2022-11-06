#!/bin/bash

jq -r '.[] | {event_time, severity, message} | join("|")' cluster_events.json > cluster_events.txt

# curl -s ${ASSISTED_INSTALL_REST_URL}/clusters/${CLUSTER_ID} | jq -M . > current_cluster_status.json

curl -s ${ASSISTED_INSTALL_REST_URL}/events?cluster_id=${CLUSTER_ID} | jq -M . > current_cluster_events.json
jq -r '.[] | {event_time, severity, message} | join("|")' current_cluster_events.json > current_cluster_events.txt

while cmp -s cluster_events.txt current_cluster_events.txt
do
  status=$(curl -s ${ASSISTED_INSTALL_REST_URL}/clusters/${CLUSTER_ID} | jq -r .status)
  if expr $status == installed > /dev/null
  then
    exit 0
  fi

  sleep 15

  curl -s ${ASSISTED_INSTALL_REST_URL}/events?cluster_id=${CLUSTER_ID} | jq -M . > current_cluster_events.json
  jq -r '.[] | {event_time, severity, message} | join("|")' current_cluster_events.json > current_cluster_events.txt
done

diff --new-line-format="%L" --old-line-format="" --unchanged-line-format="" cluster_events.txt current_cluster_events.txt > additional_events.txt

cp /dev/null latest_events.txt
input="additional_events.txt"
while read line || [ -n "$line" ];
do
  event_time=$(echo $line | cut --delimiter='|' -f 1)
  severity=$(echo $line | cut --delimiter='|' -f 2)
  message=$(echo $line | cut --delimiter='|' -f 3)
  timestamp=$(date --date=${event_time} '+%-m/%-d/%Y, %X')
  echo $timestamp $severity $message >> latest_events.txt
done < $input

cat latest_events.txt

cp current_cluster_events.json cluster_events.json

status=$(curl -s ${ASSISTED_INSTALL_REST_URL}/clusters/${CLUSTER_ID} | jq -r .status)
if expr $status == installed > /dev/null
then
  exit 0
else
  exit 1
fi
