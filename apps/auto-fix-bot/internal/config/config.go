package config

import (
	"os"

	"github.com/spf13/viper"
)

type Config struct {
	Repository string
	Owner      string
	BaseBranch string
}

func Load(configFile string) (*Config, error) {
	if _, err := os.Stat(configFile); err == nil {
		viper.SetConfigFile(configFile)
		if err := viper.ReadInConfig(); err != nil {
			return nil, err
		}
	}

	cfg := &Config{
		Repository: viper.GetString("repository"),
		Owner:      viper.GetString("owner"),
		BaseBranch: viper.GetString("base_branch"),
	}

	// Set defaults
	if cfg.BaseBranch == "" {
		cfg.BaseBranch = "main"
	}

	return cfg, nil
}
