#!/bin/sh

aws ssm start-session \
    --document-name 'AWS-StartInteractiveCommand' \
    --parameters '{"command": ["sudo tail -f /var/log/cloud-init-output.log"]}' \
    --target "$(terraform output -raw instance_id)"
