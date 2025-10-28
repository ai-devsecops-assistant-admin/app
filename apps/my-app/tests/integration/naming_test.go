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

func TestNamingValidation(t *testing.T) {
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.POST("/api/v1/validate/naming", api.ValidateNamingHandler)

	tests := []struct {
		name       string
		wantStatus int
		wantValid  bool
		input      map[string]string
	}{
		{
			name: "valid production deployment name",
			input: map[string]string{
				"name": "prod-my-app-api-deploy-v1.0.0",
				"type": "deployment",
			},
			wantStatus: http.StatusOK,
			wantValid:  true,
		},
		{
			name: "valid staging service name",
			input: map[string]string{
				"name": "staging-payment-gateway-svc-v2.1.0",
				"type": "service",
			},
			wantStatus: http.StatusOK,
			wantValid:  true,
		},
		{
			name: "invalid name missing version",
			input: map[string]string{
				"name": "prod-my-app-deploy",
				"type": "deployment",
			},
			wantStatus: http.StatusOK,
			wantValid:  false,
		},
		{
			name: "invalid name wrong environment",
			input: map[string]string{
				"name": "test-my-app-deploy-v1.0.0",
				"type": "deployment",
			},
			wantStatus: http.StatusOK,
			wantValid:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, _ := json.Marshal(tt.input)
			req, _ := http.NewRequestWithContext(context.Background(), "POST", "/api/v1/validate/naming", bytes.NewBuffer(body))
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
