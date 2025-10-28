package artifact

import (
	"encoding/json"

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
	Headers map[string]string   `json:"headers"`
	Body    map[string]any      `json:"body"`
}

func NewExecRequestFromGin(c *gin.Context) *ExecRequest {
	params := map[string]string{}
	for _, p := range c.Params {
		params[p.Key] = p.Value
	}
	q := map[string][]string(c.Request.URL.Query())
	h := map[string]string{}
	for k, v := range c.Request.Header {
		if len(v) > 0 {
			h[k] = v[0]
		}
	}
	body := readRequestBodyMap(c.Request.Body)
	return &ExecRequest{
		Method:  c.Request.Method,
		Path:    c.FullPath(),
		Params:  params,
		Query:   q,
		Headers: h,
		Body:    body,
	}
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
