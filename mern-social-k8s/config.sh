#!/bin/bash

minikube start

eval $(minikube docker-env)
docker build -t mern-social ./mern-social

kubectl create configmap nginx-config --from-file=nginx/nginx.conf
kubectl create secret generic nginx-certs --from-file=localhost.crt=nginx/certs/localhost.crt --from-file=localhost.key=nginx/certs/localhost.key

kubectl apply -f mongo-deployment.yml
kubectl apply -f mongo-service.yml
kubectl apply -f mongo-pvc.yml

kubectl apply -f webapp-deployment.yml
kubectl apply -f webapp-service.yml

kubectl apply -f mongo-express-deployment.yml
kubectl apply -f mongo-express-service.yml

kubectl apply -f nginx-deployment.yml
kubectl apply -f nginx-service.yml

sleep 60
sudo -E kubectl port-forward svc/nginx-service 80:80 443:443 --address 0.0.0.0 &

eval $(minikube docker-env -u)
