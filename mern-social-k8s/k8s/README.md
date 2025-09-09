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

# Services (general idea):
A service is a stable network endpoint that sits in front of one or more Pods.

They give a pod a fixed DNS name + a virtual IP.

For example, `mern-social.mern.svc.cluster.local`. Even if Pods restart, the address stays the same.

They also load balance traffic. For example, if we scaled to 3 replicas, the Service will automatically distribute requests across them.

They also control external access (via Service type):
- ClusterIP (default): only accessible inside the cluster
- NodePort: Opens a fixed port (like 32000) on every cluster node, so you can curl it from your machine.
- LoadBalancer: On cloud providers, it provisions an actual load balancer (AWS ELB, etc.)

```
ports:
    - port: 3000        # this is the Service's own port. Other Pods can now use this port to talk to your Service. IE entry point on the service's stable IP.
    targetPort: 3000    # this is the port inside the Pod's container to which traffic should be forwarded. Usually matches the containerPort your app listens on. IE destination inside the Pod.
    nodePort: 32000     # Only exists when Service is NodePort type. Opens a port one very node's external IP. Lets you connect from outside the cluster. Its a doorway into the cluster from your laptop/the internet.
```
## namespace.yaml
Creates the namespace needed for this cluster (assignment)
Equivalent of doing `kubectl create namespace assignment`, but its automated so it gets done when `kubectl apply -f k8s/` is run.

Every deployment is reliant on this namespace existing.

## mern-social
mern-social, the full node.js app from the github repository https://github.com/shamahoque/mern-social/tree/second-edition 
### mern-social-deployment.yaml
Sets up the Deployment 

We have one replica currently because we only want to run one instance of the app.

We're setting some environment variables so k8s knows how to communicate from this Deployment to the MongoDB Deployment (not yet created)
We are giving METADATA that says information such as `spec: containers: -name: mern-social ports: -containerPort 3000`. This DOES NOT actually expose tthe port. That is done in the Service. This is for documentation and some tooling and other things, but it doesn't actually do stuff on the netwrok!!
### mern-social-service.yaml
Sets up the Service

This actually handles networking stuff, so it exposes port 3000 which


