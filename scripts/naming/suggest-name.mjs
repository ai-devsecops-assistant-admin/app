#!/usr/bin/env node

/**
 * Suggest compliant resource names
 */

const args = process.argv.slice(2);

if (args.length === 0) {
  console.error('Usage: suggest-name.mjs <current-name> [resource-type] [environment] [version]');
  process.exit(1);
}

const [currentName, resourceType = 'deploy', environment = 'dev', version = 'v1.0.0'] = args;

// Clean and normalize name
const cleanName = currentName
  .toLowerCase()
  .replace(/[^a-z0-9-]/g, '-')
  .replace(/-+/g, '-')
  .replace(/^-|-$/g, '');

// Map resource types
const typeMap = {
  deployment: 'deploy',
  service: 'svc',
  ingress: 'ing',
  configmap: 'cm',
  secret: 'secret'
};

const suffix = typeMap[resourceType.toLowerCase()] || resourceType;

// Generate compliant name
const suggestedName = `${environment}-${cleanName}-${suffix}-${version}`;

console.log('=== Naming Suggestion ===\n');
console.log(`Current Name:   ${currentName}`);
console.log(`Suggested Name: ${suggestedName}`);
console.log('\nPattern: ^(dev|staging|prod)-[a-z0-9-]+-(deploy|svc|ing|cm|secret)-v\\d+\\.\\d+\\.\\d+(-[A-Za-z0-9]+)?$');

// Validate suggested name
const pattern = /^(dev|staging|prod)-[a-z0-9-]+-(deploy|svc|ing|cm|secret)-v\d+\.\d+\.\d+(-[A-Za-z0-9]+)?$/;
const isValid = pattern.test(suggestedName);

console.log(`\nValidation: ${isValid ? '✅ Valid' : '❌ Invalid'}`);

process.exit(isValid ? 0 : 1);
