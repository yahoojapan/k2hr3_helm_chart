## Helm Chart for K2HR3 (K2Hdkc based Resource and Roles and policy Rules)
This repository defines a **Helm Chart** for deploying **K2HR3 systems** on Kubernetes cluster.  
The code in this repository is packaged as Helm Chart and distributed from [Artifact Hub](https://artifacthub.io/packages/helm/k2hr3/k2hr3).  

You can download the Helm Chart for K2HR3 from Artifact Hub and use it right away.

![K2HR3 system overview](https://k2hr3.antpick.ax/images/top_k2hr3_helm.png){: width="60%" height="60%"}

K2HR3 is built [k2hdkc](https://github.com/yahoojapan/k2hdkc), [k2hash](https://github.com/yahoojapan/k2hash), [chmpx](https://github.com/yahoojapan/chmpx) and [k2hash transaction plugin](https://github.com/yahoojapan/k2htp_dtor) components by [AntPickax](https://antpick.ax/).

## Customization
The following options/values are supported. See values.yaml for more detailed documentation and examples:

| Parameter                      | Type         | Description                                                                                                                         | Default |
|--------------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------|---------|
| `nameOverride`                 | optional     | Override release part of fully name, if not specified fullnameOverride value.                                                       | `k2hr3` |
| `fullnameOverride`             | optional     | Override fully chart/release name                                                                                                   | n/a     |
| `serviceAccount.create`        | optional     | Specifies whether to create a service account, default is true.                                                                     | true    |
| `serviceAccount.annotations`   | optional     | Annotations to add to the service account, default is empty.                                                                        | {}      |
| `serviceAccount.name`          | optional     | Specifies Service account name, default is empty. If not set and create is true, a name is generated using the fullname template.   | ""      |
| `antpickax.configDir`          | optional     | Configration directory path for AntPickax products.                                                                                 | "/etc/antpickax" |
| `antpickax.certPeriodYear`     | optional     | Period years for self signed certificates using in pods.                                                                            | 5       |
| `minikube`                     | optional     | Specify whether or not it is a minikube environment.                                                                                | false   |
| `k2hr3.clusterName`            | optional     | Specify a cluster name for K2HR3 system, default is empty. If not set, a name is Release name(.Release.Name).                       | ""      |
| `k2hr3.startManual`            | optional     | Specifies whether to boot the k2hr3 system manually. This is a flag for debugging.                                                  | false   |
| `k2hr3.baseDomain`             | optional     | Specifies the base domain name for the k2hr3 system. The default is empty, if empty k8s.domain is used.                             | ""      |
| `k2hr3.dkc.baseName`           | optional     | Specify the base name for K2HDKC cluster, default is empty in which case "r3dkc" will be used.                                      | ""      |
| `k2hr3.dkc.count`              | optional     | Specify the server count in K2HKDC cluster.                                                                                         | 2       |
| `k2hr3.api.baseName`           | optional     | Specify the base name for K2HR3 REST API, default is empty in which case "r3api" will be used.                                      | ""      |
| `k2hr3.api.count`              | optional     | Specify the server count of K2HR3 REST API.                                                                                         | 2       |
| `k2hr3.api.extHostname`        | optional     | Specify the external hostname(FQDN) for K2HR3 REST API system, default is empty in which case internal hostanme will be used.       | ""      |
| `k2hr3.api.extPort`            | optional     | Specify the external port number for K2HR3 REST API system, default is 0 in which case 31443 will be used.                          | 0       |
| `k2hr3.app.baseName`           | optional     | Specify the base name for K2HR3 Web Application, default is empty in which case "r3app" will be used.                               | ""      |
| `k2hr3.app.count`              | optional     | Specify the server count of K2HR3 Web Application.                                                                                  | 2       |
| `k2hr3.app.extHostname`        | optional     | Specify the external hostname(FQDN) for K2HR3 Web Application system, default is empty in which case internal hostanme will be used.| ""      |
| `k2hr3.app.extPort`            | optional     | Specify the external port number for K2HR3 Web Application system, default is 0 in which case 32443 will be used.                   | 0       |
| `mountPoint.configMap`         | optional     | Specify the directory path in each pods to mount the configmap.                                                                     | "/configmap" |
| `mountPoint.ca`                | optional     | Specify the directory path in each pods to mount the secret which has CA self signed certificates.                                  | "/secret-ca" |
| `k8s.namespace`                | optional     | Specify the kubernetes namespace to deploy K2HR3 system, default is empty. If not set, use Release.Namespace.                       | ""      |
| `k8s.domain`                   | optional     | Specify the domain name of the kubernetes cluster to deploy K2HR3 system.                                                           | "svc.cluster.local" |
| `k8s.caCert`                   | optional     | Specify the CA certificate file path for the kubernetes API.                                                                        | "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt" |
| `k8s.saToken`                  | optional     | Specify the token file path for the Service account.                                                                                | "/var/run/secrets/kubernetes.io/serviceaccount/token" |
| `k8s.apiUrl`                   | optional     | Specify the kubernetes API URL.                                                                                                     | "https://kubernetes.default.svc" |
| `oidc.clientId`                | **required** | Specify the OpenID Connect Client ID.                                                                                               | n/a     |
| `oidc.clientSecret`            | **required** | Specify the OpenID Connect Secret.                                                                                                  | n/a     |
| `oidc.cookieExpire`            | **required** | Specify the OpenID Connect Cookie Expire.                                                                                           | n/a     |
| `oidc.cookieName`              | **required** | Specify the OpenID Connect Cookie Name.                                                                                             | n/a     |
| `oidc.issuerUrl`               | **required** | Specify the OpenID Connect Issuer URL.                                                                                              | n/a     |
| `oidc.usernameKey`             | optional     | Specify the OpenID Connect user key name, default is empty.                                                                         | ""      |
| `unconvertedFiles.k2hr3`       | optional     | Specify the files(unconverted) to be placed in configmap. Normally, you do not need to change this value.                           | files/*.sh |
| `convertedFiles.k2hr3`         | optional     | Specify the files(converted) to be placed in configmap. Normally, you do not need to change this value.                             | files/*.sh |

## Usage
You can deploy and remove K2HR3 systems to your Kubernetes cluster in the order shown below.

### Add Helm Chart repository
```
$ helm repo add k2hr3 https://helm.k2hr3.antpick.ax/
```

### Install
You can install by specifying the `release name` and `required options`.  
If you are using the `minikube` environment and want to install to that minikube, please add `--set minikube=true` option.  
```
$ helm install <release name> k2hr3 \
    --set k2hr3.api.extHostname=<endpoint hostname for k2hr3 api> \
    --set k2hr3.app.extHostname=<endpoint hostname for k2hr3 app> \
    --set oidc.clientId=<OpenID Connect Client ID> \
    --set oidc.clientSecret=<OpenID Connect Secret> \
    --set oidc.cookieExpire=<OpenID Connect Cookie Expire(ex, 120)> \
    --set oidc.cookieName=<OpenID Connect Cookie Name(ex, id_token)> \
    --set oidc.issuerUrl=<OpenID Connect Issuer URL(ex, https://hoge/dex)> \
    --set oidc.usernameKey=<OpenID Connect user key name> \
    (--set minikube=true)
```

### Test after install
You can check whether the installed Helm Chart is working properly as follows.  
```
$ helm test <release name>
```

### Uninstall
You can uninstall the installed Helm Chart by doing the following.  
```
$ helm uninstall <release name>
```

### Other operation
Other operations can be performed using the Helm command.  
See `helm --help` for more information.

## Use with RANCHER
K2HR3 Helm Chart can be used by registering the repository in [RANCHER](https://rancher.com/).  
[RANCHER](https://rancher.com/) allows you to use K2HR3 Helm Chart with more intuitive and simpler operations than using the `helm` command.  
See the [K2HR3 Helm Chart documentation](https://github.com/yahoojapan/k2hr3_helm_chart) for more details.  

## Documents
[K2HR3 Document](https://k2hr3.antpick.ax/index.html)  
[K2HR3 Web Application Usage](https://k2hr3.antpick.ax/usage_app.html)  
[K2HR3 Command Line Interface Usage](https://k2hr3.antpick.ax/cli.html)  
[K2HR3 REST API Usage](https://k2hr3.antpick.ax/api.html)  
[K2HR3 Demonstration](https://demo.k2hr3.antpick.ax/)

[About AntPickax](https://antpick.ax/)  

## Repositories
[K2HR3 Helm Chart](https://github.com/yahoojapan/k2hr3_helm_chart)  
[K2HR3 main repository](https://github.com/yahoojapan/k2hr3)  
[K2HR3 Web Application repository](https://github.com/yahoojapan/k2hr3_app)  
[K2HR3 Command Line Interface repository](https://github.com/yahoojapan/k2hr3_cli)  
[K2HR3 REST API repository](https://github.com/yahoojapan/k2hr3_api)  

## License
This software is released under the MIT License, see the license file.

## AntPickax
K2HR3 is one of [AntPickax](https://antpick.ax/) products.

Copyright(C) 2022 Yahoo Japan Corporation.
