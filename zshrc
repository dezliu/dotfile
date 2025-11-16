# cdf 命令，通过此命令可以直接打开当前目录的终端
cdf() {
    # 使用AppleScript获取Finder最前面窗口的POSIX路径
    target=$(osascript -e 'tell application "Finder" to if (count of windows) > 0 then get POSIX path of (target of front window as text)')

    # 如果成功获取路径，则切换到该目录
    if [ -n "$target" ]; then
        cd "$target" && echo "切换到目录: $target"
    else
        echo "错误: 未找到打开的Finder窗口。" >&2
    fi
}

# 终端开启vim模式
set -o vi


