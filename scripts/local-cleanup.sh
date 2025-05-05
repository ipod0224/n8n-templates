#!/bin/bash

# 顏色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m'

# 設定
REPO_DIR="$HOME/projects/n8n-templates"
WORKFLOWS_DIR="$REPO_DIR/workflows"

echo -e "${BLUE}=== n8n 工作流清理工具 ===${NC}"
cd "$REPO_DIR" || { echo -e "${RED}錯誤: 無法進入工作目錄${NC}"; exit 1; }

# 詢問設定
read -p "要保留多少天內的檔案? [60]: " DAYS
DAYS=${DAYS:-60}

read -p "預覽模式? (y/n) [y]: " PREVIEW
PREVIEW=${PREVIEW:-y}

# 計算閾值日期
if [[ "$OSTYPE" == "darwin"* ]]; then
  THRESHOLD=$(date -v-${DAYS}d +%Y-%m-%d)
else
  THRESHOLD=$(date -d "$DAYS days ago" +%Y-%m-%d)
fi

echo -e "${BLUE}閾值日期: $THRESHOLD${NC}"

# 檢查檔案
for file in "$WORKFLOWS_DIR"/*.json; do
  if [ ! -f "$file" ]; then continue; fi
  
  # 獲取檔案日期
  if [[ "$OSTYPE" == "darwin"* ]]; then
    FILE_DATE=$(stat -f "%Sm" -t "%Y-%m-%d" "$file")
  else
    FILE_DATE=$(stat -c "%y" "$file" | cut -d' ' -f1)
  fi
  
  # 檢查是否過期
  if [[ "$FILE_DATE" < "$THRESHOLD" ]]; then
    if [[ $PREVIEW =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}[預覽] 將刪除: $(basename "$file") (修改於 $FILE_DATE)${NC}"
    else
      echo -e "${RED}刪除: $(basename "$file") (修改於 $FILE_DATE)${NC}"
      rm "$file"
    fi
  fi
done

echo -e "${GREEN}清理完成${NC}"
