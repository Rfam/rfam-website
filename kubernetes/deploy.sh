#!/bin/bash

kubectl apply -f services.yaml 
kubectl apply -f rfam-deployment.yaml  
kubectl apply -f apache-deployment.yaml
kubectl apply -f ingress.yaml