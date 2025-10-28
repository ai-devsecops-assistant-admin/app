package main

import future.keywords.if
import future.keywords.in

# Security best practices for Kubernetes resources

# Deny containers running as root
deny[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.securityContext.runAsNonRoot

	msg := sprintf(
		"FAIL: Container '%s' in Deployment '%s' must set runAsNonRoot: true",
		[container.name, input.metadata.name]
	)
}

# Deny containers with privilege escalation
deny[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	container.securityContext.allowPrivilegeEscalation != false

	msg := sprintf(
		"FAIL: Container '%s' must set allowPrivilegeEscalation: false",
		[container.name]
	)
}

# Require resource limits
deny[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.resources.limits

	msg := sprintf(
		"FAIL: Container '%s' must define resource limits",
		[container.name]
	)
}

# Require resource requests
deny[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.resources.requests

	msg := sprintf(
		"FAIL: Container '%s' must define resource requests",
		[container.name]
	)
}

# Require readOnlyRootFilesystem
warn[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.securityContext.readOnlyRootFilesystem

	msg := sprintf(
		"WARN: Container '%s' should set readOnlyRootFilesystem: true",
		[container.name]
	)
}

# Require liveness probe
warn[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.livenessProbe

	msg := sprintf(
		"WARN: Container '%s' should define a liveness probe",
		[container.name]
	)
}

# Require readiness probe
warn[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.readinessProbe

	msg := sprintf(
		"WARN: Container '%s' should define a readiness probe",
		[container.name]
	)
}

# Deny services without selector
deny[msg] if {
	input.kind == "Service"
	not input.spec.selector

	msg := sprintf(
		"FAIL: Service '%s' must define a selector",
		[input.metadata.name]
	)
}

# Require network policies
warn[msg] if {
	input.kind == "Deployment"
	not has_network_policy

	msg := sprintf(
		"WARN: Deployment '%s' should have an associated NetworkPolicy",
		[input.metadata.name]
	)
}

has_network_policy if {
	input.kind == "NetworkPolicy"
}

# Validate image pull policy
deny[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	container.imagePullPolicy == "Always"
	not is_latest_tag(container.image)

	msg := sprintf(
		"FAIL: Container '%s' uses imagePullPolicy: Always but does not use :latest tag",
		[container.name]
	)
}

is_latest_tag(image) if {
	endswith(image, ":latest")
}

# Require security context at pod level
deny[msg] if {
	input.kind == "Deployment"
	not input.spec.template.spec.securityContext.runAsNonRoot

	msg := sprintf(
		"FAIL: Deployment '%s' must set pod-level runAsNonRoot: true",
		[input.metadata.name]
	)
}

# Validate capabilities are dropped
deny[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.securityContext.capabilities.drop

	msg := sprintf(
		"FAIL: Container '%s' must drop all capabilities",
		[container.name]
	)
}

deny[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	container.securityContext.capabilities.drop
	not "ALL" in container.securityContext.capabilities.drop

	msg := sprintf(
		"FAIL: Container '%s' must drop ALL capabilities",
		[container.name]
	)
}
