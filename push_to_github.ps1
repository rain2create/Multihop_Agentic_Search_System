#Requires -Version 5.1
<#
.SYNOPSIS
    一键推送当前 AgenticRAG 项目到 GitHub
.DESCRIPTION
    自动完成 git init → add → commit → push 的全流程，
    并在推送前检查敏感文件和大文件。
#>

$ErrorActionPreference = "Stop"
$repoUrl = "https://github.com/rain2create/Multihop_Agentic_Search_System.git"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AgenticRAG → GitHub 一键推送脚本" -ForegroundColor Cyan
Write-Host "  目标仓库: $repoUrl" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 0. 检查 git 是否可用 ──────────────────────────────────────────
try {
    $gitVersion = git --version 2>$null
    Write-Host "[OK] Git 已安装: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 未找到 git，请先安装 Git: https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}

# ── 1. 初始化仓库 ────────────────────────────────────────────────
if (Test-Path ".git") {
    Write-Host "[WARN] 当前目录已存在 .git，跳过 init" -ForegroundColor Yellow
} else {
    git init
    Write-Host "[OK] git init 完成" -ForegroundColor Green
}

# ── 2. 配置远程仓库 ──────────────────────────────────────────────
$remotes = git remote -v 2>$null
if ($remotes -match "origin") {
    Write-Host "[WARN] remote 'origin' 已存在，先移除旧配置" -ForegroundColor Yellow
    git remote remove origin
}
git remote add origin $repoUrl
Write-Host "[OK] remote origin 已添加: $repoUrl" -ForegroundColor Green

# ── 3. 敏感文件检查 ──────────────────────────────────────────────
Write-Host ""
Write-Host "--- 敏感文件检查 ---" -ForegroundColor Cyan
$sensitivePatterns = @(".env", ".env.local", "*.pem", "*.key", "id_rsa", "credentials.json")
$sensitiveFound = @()
foreach ($pat in $sensitivePatterns) {
    $matches = Get-ChildItem -Recurse -Filter $pat -ErrorAction SilentlyContinue | Where-Object {
        # 排除 .git 目录
        $_.FullName -notmatch "\\.git\\"
    }
    if ($matches) {
        $sensitiveFound += $matches
    }
}

if ($sensitiveFound.Count -gt 0) {
    Write-Host "[WARN] 发现以下可能包含敏感信息的文件：" -ForegroundColor Yellow
    $sensitiveFound | ForEach-Object { Write-Host "    - $($_.FullName)" -ForegroundColor Yellow }
    Write-Host ""
    $confirm = Read-Host "这些文件是否已确认可以提交？(y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "[ABORT] 请将敏感文件加入 .gitignore 后重试，或手动删除后再执行。" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[OK] 未发现常见敏感文件" -ForegroundColor Green
}

# ── 4. 大文件检查 (> 50MB) ───────────────────────────────────────
Write-Host ""
Write-Host "--- 大文件检查 (>50MB) ---" -ForegroundColor Cyan
$largeFiles = @()
$allFiles = git ls-files 2>$null
if (-not $allFiles) {
    # 如果还没有 tracked files，检查工作区
    $allFiles = Get-ChildItem -Recurse -File | Where-Object {
        $_.FullName -notmatch "\\.git\\" -and
        $_.FullName -notmatch "\\node_modules\\" -and
        $_.FullName -notmatch "\\__pycache__\\"
    } | Select-Object -ExpandProperty FullName
}

foreach ($f in $allFiles) {
    # 统一用相对路径处理
    $relPath = $f -replace [regex]::Escape((Get-Location).Path + "\"), ""
    $fullPath = Join-Path (Get-Location) $relPath
    if (Test-Path $fullPath) {
        $size = (Get-Item $fullPath).Length
        if ($size -gt 50MB) {
            $sizeMB = [math]::Round($size / 1MB, 2)
            $largeFiles += [PSCustomObject]@{ Path = $relPath; SizeMB = $sizeMB }
        }
    }
}

if ($largeFiles.Count -gt 0) {
    Write-Host "[WARN] 发现以下大文件（>50MB），GitHub 单文件限制 100MB：" -ForegroundColor Yellow
    $largeFiles | ForEach-Object { Write-Host "    - $($_.Path) ($($_.SizeMB) MB)" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "建议方案：" -ForegroundColor Yellow
    Write-Host "  A) 将这些文件加入 .gitignore（如索引文件可用脚本重新生成）" -ForegroundColor Yellow
    Write-Host "  B) 安装 Git LFS 管理大文件: git lfs track '*.pkl' '*.index'" -ForegroundColor Yellow
    Write-Host "  C) 如果确认文件 <100MB 且需要提交，直接继续" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "是否继续提交？(y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "[ABORT] 已取消。请处理大文件后重试。" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[OK] 未发现超过 50MB 的大文件" -ForegroundColor Green
}

# ── 5. 添加文件并提交 ────────────────────────────────────────────
Write-Host ""
Write-Host "--- 添加文件到暂存区 ---" -ForegroundColor Cyan
git add .
Write-Host "[OK] git add . 完成" -ForegroundColor Green

# 检查是否有内容需要提交
$status = git status --porcelain
if (-not $status) {
    Write-Host "[WARN] 暂存区为空，没有需要提交的内容（可能都被 .gitignore 排除了）" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "--- 提交更改 ---" -ForegroundColor Cyan
$commitMsg = "Initial commit: AgenticRAG multihop search system"
git commit -m "$commitMsg"
Write-Host "[OK] git commit 完成" -ForegroundColor Green

# ── 6. 推送到 GitHub ─────────────────────────────────────────────
Write-Host ""
Write-Host "--- 推送到 GitHub ---" -ForegroundColor Cyan
git branch -M main

try {
    git push -u origin main
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  推送成功！" -ForegroundColor Green
    Write-Host "  仓库地址: $repoUrl" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "[ERROR] 推送失败: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "常见原因及解决：" -ForegroundColor Yellow
    Write-Host "  1. 未登录 GitHub：请运行 'gh auth login' 或配置 SSH key" -ForegroundColor Yellow
    Write-Host "  2. 仓库不存在：请确认已在 GitHub 创建该仓库" -ForegroundColor Yellow
    Write-Host "  3. 权限不足：确认你对该仓库有写权限" -ForegroundColor Yellow
    exit 1
}
