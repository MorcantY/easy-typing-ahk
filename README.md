# easy-typing-ahk
[easy-typing-obsidian](https://github.com/Yaozhuwa/easy-typing-obsidian)部分功能的AutoHotkey实现，在所有输入框中享受无缝的中英文标点切换。

窗口检测参考[InputTip](https://github.com/abgox/InputTip)的部分逻辑。
> 几乎完全由AI编写，真正意义上的vibe coding史山。

## 功能说明：
在搜狗/微软输入法中文模式下，【连续按两次】标点键，自动将其替换为英文标点。
例如：按两次「，」变成「,」，按两次「。」变成「.」。
> 其他输入法未测试，若替换失效可修改检测输入法状态的参数后再次尝试运行。

### 自定义
支持在代码开端自定义以下内容：
1. `DOUBLE_CLICK_INTERVAL`连击间隔（毫秒）
2. `IME_CACHE_TIME`IME状态缓存时间（性能优化）
3. `PUNCTUATION_MAP`标点配置表

## 使用方法
### 1. 将`CnEnPunctSwitcher版本号.ahk`（如CnEnPunctSwitcher1.ahk）文件导入已有的AutoHotkey应用。
以导入[MyKeymap](https://github.com/xianyukang/MyKeymap)为例：
1. 将文件`CnEnPunctSwitcher版本号.ahk`放入MyKeymap\data\
2. 修改原有文件`custom_functions.ahk`（参考原有文件内的注释）
   > 添加`#Include ../data/CnEnPunctSwitcher版本号.ahk`至第一行

### 2. 直接使用[AutoHotkey v2](https://www.autohotkey.com/)执行

---

## 流程关系图示
### CnEnPunctSwitcher2.ahk
#### 执行流程图
```mermaid
flowchart TD
    %% =================================================
    %% 1. 启动准备
    %% =================================================
    subgraph Sub_Init ["【1】 启动与准备"]
        direction TB
        Init_Start([程序启动]) --> Init_Load["读取标点配置表<br/>(例如：，对应 ,)"]
        Init_Load --> Init_Monitor["开启后台监听模式"]
    end

    Init_Monitor --> Wait{"等待您按下标点键"}

    %% =================================================
    %% 2. 连击检测
    %% =================================================
    Wait ==>|按下标点键| Main_Check

    subgraph Sub_MainLogic ["【2】 连击行为识别"]
        direction TB
        Main_Check{"<b>是否属于连击?</b><br/>1. 跟上次按键相同<br/>2. 两次间隔 < 0.8秒"}
        
        Main_Check -->|不是| Main_Update["记下本次按键与时间"]
        Main_Update --> Main_ExitSingle([正常输入，不作处理])

        Main_Check -->|是| Main_Update2["准备触发替换逻辑"]
        Main_Update2 --> Call_IME[["检查输入法状态"]]
    end

    %% =================================================
    %% 3. 输入法环境检测
    %% =================================================
    subgraph Sub_IMELogic ["【3】 智能环境确认"]
        direction TB
        IME_Start([开始检测]) --> IME_Cache{"<b>50毫秒内查过吗?</b>"}
        
        IME_Cache -->|是| IME_RetCache[直接沿用上次的结果]
        
        IME_Cache -->|否| IME_RealQuery[询问操作系统：<br/>当前窗口是否在用中文模式?]
        IME_RealQuery --> IME_UpdateCache[更新检测记录]
        IME_UpdateCache --> IME_RetReal[返回检测结果]
    end

    Call_IME ==> IME_Start
    IME_RetCache ==> Main_IMEResult
    IME_RetReal ==> Main_IMEResult

    %% =================================================
    %% 4. 自动替换执行
    %% =================================================
    subgraph Sub_ExecLogic ["【4】 执行自动修正"]
        direction TB
        Main_IMEResult{"当前是<br/>中文输入模式?"}
        
        Main_IMEResult -->|不是| Exec_Exit[保持原样，不处理]
        
        Main_IMEResult -->|是| Exec_BS["自动删除刚输入的<br/>2个中文标点"]
        Exec_BS --> Exec_SendEn["自动补上 1 个<br/>对应的英文标点"]
        Exec_SendEn --> Exec_Anti3["重置记录<br/>(避免第三次敲击误触发)"]
        Exec_Anti3 --> Exec_End([修正完成])
    end

    %% 循环回溯
    Exec_End ==> Wait
    Exec_Exit ==> Wait
    Main_ExitSingle ==> Wait

    %% 样式美化
    classDef init fill:#f0f7ff,stroke:#005a9e,stroke-width:2px;
    classDef main fill:#fffdf0,stroke:#d4a017,stroke-width:2px;
    classDef ime fill:#f2fff2,stroke:#2d882d,stroke-width:2px;
    classDef exec fill:#fff0f5,stroke:#b03060,stroke-width:2px;
    
    class Sub_Init init;
    class Sub_MainLogic main;
    class Sub_IMELogic ime;
    class Sub_ExecLogic exec;
```
---
### CnEnPunctSwitcher1.ahk
#### 执行流程图
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
    I --> J[通过剪贴板发送英文标点<br />（防止被输入法吞字或误触发shift键）]
    J --> K[恢复 IME 状态]
    K --> L[清空 LastHotkey 记录]
    L --> F
    
    subgraph "连击条件判定"
    D1[1. 当前热键 == 上次记录热键]
    D2[2. 两次按键间隔 < 500ms]
    D3[3. 中途未被其他字母/空格打断]
    end
```

#### 类关系图
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
