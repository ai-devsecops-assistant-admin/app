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

	// Convert headers to simple map
	headers := map[string]any{}
	for k, v := range req.Headers {
		if len(v) == 1 {
			headers[k] = v[0]
		} else if len(v) > 1 {
			tmp := make([]any, len(v))
			for i := range v {
				tmp[i] = v[i]
			}
			headers[k] = tmp
		}
	}

	rt := map[string]any{
		"request": map[string]any{
			"method":  req.Method,
			"path":    req.Path,
			"params":  req.Params,
			"query":   queryToSimple(req.Query),
			"headers": headers,
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
	pathExpr := str(args["path"])
	if pathExpr == "" {
		return errors.New("set requires path")
	}
	value := getExpr(rt, args["value"], nil)
	setByPath(rt, toPath(pathExpr), value)
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
	} else if raw, ok := args["body"].(map[string]any); ok {
		body = deepCopy(raw)
	} else {
		body = map[string]any{}
	}

	return &ExecResponse{Status: status, Headers: headers, Body: body}, nil
}
