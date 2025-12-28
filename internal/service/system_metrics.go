package service

import (
	"log"
	"runtime"
	"sync"
	"time"
)

// SystemMetricsCollector 系统指标收集器
// Requirements: 9.4 - 添加性能指标收集
type SystemMetricsCollector struct {
	mu                sync.RWMutex
	performanceMonitor *PerformanceMonitor
	collectInterval   time.Duration
	isRunning         bool
	stopChan          chan struct{}
	
	// 网络统计
	networkStats      *NetworkStats
	lastNetworkCheck  time.Time
	
	// 历史数据
	cpuHistory        []float64
	memoryHistory     []int64
	maxHistorySize    int
}

// NetworkStats 网络统计
type NetworkStats struct {
	BytesIn     int64 `json:"bytes_in"`
	BytesOut    int64 `json:"bytes_out"`
	PacketsIn   int64 `json:"packets_in"`
	PacketsOut  int64 `json:"packets_out"`
	LastUpdated time.Time `json:"last_updated"`
}

// SystemSnapshot 系统快照
type SystemSnapshot struct {
	Timestamp       time.Time `json:"timestamp"`
	CPUUsage        float64   `json:"cpu_usage"`
	MemoryUsage     int64     `json:"memory_usage"`
	MemoryPercent   float64   `json:"memory_percent"`
	GoroutineCount  int       `json:"goroutine_count"`
	HeapSize        int64     `json:"heap_size"`
	HeapObjects     uint64    `json:"heap_objects"`
	GCPauseTime     time.Duration `json:"gc_pause_time"`
	GCCount         uint32    `json:"gc_count"`
	NetworkIn       int64     `json:"network_in"`
	NetworkOut      int64     `json:"network_out"`
}

// NewSystemMetricsCollector 创建系统指标收集器
func NewSystemMetricsCollector(performanceMonitor *PerformanceMonitor) *SystemMetricsCollector {
	return &SystemMetricsCollector{
		performanceMonitor: performanceMonitor,
		collectInterval:    30 * time.Second,
		isRunning:          false,
		stopChan:           make(chan struct{}),
		networkStats:       &NetworkStats{},
		lastNetworkCheck:   time.Now(),
		cpuHistory:         make([]float64, 0),
		memoryHistory:      make([]int64, 0),
		maxHistorySize:     100, // 保留最近100个数据点
	}
}

// Start 启动指标收集
func (smc *SystemMetricsCollector) Start() {
	smc.mu.Lock()
	defer smc.mu.Unlock()

	if smc.isRunning {
		return
	}

	smc.isRunning = true
	go smc.collectLoop()
	log.Println("System metrics collector started")
}

// Stop 停止指标收集
func (smc *SystemMetricsCollector) Stop() {
	smc.mu.Lock()
	defer smc.mu.Unlock()

	if !smc.isRunning {
		return
	}

	smc.isRunning = false
	close(smc.stopChan)
	log.Println("System metrics collector stopped")
}

// collectLoop 收集循环
func (smc *SystemMetricsCollector) collectLoop() {
	ticker := time.NewTicker(smc.collectInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			smc.collectMetrics()
		case <-smc.stopChan:
			return
		}
	}
}

// collectMetrics 收集系统指标
func (smc *SystemMetricsCollector) collectMetrics() {
	snapshot := smc.takeSystemSnapshot()
	
	// 不再直接调用性能监控器，避免循环依赖
	// 性能监控器可以通过 GetCurrentSnapshot() 获取数据

	// 更新历史数据
	smc.updateHistory(snapshot)
	
	log.Printf("System metrics collected: CPU=%.1f%%, Memory=%dMB, Goroutines=%d", 
		snapshot.CPUUsage, snapshot.MemoryUsage/(1024*1024), snapshot.GoroutineCount)
}

// takeSystemSnapshot 获取系统快照
func (smc *SystemMetricsCollector) takeSystemSnapshot() *SystemSnapshot {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	snapshot := &SystemSnapshot{
		Timestamp:       time.Now(),
		CPUUsage:        smc.getCPUUsage(),
		MemoryUsage:     int64(m.Alloc),
		MemoryPercent:   smc.getMemoryPercent(int64(m.Alloc)),
		GoroutineCount:  runtime.NumGoroutine(),
		HeapSize:        int64(m.HeapAlloc),
		HeapObjects:     m.HeapObjects,
		GCPauseTime:     time.Duration(m.PauseNs[(m.NumGC+255)%256]),
		GCCount:         m.NumGC,
		NetworkIn:       smc.networkStats.BytesIn,
		NetworkOut:      smc.networkStats.BytesOut,
	}

	return snapshot
}

// getCPUUsage 获取CPU使用率（简化实现）
func (smc *SystemMetricsCollector) getCPUUsage() float64 {
	// 这是一个简化的CPU使用率计算
	// 实际实现应该使用系统调用或第三方库如gopsutil
	
	// 基于Goroutine数量和GC活动的简单估算
	goroutines := runtime.NumGoroutine()
	
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	
	// 简单的启发式算法
	cpuUsage := float64(goroutines) * 0.5
	if m.NumGC > 0 {
		cpuUsage += float64(m.PauseNs[(m.NumGC+255)%256]) / 1000000.0 // 转换为毫秒
	}
	
	// 限制在0-100之间
	if cpuUsage > 100 {
		cpuUsage = 100
	}
	if cpuUsage < 0 {
		cpuUsage = 0
	}
	
	return cpuUsage
}

// getMemoryPercent 获取内存使用百分比（简化实现）
func (smc *SystemMetricsCollector) getMemoryPercent(memoryUsage int64) float64 {
	// 假设系统总内存为4GB（实际应该通过系统调用获取）
	totalMemory := int64(4 * 1024 * 1024 * 1024) // 4GB
	
	percent := float64(memoryUsage) / float64(totalMemory) * 100
	if percent > 100 {
		percent = 100
	}
	
	return percent
}

// updateHistory 更新历史数据
func (smc *SystemMetricsCollector) updateHistory(snapshot *SystemSnapshot) {
	smc.mu.Lock()
	defer smc.mu.Unlock()

	// 更新CPU历史
	smc.cpuHistory = append(smc.cpuHistory, snapshot.CPUUsage)
	if len(smc.cpuHistory) > smc.maxHistorySize {
		smc.cpuHistory = smc.cpuHistory[1:]
	}

	// 更新内存历史
	smc.memoryHistory = append(smc.memoryHistory, snapshot.MemoryUsage)
	if len(smc.memoryHistory) > smc.maxHistorySize {
		smc.memoryHistory = smc.memoryHistory[1:]
	}
}

// GetCurrentSnapshot 获取当前系统快照
func (smc *SystemMetricsCollector) GetCurrentSnapshot() *SystemSnapshot {
	return smc.takeSystemSnapshot()
}

// GetHistoricalData 获取历史数据
func (smc *SystemMetricsCollector) GetHistoricalData() map[string]interface{} {
	smc.mu.RLock()
	defer smc.mu.RUnlock()

	// 计算统计信息
	avgCPU := smc.calculateAverage(smc.cpuHistory)
	maxCPU := smc.calculateMax(smc.cpuHistory)
	minCPU := smc.calculateMin(smc.cpuHistory)

	avgMemory := smc.calculateAverageInt64(smc.memoryHistory)
	maxMemory := smc.calculateMaxInt64(smc.memoryHistory)
	minMemory := smc.calculateMinInt64(smc.memoryHistory)

	return map[string]interface{}{
		"cpu_history": map[string]interface{}{
			"data":    smc.cpuHistory,
			"average": avgCPU,
			"max":     maxCPU,
			"min":     minCPU,
		},
		"memory_history": map[string]interface{}{
			"data":    smc.memoryHistory,
			"average": avgMemory,
			"max":     maxMemory,
			"min":     minMemory,
		},
		"data_points": len(smc.cpuHistory),
		"max_history_size": smc.maxHistorySize,
	}
}

// calculateAverage 计算平均值
func (smc *SystemMetricsCollector) calculateAverage(data []float64) float64 {
	if len(data) == 0 {
		return 0
	}
	
	sum := 0.0
	for _, value := range data {
		sum += value
	}
	
	return sum / float64(len(data))
}

// calculateMax 计算最大值
func (smc *SystemMetricsCollector) calculateMax(data []float64) float64 {
	if len(data) == 0 {
		return 0
	}
	
	max := data[0]
	for _, value := range data {
		if value > max {
			max = value
		}
	}
	
	return max
}

// calculateMin 计算最小值
func (smc *SystemMetricsCollector) calculateMin(data []float64) float64 {
	if len(data) == 0 {
		return 0
	}
	
	min := data[0]
	for _, value := range data {
		if value < min {
			min = value
		}
	}
	
	return min
}

// calculateAverageInt64 计算int64平均值
func (smc *SystemMetricsCollector) calculateAverageInt64(data []int64) int64 {
	if len(data) == 0 {
		return 0
	}
	
	sum := int64(0)
	for _, value := range data {
		sum += value
	}
	
	return sum / int64(len(data))
}

// calculateMaxInt64 计算int64最大值
func (smc *SystemMetricsCollector) calculateMaxInt64(data []int64) int64 {
	if len(data) == 0 {
		return 0
	}
	
	max := data[0]
	for _, value := range data {
		if value > max {
			max = value
		}
	}
	
	return max
}

// calculateMinInt64 计算int64最小值
func (smc *SystemMetricsCollector) calculateMinInt64(data []int64) int64 {
	if len(data) == 0 {
		return 0
	}
	
	min := data[0]
	for _, value := range data {
		if value < min {
			min = value
		}
	}
	
	return min
}

// UpdateNetworkStats 更新网络统计
func (smc *SystemMetricsCollector) UpdateNetworkStats(bytesIn, bytesOut int64) {
	smc.mu.Lock()
	defer smc.mu.Unlock()

	smc.networkStats.BytesIn += bytesIn
	smc.networkStats.BytesOut += bytesOut
	smc.networkStats.LastUpdated = time.Now()
}

// GetNetworkStats 获取网络统计
func (smc *SystemMetricsCollector) GetNetworkStats() *NetworkStats {
	smc.mu.RLock()
	defer smc.mu.RUnlock()

	// 返回副本
	stats := *smc.networkStats
	return &stats
}

// SetCollectInterval 设置收集间隔
func (smc *SystemMetricsCollector) SetCollectInterval(interval time.Duration) {
	smc.mu.Lock()
	defer smc.mu.Unlock()
	
	smc.collectInterval = interval
	log.Printf("System metrics collect interval set to: %v", interval)
}

// IsRunning 检查是否正在运行
func (smc *SystemMetricsCollector) IsRunning() bool {
	smc.mu.RLock()
	defer smc.mu.RUnlock()
	return smc.isRunning
}

// GetCollectInterval 获取收集间隔
func (smc *SystemMetricsCollector) GetCollectInterval() time.Duration {
	smc.mu.RLock()
	defer smc.mu.RUnlock()
	return smc.collectInterval
}

// ForceCollect 强制收集一次指标
func (smc *SystemMetricsCollector) ForceCollect() *SystemSnapshot {
	snapshot := smc.takeSystemSnapshot()
	
	// 不再直接调用性能监控器，避免循环依赖
	// 性能监控器可以通过返回的 snapshot 获取数据

	// 更新历史数据
	smc.updateHistory(snapshot)
	
	log.Printf("Forced system metrics collection: CPU=%.1f%%, Memory=%dMB", 
		snapshot.CPUUsage, snapshot.MemoryUsage/(1024*1024))
	
	return snapshot
}

// ClearHistory 清空历史数据
func (smc *SystemMetricsCollector) ClearHistory() {
	smc.mu.Lock()
	defer smc.mu.Unlock()

	smc.cpuHistory = smc.cpuHistory[:0]
	smc.memoryHistory = smc.memoryHistory[:0]
	
	log.Println("System metrics history cleared")
}