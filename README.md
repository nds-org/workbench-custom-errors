# workbench-custom-errors

A simple NGINX instance for serving custom error messages for Kubernetes Ingress


Cases handled:
- 401: Unauthoirzed (via OAuth2)
- 503: Gateway Temporarily Unavailable (Pod is starting)

## Development
After making modifications, build + push the container image using the following:
```shell
$ docker compose build && docker compose push
```

## Deploying
This can be deployed using any NGINX Helm chart, for example:
https://artifacthub.io/packages/helm/bitnami/nginx

Add the Bitnami Helm repo:
```shell
$ helm repo add bitnami https://charts.bitnami.com/bitnami  
$ helm repo update
```

Install the NGINX helm chart using our custom image:
```shell
$ helm upgrade --install -n workbench custom-errors bitnami/nginx --set image.repository=ndslabs/custom-errors --set image.tag=latest
```

## Setting Up the Middleware

Create `middleware` for Traefik that points to this new NGINX for custom-errors

One middleware will use OAuth2 proxy and cookies to check if the user is logged in, and return 401 if they are not:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: forwardauth
  namespace: workbench
spec:
  forwardAuth:
    address: https://kubernetes.docker.internal/oauth2/auth
    authResponseHeaders:
    - X-Auth-Request-Access-Token
    - Authorization
    authResponseHeadersRegex: ^X-
    tls:
      insecureSkipVerify: true
    trustForwardHeader: true
```

And another middleware will override the default 401 "Unauthorized" page to serve our custom error page:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: redirect-to-login
  namespace: workbench
spec:
  errors:
    query: /401.html
    service:
      name: custom-errors-nginx
      port: 80
    status:
    - "401"
```

## Applying the Middleware to particular Ingress rules

The last step is to apply the middle (in the correct order) to the Ingress rules which we would like to protect:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/force-ssl-redirect: "true"
    ingress.kubernetes.io/ssl-redirect: "true"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.middlewares: workbench-redirect-to-login@kubernetescrd,workbench-forwardauth@kubernetescrd
    traefik.ingress.kubernetes.io/router.tls: "true"
  labels:
    manager: workbench
    user: testlocalhost
    workbench-app: s67487
  name: testlocalhost-s67487-toolmanager
  namespace: workbench
spec:
  ingressClassName: traefik
  rules:
  - host: testlocalhost-s67487-toolmanager.kubernetes.docker.internal
    http:
      paths:
      - backend:
          service:
            name: testlocalhost-s67487-toolmanager
            port:
              number: 8082
        path: /
        pathType: ImplementationSpecific
  tls:
  - hosts:
    - kubernetes.docker.internal
    - '*.kubernetes.docker.internal'
```
### Format
Note the `traefik.ingress.kubernetes.io/router.middlewares` annotation value contains references to our created middleware pieces in the following format:
```
{namespace}-{name}@{provider}
```

For our example:
* `{namespace}` is `workbench`
* `{name}` is each of our created middlewares above
* `{provider}` is `kubernetescrd`, since we are using the Kubernetes Custom Resource Definitions (CRDs) provided by Traefik

Note that the **order** in which the middleware is defined DOES matter

## Testing
Attempt to navigate to your Ingress host.

For our example above, this would be https://testlocalhost-s67487-toolmanager.kubernetes.docker.internal

What you should see:
* If user is already logged in, they can immediately see the expected app running under this Ingress rule
* If user is NOT logged in, they are denied with an "Unquthorized" message and given a link to to "Sign In" again
    * Additionally this custom error page will automatically redirect the user to OAuth2 Proxy / Keycloak for sign in


## TODOs
* Some styling might be nice - right now these are just raw JS embedded in HTML
* It would be nice to handle HTTP -> HTTPS redirects in a somewhat generic way
* Handle additional generic errors - e.g. 503 could refresh the page until the app becomes available (this is how Workbench V1 worked at one point)
