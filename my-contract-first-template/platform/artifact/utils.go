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
