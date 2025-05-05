#!/bin/bash

# 設置顏色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# 基本配置
PROJECT_DIR="$HOME/projects/n8n-templates"
LOG_DIR="$PROJECT_DIR/logs"
WORKFLOWS_DIR="$PROJECT_DIR/workflows"
GH_WORKFLOW="$WORKFLOWS_DIR/Generic-GitHub-Import.json"
CRAWLER_WORKFLOW="$WORKFLOWS_DIR/Crawler-JSON-Parser.json"
TIMESTAMP=$(date "+%Y%m%d%H%M%S")
GH_LOG="$LOG_DIR/dryrun-github-import-$TIMESTAMP.log"
CRAWLER_LOG="$LOG_DIR/dryrun-crawler-$TIMESTAMP.log"
SUMMARY_LOG="$LOG_DIR/dryrun-summary-$TIMESTAMP.log"

# Docker 容器設定
N8N_CONTAINER="n8n"
DOCKER_CMD="docker exec -i $N8N_CONTAINER"

# 輔助函數
print_header() { echo -e "\n${BOLD}${BLUE}===== $1 =====${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}! $1${NC}"; }
print_info() { echo -e "${BLUE}i $1${NC}"; }

# 主程序
print_header "n8n 工作流 Dry-run 沙箱驗證 (Docker 版)"
print_info "開始時間: $(date)"

# 創建目錄
mkdir -p "$LOG_DIR"
mkdir -p "$WORKFLOWS_DIR"

# 檢查目錄
cd "$PROJECT_DIR" 2>/dev/null || {
    print_warning "項目目錄不存在！正在創建..."
    mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR" || {
        print_error "無法創建項目目錄"
        exit 1
    }
}
print_success "工作目錄: $(pwd)"

# 檢查 Docker 是否運行
print_header "環境檢查"
if ! command -v docker &>/dev/null; then
    print_error "找不到 docker 命令！請確保 Docker 已安裝"
    exit 1
fi

# 檢查 n8n 容器是否運行
if ! docker ps | grep -q "$N8N_CONTAINER"; then
    print_error "n8n Docker 容器 ($N8N_CONTAINER) 未運行！"
    print_info "運行中的容器列表:"
    docker ps --format "{{.Names}}" | sed 's/^/  - /'
    print_info "請修改腳本中的 N8N_CONTAINER 變數為正確的容器名稱"
    exit 1
else
    print_success "n8n Docker 容器 ($N8N_CONTAINER) 運行中"
fi

# 檢查工作流文件
if [ ! -f "$GH_WORKFLOW" ]; then
    print_warning "GitHub Import 工作流不存在: $GH_WORKFLOW"
    print_info "請確保工作流文件位於正確的位置"
else
    print_success "找到 GitHub Import 工作流"
fi

if [ ! -f "$CRAWLER_WORKFLOW" ]; then
    print_warning "Crawler 工作流不存在: $CRAWLER_WORKFLOW"
    print_info "請確保工作流文件位於正確的位置"
else
    print_success "找到 Crawler 工作流"
fi

# 顯示 Docker 中的 n8n 版本
print_info "檢查 Docker 中的 n8n 版本..."
N8N_VERSION=$($DOCKER_CMD n8n --version 2>/dev/null || echo "無法獲取")
print_info "Docker 中的 n8n 版本: $N8N_VERSION"

# 處理 GitHub Import 工作流
GH_STATUS=1
if [ -f "$GH_WORKFLOW" ]; then
    print_header "執行 GitHub Import 工作流"
    echo "===== 執行環境 =====" > "$GH_LOG"
    echo "執行時間: $(date)" >> "$GH_LOG"
    echo "工作流: $GH_WORKFLOW" >> "$GH_LOG"
    echo "Docker 容器: $N8N_CONTAINER" >> "$GH_LOG"
    echo "===================" >> "$GH_LOG"
    
    print_info "開始執行..."
    # 複製工作流到容器內
    CONTAINER_WORKFLOW="/tmp/Generic-GitHub-Import.json"
    docker cp "$GH_WORKFLOW" "$N8N_CONTAINER:$CONTAINER_WORKFLOW"
    
    # 在容器中執行
    $DOCKER_CMD n8n workflow:run --input="$CONTAINER_WORKFLOW" --skip-nodes-on-fail >> "$GH_LOG" 2>&1
    
    if grep -q "Workflow finished with status \"success\"" "$GH_LOG"; then
        print_success "GitHub Import 工作流驗證成功"
        GH_STATUS=0
    else
        print_error "GitHub Import 工作流驗證失敗"
        print_warning "錯誤摘要:"
        grep -iE "error|exception|failed" "$GH_LOG" | head -n 5
    fi
else
    print_warning "跳過 GitHub Import 工作流驗證 (檔案不存在)"
    echo "跳過驗證 - 檔案不存在" > "$GH_LOG"
fi

# 處理 Crawler 工作流
CRAWLER_STATUS=1
if [ -f "$CRAWLER_WORKFLOW" ]; then
    print_header "執行 Crawler 工作流"
    echo "===== 執行環境 =====" > "$CRAWLER_LOG"
    echo "執行時間: $(date)" >> "$CRAWLER_LOG"
    echo "工作流: $CRAWLER_WORKFLOW" >> "$CRAWLER_LOG"
    echo "Docker 容器: $N8N_CONTAINER" >> "$CRAWLER_LOG"
    echo "===================" >> "$CRAWLER_LOG"
    
    print_info "開始執行..."
    # 複製工作流到容器內
    CONTAINER_WORKFLOW="/tmp/Crawler-JSON-Parser.json"
    docker cp "$CRAWLER_WORKFLOW" "$N8N_CONTAINER:$CONTAINER_WORKFLOW"
    
    # 在容器中執行
    $DOCKER_CMD n8n workflow:run --input="$CONTAINER_WORKFLOW" --skip-nodes-on-fail >> "$CRAWLER_LOG" 2>&1
    
    if grep -q "Workflow finished with status \"success\"" "$CRAWLER_LOG"; then
        print_success "Crawler 工作流驗證成功"
        CRAWLER_STATUS=0
    else
        print_error "Crawler 工作流驗證失敗"
        print_warning "錯誤摘要:"
        grep -iE "error|exception|failed" "$CRAWLER_LOG" | head -n 5
    fi
else
    print_warning "跳過 Crawler 工作流驗證 (檔案不存在)"
    echo "跳過驗證 - 檔案不存在" > "$CRAWLER_LOG"
fi

# 生成結果摘要
print_header "Dry-run 驗證結果摘要"
{
    echo "===== n8n 工作流 Dry-run 驗證結果摘要 ====="
    echo "執行時間: $(date)"
    echo "Docker 容器: $N8N_CONTAINER"
    echo ""
    echo "驗證結果:"
    echo "- GitHub Import: $([ $GH_STATUS -eq 0 ] && echo "通過" || echo "失敗")"
    echo "- Crawler-JSON-Parser: $([ $CRAWLER_STATUS -eq 0 ] && echo "通過" || echo "失敗")"
    echo ""
    echo "日誌檔案位置:"
    echo "- GitHub Import: $GH_LOG"
    echo "- Crawler: $CRAWLER_LOG"
    echo ""
    
    if [ $GH_STATUS -ne 0 ]; then
        echo "===== GitHub Import 錯誤摘要 ====="
        grep -iE "error|exception|failed" "$GH_LOG" | head -n 10
        echo ""
    fi
    
    if [ $CRAWLER_STATUS -ne 0 ]; then
        echo "===== Crawler-JSON-Parser 錯誤摘要 ====="
        grep -iE "error|exception|failed" "$CRAWLER_LOG" | head -n 10
        echo ""
    fi
    
    echo "===== 執行完畢 ====="
} > "$SUMMARY_LOG"

# 顯示結果
echo -e "GitHub Import: $([ $GH_STATUS -eq 0 ] && echo -e "${GREEN}通過${NC}" || echo -e "${RED}失敗${NC}")"
echo -e "Crawler-JSON-Parser: $([ $CRAWLER_STATUS -eq 0 ] && echo -e "${GREEN}通過${NC}" || echo -e "${RED}失敗${NC}")"

# 顯示日誌位置
print_info "日誌檔案位置:"
echo "- GitHub Import: $GH_LOG"
echo "- Crawler: $CRAWLER_LOG"
echo "- 摘要: $SUMMARY_LOG"

# 顯示後續步驟
print_header "後續步驟"
if [ $GH_STATUS -eq 0 ] && [ $CRAWLER_STATUS -eq 0 ]; then
    print_success "所有工作流驗證通過！"
    print_info "您可以進入 1.5 修正錯誤並重驗 步驟，或直接進入後續步驟。"
else
    print_warning "存在驗證失敗的工作流，請先修正後再重新驗證。"
    print_info "建議的後續操作:"
    echo "1. 查看詳細錯誤日誌: cat $SUMMARY_LOG | less"
    echo "2. 修正工作流中的問題"
    echo "3. 重新執行此腳本驗證"
    echo "4. 所有驗證通過後，繼續 1.5 步驟"
fi

print_info "完成時間: $(date)"
exit $(( $GH_STATUS || $CRAWLER_STATUS ))