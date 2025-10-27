-- Migration: 002_add_sbom_tracking
-- Description: Add tables for SBOM and supply chain tracking
-- Date: 2025-01-20

BEGIN;

CREATE TABLE IF NOT EXISTS sbom_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id UUID REFERENCES resources(id) ON DELETE CASCADE,
    format VARCHAR(50) NOT NULL,
    version VARCHAR(50) NOT NULL,
    document_hash VARCHAR(64) NOT NULL,
    document_url TEXT,
    components_count INTEGER DEFAULT 0,
    vulnerabilities_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sbom_documents_resource_id ON sbom_documents(resource_id);
CREATE INDEX idx_sbom_documents_created_at ON sbom_documents(created_at);

CREATE TABLE IF NOT EXISTS provenance_attestations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id UUID REFERENCES resources(id) ON DELETE CASCADE,
    predicate_type VARCHAR(255) NOT NULL,
    subject_digest VARCHAR(128) NOT NULL,
    builder_id TEXT NOT NULL,
    build_type TEXT NOT NULL,
    slsa_level INTEGER,
    signature_verified BOOLEAN DEFAULT FALSE,
    attestation_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_provenance_resource_id ON provenance_attestations(resource_id);
CREATE INDEX idx_provenance_slsa_level ON provenance_attestations(slsa_level);

CREATE TABLE IF NOT EXISTS signatures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id UUID REFERENCES resources(id) ON DELETE CASCADE,
    signature_type VARCHAR(50) NOT NULL,
    signature_value TEXT NOT NULL,
    public_key_id TEXT,
    issuer TEXT,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_signatures_resource_id ON signatures(resource_id);
CREATE INDEX idx_signatures_verified ON signatures(verified);

COMMIT;
