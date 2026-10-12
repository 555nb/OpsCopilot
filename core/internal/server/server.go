package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"opscopilot/internal/agent"
	"opscopilot/internal/guardrail"
	"opscopilot/internal/probe"
	"opscopilot/internal/remote"
	"opscopilot/internal/runbook"
)

type Server struct {
	port        int
	agent       *agent.Agent
	hostMgr     *remote.HostManager
	cachedStats *probe.SystemMetrics
	mu          sync.RWMutex
}

func NewServer(port int, ag *agent.Agent) *Server {
	return &Server{
		port:    port,
		agent:   ag,
		hostMgr: remote.NewHostManager(),
	}
}

func (s *Server) enableCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		next(w, r)
	}
}

func (s *Server) Start() error {
	mux := http.NewServeMux()

	mux.HandleFunc("/api/metrics", s.enableCORS(s.handleMetrics))
	mux.HandleFunc("/api/hosts", s.enableCORS(s.handleHosts))
	mux.HandleFunc("/api/runbooks", s.enableCORS(s.handleRunbooks))
	mux.HandleFunc("/api/chat", s.enableCORS(s.handleChat))
	mux.HandleFunc("/api/execute", s.enableCORS(s.handleExecute))
	mux.HandleFunc("/api/guardrail/check", s.enableCORS(s.handleGuardrailCheck))

	go s.metricsCollectorLoop()

	addr := fmt.Sprintf(":%d", s.port)
	fmt.Printf("[OpsCopilot] API 服务已启动，监听地址: http://0.0.0.0:%d\n", s.port)
	return http.ListenAndServe(addr, mux)
}

func (s *Server) metricsCollectorLoop() {
	for {
		m, err := probe.CollectMetrics()
		if err == nil {
			s.mu.Lock()
			s.cachedStats = m
			s.mu.Unlock()
		}
		time.Sleep(3 * time.Second)
	}
}

func (s *Server) handleMetrics(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	m := s.cachedStats
	s.mu.RUnlock()

	if m == nil {
		var err error
		m, err = probe.CollectMetrics()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(m)
}

func (s *Server) handleHosts(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(s.hostMgr.ListHosts())
		return
	}

	if r.Method == http.MethodPost {
		var h remote.RemoteHost
		if err := json.NewDecoder(r.Body).Decode(&h); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		s.hostMgr.AddHost(h)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

func (s *Server) handleRunbooks(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(runbook.GetAllPlaybooks())
}

func (s *Server) handleChat(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Prompt string `json:"prompt"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	s.mu.RLock()
	m := s.cachedStats
	s.mu.RUnlock()
	if m == nil {
		m, _ = probe.CollectMetrics()
	}

	msg, err := s.agent.ProcessQuery(req.Prompt, m)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(msg)
}

func (s *Server) handleExecute(w http.ResponseWriter, r *http.Request) {
	var req struct {
		HostID  string `json:"host_id"`
		Command string `json:"command"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if req.HostID == "" {
		req.HostID = "local"
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	result, err := s.hostMgr.ExecuteCommand(ctx, req.HostID, req.Command)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (s *Server) handleGuardrailCheck(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Command string `json:"command"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	radius := guardrail.AnalyzeCommand(req.Command)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(radius)
}
