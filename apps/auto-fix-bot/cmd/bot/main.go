package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/example/platform-governance/apps/auto-fix-bot/internal/bot"
	"github.com/example/platform-governance/apps/auto-fix-bot/internal/config"
	"github.com/spf13/cobra"
)

var configFile string

func main() {
	rootCmd := &cobra.Command{
		Use:   "auto-fix-bot",
		Short: "Automated issue detection and fixing bot",
		Long:  `Auto-fix bot scans for policy violations and automatically creates PRs with fixes.`,
		RunE:  run,
	}

	rootCmd.Flags().StringVarP(&configFile, "config", "c", ".config/auto-fix/mapping.yaml", "Config file path")

	if err := rootCmd.Execute(); err != nil {
		log.Fatalf("Error: %v", err)
	}
}

func run(cmd *cobra.Command, args []string) error {
	ctx := context.Background()

	// Load configuration
	cfg, err := config.Load(configFile)
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Get GitHub token
	token := os.Getenv("GITHUB_TOKEN")
	if token == "" {
		return fmt.Errorf("GITHUB_TOKEN environment variable not set")
	}

	// Create bot instance
	b := bot.New(cfg, token)

	// Run the bot
	log.Println("Starting auto-fix bot...")
	if err := b.Run(ctx); err != nil {
		return fmt.Errorf("bot execution failed: %w", err)
	}

	log.Println("Auto-fix bot completed successfully")
	return nil
}
