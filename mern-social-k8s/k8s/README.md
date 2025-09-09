# K8S YAML FILES


## Deployments (general idea):
Tells k8s how many replicas of a Pod to run.
K8s creates and manages the Pods based on the template.
If the Pod crashes or the node dies, the Deployment automatically re-creates it.

To apply just one Deployment, do `kubectl apply -f mern-social-deployment.yaml` (for example)
then you can check its runnign by doing
```
kubectl -n assignment get pods # where assignment is the k8s namespace
kubectl -n assignment logs deploy/mern-social
```

## namespace.yaml
Creates the namespace needed for this cluster (assignment)
Equivalent of doing `kubectl create namespace assignment`, but its automated so it gets done when `kubectl apply -f k8s/` is run.

Every deployment is reliant on this namespace existing.

## mern-social-deployment.yaml
Sets up the Deployment for mern-social, the full node.js app.

