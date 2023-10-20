#!/bin/sh

nc "$(terraform output -raw instance_public_ip)" 22
