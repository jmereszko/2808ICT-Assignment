# K8S YAML FILES


# Deployments (general idea):
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
    nodePort: 32000     # Only exists when Service is NodePort type. Opens a port one every node's external IP. Lets you connect from outside the cluster. Its a doorway into the cluster from your laptop/the internet.
```

A Kubernetes Service operates at L3/L4 of the OSI model. It provides a stable ClusterIP (L3) and forwards traffic based on TCP/UDP ports (L4). It does not inspect or route based on application-layer (L7) data like URLs or headers — that’s the role of an Ingress or reverse proxy. The actual app (mern-social) sits at L7 and processes HTTP requests.

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

We want one thing:
1) for us to be able to go to http://{minikube-ip}:32000/ and access the mern-social app on a web browser on this device.  

`http://{minikube-ip}:32000/` means "send traffic to Minikube's VM at port 32000".

(minikube is just a small k8s cluster running on a machine btw)

By setting `NodePort: 32000`, we give k8s a rule:
- "Any traffic hitting the cluster's node on port 32000 goes to the `mern-social` Service.".
This is the entry point from OUTSIDE the cluster (think Transport/Network OSI layers. By setting NodePort32000, a web browser (like w3m) can now open a TCP connection to `http://{minikube-ip}:32000/`.)

By setting `port: 3000` in this Service, port 3000 is now exposed inside the cluster. 
That means the TCP traffic that arrived at NodePort 32000 will be forwarded into this 
Service’s port 3000. 

The Service then sends that traffic to the `targetPort` defined for the backing Pods. 
Each port entry in a Service maps one `port` → one `targetPort`, but a Service can 
have multiple such entries if the Pods expose multiple ports (for example, HTTP on 
8080 and admin on 9090). 

In our case, we only defined one mapping: Service port 3000 → Pod targetPort 3000. 
Since the mern-social container is listening on port 3000, the traffic arrives where 
the Express app can handle it.

By setting `targetPort` in this Service to 3000, the Service now knows it needs to deliver this traffic to one of the backing Pods. It is basically now told "inside the Pod, send this TCP traffic to port 3000". 

Since mern-social's Deployment is LISTENING on port 3000 (we previously set `containerPort: 3000`, which describes that in the node.js, the Express app is listening on port 3000. This is defined by the architecture of the MERN app.), the app code will know to handle the HTTP request.

So the chain is:  
Browser → NodePort 32000 → Service port 3000 → targetPort 3000 → Pod containerPort 3000 → Express app.


