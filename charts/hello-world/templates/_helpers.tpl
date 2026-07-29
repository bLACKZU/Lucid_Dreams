{{- define "hello-world.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "hello-world.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hello-world.labels" -}}
app.kubernetes.io/name: {{ include "hello-world.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "hello-world.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hello-world.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "hello-world.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "hello-world.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
