# Instructions

## mern-social-db
On every restart, need to do this:
1. start minikube
`minikube start`

2. Point Docker to minikube's daemon
`eval $(minikube -p minikube docker-env)`

3. Check cluster health
```
kubectl get nodes
kubectl get pods -A
```


