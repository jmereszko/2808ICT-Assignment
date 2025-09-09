#!/bin/bash

eval $(minikube docker-env)
docker build -t mern-social ./mern-social

kubectl create configmap nginx-all --from-file=nginx/


kubectl apply -f mongo-deployment.yml
kubectl apply -f mongo-service.yml

kubectl apply -f webapp-deployment.yml
kubectl apply -f webapp-service.yml

kubectl apply -f mongo-express-deployment.yml
kubectl apply -f mongo-express-service.yml

kubectl apply -f nginx-deployment.yml
kubectl apply -f nginx-service.yml

eval $(minikube docker-env -u)
