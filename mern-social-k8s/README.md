# Instructions

## mern-social-db
On every restart, need to do this:
1. start minikube
`minikube start`

2. Point Docker to minikube's daemon
`eval $(minikube -p minikube docker-env)`

3. Check cluster health (optional)
```
kubectl get nodes
kubectl get pods -A
```

4. If the minikube VM or container was deleted, need to rebuild the docker images.
```
docker build -t mern-social:local .
```

5. Note: persistent data is also wiped if minikube is recreated. 

