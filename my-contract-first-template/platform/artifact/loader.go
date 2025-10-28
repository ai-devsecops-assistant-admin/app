package artifact

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

func LoadRegistry(path string) (*Registry, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var reg Registry
	if err := json.Unmarshal(b, &reg); err != nil {
		return nil, err
	}
	return &reg, nil
}

func LoadFlow(repoPath, flowFile string) (*Flow, error) {
	fp := filepath.Join(repoPath, "flows", flowFile)
	b, err := os.ReadFile(fp)
	if err != nil {
		return nil, fmt.Errorf("read flow %s: %w", flowFile, err)
	}
	var f Flow
	if yamlErr := yaml.Unmarshal(b, &f); yamlErr == nil && len(f.Steps) > 0 {
		return &f, nil
	}
	if jsonErr := json.Unmarshal(b, &f); jsonErr == nil && len(f.Steps) > 0 {
		return &f, nil
	}
	return nil, fmt.Errorf("parse flow failed: %s", flowFile)
}
