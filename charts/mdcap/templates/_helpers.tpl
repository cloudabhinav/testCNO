{{/*
Copyright (C) 2021 Robin.io All Rights Reserved.
*/}}

{{/*       Util templates for all charts     */}}
{{/*       =============================     */}}
{{/*
Return the image name
{{ include "util.images.image" ( dict "imageRoot" .Values.path.to.the.image "global" $) }}
*/}}
{{- define "util.images.image" -}}
{{- $registryName := .imageRoot.registry -}}
{{- $repositoryName := .imageRoot.repository -}}
{{- $tag := .imageRoot.tag | toString -}}
{{- if .global }}
    {{- if .global.imageRegistry }}
     {{- $registryName = .global.imageRegistry -}}
    {{- end -}}
{{- end -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else -}}
{{- printf "%s:%s" $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{/*
Return the docker image registry secret names
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.path.to.the.image1, .Values.path.to.the.image2) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
*/}}
{{- define "util.images.pullSecrets" -}}
  {{- $pullSecrets := list }}
  {{- if .global }}
    {{- range .global.imagePullSecrets }}
      {{- $pullSecrets = append $pullSecrets . -}}
    {{- end }}
  {{- end }}
  {{- range .images }}
    {{- range .pullSecrets }}
      {{- $pullSecrets = append $pullSecrets . -}}
    {{- end }}
  {{- end }}
  {{- if .credentials.registry -}}
    {{- $defaultSecret := printf "%s-imagepull-secret" .releaseName -}}
    {{- $pullSecrets = append $pullSecrets $defaultSecret -}}
  {{- end -}}
  {{- if (not (empty $pullSecrets)) -}}
imagePullSecrets:
    {{- range $pullSecrets }}
  - name: {{ . }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Return the storage class name
{{ include "util.storage.class" ( dict "persistentVolume" .Values.path.to.the.persistentVolume "global" $) }}
*/}}
{{- define "util.storage.class" -}}
{{- $storageClassName := .persistentVolume.storageClass | default "" -}}
{{- if or (eq $storageClassName "") (not (hasKey .persistentVolume "storageClass")) }}
    {{- if .global }}
        {{- if .global.storageClass }}
            {{- $storageClassName = .global.storageClass -}}
        {{- end -}}
    {{- end -}}
{{- end -}}
{{- printf "storageClassName: %s" $storageClassName -}}
{{- end -}}


{{/*
Return the annotations for RWX volumes. CNP expects this annotation on PVC for RWX PVs to work.
{{ include "util.storage.rwxAnnotation" ( dict "persistentVolume" .Values.path.to.the.persistentVolume ) }}
*/}}
{{- define "util.storage.rwxAnnotation" -}}
{{- $accessMode := .persistentVolume.accessMode | default "ReadWriteMany" -}}
{{- $replicas := (.persistentVolume.rwxReplicas | default 2) | int -}}
{{- if eq $accessMode "ReadWriteMany" }}
    {{- if eq $replicas 1 -}}
      {{- printf "robin.io/rwx_force_single_replica: \"%d\"" $replicas -}}
    {{- else -}}
      {{- printf "robin.io/replication: \"%d\"" $replicas -}}
    {{- end -}}
{{- end -}}
{{- end -}}
{{/*       =============================     */}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mdcap.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "mdcap.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

#{{/*
#Create the headless service/Pod. This provides the DNS FQDN resolution/pod
#*/}}
#{{- define "mdcap.headlessService" -}}
#apiVersion: v1
#kind: Service
#metadata:
#  name: {{ .Release.Name }}-{{ .SubTemplateArgs.Component }}
#spec:
#  ports:
#  - name: {{ .Release.Name }}-{{ .SubTemplateArgs.Component }}
#    port: 65535
#    protocol: UDP
#    targetPort: 65535
#  selector:
#    app: {{ .Release.Name }}-{{ .SubTemplateArgs.Component }}
#  type: ClusterIP
#  clusterIP: None
#{{- end -}}


{{/*
Create a fully qualified engine name.
*/}}

{{- define "engine.fullname" -}}
{{- if .Values.engine.fullnameOverride -}}
{{- .Values.engine.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.engine.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.engine.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return engine image name
*/}}
{{- define "engine.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.engine.image "global" .Values.global) }}
{{- end -}}

{{/*
Return engine docker image registry secret names
*/}}
{{- define "engine.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.engine.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "grafana.fullname" -}}
{{- if .Values.grafana.fullnameOverride -}}
{{- .Values.grafana.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.grafana.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.grafana.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return grafana image name
*/}}
{{- define "grafana.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.grafana.image "global" .Values.global) }}
{{- end -}}

{{/*
Return grafana docker image registry secret names
*/}}
{{- define "grafana.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.grafana.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "vmetrics.fullname" -}}
{{- if .Values.vmetrics.fullnameOverride -}}
{{- .Values.vmetrics.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.vmetrics.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.vmetrics.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return vmetrics image name
*/}}
{{- define "vmetrics.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.vmetrics.image "global" .Values.global) }}
{{- end -}}

{{/*
Return vmetrics docker image registry secret names
*/}}
{{- define "vmetrics.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.vmetrics.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "artifactory.fullname" -}}
{{- if .Values.artifactory.fullnameOverride -}}
{{- .Values.artifactory.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.artifactory.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.artifactory.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return artifactory image name
*/}}
{{- define "artifactory.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.artifactory.image "global" .Values.global) }}
{{- end -}}

{{/*
Return artifactory docker image registry secret names
*/}}
{{- define "artifactory.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.artifactory.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "eventmgr.fullname" -}}
{{- if .Values.eventmgr.fullnameOverride -}}
{{- .Values.eventmgr.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.eventmgr.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.eventmgr.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return eventmgr image name
*/}}
{{- define "eventmgr.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.eventmgr.image "global" .Values.global) }}
{{- end -}}

{{/*
Return eventmgr docker image registry secret names
*/}}
{{- define "eventmgr.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.eventmgr.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "keycloak.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.keycloak.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "logstore.fullname" -}}
{{- if .Values.logstore.fullnameOverride -}}
{{- .Values.logstore.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.logstore.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.logstore.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return logstore image name
*/}}
{{- define "logstore.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.logstore.image "global" .Values.global) }}
{{- end -}}

{{/*
Return logstore docker image registry secret names
*/}}
{{- define "logstore.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.logstore.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "dashboard.fullname" -}}
{{- if .Values.dashboard.fullnameOverride -}}
{{- .Values.dashboard.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.dashboard.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.dashboard.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return dashboard image name
*/}}
{{- define "dashboard.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.dashboard.image "global" .Values.global) }}
{{- end -}}

{{/*
Return dashboard docker image registry secret names
*/}}
{{- define "dashboard.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.dashboard.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "nginx.fullname" -}}
{{- if .Values.nginx.fullnameOverride -}}
{{- .Values.nginx.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.nginx.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.nginx.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "engine.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.engine.persistentVolume "global" .Values.global) }}
{{- end -}}

{{- define "artifactory.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.artifactory.persistentVolume "global" .Values.global) }}
{{- end -}}

{{- define "eventmgr.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.eventmgr.persistentVolume "global" .Values.global) }}
{{- end -}}

{{- define "logstore.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.logstore.persistentVolume "global" .Values.global) }}
{{- end -}}

{{- define "nginx.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.nginx.persistentVolume "global" .Values.global) }}
{{- end -}}

{{- define "vmetrics.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.vmetrics.persistentVolume "global" .Values.global) }}
{{- end -}}

{{- define "grafana.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.grafana.persistentVolume "global" .Values.global) }}
{{- end -}}

{{- define "imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}


{{- define "mdcap.add.imagePullSecret" }}
{{ if .Values.imageCredentials.registry }}
imagePullSecrets:
  - name:  {{ .Release.Name }}-imagepull-secret
{{- end }}
{{- end }}

{{- define "versionValidateK8s" -}}
{{- printf "%s" .Capabilities.KubeVersion.Version -}}
{{- if .Capabilities.KubeVersion.Version | trimPrefix "v" | semverCompare "<1.19" -}}
{{ required "Robin Version less than 5.3.5 does not support RWX volume access mode. vmetrics can not run without RXW support. Please use --set vmetrics.enabled=false to disable metrics." .value }}
{{- end -}}
{{- end -}}

{{- define "annotationsToStr" -}}
{{- $annstr := "" -}}
{{- range $k, $v := .Values.taskrunner.annotations -}}
{{- $annstr := list $k ":" $v "," | join ""  -}}
{{- printf "%s" $annstr -}}
{{- end -}}
{{- end -}}

# Robin 5.3.5 is K8s 1.20
# robin 5.3.3 is K8s 1.18 
{{- define "robinVersion533" -}}
{{- if .Capabilities.KubeVersion.Version | trimPrefix "v" | semverCompare "<1.19" -}}
{{- printf "%s" "true"  -}}
{{- else -}}
{{- printf "%s" "false"  -}}
{{- end -}}
{{- end -}}

{{/*
Return nginx image name
*/}}
{{- define "nginx.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.nginx.image "global" .Values.global) }}
{{- end -}}

{{/*
Return nginx docker image registry secret names
*/}}
{{- define "nginx.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.nginx.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{/*
Return nginxExporter image name
*/}}
{{- define "nginxExporter.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.nginxExporter.image "global" .Values.global) }}
{{- end -}}

{{/*
Return taskrunner image name
*/}}
{{- define "taskrunner.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.taskrunner.image "global" .Values.global) }}
{{- end -}}

{{/*
Return taskrunner docker image registry secret names
*/}}
{{- define "taskrunner.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.taskrunner.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{/*
Return upgrade image name
*/}}
{{- define "upgrade.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.upgrade.image "global" .Values.global) }}
{{- end -}}

{{/*
Return upgrade docker image registry secret names
*/}}
{{- define "upgrade.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.upgrade.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{/*
Return vault image name
*/}}
{{- define "vault.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.vault.image "global" .Values.global) }}
{{- end -}}

{{/*
Return vault docker image registry secret names
*/}}
{{- define "vault.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.vault.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{/*
Generate certificates for MDCAP
*/}}
{{- define "util.mdcap.gen-certs" -}}
{{- $secretName := printf "%s-etcd-tlscerts" .Release.Name -}}
{{- $secretObj := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if $secretObj -}}
{{/*
   Reusing existing secret data
*/}}
{{- $secretData := (get $secretObj "data") }}
cert.pem: {{ (get $secretData "cert.pem") | quote }}
key.pem: {{ (get $secretData "key.pem") | quote }}
{{- else if $.Values.externalName -}}
{{/*
   Use externalName for CA/CN/IPSAN/SAN
*/}}
{{- $parts := split "." $.Values.externalName -}}
{{- $sanShort := printf "%s" $parts._0 -}}
{{- $fullCAName := printf "%s/C=US/ST=CA/L=San Jose/O=Robin.io/OU=MDCAP" $.Values.externalName -}}
{{- $ca := genCA $fullCAName 1825 -}}
{{- $cert := genSignedCert $.Values.externalName (list $.Values.externalIp) (list $sanShort $.Values.externalName) 1825 $ca -}}
cert.pem: {{ $cert.Cert | b64enc }}
key.pem: {{ $cert.Key | b64enc }}
{{- else }}
{{/*
   Use externalIp for CA/CN/IPSAN/SAN
*/}}
{{- $fullCAName := printf "%s/C=US/ST=CA/L=San Jose/O=Robin.io/OU=MDCAP" $.Values.externalIp -}}
{{- $ca := genCA $fullCAName 1825 -}}
{{- $cert := genSignedCert $.Values.externalIp (list $.Values.externalIp) (list $.Values.externalIp) 1825 $ca -}}
cert.pem: {{ $cert.Cert | b64enc }}
key.pem: {{ $cert.Key | b64enc }}
{{- end -}}
{{- end -}}

{{- define "bmmDeploymentTypeValidate" -}}
{{ $deploymentType := .Values.bmm.deploymentType }}
{{- if or (eq $deploymentType "telus") (eq $deploymentType "ngdu") (eq $deploymentType "rmi") (eq $deploymentType "one_und_one") (eq $deploymentType "na") (eq $deploymentType "non-telco") -}}
{{- printf "%s" $deploymentType -}}
{{- end -}}
{{- end -}}

{{- define "client.fullname" -}}
{{- if .Values.client.fullnameOverride -}}
{{- .Values.client.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.client.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.client.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return client image name
*/}}
{{- define "client.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.client.image "global" .Values.global) }}
{{- end -}}

{{/*
Return client docker image registry secret names
*/}}
{{- define "client.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.client.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "client.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.client.persistentVolume "global" .Values.global) }}
{{- end -}}

{{/*
Return mcp fullname
*/}}
{{- define "mcp.fullname" -}}
{{- if .Values.mcp.fullnameOverride -}}
{{- .Values.mcp.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-mcp" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return mcp image name
*/}}
{{- define "mcp.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.mcp.image "global" .Values.global) }}
{{- end -}}

{{/*
Return mcp docker image registry secret names
*/}}
{{- define "mcp.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.mcp.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}
