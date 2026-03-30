#Requires AutoHotkey v2.0

; ==============================================================================
;   脚本名称：中英文标点转换器
;   功能说明：在中文输入法下，【连续按两次】标点键，自动将其替换为英文标点。
;           例如：按两次「，」变成「,」，按两次「。」变成「.」。
; ==============================================================================

; 定义一个“类” (Class)，把所有相关的功能和数据都封装在一起
; 这样做的好处是：代码整洁，不污染全局变量，方便维护
class CnEnPunctSwitcher {
    
    ; --------------------------------------------------------------------------
    ;   1. 配置区 (小白唯一可能需要修改的地方)
    ;   格式：{Key: "物理按键", Cn: "中文标点", En: "英文标点"}
    ; --------------------------------------------------------------------------
    static Config := [
        {Key: ",",   Cn: "，", En: ","},      ; 逗号
        {Key: ".",   Cn: "。", En: "."},      ; 句号
        {Key: ";",   Cn: "；", En: ";"},      ; 分号
        {Key: "[",   Cn: "【", En: "["},      ; 左方括号
        {Key: "]",   Cn: "】", En: "]"},      ; 右方括号
        {Key: "\",   Cn: "、", En: "\"},      ; 顿号
        {Key: "``",  Cn: "·",  En: "``"},     ; 间隔号 (注意：AHK中反引号要写两个)
        {Key: "+;",  Cn: "：", En: ":"},      ; 冒号 (+; 表示 Shift+;)
        {Key: "+1",  Cn: "！", En: "!"},      ; 感叹号 (+1 表示 Shift+1)
        {Key: "+/",  Cn: "？", En: "?"},      ; 问号 (+/ 表示 Shift+/)
        {Key: "+9",  Cn: "（", En: "("},      ; 左括号 (+9 表示 Shift+9)
        {Key: "+0",  Cn: "）", En: ")"},      ; 右括号 (+0 表示 Shift+0)
        {Key: "+,",  Cn: "《", En: "<"},      ; 左书名号 (+, 表示 Shift+,)
        {Key: "+.",  Cn: "》", En: ">"}       ; 右书名号 (+. 表示 Shift+.)
    ]

    ; --------------------------------------------------------------------------
    ;   2. 内部状态变量 (这些是脚本运行时的“记忆仓库”)
    ; --------------------------------------------------------------------------
    static SymbolMap := Map()  ; 映射表：用来快速查“中文标点”对应的“英文标点”
    static LastHotkey := ""    ; 记录：上一次按的是哪个热键 (用于判断是否连击)
    static PunctVKSet := ""    ; 集合：存放所有标点键的“身份证号”(虚拟码 VK)
    static IH := ""             ; 监听器：InputHook 对象，用来监听全局键盘动作

    ; --------------------------------------------------------------------------
    ;   3. 启动器 (脚本入口)
    ;   就像汽车的点火开关，按顺序启动各个部件
    ; --------------------------------------------------------------------------
    static Start() {
        this.BuildMap()           ; 第一步：建造“查字典”用的映射表
        this.CollectVK()          ; 第二步：收集所有标点键的“身份证号”
        this.SetupInputHook()     ; 第三步：启动键盘监听器
        this.RegisterHotkeys()    ; 第四步：注册热键 (让按键生效)
    }

    ; --------------------------------------------------------------------------
    ;   4. 构建映射表 (Build Map)
    ;   目的：把 Config 里的数据倒进 SymbolMap，方便以后像查字典一样快速查找
    ; --------------------------------------------------------------------------
    static BuildMap() {
        ; 循环遍历 Config 数组里的每一项
        for item in this.Config {
            ; 例子：SymbolMap["，"] := ","
            this.SymbolMap[item.Cn] := item.En
        }
    }

    ; --------------------------------------------------------------------------
    ;   5. 收集虚拟码 (Collect Virtual Keys)
    ;   目的：我们需要知道哪些键是“标点键”。
    ;        当按下“数字键”或“字母键”时，我们要重置“连击”状态。
    ; --------------------------------------------------------------------------
    static CollectVK() {
        ; 先创建一个临时的 Map 用来去重 (防止同一个按键被加两次)
        physicalKeys := Map()
        
        ; 遍历配置
        for item in this.Config {
            ; 提取纯按键名：比如把 "+;" 变成 ";" (去掉加号，只看物理按键)
            pureKey := StrReplace(item.Key, "+", "")
            
            ; 获取这个按键的“身份证号” (VK 码)
            vkCode := GetKeyVK(pureKey)
            
            ; 如果获取成功，且我们还没记录过这个号码
            if (vkCode && !physicalKeys.Has(vkCode)) {
                physicalKeys[vkCode] := true  ; 在临时 Map 里标记一下“已记录”
                
                ; 把号码存进 PunctVKSet 字符串，格式是 |188|190|...
                ; 这样以后用 InStr 就能快速判断某个键是不是标点键了
                this.PunctVKSet .= "|" vkCode "|"
            }
        }
    }

    ; --------------------------------------------------------------------------
    ;   6. 设置键盘监听器 (Setup InputHook)
    ;   目的：监听整个键盘，一旦发现按了“非标点键”(比如空格、字母)，
    ;        就立刻把“连击状态”清空。
    ; --------------------------------------------------------------------------
    static SetupInputHook() {
        ; 创建一个 InputHook 对象
        ; "V" = Visible (按键照常输出，不拦截)
        ; "L0" = No Limit (不限制输入长度)
        this.IH := InputHook("V L0")
        
        ; 绑定回调函数：意思是“每当有键按下，就去调用 ResetIfNotPunct 函数”
        ; .Bind(this) 是为了让函数里还能认识 this (这个类本身)
        this.IH.OnKeyDown := this.ResetIfNotPunct.Bind(this)
        
        ; 启动监听器
        this.IH.Start()
    }

    ; --------------------------------------------------------------------------
    ;   7. 重置状态的回调函数
    ;   参数 vk：刚刚按下的那个键的“身份证号”
    ; --------------------------------------------------------------------------
    static ResetIfNotPunct(ih, vk, sc) {
        ; 检查：刚刚按下的这个键，不在我们的“标点键身份证列表”里吗？
        if !InStr(this.PunctVKSet, "|" vk "|") {
            ; 如果是“非标点键”(比如按了 3、a、空格 等)，
            ; 就把“上次按键记录”清空。
            ; 这样下次再按标点，就会认为是第一次按，而不是连击。
            this.LastHotkey := ""
        }
    }

    ; --------------------------------------------------------------------------
    ;   8. 注册热键 (Register Hotkeys)
    ;   核心技术：使用 Bind() 解决循环变量的坑
    ; --------------------------------------------------------------------------
    static RegisterHotkeys() {
        ; 遍历配置里的每一项
        for item in this.Config {
            
            ; Hotkey 命令：注册一个热键
            ; 第一个参数："~" 表示“不拦截按键，让它先打出来，我们再处理后续逻辑”
            ; 第二个参数：这是一个“绑定函数对象” (BoundFunc)
            
            ; 【魔法代码】Bind(this, item.Cn)
            ; 意思是：创建一个新的函数。
            ; 当热键被触发时，自动运行 this.HandleKey，
            ; 并且把【当前循环的 item.Cn】(比如 "，") 当作参数【硬塞】进去。
            ; 这样就完美解决了“循环里所有回调都变成最后一个值”的问题。
            Hotkey("~" item.Key, this.HandleKey.Bind(this, item.Cn))
        }
    }

    ; --------------------------------------------------------------------------
    ;   9. 核心转换逻辑 (Handle Key)
    ;   参数 char：通过 Bind 传进来的“中文标点”(如 "，")
    ;   参数 *：忽略热键自带的其他参数
    ; --------------------------------------------------------------------------
    static HandleKey(char, *) {
        ; 第一步：检查当前是不是在【中文输入法】模式下？
        ; 如果不是中文模式，直接退出，不干活
        if !this.IsIMECnMode()
            return

        ; 第二步：判断是不是【快速双击】？
        ; 条件1：上次按的热键 和 这次按的热键 是同一个 (A_PriorHotkey = A_ThisHotkey)
        ; 条件2：两次按键的时间间隔 小于 500毫秒 (0.5秒)
        ; 条件3：我们内部记录的 LastHotkey 也是这个 (防止误判)
        if (A_PriorHotkey = A_ThisHotkey 
            && A_TimeSincePriorHotkey < 500 
            && this.LastHotkey = A_ThisHotkey) {
            
            ; --- 确认是连击，开始替换！ ---
            
            ; 安全检查：如果 Shift 键还没松开，先等它松开
            ; 防止 Shift 键干扰后续操作
            if GetKeyState("Shift", "P")
                KeyWait("Shift")

            ; 保存当前的输入法状态 (等下可能会被 Shift 打乱，要恢复)
            savedMode := this.GetIMEConvMode()

            ; 核心操作1：按两下退格键 (BackSpace)
            ; 因为我们按了两次中文标点，屏幕上现在是 "，，"，
            ; 所以要删掉这两个字符。
            Send("{BackSpace 2}")
            
            ; 核心操作2：发送对应的英文标点
            ; 查字典：this.SymbolMap[char] 就能找到 "，" 对应的 ","
            this.SendText(this.SymbolMap[char])

            ; 恢复刚才保存的输入法状态
            ; (因为有时候按 Shift 会不小心切换中英文，这里给它切回来)
            if (savedMode != -1)
                this.RestoreIMEMode(savedMode)

            ; 收尾：把“上次按键记录”清空，准备迎接下一次输入
            this.LastHotkey := ""
        } else {
            ; --- 不是连击，或者是第一次按 ---
            ; 记录一下：“这次按了这个键”，
            ; 看看 0.5 秒内会不会再按一次。
            this.LastHotkey := A_ThisHotkey
        }
    }

    ; --------------------------------------------------------------------------
    ;   10. 智能发送文本 (Send Text)
    ;   优先用“剪贴板粘贴”(速度快，不依赖键盘布局)，
    ;   如果失败，就降级为“直接打字”(兜底方案)。
    ; --------------------------------------------------------------------------
    static SendText(str) {
        try {
            ; 第一步：保存当前用户剪贴板里的东西 (不能把人家的东西弄丢了)
            savedClip := ClipboardAll()
            
            ; 第二步：把我们要发送的英文标点放进剪贴板
            A_Clipboard := str
            
            ; 等待剪贴板准备好 (最多等 0.5 秒)
            if ClipWait(0.5) {
                ; 发送 Ctrl+V 进行粘贴
                Send("^v")
                ; 稍微等一小会儿，确保有些慢反应的程序能粘贴完
                Sleep 50
            }
            
            ; 第三步：恢复用户原来的剪贴板内容 (做好事不留名)
            A_Clipboard := savedClip
        } catch {
            ; 如果上面的剪贴板大法出错了 (比如在某些禁止粘贴的软件里)，
            ; 就用最原始的方法：直接把文本发送出去
            SendText(str)
        }
    }

    ; --------------------------------------------------------------------------
    ;   底层代码区 (小白可以跳过，这是和 Windows 输入法打交道的黑科技)
    ; --------------------------------------------------------------------------

    ; 检查 IME 是否处于中文模式 (0x400 是 Windows 规定的中文状态标志)
    static IsIMECnMode() {
        mode := this.GetIMEConvMode()
        return (mode != -1 && (mode & 0x400))
    }

    ; 获取当前“真正拥有焦点”的窗口句柄 (有时候焦点在输入框里，不在主窗口)
    static GetFocusedHwnd() {
        if foreHwnd := WinExist("A") {
            size := A_PtrSize == 8 ? 72 : 48
            guiThreadInfo := Buffer(size)
            NumPut("uint", size, guiThreadInfo)
            if DllCall("GetGUIThreadInfo", "uint", DllCall("GetWindowThreadProcessId", "ptr", foreHwnd, "ptr", 0, "uint"), "ptr", guiThreadInfo) {
                if focusedHwnd := NumGet(guiThreadInfo, A_PtrSize == 8 ? 16 : 12, "ptr")
                    return focusedHwnd
            }
            return foreHwnd
        }
        return 0
    }

    ; 获取当前输入法的状态
    static GetIMEConvMode() {
        return this.SendIMEMessage(0x001, 0)
    }

    ; 恢复输入法的状态
    static RestoreIMEMode(savedMode) {
        this.SendIMEMessage(0x002, savedMode)
    }

    ; 给输入法发送消息的底层函数
    static SendIMEMessage(wParam, lParam) {
        static WM_IME_CONTROL := 0x283
        hwnd := this.GetFocusedHwnd()
        imeHwnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
        if !imeHwnd
            return -1
        DllCall("SendMessageTimeoutW", "ptr", imeHwnd, "uint", WM_IME_CONTROL,
            "ptr", wParam, "ptr", lParam, "uint", 0, "uint", 500, "ptr*", &result := 0)
        return result
    }
}

; ==============================================================================
;   脚本真正开始运行的地方！
;   调用上面那个类的 Start() 方法，点火启动！
;   下面的启动函数有可能需要在其他文件中添加
; ==============================================================================
CnEnPunctSwitcher.Start()