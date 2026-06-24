{{/*
Common labels
*/}}
{{- define "microservice.labels" -}}
app: {{ .Release.Name }}
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
release: {{ .Release.Name }}
managed-by: Helm
{{- end }}
