package artifact

import (
	"encoding/json"
	"fmt"

	"github.com/gin-gonic/gin"
)

type Registry struct {
	Version   string        `json:"version"`
	BasePath  string        `json:"basePath"`
	Endpoints []EndpointDef `json:"endpoints"`
}

type EndpointDef struct {
	ID     string `json:"id"`
	Method string `json:"method"`
	Path   string `json:"path"`
	Flow   string `json:"flow"`
}

type Flow struct {
	Version     int        `json:"version" yaml:"version"`
	Name        string     `json:"name" yaml:"name"`
	Description string     `json:"description" yaml:"description"`
	Steps       []FlowStep `json:"steps" yaml:"steps"`
}

type FlowStep struct {
	ID         string         `json:"id" yaml:"id"`
	Op         string         `json:"op" yaml:"op"`
	Args       map[string]any `json:"args" yaml:"args"`
	When       string         `json:"when,omitempty" yaml:"when,omitempty"`
	OnConflict *InlineAction  `json:"onConflict,omitempty" yaml:"onConflict,omitempty"`
	Out        string         `json:"out,omitempty" yaml:"out,omitempty"`
}

type InlineAction struct {
	Op   string         `json:"op" yaml:"op"`
	Args map[string]any `json:"args" yaml:"args"`
}

type ExecRequest struct {
	Method  string              `json:"method"`
	Path    string              `json:"path"`
	Params  map[string]string   `json:"params"`
	Query   map[string][]string `json:"query"`
	Headers map[string][]string `json:"headers"`
	Body    map[string]any      `json:"body"`
	Dataset map[string]any      `json:"dataset"`
}

func NewExecRequestFromGin(c *gin.Context) (*ExecRequest, error) {
	params := map[string]string{}
	for _, p := range c.Params {
		params[p.Key] = p.Value
	}
	queryValues := c.Request.URL.Query()
	q := make(map[string][]string, len(queryValues))
	for key, values := range queryValues {
		if len(values) == 0 {
			continue
		}
		copied := make([]string, len(values))
		copy(copied, values)
		q[key] = copied
	}
	h := map[string][]string{}
	for k, v := range c.Request.Header {
		if len(v) == 0 {
			continue
		}
		copied := make([]string, len(v))
		copy(copied, v)
		h[k] = copied
	}
	body, err := readRequestBodyMap(c.Request.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read request body: %w", err)
	}
	req := &ExecRequest{
		Method:  c.Request.Method,
		Path:    c.FullPath(),
		Params:  params,
		Query:   q,
		Headers: h,
		Body:    body,
		Dataset: map[string]any{},
	}

	if overrideHeader := c.GetHeader("X-Artifact-Request"); overrideHeader != "" {
		if err := applyRequestOverrides(req, overrideHeader); err != nil {
			return nil, err
		}
	}

	return req, nil
}

type ExecResponse struct {
	Status  int               `json:"status"`
	Headers map[string]string `json:"headers"`
	Body    any               `json:"body"`
}

func (r *ExecResponse) BodyJSON() []byte {
	b, _ := json.Marshal(r.Body)
	return b
}

type StepError struct {
	StepID string
	Status int
	Msg    string
}

func (e *StepError) Error() string { return e.Msg }

func applyRequestOverrides(req *ExecRequest, raw string) error {
	var payload map[string]any
	if err := json.Unmarshal([]byte(raw), &payload); err != nil {
		return fmt.Errorf("invalid X-Artifact-Request header: %w", err)
	}

	if method, ok := payload["method"].(string); ok && method != "" {
		req.Method = method
	}
	if path, ok := payload["path"].(string); ok && path != "" {
		req.Path = path
	}
	if paramsRaw, ok := payload["params"]; ok {
		paramsMap, ok := paramsRaw.(map[string]any)
		if !ok {
			return fmt.Errorf("invalid X-Artifact-Request header: params must be an object")
		}
		if req.Params == nil {
			req.Params = map[string]string{}
		}
		for k, v := range paramsMap {
			req.Params[k] = toString(v)
		}
	}
	if queryRaw, ok := payload["query"]; ok {
		queryMap, ok := queryRaw.(map[string]any)
		if !ok {
			return fmt.Errorf("invalid X-Artifact-Request header: query must be an object")
		}
		if req.Query == nil {
			req.Query = map[string][]string{}
		}
		for k, v := range queryMap {
			if slice := normalizeStrings(v); slice != nil {
				req.Query[k] = slice
				continue
			}
			delete(req.Query, k)
		}
	}
	if headersRaw, ok := payload["headers"]; ok {
		headersMap, ok := headersRaw.(map[string]any)
		if !ok {
			return fmt.Errorf("invalid X-Artifact-Request header: headers must be an object")
		}
		if req.Headers == nil {
			req.Headers = map[string][]string{}
		}
		for k, v := range headersMap {
			if slice := normalizeStrings(v); slice != nil {
				req.Headers[k] = slice
			}
			// If normalizeStrings returns nil, do not update or delete the header.
			// This makes nil values in the override payload ignored, not deletions.
		}
	}
	if bodyRaw, ok := payload["body"]; ok {
		bodyMap, ok := bodyRaw.(map[string]any)
		if !ok {
			return fmt.Errorf("invalid X-Artifact-Request header: body must be an object")
		}
		if req.Body == nil {
			req.Body = map[string]any{}
		}
		for k, v := range bodyMap {
			req.Body[k] = v
		}
	}
	if datasetRaw, ok := payload["dataset"]; ok {
		datasetMap, ok := datasetRaw.(map[string]any)
		if !ok {
			return fmt.Errorf("invalid X-Artifact-Request header: dataset must be an object")
		}
		if req.Dataset == nil {
			req.Dataset = map[string]any{}
		}
		for k, v := range datasetMap {
			req.Dataset[k] = v
		}
	}

	return nil
}
