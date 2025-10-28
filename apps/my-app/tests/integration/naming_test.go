package integration_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/example/platform-governance/apps/my-app/internal/api"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

type namingRequest struct {
	Name string `json:"name"`
	Type string `json:"type"`
}

func TestNamingValidation(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.POST("/api/v1/validate/naming", api.ValidateNamingHandler)

	tests := []struct {
		name       string
		wantStatus int
		wantValid  bool
		input      namingRequest
	}{
		{
			name: "valid production deployment name",
			input: namingRequest{
				Name: "prod-my-app-api-deploy-v1.0.0",
				Type: "deployment",
			},
			wantStatus: http.StatusOK,
			wantValid:  true,
		},
		{
			name: "valid staging service name",
			input: namingRequest{
				Name: "staging-payment-gateway-svc-v2.1.0",
				Type: "service",
			},
			wantStatus: http.StatusOK,
			wantValid:  true,
		},
		{
			name: "invalid name missing version",
			input: namingRequest{
				Name: "prod-my-app-deploy",
				Type: "deployment",
			},
			wantStatus: http.StatusOK,
			wantValid:  false,
		},
		{
			name: "invalid name wrong environment",
			input: namingRequest{
				Name: "test-my-app-deploy-v1.0.0",
				Type: "deployment",
			},
			wantStatus: http.StatusOK,
			wantValid:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, err := json.Marshal(tt.input)
			assert.NoError(t, err)
			req, err := http.NewRequestWithContext(context.Background(), "POST", "/api/v1/validate/naming", bytes.NewBuffer(body))
			assert.NoError(t, err)
			req.Header.Set("Content-Type", "application/json")

			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)

			assert.Equal(t, tt.wantStatus, w.Code)

			var response map[string]interface{}
			err := json.Unmarshal(w.Body.Bytes(), &response)
			assert.NoError(t, err)
			assert.Equal(t, tt.wantValid, response["valid"])
		})
	}
}
