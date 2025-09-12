# Instructions


Note, any timey ou make a change to a deployment or service, you have to reapply it 
```
kubectl apply -k ./k8s
```
and then run

```
kubectl rollout restart deployment mern-social -n assignment
```
## mern-social
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

