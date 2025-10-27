package naming

import future.keywords.if
import future.keywords.in

# Naming pattern for Kubernetes resources
naming_pattern := `^(dev|staging|prod)-[a-z0-9-]+-(deploy|svc|ing|cm|secret)-v\d+\.\d+\.\d+(-[A-Za-z0-9]+)?$`

# Resource types that require naming validation
resource_types := {"Deployment", "Service", "Ingress", "ConfigMap", "Secret"}

# Deny if resource name doesn't match pattern
deny[msg] if {
	input.kind in resource_types
	not regex.match(naming_pattern, input.metadata.name)
	msg := sprintf("Resource name '%s' does not match naming convention", [input.metadata.name])
}

# Helper function to suggest a compliant name
suggest_name(name, kind, env, version) := suggested if {
	lower_name := lower(name)
	clean_name := regex.replace(lower_name, "[^a-z0-9-]", "-")

	type_suffix := type_suffix_map[kind]
	suggested := sprintf("%s-%s-%s-%s", [env, clean_name, type_suffix, version])
}

type_suffix_map := {
	"Deployment": "deploy",
	"Service": "svc",
	"Ingress": "ing",
	"ConfigMap": "cm",
	"Secret": "secret",
}

# Validation function
is_valid_name(name) if {
	regex.match(naming_pattern, name)
}

# Extract environment from name
get_environment(name) := env if {
	parts := split(name, "-")
	count(parts) > 0
	env := parts[0]
	env in {"dev", "staging", "prod"}
}

# Extract version from name
get_version(name) := version if {
	regex.match(`v\d+\.\d+\.\d+`, name)
	parts := regex.find_all_string_submatch_n(`v(\d+\.\d+\.\d+)`, name, -1)
	count(parts) > 0
	version := parts[0][1]
}
