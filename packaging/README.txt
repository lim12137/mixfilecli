MixFile Windows 加速整合版（MixFile CLI 2.0.13 + dispatch 聚合代理）
=====================================================================

目录内容
  MixFile\              MixFile 命令行版（自带 JRE，无需安装 Java）
  dispatch\             dispatch（Rust 版 dispatch-proxy）多网卡聚合代理
  Start-MixFile.bat     【推荐】一键双网卡聚合启动
  List-Interfaces.bat   查看本机可用网卡列表
  README.txt            本说明

一、普通启动（不走聚合）
  双击 MixFile\MixFile.exe，浏览器打开 http://localhost:4719
  （4719 被占用时会自动换端口，以控制台输出为准）

二、WiFi + 有线 双网卡聚合启动（下载/上传叠加两条线路带宽）
  1. 确认两条线路都已连接且能上网（例如 WiFi + 网线）
  2. 双击 Start-MixFile.bat，它会：
     - 自动检测所有可上网的网卡，等权重分发给 dispatch
     - 启动 dispatch（监听 127.0.0.1:17419，最小化窗口）
     - 通过代理参数启动 MixFile（MixFile 全部流量走 dispatch）
     - 可用网卡不足 2 块时自动回退为普通直连启动
  3. 浏览器打开 http://localhost:4719 正常使用
  4. 用完退出：关闭 MixFile 控制台窗口；dispatch 的最小化窗口可一并关闭

三、原理与说明
  - MixFile 下载采用多连接分块（默认 5 并发，可在 config.yml 调大
    download_task），dispatch 把每条 TCP 连接轮流分发到不同网卡，
    总速度约等于各线路之和；单线程任务只有一条连接，不会加速
  - 聚合启动后 MixFile 依赖 dispatch；若 dispatch 未运行请直接双击
    MixFile\MixFile.exe（直连模式），两种方式互不影响
  - 控制台出现 "Picked up JAVA_TOOL_OPTIONS" 属正常现象
  - dispatch 运行日志写在 dispatch\logs 目录
  - 免责声明：MixFile 与 dispatch 均为开源项目，仅供学习交流
