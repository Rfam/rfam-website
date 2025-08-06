#!/bin/bash

kubectl delete -f apache-deployment.yaml --ignore-not-found=true
kubectl delete -f rfam-deployment.yaml --ignore-not-found=true
kubectl delete -f catalyst-service.yaml --ignore-not-found=true