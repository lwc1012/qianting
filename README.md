- Main.qml中有前端和均衡算法；serialReader是串口读取代码；voiceController是语音代码
- 使用方法：

1. 用windeployqt appproj1.exe得到程序运行库，再把源码中`.qml`,`.cpp`,`.h`的代码移动到生成的`/qml`下，再运行一次windeployqt appproj1.exe;  
2. 下载Whisper.cpp的Release解压放在项目根目录，重命名为`whisper-blas-bin-x64`;
3. 下载llama.cpp的cuda版Release、cuda运行库，把这两个都放在一个llama-bin文件夹，放在项目根目录
