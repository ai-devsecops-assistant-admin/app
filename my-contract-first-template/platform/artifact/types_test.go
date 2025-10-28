package artifact

import (
	"encoding/json"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/require"
)

func TestNewExecRequestFromGinCopiesHeadersAndQuery(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	ctx, _ := gin.CreateTestContext(w)

	req := httptest.NewRequest("POST", "/test?foo=bar&foo=baz", nil)
	req.Header.Add("X-Test", "value")
	ctx.Request = req
	ctx.Params = gin.Params{{Key: "id", Value: "123"}}

	execReq, err := NewExecRequestFromGin(ctx)
	require.NoError(t, err)
	require.Equal(t, []string{"bar", "baz"}, execReq.Query["foo"])
	require.Equal(t, []string{"value"}, execReq.Headers["X-Test"])

	// mutate original request data to confirm copies were made
	values := req.URL.Query()
	values.Add("foo", "qux")
	req.URL.RawQuery = values.Encode()
	req.Header.Add("X-Test", "other")

	require.Equal(t, []string{"bar", "baz"}, execReq.Query["foo"])
	require.Equal(t, []string{"value"}, execReq.Headers["X-Test"])
}

func TestApplyRequestOverridesValidation(t *testing.T) {
	base := &ExecRequest{
		Method:  "GET",
		Path:    "/test",
		Params:  map[string]string{"existing": "1"},
		Query:   map[string][]string{"q": []string{"a"}},
		Headers: map[string][]string{"X-Test": []string{"value"}},
	}

	override := map[string]any{
		"method":  "POST",
		"params":  map[string]any{"new": 2},
		"query":   map[string]any{"q": []any{"b"}},
		"headers": map[string]any{"X-Test": []string{"override"}},
		"body":    map[string]any{"key": "value"},
	}

	raw, err := json.Marshal(override)
	require.NoError(t, err)

	err = applyRequestOverrides(base, string(raw))
	require.NoError(t, err)
	require.Equal(t, "POST", base.Method)
	require.Equal(t, "b", base.Query["q"][0])
	require.Equal(t, "override", base.Headers["X-Test"][0])
	require.Equal(t, "value", base.Body["key"])

	// invalid query should return error
	err = applyRequestOverrides(base, `{"query": []}`)
	require.Error(t, err)
}
