#!/bin/bash

kubectl apply -f catalyst-service.yaml
kubectl apply -f rfam-deployment.yaml
kubectl apply -f apache-deployment.yaml