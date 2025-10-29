#!/usr/bin/env bash
# ==============================================================================
# Artifact Gateway Setup Script
# ==============================================================================
# Creates a complete Contract-First API gateway with flow-based execution
#
# Usage:
#   ./setup-artifact-gateway.sh [APP_NAME] [MODULE_NAME]
#
# Examples:
#   ./setup-artifact-gateway.sh my-app
#   ./setup-artifact-gateway.sh my-api github.com/myorg/my-api
# ==============================================================================

set -euo pipefail

APP_NAME="${1:-my-app}"
MODULE_NAME="${2:-example.com/${APP_NAME}}"

echo "======================================================================"
echo "  Artifact Gateway Setup"
echo "======================================================================"
echo "  App Name:    ${APP_NAME}"
echo "  Module Name: ${MODULE_NAME}"
echo "======================================================================"
echo ""

# ==============================================================================
# Step 1: Initialize Go Module and Dependencies
# ==============================================================================
echo "[1/9] Initialize Go module and dependencies"
mkdir -p "${APP_NAME}"
cd "${APP_NAME}"

if [ ! -f go.mod ]; then
  go mod init "${MODULE_NAME}"
fi

go get github.com/gin-gonic/gin@v1.10.0
go get github.com/xeipuuv/gojsonschema@v1.2.0
go get gopkg.in/yaml.v3@v3.0.1

# ==============================================================================
# Step 2: Create Directory Structure
# ==============================================================================
echo "[2/9] Create directory structure"
mkdir -p cmd/artifact-gateway \
         platform/artifact \
         repo/api \
         repo/flows \
         repo/data \
         .runtime/state \
         scripts

# ==============================================================================
# Step 3: Create Repository Index and Seed Data
# ==============================================================================
echo "[3/9] Write repository index and seed data"

cat > repo/api/index.json <<'JSON'
{
  "routes": [
    { "method": "GET",    "path": "/v1/users",      "flow": "users.list.flow.yaml" },
    { "method": "GET",    "path": "/v1/users/:id",  "flow": "users.detail.flow.yaml" },
    { "method": "POST",   "path": "/v1/users",      "flow": "users.create.flow.yaml" },
    { "method": "PUT",    "path": "/v1/users/:id",  "flow": "users.update.flow.yaml" },
    { "method": "DELETE", "path": "/v1/users/:id",  "flow": "users.delete.flow.yaml" }
  ]
}
JSON

cat > repo/data/seed.users.v1.json <<'JSON'
[
  { "id": "u_1", "email": "john@example.com", "name": "John Doe" },
  { "id": "u_2", "email": "jane@example.com", "name": "Jane Smith" }
]
JSON

# ==============================================================================
# Step 4: Create Flow Examples (CRUD Operations)
# ==============================================================================
echo "[4/9] Write flow examples"

cat > repo/flows/users.list.flow.yaml <<'YAML'
steps:
  - id: load
    op: loadDataset
    args:
      dataset: users
    out: users
  - id: filter
    op: filterAndPaginate
    args:
      source: $ctx.users
      page: $request.query.page
      size: $request.query.size
      q: $request.query.q
      fields: [id, name, email]
      sort: $request.query.sort
    out: list
  - id: respond
    op: respond
    args:
      status: 200
      bodyFrom: $ctx.list
YAML

cat > repo/flows/users.detail.flow.yaml <<'YAML'
steps:
  - id: load
    op: loadDataset
    args:
      dataset: users
    out: users
  - id: find
    op: findById
    args:
      source: $ctx.users
      id: $request.params.id
    out: found
  - id: respond
    op: respond
    args:
      status: 200
      bodyFrom: $ctx.found
YAML

cat > repo/flows/users.create.flow.yaml <<'YAML'
steps:
  - id: validate
    op: validateBody
    args:
      schema:
        type: object
        required: [email, name]
        properties:
          email: { type: string, format: email }
          name:  { type: string, minLength: 1 }
  - id: load
    op: loadDataset
    args:
      dataset: users
    out: users
  - id: ensureUniqueEmail
    op: checkUnique
    args:
      source: $ctx.users
      field: email
      value: $request.body.email
  - id: genId
    op: assignId
    args:
      prefix: u_
    out: newId
  - id: setId
    op: set
    args:
      path: $request.body.id
      value: $ctx.newId
  - id: setCreatedAt
    op: now
    out: nowVal
  - id: assignCreatedAt
    op: set
    args:
      path: $request.body.createdAt
      value: $ctx.nowVal
  - id: insert
    op: insertRecord
    args:
      dataset: users
      record: $request.body
    out: created
  - id: respond
    op: respond
    args:
      status: 201
      bodyFrom: $ctx.created
YAML

cat > repo/flows/users.update.flow.yaml <<'YAML'
steps:
  - id: validate
    op: validateBody
    args:
      schema:
        type: object
        properties:
          email: { type: string, format: email }
          name:  { type: string, minLength: 1 }
  - id: load
    op: loadDataset
    args:
      dataset: users
    out: users
  - id: ensureUniqueEmail
    when: $request.body.email != null
    op: checkUnique
    args:
      source: $ctx.users
      field: email
      value: $request.body.email
      excludeId: $request.params.id
  - id: setUpdatedAt
    op: now
    out: nowVal
  - id: assignUpdatedAt
    op: set
    args:
      path: $request.body.updatedAt
      value: $ctx.nowVal
  - id: update
    op: updateRecord
    args:
      dataset: users
      id: $request.params.id
      patch: $request.body
    out: updated
  - id: respond
    op: respond
    args:
      status: 200
      bodyFrom: $ctx.updated
YAML

cat > repo/flows/users.delete.flow.yaml <<'YAML'
steps:
  - id: delete
    op: deleteRecord
    args:
      dataset: users
      id: $request.params.id
  - id: respond
    op: respond
    args:
      status: 204
      body: null
YAML

# ==============================================================================
# Step 5: Create Platform Types
# ==============================================================================
echo "[5/9] Write artifact platform types"

cat > platform/artifact/types.go <<'GO'
package artifact

// ExecRequest represents an incoming HTTP request to be executed by a flow
type ExecRequest struct {
	Method  string
	Path    string
	Headers map[string]string
	Query   map[string][]string
	Params  map[string]string
	Body    map[string]any
	Dataset string
}

// ExecResponse represents the HTTP response from a flow execution
type ExecResponse struct {
	Status  int
	Headers map[string]string
	Body    any
}

// Flow represents a declarative workflow with multiple steps
type Flow struct {
	Steps []FlowStep `json:"steps" yaml:"steps"`
}

// FlowStep represents a single operation in a flow
type FlowStep struct {
	ID         string         `json:"id" yaml:"id"`
	Op         string         `json:"op" yaml:"op"`
	Args       map[string]any `json:"args" yaml:"args"`
	Out        string         `json:"out" yaml:"out"`
	When       string         `json:"when" yaml:"when"`
	OnConflict *InlineAction  `json:"onConflict" yaml:"onConflict"`
}

// InlineAction represents an error handling action
type InlineAction struct {
	Op   string         `json:"op" yaml:"op"`
	Args map[string]any `json:"args" yaml:"args"`
}

// StepError represents an error that occurred during step execution
type StepError struct {
	StepID string
	Status int
	Msg    string
}

func (e *StepError) Error() string {
	return e.Msg
}
GO

# ==============================================================================
# Step 6: Create Loader
# ==============================================================================
echo "[6/9] Write artifact loader"

cat > platform/artifact/loader.go <<'GO'
package artifact

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Route represents a single API route configuration
type Route struct {
	Method string `json:"method"`
	Path   string `json:"path"`
	Flow   string `json:"flow"`
}

// RouteIndex contains all route configurations
type RouteIndex struct {
	Routes []Route `json:"routes"`
}

// LoadIndex loads the route index from the repository
func LoadIndex(repoPath string) (*RouteIndex, error) {
	path := filepath.Join(repoPath, "api", "index.json")
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read index: %w", err)
	}

	var idx RouteIndex
	if err := json.Unmarshal(b, &idx); err != nil {
		return nil, fmt.Errorf("parse index: %w", err)
	}

	return &idx, nil
}

// LoadFlow loads a flow definition from the repository
func LoadFlow(repoPath, flowFile string) (*Flow, error) {
	path := filepath.Join(repoPath, "flows", flowFile)
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read flow: %w", err)
	}

	var f Flow
	if err := yaml.Unmarshal(b, &f); err != nil {
		return nil, fmt.Errorf("parse flow: %w", err)
	}

	return &f, nil
}
GO

# ==============================================================================
# Step 7: Create Utilities
# ==============================================================================
echo "[7/9] Write artifact utilities"

cat > platform/artifact/utils.go <<'GO'
package artifact

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Type conversion helpers

func toSlice(v any) ([]any, bool) {
	switch a := v.(type) {
	case []any:
		return a, true
	case []map[string]any:
		out := make([]any, len(a))
		for i := range a {
			out[i] = a[i]
		}
		return out, true
	default:
		return nil, false
	}
}

func toMap(v any) (map[string]any, bool) {
	m, ok := v.(map[string]any)
	return m, ok
}

func str(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func toString(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case int:
		return strconv.Itoa(t)
	case int64:
		return strconv.FormatInt(t, 10)
	case bool:
		return strconv.FormatBool(t)
	case nil:
		return ""
	default:
		b, _ := json.Marshal(t)
		return string(b)
	}
}

func toInt(v any) int {
	switch t := v.(type) {
	case float64:
		return int(t)
	case int:
		return t
	case string:
		i, _ := strconv.Atoi(t)
		return i
	default:
		return 0
	}
}

func toStringSlice(v any) []string {
	if v == nil {
		return []string{}
	}

	switch val := v.(type) {
	case []any:
		result := make([]string, len(val))
		for i, item := range val {
			result[i] = toString(item)
		}
		return result
	case []string:
		return val
	default:
		return []string{toString(v)}
	}
}

func deepCopy(v any) any {
	b, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var out any
	_ = json.Unmarshal(b, &out)
	return out
}

// Query and data helpers

func queryToSimple(q map[string][]string) map[string]any {
	out := map[string]any{}
	for k, v := range q {
		if len(v) == 1 {
			out[k] = v[0]
		} else {
			tmp := make([]any, len(v))
			for i := range v {
				tmp[i] = v[i]
			}
			out[k] = tmp
		}
	}
	return out
}

// Expression evaluation

func getExpr(rt map[string]any, v any, def any) any {
	if s, ok := v.(string); ok && strings.HasPrefix(s, "$") {
		got := getByPath(rt, toPath(s))
		if got == nil {
			return def
		}
		return got
	}
	if v == nil {
		return def
	}
	return v
}

func toPath(expr string) []string {
	return strings.Split(strings.TrimPrefix(expr, "$"), ".")
}

func getByPath(root map[string]any, path []string) any {
	var cur any = root
	for _, p := range path {
		switch node := cur.(type) {
		case map[string]any:
			cur = node[p]
		default:
			return nil
		}
	}
	return cur
}

func setByPath(root map[string]any, path []string, value any) {
	cur := root
	for i, p := range path {
		if i == len(path)-1 {
			cur[p] = value
			return
		}
		next, ok := cur[p].(map[string]any)
		if !ok {
			next = map[string]any{}
			cur[p] = next
		}
		cur = next
	}
}

// File I/O

func readJSONFile(path string) ([]byte, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read file %s: %w", path, err)
	}
	return b, nil
}

func writeJSONPretty(path string, v any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	if err := os.WriteFile(path, b, 0o644); err != nil {
		return fmt.Errorf("write file: %w", err)
	}
	return nil
}

// Condition evaluation

func evalCondition(expr string, rt map[string]any) (bool, error) {
	expr = strings.TrimSpace(expr)
	if expr == "" {
		return true, nil
	}

	// Simple path existence check
	if strings.HasPrefix(expr, "$") {
		val := getByPath(rt, toPath(expr))
		return val != nil, nil
	}

	// Equality check
	if strings.Contains(expr, "==") {
		parts := strings.SplitN(expr, "==", 2)
		if len(parts) != 2 {
			return false, fmt.Errorf("invalid condition: %s", expr)
		}
		left := getByPath(rt, toPath(strings.TrimSpace(parts[0])))
		right := strings.TrimSpace(parts[1])
		if right == "null" {
			return left == nil, nil
		}
		return toString(left) == strings.Trim(right, `"`), nil
	}

	// Inequality check
	if strings.Contains(expr, "!=") {
		parts := strings.SplitN(expr, "!=", 2)
		if len(parts) != 2 {
			return false, fmt.Errorf("invalid condition: %s", expr)
		}
		left := getByPath(rt, toPath(strings.TrimSpace(parts[0])))
		right := strings.TrimSpace(parts[1])
		if right == "null" {
			return left != nil, nil
		}
		return toString(left) != strings.Trim(right, `"`), nil
	}

	return false, fmt.Errorf("unsupported condition: %s", expr)
}

// ReadBodyJSON reads request body as JSON map
func ReadBodyJSON(r io.ReadCloser) map[string]any {
	defer r.Close()
	b, err := io.ReadAll(r)
	if err != nil || len(b) == 0 {
		return map[string]any{}
	}
	var m map[string]any
	if err := json.Unmarshal(b, &m); err == nil {
		return m
	}
	return map[string]any{}
}

// Math helpers

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func clamp(v, minV, maxV int) int {
	if v < minV {
		return minV
	}
	if v > maxV {
		return maxV
	}
	return v
}
GO

# ==============================================================================
# Step 8: Create Engine with All Operators
# ==============================================================================
echo "[8/9] Write artifact engine with operators"

cat > platform/artifact/engine.go <<'GO'
package artifact

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/xeipuuv/gojsonschema"
)

// Executor executes flows against the artifact repository
type Executor struct {
	repoPath string
}

// NewExecutor creates a new flow executor
func NewExecutor(repoPath string) *Executor {
	return &Executor{repoPath: repoPath}
}

// Run executes a flow with the given request context
func (e *Executor) Run(ctx context.Context, flowFile string, req *ExecRequest) (*ExecResponse, error) {
	flow, err := LoadFlow(e.repoPath, flowFile)
	if err != nil {
		return nil, &StepError{Status: 500, Msg: "failed to load flow: " + err.Error()}
	}

	rt := map[string]any{
		"request": map[string]any{
			"method":  req.Method,
			"path":    req.Path,
			"params":  req.Params,
			"query":   queryToSimple(req.Query),
			"headers": req.Headers,
			"body":    deepCopy(req.Body),
			"dataset": req.Dataset,
		},
		"ctx": map[string]any{},
	}

	for _, step := range flow.Steps {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		default:
		}

		// Evaluate conditional execution
		if step.When != "" {
			ok, condErr := evalCondition(step.When, rt)
			if condErr != nil {
				return handleError(step, &StepError{
					StepID: step.ID,
					Status: 500,
					Msg:    "condition evaluation failed: " + condErr.Error(),
				})
			}
			if !ok {
				continue
			}
		}

		// Execute operation
		var out any
		switch step.Op {
		case "loadDataset":
			out, err = opLoadDataset(e.repoPath, step.Args)
		case "filterAndPaginate":
			out, err = opFilterAndPaginate(step.Args, rt)
		case "findById":
			out, err = opFindById(step.Args, rt)
		case "validateBody":
			err = opValidateBody(step.Args, rt)
		case "checkUnique":
			err = opCheckUnique(step.Args, rt)
		case "assignId":
			out, err = opAssignId(step.Args, rt)
		case "insertRecord":
			out, err = opInsertRecord(e.repoPath, step.Args, rt)
		case "updateRecord":
			out, err = opUpdateRecord(e.repoPath, step.Args, rt)
		case "deleteRecord":
			err = opDeleteRecord(e.repoPath, step.Args, rt)
		case "now":
			out, err = opNow()
		case "set":
			err = opSet(step.Args, rt)
		case "respond":
			return opRespond(step.Args, rt)
		default:
			err = fmt.Errorf("unknown operation: %s", step.Op)
		}

		if err != nil {
			return handleError(step, err)
		}

		// Store output in context
		if step.Out != "" {
			ctxMap, _ := rt["ctx"].(map[string]any)
			if ctxMap == nil {
				ctxMap = map[string]any{}
				rt["ctx"] = ctxMap
			}
			ctxMap[step.Out] = deepCopy(out)
		}
	}

	// Default response if no explicit respond
	return &ExecResponse{Status: 204}, nil
}

func handleError(step FlowStep, err error) (*ExecResponse, error) {
	status := 500
	msg := err.Error()

	if se, ok := err.(*StepError); ok {
		status = se.Status
		msg = se.Msg
	}

	if step.OnConflict != nil && step.OnConflict.Op == "respond" {
		errCtx := map[string]any{
			"error": map[string]any{
				"message": msg,
				"status":  status,
			},
		}
		return opRespond(step.OnConflict.Args, errCtx)
	}

	return nil, &StepError{StepID: step.ID, Status: status, Msg: msg}
}

// ============================================================================
// Operators
// ============================================================================

func opLoadDataset(repoPath string, args map[string]any) (any, error) {
	ds := str(args["dataset"])
	if ds == "" {
		return nil, errors.New("loadDataset requires dataset name")
	}

	// Try state file first
	statePath := filepath.Join(repoPath, ".runtime", "state", ds+".json")
	if b, err := readJSONFile(statePath); err == nil {
		var v any
		if json.Unmarshal(b, &v) == nil {
			return v, nil
		}
	}

	// Fallback to seed file
	seedName := str(args["seed"])
	if seedName == "" {
		seedName = "seed." + ds + ".v1.json"
	}
	seedPath := filepath.Join(repoPath, "data", seedName)

	if b, err := readJSONFile(seedPath); err == nil {
		var v any
		if json.Unmarshal(b, &v) == nil {
			return v, nil
		}
	}

	return []any{}, nil
}

func opFilterAndPaginate(args map[string]any, rt map[string]any) (any, error) {
	src := getByPath(rt, toPath(str(args["source"])))
	arr, ok := toSlice(src)
	if !ok {
		return nil, errors.New("filterAndPaginate requires array source")
	}

	page := max(1, toInt(getExpr(rt, args["page"], 1)))
	size := clamp(toInt(getExpr(rt, args["size"], 20)), 1, 100)
	query := strings.ToLower(str(getExpr(rt, args["q"], "")))
	fields := toStringSlice(args["fields"])
	sortBy := str(getExpr(rt, args["sort"], ""))

	// Filter by search query
	filtered := make([]map[string]any, 0, len(arr))
	for _, it := range arr {
		m, ok := toMap(it)
		if !ok {
			continue
		}
		if query == "" {
			filtered = append(filtered, m)
			continue
		}

		// Search in specified fields
		match := false
		for _, f := range fields {
			if s, ok := m[f].(string); ok {
				if strings.Contains(strings.ToLower(s), query) {
					match = true
					break
				}
			}
		}
		if match {
			filtered = append(filtered, m)
		}
	}

	// Sort if requested
	if sortBy != "" {
		parts := strings.Split(sortBy, ":")
		key := parts[0]
		dir := "asc"
		if len(parts) > 1 {
			dir = strings.ToLower(parts[1])
		}
		sort.SliceStable(filtered, func(i, j int) bool {
			a, b := toString(filtered[i][key]), toString(filtered[j][key])
			if dir == "desc" {
				return a > b
			}
			return a < b
		})
	}

	// Paginate
	total := len(filtered)
	start := (page - 1) * size
	if start >= total {
		return map[string]any{
			"items": []any{},
			"page":  page,
			"size":  size,
			"total": 0,
		}, nil
	}
	end := min(start+size, total)

	items := make([]any, end-start)
	for i := range items {
		items[i] = filtered[start+i]
	}

	return map[string]any{
		"items": items,
		"page":  page,
		"size":  size,
		"total": total,
	}, nil
}

func opFindById(args map[string]any, rt map[string]any) (any, error) {
	src := getByPath(rt, toPath(str(args["source"])))
	targetID := toString(getByPath(rt, toPath(str(args["id"]))))

	arr, ok := toSlice(src)
	if !ok {
		return nil, errors.New("findById requires array source")
	}

	for _, it := range arr {
		m, ok := toMap(it)
		if !ok {
			continue
		}
		if toString(m["id"]) == targetID {
			return m, nil
		}
	}
	return nil, &StepError{Status: 404, Msg: "record not found"}
}

func opValidateBody(args map[string]any, rt map[string]any) error {
	schemaRaw := args["schema"]
	if schemaRaw == nil {
		return nil
	}

	schemaBytes, err := json.Marshal(schemaRaw)
	if err != nil {
		return fmt.Errorf("invalid schema: %w", err)
	}

	bodyVal := getByPath(rt, []string{"request", "body"})
	if bodyVal == nil {
		bodyVal = map[string]any{}
	}
	bodyBytes, err := json.Marshal(bodyVal)
	if err != nil {
		return fmt.Errorf("invalid body: %w", err)
	}

	schemaLoader := gojsonschema.NewBytesLoader(schemaBytes)
	bodyLoader := gojsonschema.NewBytesLoader(bodyBytes)

	result, err := gojsonschema.Validate(schemaLoader, bodyLoader)
	if err != nil {
		return fmt.Errorf("schema validation setup failed: %w", err)
	}

	if !result.Valid() {
		details := make([]string, 0, len(result.Errors()))
		for _, desc := range result.Errors() {
			details = append(details, fmt.Sprintf("%s (%s)", desc.Message(), desc.Field()))
		}
		return &StepError{
			Status: 400,
			Msg:    "validation failed: " + strings.Join(details, ", "),
		}
	}

	return nil
}

func opCheckUnique(args map[string]any, rt map[string]any) error {
	src := getByPath(rt, toPath(str(args["source"])))
	field := str(args["field"])
	value := toString(getExpr(rt, args["value"], ""))
	excludeID := toString(getExpr(rt, args["excludeId"], ""))

	arr, ok := toSlice(src)
	if !ok {
		return nil
	}

	for _, it := range arr {
		m, ok := toMap(it)
		if !ok {
			continue
		}

		// Skip excluded ID (for updates)
		if excludeID != "" && toString(m["id"]) == excludeID {
			continue
		}

		if toString(m[field]) == value {
			return &StepError{
				Status: 409,
				Msg:    fmt.Sprintf("duplicate value '%s' for field '%s'", value, field),
			}
		}
	}
	return nil
}

func opAssignId(args map[string]any, rt map[string]any) (any, error) {
	prefix := str(args["prefix"])
	if prefix == "" {
		prefix = "id_"
	}

	timestamp := time.Now().UnixNano()
	id := fmt.Sprintf("%s%d", prefix, timestamp)
	return id, nil
}

func opInsertRecord(repoPath string, args map[string]any, rt map[string]any) (any, error) {
	dataset := str(args["dataset"])
	record := getExpr(rt, args["record"], nil)

	if dataset == "" {
		return nil, errors.New("insertRecord requires dataset name")
	}
	if record == nil {
		return nil, errors.New("insertRecord requires record data")
	}

	recordMap, ok := toMap(record)
	if !ok {
		return nil, errors.New("record must be an object")
	}

	stateFile := filepath.Join(repoPath, ".runtime", "state", dataset+".json")

	var data []any
	if b, err := readJSONFile(stateFile); err == nil {
		_ = json.Unmarshal(b, &data)
	}

	data = append(data, recordMap)

	if err := writeJSONPretty(stateFile, data); err != nil {
		return nil, fmt.Errorf("failed to save record: %w", err)
	}

	return recordMap, nil
}

func opUpdateRecord(repoPath string, args map[string]any, rt map[string]any) (any, error) {
	dataset := str(args["dataset"])
	id := toString(getExpr(rt, args["id"], ""))
	patch := getExpr(rt, args["patch"], nil)

	if dataset == "" {
		return nil, errors.New("updateRecord requires dataset name")
	}
	if id == "" {
		return nil, errors.New("updateRecord requires record id")
	}

	patchMap, ok := toMap(patch)
	if !ok {
		return nil, errors.New("patch must be an object")
	}

	stateFile := filepath.Join(repoPath, ".runtime", "state", dataset+".json")

	var data []any
	if b, err := readJSONFile(stateFile); err == nil {
		_ = json.Unmarshal(b, &data)
	}

	found := false
	var updated map[string]any
	for i, it := range data {
		m, ok := toMap(it)
		if !ok {
			continue
		}
		if toString(m["id"]) == id {
			// Merge patch into existing record
			for k, v := range patchMap {
				m[k] = v
			}
			data[i] = m
			updated = m
			found = true
			break
		}
	}

	if !found {
		return nil, &StepError{Status: 404, Msg: "record not found"}
	}

	if err := writeJSONPretty(stateFile, data); err != nil {
		return nil, fmt.Errorf("failed to update record: %w", err)
	}

	return updated, nil
}

func opDeleteRecord(repoPath string, args map[string]any, rt map[string]any) error {
	dataset := str(args["dataset"])
	id := toString(getExpr(rt, args["id"], ""))

	if dataset == "" {
		return errors.New("deleteRecord requires dataset name")
	}
	if id == "" {
		return errors.New("deleteRecord requires record id")
	}

	stateFile := filepath.Join(repoPath, ".runtime", "state", dataset+".json")

	var data []any
	if b, err := readJSONFile(stateFile); err == nil {
		_ = json.Unmarshal(b, &data)
	}

	found := false
	newData := make([]any, 0, len(data))
	for _, it := range data {
		m, ok := toMap(it)
		if !ok {
			newData = append(newData, it)
			continue
		}
		if toString(m["id"]) == id {
			found = true
			continue
		}
		newData = append(newData, m)
	}

	if !found {
		return &StepError{Status: 404, Msg: "record not found"}
	}

	if err := writeJSONPretty(stateFile, newData); err != nil {
		return fmt.Errorf("failed to delete record: %w", err)
	}

	return nil
}

func opNow() (any, error) {
	return time.Now().Format(time.RFC3339), nil
}

func opSet(args map[string]any, rt map[string]any) error {
	pathStr := str(args["path"])
	if pathStr == "" {
		return errors.New("set requires path")
	}

	value := getExpr(rt, args["value"], nil)
	setByPath(rt, toPath(pathStr), value)
	return nil
}

func opRespond(args map[string]any, rt map[string]any) (*ExecResponse, error) {
	status := toInt(getExpr(rt, args["status"], 200))

	headers := map[string]string{}
	if h, ok := args["headers"].(map[string]any); ok {
		for k, v := range h {
			headers[k] = toString(getExpr(rt, v, ""))
		}
	}

	var body any
	if bodyExpr, ok := args["bodyFrom"].(string); ok && strings.HasPrefix(bodyExpr, "$") {
		body = deepCopy(getByPath(rt, toPath(bodyExpr)))
	} else if raw, ok := args["body"]; ok {
		body = deepCopy(raw)
	} else {
		body = map[string]any{}
	}

	return &ExecResponse{
		Status:  status,
		Headers: headers,
		Body:    body,
	}, nil
}
GO

# ==============================================================================
# Step 9: Create Main Gateway Application
# ==============================================================================
echo "[9/9] Write main gateway application"

cat > cmd/artifact-gateway/main.go <<GO
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"${MODULE_NAME}/platform/artifact"
)

func main() {
	repoPath := getEnv("REPO_PATH", "repo")
	addr := getEnv("ADDR", ":8080")
	mode := getEnv("GIN_MODE", "debug")

	gin.SetMode(mode)

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery(), corsMiddleware())

	// Serve repository files for inspection
	r.StaticFS("/repo", http.Dir(repoPath))

	// Load route index
	idx, err := artifact.LoadIndex(repoPath)
	if err != nil {
		log.Fatalf("Failed to load index: %v", err)
	}

	exec := artifact.NewExecutor(repoPath)

	// Register routes
	mock := r.Group("/mock")
	for _, rt := range idx.Routes {
		registerRoute(mock, rt, exec)
	}

	log.Printf("Artifact Gateway listening on %s (repo=%s)", addr, filepath.Clean(repoPath))
	if err := r.Run(addr); err != nil {
		log.Fatal(err)
	}
}

func registerRoute(g *gin.RouterGroup, rt artifact.Route, exec *artifact.Executor) {
	flowFile := rt.Flow
	handler := func(c *gin.Context) {
		handleFlow(c, exec, flowFile)
	}

	switch rt.Method {
	case http.MethodGet:
		g.GET(rt.Path, handler)
	case http.MethodPost:
		g.POST(rt.Path, handler)
	case http.MethodPut:
		g.PUT(rt.Path, handler)
	case http.MethodPatch:
		g.PATCH(rt.Path, handler)
	case http.MethodDelete:
		g.DELETE(rt.Path, handler)
	default:
		log.Printf("Warning: unsupported method %s for path %s", rt.Method, rt.Path)
	}
}

func handleFlow(c *gin.Context, exec *artifact.Executor, flowFile string) {
	req := &artifact.ExecRequest{
		Method:  c.Request.Method,
		Path:    c.FullPath(),
		Headers: extractHeaders(c),
		Query:   c.Request.URL.Query(),
		Params:  extractParams(c),
		Body:    artifact.ReadBodyJSON(c.Request.Body),
	}

	ctx, cancel := context.WithTimeout(c, 10*time.Second)
	defer cancel()

	resp, err := exec.Run(ctx, flowFile, req)
	if err != nil {
		status := 500
		if se, ok := err.(*artifact.StepError); ok {
			status = se.Status
		}
		c.JSON(status, gin.H{
			"error": gin.H{
				"message": err.Error(),
			},
		})
		return
	}

	for k, v := range resp.Headers {
		c.Header(k, v)
	}

	if resp.Body == nil {
		c.Status(resp.Status)
		return
	}

	c.JSON(resp.Status, resp.Body)
}

func extractHeaders(c *gin.Context) map[string]string {
	headers := map[string]string{}
	for k, v := range c.Request.Header {
		if len(v) > 0 {
			headers[k] = v[0]
		}
	}
	return headers
}

func extractParams(c *gin.Context) map[string]string {
	params := map[string]string{}
	for _, p := range c.Params {
		params[p.Key] = p.Value
	}
	return params
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
GO

# ==============================================================================
# Finalize
# ==============================================================================
echo ""
echo "======================================================================"
echo "  Setup Complete!"
echo "======================================================================"
echo ""
echo "Next steps:"
echo "  1. cd ${APP_NAME}"
echo "  2. go mod tidy"
echo "  3. go run cmd/artifact-gateway/main.go"
echo ""
echo "Then test the API:"
echo "  curl http://localhost:8080/mock/v1/users"
echo "  curl http://localhost:8080/mock/v1/users/u_1"
echo ""
echo "======================================================================"
