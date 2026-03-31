# easy-typing
[easy-typing-obsidian](https://github.com/Yaozhuwa/easy-typing-obsidian)部分功能的AutoHotkey实现，在所有输入框中享受无缝的中英文标点切换。
> 几乎完全由AI编写，真正意义上的vibe coding史山。

## 功能说明：
在搜狗输入法中文模式下，【连续按两次】标点键，自动将其替换为英文标点。
例如：按两次「，」变成「,」，按两次「。」变成「.」。

支持自定义符号转换。

## 使用方法
### 将`SymbolFunc.ahk`文件导入已有的AutoHotkey应用。
以导入[MyKeymap](https://github.com/xianyukang/MyKeymap)为例：
1. 将文件`SymbolFunc.ahk`放入MyKeymap\data\
2. 修改原有文件`custom_functions.ahk`（参考原有文件内的注释）
   > 添加`#Include ../data/SymbolFunc.ahk`至第一行

### 直接[AutoHotkey v2](https://www.autohotkey.com/)执行

## 执行流程图
```mermaid
flowchart TD
    A[用户按下标点键] --> B{触发 ~Key 热键}
    B --> C[HandleKey 被调用]
    C --> D[获取并缓存当前窗口 hwnd]
    D --> E{IsIMECnMode 判定<br />是否为中文标点模式?}
    
    E -- 否 --> F[直接退出<br />依赖输入法默认行为]
    E -- 是 --> G{双击条件判定?<br />1. PriorHotkey == ThisHotkey<br />2. 时间差 < 500ms<br />3. LastHotkey == ThisHotkey}
    
    G -- 否 首次单击 --> H[记录 LastHotkey = ThisHotkey<br />退出等待下一次按键]
    G -- 是 连续双击 --> I[防御检查: SymbolMap 是否存在该字符?]
    
    I -- 不存在 --> J[弹窗报错并重置状态]
    I -- 存在 --> K[等待 Shift 键释放 避免冲突]
    K --> L[保存当前 IME ConvMode]
    L --> M[发送 BackSpace 2<br />删除刚刚输入的两个中文标点]
    M --> N[调用 SafeSendText 发送英文标点]
    
    subgraph SafeSendText [SafeSendText 执行细节]
        direction TB
        N1[备份原有剪贴板 ClipboardAll] --> N2[清空并写入英文标点]
        N2 --> N3{ClipWait 0.5s 超时?}
        N3 -- 否 --> N4[Send ^v 粘贴]
        N3 -- 是 --> N5[降级: 使用 SendText 发送]
        N4 --> N6[恢复原有剪贴板]
        N5 --> N6
    end
    
    N --> SafeSendText
    SafeSendText --> O[RestoreIMEMode 恢复输入法状态]
    O --> P[清空 LastHotkey 状态]
    P --> Q[流程结束]

    %% 并行的 InputHook 监控
    R[InputHook 后台持续运行] --> S{按下的键在 PunctVKMap 中?}
    S -- 否 --> T[ResetIfNotPunct 被触发]
    T --> U[清空 LastHotkey<br />打断双击连击链]
    S -- 是 --> V[不干预 等待热键处理]
```
