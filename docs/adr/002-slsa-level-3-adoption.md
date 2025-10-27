# ADR 002: SLSA Level 3 Adoption for Supply Chain Security

## Status
Accepted

## Context
Supply chain attacks are increasingly targeting software build and deployment pipelines. We need verifiable provenance for all artifacts to ensure:
- Build integrity
- Source traceability
- Tamper detection
- Compliance with security standards

## Decision
Implement SLSA (Supply-chain Levels for Software Artifacts) Level 3 for all production deployments.

### SLSA Level 3 Requirements
1. **Source Integrity**: All source code from version control
2. **Build Service**: Builds run on dedicated, hardened infrastructure
3. **Provenance**: Automatically generated, non-falsifiable
4. **Isolation**: Build service prevents cross-build influence
5. **Parameterless**: Build process deterministic from source

### Implementation
- **Generator**: slsa-github-generator
- **Format**: in-toto provenance
- **Storage**: OCI registry alongside images
- **Signing**: Cosign keyless (Sigstore)
- **Verification**: Policy-based checks in deployment pipeline

## Consequences

### Positive
- Verifiable artifact provenance
- Protection against supply chain attacks
- Compliance with security frameworks (NIST SSDF)
- Automated security evidence generation
- Improved incident response capabilities

### Negative
- Increased build time (provenance generation)
- Additional storage for attestations
- Complexity in build pipeline
- Learning curve for team

## References
- [SLSA Specification](https://slsa.dev/spec/v1.0/)
- [slsa-github-generator](https://github.com/slsa-framework/slsa-github-generator)
- [Sigstore Documentation](https://docs.sigstore.dev/)
