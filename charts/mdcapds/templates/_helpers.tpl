{{/*
Copyright (C) 2021 Robin.io All Rights Reserved.
*/}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ds.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "ds.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified etcd name.
*/}}

{{- define "etcd.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.etcd.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.etcd.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "db.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.db.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.db.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "client.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.client.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.client.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{/*
Get the site index by parsing peers and ip
*/}}
{{- define "siteindex" -}}
{{- if not .Values.multiCluster -}}
{{- printf "site0" -}}
{{- else -}}
{{- $IP := .Values.ip -}}
{{- range $index, $peer := .Values.peers -}}
{{- if eq $peer $IP -}}
{{- printf "site%d" $index -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return mdcapdsclient image name
*/}}
{{- define "mdcapdsclient.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.mdcapdsclient.image "global" .Values.global) }}
{{- end -}}

{{/*
Return mdcapdsclient docker image registry secret names
*/}}
{{- define "mdcapdsclient.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.mdcapdsclient.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{/*
Return etcd image name
*/}}
{{- define "etcd.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.etcd.image "global" .Values.global) }}
{{- end -}}

{{/*
Return etcd docker image registry secret names
*/}}
{{- define "etcd.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.etcd.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "etcd.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.etcd.persistentVolume "global" .Values.global) }}
{{- end -}}

{{/*
Return patroniExporter image name
*/}}
{{- define "patroniExporter.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.patroniExporter.image "global" .Values.global) }}
{{- end -}}

{{/*
Return postgresql image name
*/}}
{{- define "postgresql.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.postgresql.image "global" .Values.global) }}
{{- end -}}

{{/*
Return postgresql docker image registry secret names
*/}}
{{- define "postgresql.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.postgresql.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

{{- define "postgresql.storageclass.name" -}}
{{ include "util.storage.class" ( dict "persistentVolume" .Values.postgresql.persistentVolume "global" .Values.global) }}
{{- end -}}

{{/*
Return postgresqlExporter image name
*/}}
{{- define "postgresqlExporter.image" -}}
{{ include "util.images.image" (dict "imageRoot" .Values.postgresqlExporter.image "global" .Values.global) }}
{{- end -}}

{{/*
Return postgresqlExporter docker image registry secret names
*/}}
{{- define "postgresqlExporter.imagePullSecrets" -}}
{{ include "util.images.pullSecrets" ( dict "images" (list .Values.postgresqlExporter.image) "global" .Values.global "credentials" .Values.imageCredentials "releaseName" .Release.Name ) }}
{{- end -}}

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
Generate certificates for etcd
*/}}
{{- define "util.etcd.gen-certs" -}}
{{- $secretName := printf "%s-etcd-tlscerts" .Release.Name -}}
{{- $secretObj := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if $secretObj -}}
{{/*
   Reusing existing secret data
*/}}
{{- $secretData := (get $secretObj "data") }}
ca.crt: {{ (get $secretData "ca.crt") | quote }}
client.crt: {{ (get $secretData "client.crt") | quote }}
client.key: {{ (get $secretData "client.key") | quote }}
peer.crt: {{ (get $secretData "peer.crt") | quote }}
peer.key: {{ (get $secretData "peer.key") | quote }}
server.crt: {{ (get $secretData "server.crt") | quote }}
server.key: {{ (get $secretData "server.key") | quote }}
{{- else -}}
{{- $ca := genCA "*/C=US/ST=CA/L=San Jose/O=Robin.io/OU=MDCAP" 1825 -}}
{{- $server := genSignedCert "*" nil nil 1825 $ca -}}
{{- $client := genSignedCert "*" nil nil 1825 $ca -}}
{{- $peer := genSignedCert "*" nil nil 1825 $ca -}}
ca.crt: {{ $ca.Cert | b64enc }}
client.crt: {{ $client.Cert | b64enc }}
client.key: {{ $client.Key | b64enc }}
peer.crt: {{ $peer.Cert | b64enc }}
peer.key: {{ $peer.Key | b64enc }}
server.crt: {{ $server.Cert | b64enc }}
server.key: {{ $server.Key | b64enc }}
{{- end -}}
{{- end -}}

{{/*
Generate certificates for postgres
*/}}
{{- define "util.postgres.gen-certs" -}}
{{- $secretName := printf "%s-postgresql-tlscerts" .Release.Name -}}
{{- $secretObj := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if $secretObj -}}
{{/*
   Reusing existing secret data
*/}}
{{- $secretData := (get $secretObj "data") }}
cert.pem: {{ (get $secretData "cert.pem") | quote }}
key.pem: {{ (get $secretData "key.pem") | quote }}
{{- else -}}
{{- $ca := genCA "*/C=US/ST=CA/L=San Jose/O=Robin.io/OU=MDCAP" 1825 -}}
{{- $postgres := genSignedCert "*" nil nil 1825 $ca -}}
cert.pem: {{ $postgres.Cert | b64enc }}
key.pem: {{ $postgres.Key | b64enc }}
{{- end -}}
{{- end -}}
{{/*       =============================     */}}
