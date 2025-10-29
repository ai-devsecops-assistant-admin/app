package artifact

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func readJSONFile(path string) ([]byte, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read file %s: %w", path, err)
	}
	return b, nil
}

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

func evalCondition(expr string, rt map[string]any) (bool, error) {
	expr = strings.TrimSpace(expr)
	if expr == "" {
		return true, nil
	}

	// Simple path existence check
	if strings.HasPrefix(expr, "$") && !strings.Contains(expr, "==") && !strings.Contains(expr, "!=") {
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

	// Negation check
	if strings.HasPrefix(expr, "!") {
		val := getByPath(rt, toPath(strings.TrimPrefix(expr, "!")))
		return val == nil || val == false, nil
	}

	return false, fmt.Errorf("unsupported condition: %s", expr)
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
		err  error
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

func normalizeStrings(v any) []string {
	switch val := v.(type) {
	case nil:
		return nil
	case []string:
		out := make([]string, len(val))
		copy(out, val)
		return out
	case []any:
		out := make([]string, 0, len(val))
		for _, it := range val {
			out = append(out, toString(it))
		}
		return out
	default:
		return []string{toString(val)}
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

// ReadBodyJSON reads request body as JSON map
func ReadBodyJSON(r io.ReadCloser) map[string]any {
	if r == nil {
		return map[string]any{}
	}
	defer func() {
		_ = r.Close()
	}()
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
