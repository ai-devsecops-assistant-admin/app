#!/bin/bash
set -e

REPO_NAME="my-contract-first-template"
echo "🔧 Creating contract-first template: $REPO_NAME"

rm -rf "$REPO_NAME"
mkdir -p "$REPO_NAME"
cd "$REPO_NAME"

cat > README.md << 'EOR'
# 📜 Contract-First Fullstack Template

> 契約驅動 · 克隆即跑 · Mock/Real 雙模式 · 可治理 Flow 引擎

## ✅ 特性
- 🔗 OpenAPI + JSON/YAML 契約為唯一真相
- 🎮 Flow 編排引擎（Go 實作）
- 🧪 內建 CRUD Mock API（GET/POST/:id）
- 🔄 前端支援切換 `mock` / `real` 模式
- 🐳 Docker Compose + Makefile
- 🛡️ CI/CD：校驗契約一致性 + 輕量 E2E 測試

## 🚀 快速啟動
```sh
make dev.up
```

| 服務 | URL |
|------|-----|
| Frontend | http://localhost:4200 |
| Mock API | http://localhost:8787/mock/v1/users |
| Artifact Repo | http://localhost:8787/repo/api/index.json |

## 🛠️ 開發命令
```sh
make gen.openapi     # 生成 OpenAPI 與 TS 型別
make validate.artifact # 校驗 flows/datasets 是否存在
make test.e2e        # 執行輕量 E2E 測試
make dev.down        # 關閉服務
```

## 🌱 使用 degit 初始化新專案
```sh
npx degit your-org/my-contract-first-template my-new-project
cd my-new-project && make init
```
EOR

cat > Makefile << 'EOR'
.PHONY: dev.up dev.down gen.openapi validate.artifact test.e2e init

dev.up:
docker-compose up --build -d

dev.down:
docker-compose down

gen.openapi:
chmod +x scripts/gen-openapi.sh
./scripts/gen-openapi.sh

validate.artifact:
node scripts/validate-artifact.mjs

test.e2e:
chmod +x scripts/test-e2e.sh
./scripts/test-e2e.sh

init:
npm install --prefix web
go mod tidy
EOR

cat > .gitignore << 'EOR'
node_modules/
dist/
*.log
.env
*.tmp
/repo/.runtime/state/*
/go-build
.DS_Store
EOR

mkdir -p repo/api repo/data repo/flows repo/.runtime/state

cat > repo/api/index.json << 'EOR'
{
  "version": "1.0",
  "basePath": "/v1",
  "endpoints": [
    {
      "id": "users.list",
      "method": "GET",
      "path": "/users",
      "flow": "users.list.flow.yaml"
    },
    {
      "id": "users.get",
      "method": "GET",
      "path": "/users/:id",
      "flow": "users.get.flow.yaml"
    },
    {
      "id": "users.create",
      "method": "POST",
      "path": "/users",
      "flow": "users.create.flow.yaml"
    }
  ]
}
EOR

cat > repo/data/seed.users.v1.json << 'EOR'
[
  {
    "id": "u_1",
    "name": "Alice",
    "email": "alice@example.com"
  }
]
EOR

cat > repo/flows/users.list.flow.yaml << 'EOR'
version: 1
name: List Users
steps:
  - id: load
    op: loadDataset
    args:
      dataset: users
    out: allUsers

  - id: paginate
    op: filterAndPaginate
    args:
      source: "$ctx.allUsers"
      page: "$request.query.page"
      size: "$request.query.size"
      q: "$request.query.q"
      fields: ["name", "email"]
      sort: "$request.query.sort"
    out: result

  - op: respond
    args:
      status: 200
      bodyFrom: "$ctx.result"
EOR

cat > repo/flows/users.get.flow.yaml << 'EOR'
version: 1
name: Get User By ID
steps:
  - id: load
    op: loadDataset
    args:
      dataset: users
    out: allUsers

  - id: find
    op: findById
    args:
      source: "$ctx.allUsers"
      id: "$request.params.id"
    out: user

  - op: respond
    when: "$ctx.user != null"
    args:
      status: 200
      bodyFrom: "$ctx.user"

  - op: respond
    when: "$ctx.user == null"
    args:
      status: 404
      body:
        error: "User not found"
EOR

cat > repo/flows/users.create.flow.yaml << 'EOR'
version: 1
name: Create User
steps:
  - op: validateBody
    args:
      schema:
        type: object
        required: [name, email]
        properties:
          name: { type: string, minLength: 1 }
          email: { type: string, format: email }
    onConflict:
      op: respond
      args:
        status: 400
        body:
          error: "$error.message"

  - op: checkUnique
    args:
      source: "$request.dataset.users"
      field: email
      value: "$request.body.email"
    onConflict:
      op: respond
      args:
        status: 409
        body:
          error: "Email already exists"

  - op: assignId
    args:
      prefix: "u_"
    out: newId

  - op: set
    args:
      path: "$request.body.id"
      value: "$ctx.newId"

  - op: insertRecord
    args:
      dataset: users
      record: "$request.body"
    out: saved

  - op: respond
    args:
      status: 201
      bodyFrom: "$ctx.saved"
EOR

mkdir -p cmd/artifact-gateway

cat > cmd/artifact-gateway/main.go << 'EOR'
package main

import (
"log"
"net/http"
"os"

"github.com/gin-gonic/gin"
"my-app/platform/artifact"
)

func main() {
repoPath := os.Getenv("REPO_PATH")
if repoPath == "" {
repoPath = "./repo"
}
basePath := os.Getenv("BASE_PATH")
if basePath == "" {
basePath = "/v1"
}
addr := os.Getenv("GATEWAY_ADDR")
if addr == "" {
addr = ":8787"
}

engine := artifact.NewExecutor(repoPath)

r := gin.Default()
r.Static("/repo", repoPath)

indexFile := repoPath + "/api/index.json"
index, err := artifact.LoadRegistry(indexFile)
if err != nil {
log.Fatal("Failed to load registry:", err)
}

for _, ep := range index.Endpoints {
mockPath := artifact.CleanJoin(basePath, ep.Path)
r.Handle(ep.Method, mockPath, func(def artifact.EndpointDef) gin.HandlerFunc {
return func(c *gin.Context) {
req, err := artifact.NewExecRequestFromGin(c)
if err != nil {
c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
return
}
res, err := engine.Run(c.Request.Context(), def.Flow, req)
if err != nil {
c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
return
}
for k, v := range res.Headers {
c.Header(k, v)
}
c.Data(res.Status, "application/json", res.BodyJSON())
}
}(ep))
log.Printf(" ROUTE %s %s → %s", ep.Method, mockPath, ep.Flow)
}

log.Printf("🚀 Artifact Gateway running on %s (base: %s)", addr, basePath)
if err := r.Run(addr); err != nil {
log.Fatal("Server failed:", err)
}
}
EOR

mkdir -p platform/artifact

cat > platform/artifact/types.go << 'EOR'
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
ID         string                 `json:"id" yaml:"id"`
Op         string                 `json:"op" yaml:"op"`
Args       map[string]any         `json:"args" yaml:"args"`
When       string                 `json:"when,omitempty" yaml:"when,omitempty"`
OnConflict *InlineAction          `json:"onConflict,omitempty" yaml:"onConflict,omitempty"`
Out        string                 `json:"out,omitempty" yaml:"out,omitempty"`
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
}

func NewExecRequestFromGin(c *gin.Context) (*ExecRequest, error) {
params := map[string]string{}
for _, p := range c.Params {
params[p.Key] = p.Value
}
q := map[string][]string(c.Request.URL.Query())
h := map[string][]string{}
for k, v := range c.Request.Header {
if len(v) == 0 {
continue
}
cp := make([]string, len(v))
copy(cp, v)
h[k] = cp
}
body, err := readRequestBodyMap(c.Request.Body)
if err != nil {
return nil, fmt.Errorf("failed to read request body: %w", err)
}
return &ExecRequest{
Method:  c.Request.Method,
Path:    c.FullPath(),
Params:  params,
Query:   q,
Headers: h,
Body:    body,
}, nil
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
EOR

cat > platform/artifact/loader.go << 'EOR'
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
EOR

cat > platform/artifact/utils.go << 'EOR'
package artifact

import (
"bytes"
"encoding/json"
"io"
"os"
"path/filepath"
"strconv"
"strings"
)

func readJSONFile(path string) ([]byte, error) { return os.ReadFile(path) }

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

func deepCopy(v any) any {
b, _ := json.Marshal(v)
var out any
_ = json.Unmarshal(b, &out)
return out
}

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

func toPath(expr string) []string { return strings.Split(strings.TrimPrefix(expr, "$"), ".") }

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

func writeJSONPretty(path string, v any) error {
if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
return err
}
b, err := json.MarshalIndent(v, "", "  ")
if err != nil {
return err
}
return os.WriteFile(path, b, 0644)
}

func evalCondition(expr string, rt map[string]any) (bool, error) {
expr = strings.TrimSpace(expr)
if expr == "" {
return true, nil
}
if strings.Contains(expr, "==") {
parts := strings.Split(expr, "==")
l := getByPath(rt, toPath(strings.TrimSpace(parts[0])))
r := strings.TrimSpace(parts[1])
if r == "null" {
return l == nil, nil
}
return toString(l) == r, nil
}
if strings.Contains(expr, "!=") {
parts := strings.Split(expr, "!=")
l := getByPath(rt, toPath(strings.TrimSpace(parts[0])))
r := strings.TrimSpace(parts[1])
if r == "null" {
return l != nil, nil
}
return toString(l) != r, nil
}
if strings.HasPrefix(expr, "!") {
l := getByPath(rt, toPath(strings.TrimPrefix(expr, "!")))
return l == nil || l == false, nil
}
return false, nil
}

func CleanJoin(base, p string) string {
b := strings.TrimRight(base, "/")
pp := strings.TrimLeft(p, "/")
if b == "" {
return "/" + pp
}
return b + "/" + pp
}

func readRequestBodyMap(r io.Reader) (map[string]any, error) {
if r == nil {
return map[string]any{}, nil
}

var (
data []byte
err error
)

switch rc := r.(type) {
case io.ReadCloser:
defer rc.Close()
data, err = io.ReadAll(rc)
default:
data, err = io.ReadAll(r)
}
if err != nil {
return map[string]any{}, err
}
if len(bytes.TrimSpace(data)) == 0 {
return map[string]any{}, nil
}

var m map[string]any
if err := json.Unmarshal(data, &m); err != nil {
return map[string]any{}, err
}
if m == nil {
m = map[string]any{}
}
return m, nil
}
EOR

cat > platform/artifact/engine.go << 'EOR'
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

func NewExecutor(repoPath string) *Executor { return &Executor{repoPath: repoPath} }

type Executor struct {
repoPath string
}

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
"headers": queryToSimple(req.Headers),
"body":    req.Body,
},
"ctx": map[string]any{},
}

for _, step := range flow.Steps {
select {
case <-ctx.Done():
return nil, ctx.Err()
default:
}

if step.When != "" {
ok, condErr := evalCondition(step.When, rt)
if condErr != nil {
return handleError(step, &StepError{
StepID: step.ID,
Status: 500,
Msg:    "when eval failed: " + condErr.Error(),
})
}
if !ok {
continue
}
}

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
out, err = opAssignId(step.Args)
case "insertRecord":
out, err = opInsertRecord(e.repoPath, step.Args, rt)
case "now":
out, err = opNow()
case "set":
err = opSet(step.Args, rt)
case "respond":
return opRespond(step.Args, rt)
default:
err = fmt.Errorf("unknown op: %s", step.Op)
}

if err != nil {
return handleError(step, err)
}

if step.Out != "" {
ctxMap := rt["ctx"].(map[string]any)
ctxMap[step.Out] = deepCopy(out)
}
}

return &ExecResponse{Status: 204}, nil
}

func handleError(step FlowStep, err error) (*ExecResponse, error) {
var status = 500
var msg = err.Error()

if se, ok := err.(*StepError); ok {
status = se.Status
msg = se.Msg
}

if step.OnConflict != nil && step.OnConflict.Op == "respond" {
return opRespond(step.OnConflict.Args, map[string]any{"error": map[string]any{"message": msg, "status": status}})
}

return nil, &StepError{StepID: step.ID, Status: status, Msg: msg}
}

func opLoadDataset(repoPath string, args map[string]any) (any, error) {
ds := str(args["dataset"])
if ds == "" {
return nil, errors.New("loadDataset requires dataset")
}
statePath := filepath.Join(repoPath, ".runtime", "state", ds+".json")

if b, err := readJSONFile(statePath); err == nil {
var v any
if json.Unmarshal(b, &v) == nil {
return v, nil
}
}

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
return nil, errors.New("filterAndPaginate source must be array")
}

page := max(1, toInt(getExpr(rt, args["page"], 1)))
size := clamp(toInt(getExpr(rt, args["size"], 20)), 1, 100)
q := strings.ToLower(str(getExpr(rt, args["q"], "")))
fields := toStringSlice(args["fields"])
sortBy := str(getExpr(rt, args["sort"], ""))

filtered := make([]map[string]any, 0, len(arr))
for _, it := range arr {
m, ok := toMap(it)
if !ok {
continue
}
if q == "" {
filtered = append(filtered, m)
continue
}
match := false
for _, f := range fields {
if s, ok := m[f].(string); ok && strings.Contains(strings.ToLower(s), q) {
match = true
break
}
}
if match {
filtered = append(filtered, m)
}
}

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

total := len(filtered)
start := (page - 1) * size
if start >= total {
return map[string]any{"items": []any{}, "page": page, "size": size, "total": 0}, nil
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
return nil, errors.New("findById source must be array")
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
return nil, nil
}

func opValidateBody(args map[string]any, rt map[string]any) error {
schemaRaw := args["schema"]
if schemaRaw == nil {
return nil
}

schemaBytes, _ := json.Marshal(schemaRaw)
bodyVal := getByPath(rt, []string{"request", "body"})
if bodyVal == nil {
bodyVal = map[string]any{}
}
bodyBytes, _ := json.Marshal(bodyVal)

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
value := toString(getByPath(rt, toPath(str(args["value"]))))

arr, ok := toSlice(src)
if !ok {
return nil
}

for _, it := range arr {
m, ok := toMap(it)
if !ok {
continue
}
if toString(m[field]) == value {
return &StepError{Status: 409, Msg: "value already exists"}
}
}
return nil
}

func opAssignId(args map[string]any) (any, error) {
prefix := str(args["prefix"])
return prefix + fmt.Sprintf("%d", time.Now().UnixNano()), nil
}

func opInsertRecord(repoPath string, args map[string]any, rt map[string]any) (any, error) {
ds := str(args["dataset"])
record := getByPath(rt, toPath(str(args["record"])))
if ds == "" || record == nil {
return nil, errors.New("insertRecord requires dataset and record")
}

recordMap, ok := toMap(record)
if !ok {
return nil, errors.New("record must be object")
}

path := filepath.Join(repoPath, ".runtime", "state", ds+".json")
var data []any
if b, err := readJSONFile(path); err == nil {
_ = json.Unmarshal(b, &data)
}
data = append(data, recordMap)
if err := writeJSONPretty(path, data); err != nil {
return nil, err
}
return recordMap, nil
}

func opNow() (any, error) {
return time.Now().Format(time.RFC3339), nil
}

func opSet(args map[string]any, rt map[string]any) error {
pathExpr := str(args["path"])
if pathExpr == "" {
return errors.New("set requires path")
}
value := getExpr(rt, args["value"], nil)
setByPath(rt, toPath(pathExpr), value)
return nil
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
} else if raw, ok := args["body"].(map[string]any); ok {
body = deepCopy(raw)
} else {
body = map[string]any{}
}

return &ExecResponse{Status: status, Headers: headers, Body: body}, nil
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

func max(a, b int) int {
if a > b {
return a
}
return b
}

func min(a, b int) int {
if a < b {
return a
}
return b
}

func toStringSlice(v any) []string {
if v == nil {
return nil
}
switch arr := v.(type) {
case []any:
out := make([]string, 0, len(arr))
for _, it := range arr {
out = append(out, toString(it))
}
return out
case []string:
return arr
default:
return nil
}
}
EOR

