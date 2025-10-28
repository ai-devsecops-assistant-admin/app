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
