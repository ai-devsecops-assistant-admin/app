// Package api contains HTTP handlers for the governance service.
package api

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// HealthHandler returns the health status
func HealthHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// ReadyHandler returns the readiness status
func ReadyHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "ready",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// GetDashboardMetrics returns dashboard metrics
func GetDashboardMetrics(c *gin.Context) {
	metrics := map[string]interface{}{
		"namingComplianceRate": 98.5,
		"totalResources":       1250,
		"violations":           18,
		"autoFixedIssues":      142,
	}

	c.JSON(http.StatusOK, metrics)
}

// ValidateNamingHandler validates resource naming
func ValidateNamingHandler(c *gin.Context) {
	var req struct {
		Name string `json:"name" binding:"required"`
		Type string `json:"type" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Simple validation (in production, use OPA)
	valid := len(req.Name) > 0 && len(req.Type) > 0

	c.JSON(http.StatusOK, gin.H{
		"valid": valid,
		"name":  req.Name,
		"type":  req.Type,
	})
}

// ListResourcesHandler lists resources
func ListResourcesHandler(c *gin.Context) {
	environment := c.Query("environment")
	resourceType := c.Query("type")

	resources := []map[string]interface{}{
		{
			"id":          "1",
			"name":        "prod-my-app-api-deploy-v1.0.0",
			"type":        "Deployment",
			"environment": "prod",
			"isCompliant": true,
		},
		{
			"id":          "2",
			"name":        "prod-my-app-api-svc-v1.0.0",
			"type":        "Service",
			"environment": "prod",
			"isCompliant": true,
		},
	}

	filtered := resources
	if environment != "" || resourceType != "" {
		filtered = make([]map[string]interface{}, 0, len(resources))
		for _, r := range resources {
			env, _ := r["environment"].(string)
			if environment != "" && !strings.EqualFold(environment, env) {
				continue
			}
			typ, _ := r["type"].(string)
			if resourceType != "" && !strings.EqualFold(resourceType, typ) {
				continue
			}
			filtered = append(filtered, r)
		}
	}

	c.JSON(http.StatusOK, filtered)
}
