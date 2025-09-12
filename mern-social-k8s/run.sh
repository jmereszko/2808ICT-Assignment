#!/bin/bash

minikube start

eval $(minikube docker-env)
docker build -t mern-social ./mern-social

kubectl apply -k ./k8s
kubectl rollout restart deployment mern-social -n assignment

sleep 60
sudo -E kubectl port-forward svc/nginx-service 80:80 443:443 --address 0.0.0.0 &

eval $(minikube docker-env -u)
