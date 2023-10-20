#!/bin/sh


aws ssm start-session --target "$(terraform output -raw instance_id)"
