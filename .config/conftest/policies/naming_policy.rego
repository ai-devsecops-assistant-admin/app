package main

import future.keywords.if
import future.keywords.in

# Naming pattern
naming_pattern := `^(dev|staging|prod)-[a-z0-9-]+-(deploy|svc|ing|cm|secret)-v\d+\.\d+\.\d+(-[A-Za-z0-9]+)?$`

# Deny resources with non-compliant names
deny[msg] if {
	input.kind in ["Deployment", "Service", "Ingress", "ConfigMap", "Secret"]
	not regex.match(naming_pattern, input.metadata.name)

	msg := sprintf(
		"FAIL: %s '%s' does not match naming convention\nExpected pattern: %s",
		[input.kind, input.metadata.name, naming_pattern]
	)
}

# Warn about resources without version labels
warn[msg] if {
	input.kind in ["Deployment", "Service"]
	not input.metadata.labels.version

	msg := sprintf(
		"WARN: %s '%s' is missing 'version' label",
		[input.kind, input.metadata.name]
	)
}

# Warn about resources without environment labels
warn[msg] if {
	input.kind in ["Deployment", "Service"]
	not input.metadata.labels.environment

	msg := sprintf(
		"WARN: %s '%s' is missing 'environment' label",
		[input.kind, input.metadata.name]
	)
}

# Validate namespace matches environment prefix
deny[msg] if {
	input.kind in ["Deployment", "Service", "Ingress"]
	input.metadata.namespace
	name_parts := split(input.metadata.name, "-")
	count(name_parts) > 0
	env_prefix := name_parts[0]
	env_prefix in ["dev", "staging", "prod"]
	input.metadata.namespace != env_prefix

	msg := sprintf(
		"FAIL: %s '%s' has environment prefix '%s' but is in namespace '%s'",
		[input.kind, input.metadata.name, env_prefix, input.metadata.namespace]
	)
}
