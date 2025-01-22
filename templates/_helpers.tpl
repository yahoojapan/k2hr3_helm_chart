{{-
/*
*
* K2HR3 Helm Chart
*
* Copyright 2022 Yahoo Japan Corporation.
*
* K2HR3 is K2hdkc based Resource and Roles and policy Rules, gathers 
* common management information for the cloud.
* K2HR3 can dynamically manage information as "who", "what", "operate".
* These are stored as roles, resources, policies in K2hdkc, and the
* client system can dynamically read and modify these information.
*
* For the full copyright and license information, please view
* the license file that was distributed with this source code.
*
* AUTHOR:   Takeshi Nakatani
* CREATE:   Wed Jan 19 2022
* REVISION:
*
*/ -}}

{{-
/*---------------------------------------------------------
* Expand the name of the chart.
*
*/}}
{{- define "k2hr3.name" -}}
	{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{-
/*---------------------------------------------------------
* Create a default fully qualified app name.
*
* We truncate at 63 chars because some Kubernetes name fields
* are limited to this (by the DNS naming spec).
* If release name contains chart name it will be used as a full
* name.
*
*/}}
{{- define "k2hr3.fullname" -}}
	{{- if .Values.fullnameOverride }}
		{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
	{{- else }}
		{{- $name := default .Chart.Name .Values.nameOverride }}
		{{- if contains $name .Release.Name }}
			{{- .Release.Name | trunc 63 | trimSuffix "-" }}
		{{- else }}
			{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
		{{- end }}
	{{- end }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set k2hr3 cluster name for dbaas.
*
*/}}
{{- define "k2hr3.clusterName" -}}
	{{- $tmpname := default .Release.Name .Values.k2hr3.clusterName }}
	{{- printf "%s" $tmpname | trunc 63 | trimSuffix "-" }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set kubernetes namespace.
*
*/}}
{{- define "k2hr3.k8sNamespace" -}}
	{{- $tmpname := default .Release.Namespace .Values.k8s.namespace }}
	{{- printf "%s" $tmpname }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set base domain(fqdn) for dbaas and k2hr3.
*
*/}}
{{- define "k2hr3.k2hr3BaseDomain" -}}
	{{- $tmpdomain := default .Values.k8s.domain .Values.k2hr3.baseDomain }}
	{{- printf "%s" $tmpdomain }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set base name / external hostname for k2hr3.
*
*/}}
{{- define "k2hr3.r3dkcBaseName" -}}
	{{- if .Values.k2hr3.dkc.baseName }}
		{{- .Values.k2hr3.dkc.baseName }}
	{{- else }}
		{{- $tmpbasename := include "k2hr3.clusterName" . }}
		{{- printf "r3dkc-%s" $tmpbasename }}
	{{- end }}
{{- end }}

{{- define "k2hr3.r3apiBaseName" -}}
	{{- if .Values.k2hr3.api.baseName }}
		{{- .Values.k2hr3.api.baseName }}
	{{- else }}
		{{- $tmpbasename := include "k2hr3.clusterName" . }}
		{{- printf "r3api-%s" $tmpbasename }}
	{{- end }}
{{- end }}

{{- define "k2hr3.r3appBaseName" -}}
	{{- if .Values.k2hr3.app.baseName }}
		{{- .Values.k2hr3.app.baseName }}
	{{- else }}
		{{- $tmpbasename := include "k2hr3.clusterName" . }}
		{{- printf "r3app-%s" $tmpbasename }}
	{{- end }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set external/internal hostname for k2hr3 system.
*
*/}}
{{- define "k2hr3.r3apiIntHostname" -}}
	{{- printf "svc-%s.%s.%s" (include "k2hr3.r3apiBaseName" .) (include "k2hr3.k8sNamespace" .) (include "k2hr3.k2hr3BaseDomain" .) }}
{{- end }}

{{- define "k2hr3.r3apiExtHostname" -}}
	{{- if .Values.k2hr3.api.extHostname }}
		{{- .Values.k2hr3.api.extHostname }}
	{{- else }}
		{{- printf "localhost" }}
	{{- end }}
{{- end }}

{{- define "k2hr3.r3appExtHostname" -}}
	{{- if .Values.k2hr3.app.extHostname }}
		{{- .Values.k2hr3.app.extHostname }}
	{{- else }}
		{{- printf "localhost" }}
	{{- end }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set external port for k2hr3 system.
*
*/}}
{{- define "k2hr3.r3apiExtPort" -}}
	{{- $tmpport := default 31443 .Values.k2hr3.api.extPort }}
	{{- printf "%d" $tmpport }}
{{- end }}

{{- define "k2hr3.r3apiNodePort" -}}
	{{ include "k2hr3.r3apiExtPort" . }}
{{- end }}

{{- define "k2hr3.r3appExtPort" -}}
	{{- $tmpport := default 32443 .Values.k2hr3.app.extPort }}
	{{- printf "%d" $tmpport }}
{{- end }}

{{- define "k2hr3.r3appNodePort" -}}
	{{ include "k2hr3.r3appExtPort" . }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set custom configration(local.json(local.json5)) for k2hr3 system.
*
*/}}
{{- define "k2hr3.r3apiCustomConf" -}}
	{{- default "" .Values.k2hr3.api.customConf }}
{{- end }}

{{- define "k2hr3.r3appCustomConf" -}}
	{{- default "" .Values.k2hr3.app.customConf }}
{{- end }}

/*---------------------------------------------------------
* Set local tenant configration(local.json(local.json5)) for k2hr3 system.
*
*/}}
{{- define "k2hr3.r3apiLocalTenant" -}}
	{{- .Values.k2hr3.api.localTenant }}
{{- end }}

{{- define "k2hr3.r3appLocalTenant" -}}
	{{- .Values.k2hr3.app.localTenant }}
{{- end }}

{{-
/*---------------------------------------------------------
* Create chart name and version as used by the chart label.
*
*/}}
{{- define "k2hr3.chart" -}}
	{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{-
/*---------------------------------------------------------
* Common labels
*
*/}}
{{- define "k2hr3.labels" -}}
helm.sh/chart: {{ include "k2hr3.chart" . }}
{{ include "k2hr3.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{-
/*---------------------------------------------------------
* Selector labels
*
*/}}
{{- define "k2hr3.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k2hr3.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{-
/*---------------------------------------------------------
* Create the name of the service account to use
*
*/}}
{{- define "k2hr3.serviceAccountName" -}}
	{{- if .Values.serviceAccount.create }}
		{{- if .Values.serviceAccount.name }}
			{{- .Values.serviceAccount.name }}
		{{- else }}
			{{- printf "sa-%s" (include "k2hr3.r3apiBaseName" .) }}
		{{- end }}
	{{- else }}
		{{- default "default" .Values.serviceAccount.name }}
	{{- end }}
{{- end }}

{{-
/*---------------------------------------------------------
* Create self-signed CA and server certs
*
* [NOTE] not set subjects for country etc...
*
*/}}
{{- define "k2hr3.certPeriodDays" -}}
	{{- int (mul .Values.antpickax.certPeriodYear 365) }}
{{- end }}

{{- define "k2hr3.cacert" -}}
{{- $tmpcadomain := printf "%s.%s" (include "k2hr3.k8sNamespace" .) (include "k2hr3.k2hr3BaseDomain" .) }}
{{- $tmpperioddays := int (include "k2hr3.certPeriodDays" .) }}
{{- $ca := genCA $tmpcadomain $tmpperioddays }}
Cert: {{ b64enc $ca.Cert }}
Key: {{ b64enc $ca.Key }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set organization and version fo images
*
* K2HR3 APP Image ( tmpAppImage / images.k2hr3appImage )
*/
-}}
{{- define "images.k2hr3appImage" -}}
	{{- if .Values.images.app.fullImageName }}
		{{- default "" .Values.images.app.fullImageName }}
	{{- else }}
		{{- $tmpapporg  := default "antpickax" .Values.images.default.organization }}
		{{- $tmpappname := "k2hr3-app" }}
		{{- $tmpappver  := "1.0.39" }}
		{{- if .Values.images.app.organization }}
			{{- $tmpapporg = .Values.images.app.organization }}
		{{- end }}
		{{- if .Values.images.app.imageName }}
			{{- $tmpappname = .Values.images.app.imageName }}
		{{- end }}
		{{- if .Values.images.app.version }}
			{{- $tmpappver = .Values.images.app.version }}
		{{- end }}
		{{- printf "%s/%s:%s" $tmpapporg $tmpappname $tmpappver }}
	{{- end }}
{{- end }}

{{-
/*
* K2HR3 API Image ( tmpApiImage / images.k2hr3apiImage )
*/
-}}
{{- define "images.k2hr3apiImage" -}}
	{{- if .Values.images.api.fullImageName }}
		{{- default "" .Values.images.api.fullImageName }}
	{{- else }}
		{{- $tmpapiorg  := default "antpickax" .Values.images.default.organization }}
		{{- $tmpapiname := "k2hr3-api" }}
		{{- $tmpapiver  := "1.0.38" }}
		{{- if .Values.images.api.organization }}
			{{- $tmpapiorg = .Values.images.api.organization }}
		{{- end }}
		{{- if .Values.images.api.imageName }}
			{{- $tmpapiname = .Values.images.api.imageName }}
		{{- end }}
		{{- if .Values.images.api.version }}
			{{- $tmpapiver = .Values.images.api.version }}
		{{- end }}
		{{- printf "%s/%s:%s" $tmpapiorg $tmpapiname $tmpapiver }}
	{{- end }}
{{- end }}

{{-
/*
* K2HDKC Image ( tmpDkcImage / images.k2hdkcImage )
*/
-}}
{{- define "images.k2hdkcImage" -}}
	{{- if .Values.images.dkc.fullImageName }}
		{{- default "" .Values.images.dkc.fullImageName }}
	{{- else }}
		{{- $tmpdkcorg  := default "antpickax" .Values.images.default.organization }}
		{{- $tmpdkcname := "k2hdkc" }}
		{{- $tmpdkcver  := "1.0.14" }}
		{{- if .Values.images.dkc.organization }}
			{{- $tmpdkcorg = .Values.images.dkc.organization }}
		{{- end }}
		{{- if .Values.images.dkc.imageName }}
			{{- $tmpdkcname = .Values.images.dkc.imageName }}
		{{- end }}
		{{- if .Values.images.dkc.version }}
			{{- $tmpdkcver = .Values.images.dkc.version }}
		{{- end }}
		{{- printf "%s/%s:%s" $tmpdkcorg $tmpdkcname $tmpdkcver }}
	{{- end }}
{{- end }}

{{-
/*
* Chmpx Image ( tmpChmpxImage / images.chmpxImage )
*/
-}}
{{- define "images.chmpxImage" -}}
	{{- if .Values.images.chmpx.fullImageName }}
		{{- default "" .Values.images.chmpx.fullImageName }}
	{{- else }}
		{{- $tmpchmpxorg  := default "antpickax" .Values.images.default.organization }}
		{{- $tmpchmpxname := "chmpx" }}
		{{- $tmpchmpxver  := "1.0.106" }}
		{{- if .Values.images.chmpx.organization }}
			{{- $tmpchmpxorg = .Values.images.chmpx.organization }}
		{{- end }}
		{{- if .Values.images.chmpx.imageName }}
			{{- $tmpchmpxname = .Values.images.chmpx.imageName }}
		{{- end }}
		{{- if .Values.images.chmpx.version }}
			{{- $tmpchmpxver = .Values.images.chmpx.version }}
		{{- end }}
		{{- printf "%s/%s:%s" $tmpchmpxorg $tmpchmpxname $tmpchmpxver }}
	{{- end }}
{{- end }}

{{-
/*
* Init Image ( tmpInitImage / images.initImage )
*/
-}}
{{- define "images.initImage" -}}
	{{- if .Values.images.init.fullImageName }}
		{{- default "" .Values.images.init.fullImageName }}
	{{- else }}
		{{- $tmpinitorg  := "" }}
		{{- $tmpinitname := "alpine" }}
		{{- $tmpinitver  := "3.20" }}
		{{- if .Values.images.init.organization }}
			{{- $tmpinitorg = .Values.images.init.organization }}
		{{- end }}
		{{- if .Values.images.init.imageName }}
			{{- $tmpinitname = .Values.images.init.imageName }}
		{{- end }}
		{{- if .Values.images.init.version }}
			{{- $tmpinitver = .Values.images.init.version }}
		{{- end }}
		{{- if $tmpinitorg }}
			{{- printf "%s/%s:%s" $tmpinitorg $tmpinitname $tmpinitver }}
		{{- else }}
			{{- printf "%s:%s" $tmpinitname $tmpinitver }}
		{{- end }}
	{{- end }}
{{- end }}

{{-
/*---------------------------------------------------------
* Set PROXY environments for k2hr3 system.
*
* Schema separation for Base proxy environment
*/}}
{{- define "tmp.HttpProxyWS" -}}
	{{- if .Values.k2hr3.env.httpProxy }}
		{{- if contains "http://" .Values.k2hr3.env.httpProxy }}
			{{- default "" .Values.k2hr3.env.httpProxy }}
		{{- else if contains "https://" .Values.k2hr3.env.httpProxy }}
			{{- default "" .Values.k2hr3.env.httpProxy }}
		{{- else }}
			{{- printf "http://%s" .Values.k2hr3.env.httpProxy }}
		{{- end }}
	{{- else }}
		{{- default "" .Values.k2hr3.env.httpProxy }}
	{{- end }}
{{- end }}

{{- define "tmp.HttpProxy" -}}
	{{- if .Values.k2hr3.env.httpProxy }}
		{{- if contains "http://" .Values.k2hr3.env.httpProxy }}
			{{- default "" .Values.k2hr3.env.httpProxy | replace "http://" "" }}
		{{- else if contains "https://" .Values.k2hr3.env.httpProxy }}
			{{- default "" .Values.k2hr3.env.httpProxy | replace "https://" "" }}
		{{- else }}
			{{- default "" .Values.k2hr3.env.httpProxy }}
		{{- end }}
	{{- else }}
		{{- default "" .Values.k2hr3.env.httpProxy }}
	{{- end }}
{{- end }}

{{- define "tmp.HttpsProxyWS" -}}
	{{- if .Values.k2hr3.env.httpsProxy }}
		{{- if contains "http://" .Values.k2hr3.env.httpsProxy }}
			{{- default "" .Values.k2hr3.env.httpsProxy }}
		{{- else if contains "https://" .Values.k2hr3.env.httpsProxy }}
			{{- default "" .Values.k2hr3.env.httpsProxy }}
		{{- else }}
			{{- printf "http://%s" .Values.k2hr3.env.httpsProxy }}
		{{- end }}
	{{- else }}
		{{- default "" .Values.k2hr3.env.httpsProxy }}
	{{- end }}
{{- end }}

{{- define "tmp.HttpsProxy" -}}
	{{- if .Values.k2hr3.env.httpsProxy }}
		{{- if contains "http://" .Values.k2hr3.env.httpsProxy }}
			{{- default "" .Values.k2hr3.env.httpsProxy | replace "http://" "" }}
		{{- else if contains "https://" .Values.k2hr3.env.httpsProxy }}
			{{- default "" .Values.k2hr3.env.httpsProxy | replace "https://" "" }}
		{{- else }}
			{{- default "" .Values.k2hr3.env.httpsProxy }}
		{{- end }}
	{{- else }}
		{{- default "" .Values.k2hr3.env.httpsProxy }}
	{{- end }}
{{- end }}

{{-
/*
* PROXY Environment for K2HR3 APP
*/
-}}
{{- define "env.app.httpProxy" -}}
	{{- if contains "alpine" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.app.httpsProxy" -}}
	{{- if contains "alpine" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "images.k2hr3appImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.app.noProxy" -}}
	{{- default "" .Values.k2hr3.env.noProxy }}
{{- end }}

{{-
/*
* PROXY Environment for K2HR3 API
*/
-}}
{{- define "env.api.httpProxy" -}}
	{{- if contains "alpine" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.api.httpsProxy" -}}
	{{- if contains "alpine" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "images.k2hr3apiImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.api.noProxy" -}}
	{{- default "" .Values.k2hr3.env.noProxy }}
{{- end }}

{{-
/*
* PROXY Environment for K2HDKC
*/
-}}
{{- define "env.dkc.httpProxy" -}}
	{{- if contains "alpine" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.dkc.httpsProxy" -}}
	{{- if contains "alpine" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "images.k2hdkcImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.dkc.noProxy" -}}
	{{- default "" .Values.k2hr3.env.noProxy }}
{{- end }}

{{-
/*
* PROXY Environment for CHMPX
*/
-}}
{{- define "env.chmpx.httpProxy" -}}
	{{- if contains "alpine" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.chmpx.httpsProxy" -}}
	{{- if contains "alpine" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "images.chmpxImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.chmpx.noProxy" -}}
	{{- default "" .Values.k2hr3.env.noProxy }}
{{- end }}

{{-
/*
* PROXY Environment for Init
*/
-}}
{{- define "env.init.httpProxy" -}}
	{{- if contains "alpine" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- else if contains "debian" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "ubuntu" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "rocky" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "centos" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else if contains "fedora" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.init.httpsProxy" -}}
	{{- if contains "alpine" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- else if contains "debian" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "ubuntu" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "rocky" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "centos" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else if contains "fedora" (include "images.initImage" .) }}
		{{- printf "%s" (include "tmp.HttpsProxy" .) }}
	{{- else }}
		{{- printf "%s" (include "tmp.HttpsProxyWS" .) }}
	{{- end }}
{{- end }}
{{- define "env.init.noProxy" -}}
	{{- default "" .Values.k2hr3.env.noProxy }}
{{- end }}

/*---------------------------------------------------------
* Set CHMPX ini file name for k2hr3 API system.
*
*/}}
{{- define "k2hr3.r3apiIniFilename" -}}
	{{- if contains "alpine" (include "images.k2hr3apiImage" .) }}
		{{- printf "slave.ini" }}
	{{- else if contains "debian" (include "images.k2hr3apiImage" .) }}
		{{- printf "slave.ini" }}
	{{- else if contains "ubuntu" (include "images.k2hr3apiImage" .) }}
		{{- printf "slave.ini" }}
	{{- else if contains "rocky" (include "images.k2hr3apiImage" .) }}
		{{- printf "nss_slave.ini" }}
	{{- else if contains "centos" (include "images.k2hr3apiImage" .) }}
		{{- printf "slave.ini" }}
	{{- else if contains "fedora" (include "images.k2hr3apiImage" .) }}
		{{- printf "nss_slave.ini" }}
	{{- else }}
		{{- printf "slave.ini" }}
	{{- end }}
{{- end }}

{{-
/*
* Local variables:
* tab-width: 4
* c-basic-offset: 4
* End:
* vim600: noexpandtab sw=4 ts=4 fdm=marker
* vim<600: noexpandtab sw=4 ts=4
*/ -}}
