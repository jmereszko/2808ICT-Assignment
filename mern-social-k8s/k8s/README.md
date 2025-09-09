# K8S YAML FILES


## Deployments (general idea):
Tells k8s how many replicas of a Pod to run.
K8s creates and manages the Pods based on the template.
If the Pod crashes or the node dies, the Deployment automatically re-creates it.

## namespace.yaml
Creates the namespace needed for this cluster (assignment)
Equivalent of doing `kubectl create namespace assignment`, but its automated so it gets done when `kubectl apply -f k8s/` is run.

Every deployment is reliant on this namespace existing.

## mern-social-deployment.yaml
Sets up the Deployment for mern-social, the full node.js app.

