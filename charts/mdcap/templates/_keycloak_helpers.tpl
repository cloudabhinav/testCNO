{{/*
Copyright (C) 2021 Robin.io All Rights Reserved.
*/}}

{{/*
Render a template value that may itself contain template directives.
*/}}
{{- define "common.tplvalues.render" -}}
{{- $value := typeIs "string" .value | ternary .value (.value | toYaml) }}
{{- if contains "{{" (toJson .value) }}
  {{- if .scope }}
    {{- tpl (cat "{{- with $.RelativeScope -}}" $value "{{- end }}") (merge (dict "RelativeScope" .scope) .context) }}
  {{- else }}
    {{- tpl $value .context }}
  {{- end }}
{{- else }}
  {{- $value }}
{{- end }}
{{- end -}}

{{/*
Render a security context, stripping fields incompatible with OpenShift
and removing the internal "enabled" key before passing to Kubernetes.
*/}}
{{- define "common.compatibility.renderSecurityContext" -}}
{{- $adaptedContext := .secContext -}}
{{- if (((.context.Values.global).compatibility).openshift) -}}
  {{- if or (eq .context.Values.global.compatibility.openshift.adaptSecurityContext "force")
            (and (eq .context.Values.global.compatibility.openshift.adaptSecurityContext "auto")
                 (include "common.compatibility.isOpenshift" .context)) -}}
    {{- $adaptedContext = omit $adaptedContext "fsGroup" "runAsUser" "runAsGroup" -}}
    {{- if not .secContext.seLinuxOptions -}}
      {{- $adaptedContext = omit $adaptedContext "seLinuxOptions" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if and (((.context.Values.global).compatibility).omitEmptySeLinuxOptions)
           (not .secContext.seLinuxOptions) -}}
  {{- $adaptedContext = omit $adaptedContext "seLinuxOptions" -}}
{{- end -}}
{{- if $adaptedContext.privileged -}}
  {{- $adaptedContext = omit $adaptedContext "capabilities" -}}
{{- end -}}
{{- omit $adaptedContext "enabled" | toYaml -}}
{{- end -}}

{{/*
Create a fully qualified Keycloak name derived from the release name.
Respects keycloak.fullnameOverride if set.
Truncated to 63 chars per DNS spec.
*/}}
{{- define "keycloak.fullname" -}}
{{- if .Values.keycloak.fullnameOverride -}}
  {{- .Values.keycloak.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
  {{- printf "%s-keycloak" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database hostname.
Uses internal PostgreSQL fullname if postgresql.enabled, otherwise externalDatabase.host.
*/}}
{{- define "keycloak.database.host" -}}
{{- if .Values.keycloak.postgresql.enabled -}}
  {{- printf "%s-postgresql" .Release.Name -}}
  {{- if eq .Values.keycloak.postgresql.architecture "replication" -}}-primary{{- end -}}
{{- else -}}
  {{- tpl .Values.keycloak.externalDatabase.host . -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database port.
*/}}
{{- define "keycloak.database.port" -}}
{{- if .Values.keycloak.postgresql.enabled -}}
  {{- print "5432" -}}
{{- else -}}
  {{- .Values.keycloak.externalDatabase.port | toString -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database name.
*/}}
{{- define "keycloak.database.name" -}}
{{- if .Values.keycloak.postgresql.enabled -}}
  {{- coalesce
      (((.Values.global).postgresql).auth).database
      .Values.keycloak.postgresql.auth.database
      "postgres" -}}
{{- else -}}
  {{- tpl .Values.keycloak.externalDatabase.database . -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database schema.
Returns "public" when using internal PostgreSQL, otherwise uses externalDatabase.schema.
*/}}
{{- define "keycloak.database.schema" -}}
{{- if .Values.keycloak.postgresql.enabled -}}
  {{- print "public" -}}
{{- else -}}
  {{- .Values.keycloak.externalDatabase.schema -}}
{{- end -}}
{{- end -}}

{{/*
Return extra DSN connection parameters for the external database.
Prepends "&" so the value can be appended directly to the JDBC URL.
*/}}
{{- define "keycloak.database.extraParams" -}}
{{- if .Values.keycloak.externalDatabase.extraParams -}}
  {{- printf "&%s" (tpl .Values.keycloak.externalDatabase.extraParams .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the Secret that holds the Keycloak admin password.
Uses existingSecret if provided, otherwise derives from keycloak.fullname.
*/}}
{{- define "keycloak.secretName" -}}
{{- if .Values.keycloak.auth.existingSecret -}}
  {{- tpl .Values.keycloak.auth.existingSecret . -}}
{{- else -}}
  {{- include "keycloak.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Return the Secret key that holds the Keycloak admin password.
*/}}
{{- define "keycloak.secretKey" -}}
{{- if and .Values.keycloak.auth.existingSecret
           .Values.keycloak.auth.passwordSecretKey -}}
  {{- tpl .Values.keycloak.auth.passwordSecretKey . -}}
{{- else -}}
  {{- print "admin-password" -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the Secret that holds the database credentials.
Resolution order:
  1. Internal PostgreSQL: global override → postgresql.auth.existingSecret → derived name
  2. External database:   externalDatabase.existingSecret → derived name
*/}}
{{- define "keycloak.database.secretName" -}}
{{- if .Values.keycloak.postgresql.enabled -}}
  {{- $globalSecret := (((.Values.global).postgresql).auth).existingSecret | default "" -}}
  {{- $localSecret  := .Values.keycloak.postgresql.auth.existingSecret    | default "" -}}
  {{- $merged       := coalesce $globalSecret $localSecret "" -}}
  {{- if not (empty $merged) -}}
    {{- tpl $merged . -}}
  {{- else -}}
    {{- printf "%s-postgresql" .Release.Name -}}
  {{- end -}}
{{- else if not (empty .Values.keycloak.externalDatabase.existingSecret) -}}
  {{- tpl .Values.keycloak.externalDatabase.existingSecret . -}}
{{- else -}}
  {{- printf "%s-keycloak-externaldb" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Return the Secret key that holds the database password.
*/}}
{{- define "keycloak.database.secretPasswordKey" -}}
{{- if .Values.keycloak.postgresql.enabled -}}
  {{- default "password" .Values.keycloak.postgresql.auth.secretKeys.userPasswordKey -}}
{{- else if .Values.keycloak.externalDatabase.existingSecret -}}
  {{- default "db-password" .Values.keycloak.externalDatabase.existingSecretPasswordKey -}}
{{- else -}}
  {{- print "db-password" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Secret key that holds the database username.
*/}}
{{- define "keycloak.database.secretUserKey" -}}
{{- if .Values.keycloak.externalDatabase.existingSecret -}}
  {{- default "db-user" .Values.keycloak.externalDatabase.existingSecretUserKey -}}
{{- else -}}
  {{- print "db-user" -}}
{{- end -}}
{{- end -}}

{{/*
Return the fully qualified headless service name used for ISPN/JGroups DNS discovery.
Format: <keycloak-fullname>-headless-ispn-<appVersion-dots-replaced-with-dashes>
Truncated to 63 chars.
*/}}
{{- define "keycloak.headless.ispn.serviceName" -}}
{{- printf "%s-headless-ispn-%s"
    (include "keycloak.fullname" .)
    (replace "." "-" .Chart.AppVersion) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the fully qualified headless service name for standard pod DNS discovery.
Format: <keycloak-fullname>-headless
Truncated to 63 chars.
*/}}
{{- define "keycloak.headless.serviceName" -}}
{{- printf "%s-headless" (include "keycloak.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the proper Keycloak container image string.
Respects global.imageRegistry override and optional digest pinning.
*/}}
{{- define "common.images.image" -}}
{{- $registryName   := default .imageRoot.registry ((.global).imageRegistry) -}}
{{- $repositoryName := .imageRoot.repository -}}
{{- $separator      := ":" -}}
{{- $termination    := .imageRoot.tag | toString -}}
{{- if not .imageRoot.tag -}}
  {{- if .chart -}}
    {{- $termination = .chart.AppVersion | toString -}}
  {{- end -}}
{{- end -}}
{{- if .imageRoot.digest -}}
  {{- $separator   = "@" -}}
  {{- $termination = .imageRoot.digest | toString -}}
{{- end -}}
{{- if $registryName -}}
  {{- printf "%s/%s%s%s" $registryName $repositoryName $separator $termination -}}
{{- else -}}
  {{- printf "%s%s%s" $repositoryName $separator $termination -}}
{{- end -}}
{{- end -}}

{{/*
Return the Keycloak container image name.
*/}}
{{- define "keycloak.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.keycloak.image "global" .Values.global) -}}
{{- end -}}

{{/*
Return the stunnel sidecar image name.
Respects global.imageRegistry override.
*/}}
{{- define "keycloak.stunnel.image" -}}
{{- $reg  := default "" .Values.keycloak.googleLdap.stunnel.image.registry -}}
{{- $repo := .Values.keycloak.googleLdap.stunnel.image.repository -}}
{{- $tag  := .Values.keycloak.googleLdap.stunnel.image.tag | toString -}}
{{- if and .Values.global .Values.global.imageRegistry -}}
  {{- $reg = .Values.global.imageRegistry -}}
{{- end -}}
{{- if $reg -}}
  {{- printf "%s/%s:%s" $reg $repo $tag -}}
{{- else -}}
  {{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the stunnel ConfigMap.
*/}}
{{- define "keycloak.stunnel.configMapName" -}}
{{- printf "%s-stunnel-config" .Release.Name -}}
{{- end -}}

{{/*
Return the name of the Google LDAP client cert Secret.
Uses stunnel.clientCertSecretName override if set, otherwise derives
from the release name as "<release>-google-ldap-cert".
*/}}
{{- define "keycloak.googleLdap.certSecretName" -}}
{{- if .Values.keycloak.googleLdap.stunnel.clientCertSecretName -}}
  {{- .Values.keycloak.googleLdap.stunnel.clientCertSecretName -}}
{{- else -}}
  {{- printf "%s-google-ldap-cert" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the custom truststore CA Secret.
Resolution order: secretNameOverride → derived from caCert → caCertSecretName.
*/}}
{{- define "keycloak.customTruststore.caSecretName" -}}
{{- if .Values.keycloak.googleLdap.customTruststore.secretNameOverride -}}
  {{- .Values.keycloak.googleLdap.customTruststore.secretNameOverride -}}
{{- else if .Values.keycloak.googleLdap.customTruststore.caCert -}}
  {{- printf "%s-keycloak-custom-ca" .Release.Name -}}
{{- else -}}
  {{- .Values.keycloak.googleLdap.customTruststore.caCertSecretName -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the emptyDir volume used for the generated truststore JKS.
*/}}
{{- define "keycloak.truststore.volumeName" -}}
{{- print "truststore-vol" -}}
{{- end -}}

{{/*
Validate googleLdap configuration at helm template/install time.
Fails fast with a descriptive error if required inputs are missing or conflicting.
*/}}
{{- define "keycloak.googleLdap.validate" -}}
{{- if .Values.keycloak.googleLdap.enabled -}}
  {{- $hasCert   := .Values.keycloak.googleLdap.clientCertFile -}}
  {{- $hasKey    := .Values.keycloak.googleLdap.clientKeyFile -}}
  {{- $hasFiles  := and $hasCert $hasKey -}}
  {{- $hasSecret := .Values.keycloak.googleLdap.stunnel.clientCertSecretName -}}
  {{/* Fail if neither option is provided */}}
  {{- if not (or $hasFiles $hasSecret) -}}
    {{- fail "[keycloak.googleLdap] enabled=true but no certificate source provided.\nSet either:\n  (a) keycloak.googleLdap.clientCertFile + keycloak.googleLdap.clientKeyFile  (chart-relative file paths)\n  (b) keycloak.googleLdap.stunnel.clientCertSecretName  (name of a pre-existing Kubernetes Secret)" -}}
  {{- end -}}
  {{/* Fail if both options are provided simultaneously */}}
  {{- if and $hasFiles $hasSecret -}}
    {{- fail "[keycloak.googleLdap] Conflicting certificate sources. Provide EITHER (clientCertFile + clientKeyFile) OR stunnel.clientCertSecretName — not both." -}}
  {{- end -}}
  {{/* Fail if only one of clientCertFile / clientKeyFile is set */}}
  {{- if and $hasCert (not $hasKey) -}}
    {{- fail "[keycloak.googleLdap] clientCertFile is set but clientKeyFile is missing. Both must be provided together." -}}
  {{- end -}}
  {{- if and $hasKey (not $hasCert) -}}
    {{- fail "[keycloak.googleLdap] clientKeyFile is set but clientCertFile is missing. Both must be provided together." -}}
  {{- end -}}
  {{/* Validate customTruststore if enabled */}}
  {{- if .Values.keycloak.googleLdap.customTruststore.enabled -}}
    {{- if and (not .Values.keycloak.googleLdap.customTruststore.caCert)
               (not .Values.keycloak.googleLdap.customTruststore.caCertSecretName) -}}
      {{- fail "[keycloak.googleLdap.customTruststore] enabled=true requires either customTruststore.caCert (inline PEM) or customTruststore.caCertSecretName (pre-existing secret)." -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}