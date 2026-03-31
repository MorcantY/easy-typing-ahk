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

---

## 流程关系图示
### 执行流程图
```mermaid
graph TD
    A([用户按下标点键]) --> B{当前是中文输入法?}
    B -- 否 --> C([正常输入, 不处理])
    B -- 是 --> D{满足连击条件?}
    
    D -- "否 (第一次按/按太慢)" --> E[记录当前按键为 LastHotkey]
    E --> F([结束本次检测])
    
    D -- "是 (500ms内重复按)" --> G[等待 Shift 键松开]
    G --> H[保存当前 IME 状态]
    H --> I[发送两次 Backspace 擦除中文标点]
    I --> J[通过剪贴板发送英文标点]
    J --> K[恢复 IME 状态]
    K --> L[清空 LastHotkey 记录]
    L --> F
    
    subgraph "连击条件判定"
    D1[1. 当前热键 == 上次记录热键]
    D2[2. 两次按键间隔 < 500ms]
    D3[3. 中途未被其他字母/空格打断]
    end
```

### 类关系图
```mermaid
classDiagram
    class CnEnPunctSwitcher {
        +Config : Array~Object~
        +SymbolMap : Map
        +LastHotkey : String
        +PunctVKMap : Map
        +IH : InputHook
        
        <<Entry Point>>
        +Start()
        +Cleanup()
        
        <<Initialization>>
        -InitializeMaps()
        -SetupInputHook()
        -RegisterHotkeys()
        
        <<Core Logic>>
        -HandleKey(char)
        -SafeSendText(str)
        
        <<Windows API Helpers>>
        -IsIMECnMode(hwnd)
        -GetFocusedHwnd()
        -GetIMEConvMode(hwnd)
        -SendIMEMessage(wParam, lParam, hwnd)
    }

    note for CnEnPunctSwitcher "Static Class: 所有成员均为静态，无需实例化即可运行"
```
