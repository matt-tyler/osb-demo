#!/bin/zsh

set -eux

svcat unbind storage-instance --wait

svcat unbind gcp-iam --wait

svcat deprovision gcp-iam

svcat deprovision storage-instance --wait
