;gemini 对版本14大幅度改进，改变了逻辑
#Requires AutoHotkey v2.0

; ==============================================================================
;   脚本名称：中英文标点转换器 (优化版)
;   核心功能：在中文输入法状态下，快速连按两次中文标点，自动替换为对应的英文标点。
; ==============================================================================

class CnEnPunctSwitcher {

    ; --------------------------------------------------------------------------
    ;   1. 配置区：定义你想转换的标点符号规则
    ; --------------------------------------------------------------------------
    static Config := [
        ; Key: 键盘上的按键 (带+表示需要按Shift) 
        ; Cn: 输入法默认打出的中文标点
        ; En: 需要转换成的英文标点
        {Key: ",",   Cn: "，", En: ","},      ; 逗号
        {Key: ".",   Cn: "。", En: "."},      ; 句号
        {Key: ";",   Cn: "；", En: ";"},      ; 分号
        ;{Key: "[",   Cn: "【", En: "["},      ; 左方括号 (暂未启用)
        ;{Key: "]",   Cn: "】", En: "]"},      ; 右方括号 (暂未启用)
        {Key: "\",   Cn: "、", En: "\"},      ; 顿号 (中文反斜杠通常是顿号)
        {Key: "``",  Cn: "·",  En: "``"},     ; 间隔号 (键盘左上角的波浪号键)
        {Key: "+;",  Cn: "：", En: ":"},      ; 冒号 (Shift + ;)
        {Key: "+1",  Cn: "！", En: "!"},      ; 感叹号 (Shift + 1)
        {Key: "+/",  Cn: "？", En: "?"},      ; 问号 (Shift + /)
        {Key: "+9",  Cn: "（", En: "("},      ; 左括号 (Shift + 9)
        {Key: "+0",  Cn: "）", En: ")"},      ; 右括号 (Shift + 0)
        {Key: "+,",  Cn: "《", En: "<"},      ; 左书名号 (Shift + ,)
        {Key: "+.",  Cn: "》", En: ">"}       ; 右书名号 (Shift + .)
    ]

    ; --------------------------------------------------------------------------
    ;   2. 内部状态变量：用于脚本运行时的“记忆”
    ; --------------------------------------------------------------------------
    static SymbolMap := Map()    ; 字典：通过中文标点快速查找到对应的英文标点
    static LastHotkey := ""      ; 记忆：你上一次按下的热键是什么（用于判断是否连击）
    static PunctVKMap := Map()   ; 集合：存储所有标点符号的“虚拟键码”(VK)，方便快速查询
    static IH := ""              ; 对象：底层的键盘监听器 (InputHook)

    ; --------------------------------------------------------------------------
    ;   3. 启动器：脚本的入口，按顺序执行初始化步骤
    ; --------------------------------------------------------------------------
    static Start() {
        ; 依次执行三大准备工作，如果有任何一步出错，都会弹窗提示并停止，防止脚本带病运行
        try {
            this.InitializeMaps()  ; 第一步：把上面的配置项转化为脚本好识别的格式
        } catch as e {
            MsgBox("【InitializeMaps 失败】`n" e.Message "`n`n" e.Stack, "CnEnPunctSwitcher 启动错误", "Icon!")
            return
        }

        try {
            this.SetupInputHook()  ; 第二步：启动底层键盘监听，用来打断非连续的按键
        } catch as e {
            MsgBox("【SetupInputHook 失败】`n" e.Message "`n`n" e.Stack, "CnEnPunctSwitcher 启动错误", "Icon!")
            return
        }

        try {
            this.RegisterHotkeys() ; 第三步：正式为你配置的按键注册热键
        } catch as e {
            MsgBox("【RegisterHotkeys 失败】`n" e.Message "`n`n" e.Stack, "CnEnPunctSwitcher 启动错误", "Icon!")
            return
        }
        
        ; 当你右键托盘图标退出脚本时，执行清理工作，释放资源
        OnExit(this.Cleanup.Bind(this))
    }
    
    ; --------------------------------------------------------------------------
    ;   清理回调：退出时关闭键盘监听
    ; --------------------------------------------------------------------------
    static Cleanup(*) {
        if this.IH
            this.IH.Stop()
    }

    ; --------------------------------------------------------------------------
    ;   4. 初始化映射表：将人类可读的配置，转换为机器查找最快的字典
    ; --------------------------------------------------------------------------
    static InitializeMaps() {
        invalidKeys  := []          ; 用来收集写错的配置项

        for item in this.Config {
            ; 建立 中文 -> 英文 的直接映射。比如：SymbolMap["，"] = ","
            this.SymbolMap[item.Cn] := item.En

            ; 去掉配置项里的 "+" 号（比如把 "+;" 变成 ";"），然后获取它的虚拟键码 (VK)
            pureKey := StrReplace(item.Key, "+", "")
            vkCode  := GetKeyVK(pureKey)

            if !vkCode {
                ; 如果系统认不出这个按键，记录下来，稍后统一报错
                invalidKeys.Push("Key='" item.Key "' (pureKey='" pureKey "')")
                continue
            }

            ; 把这个按键的虚拟键码存入集合，标记为 true，代表“这是一个我们要处理的标点键”
            if !this.PunctVKMap.Has(vkCode) {
                this.PunctVKMap[vkCode] := true
            }
        }

        ; 如果配置里有错字，统一弹一次窗告诉你，而不是弹十几个窗烦人
        if invalidKeys.Length > 0 {
            msg := "【InitializeMaps】以下 Config 项的 Key 无法解析为虚拟键码，已跳过：`n`n"
            for entry in invalidKeys
                msg .= "  · " entry "`n"
            MsgBox(msg, "CnEnPunctSwitcher 配置警告", "Icon!")
        }
    }

    ; --------------------------------------------------------------------------
    ;   5. 设置键盘监听器 (InputHook)：这个脚本最精妙的逻辑之一
    ; --------------------------------------------------------------------------
    static SetupInputHook() {
        ; 创建一个底层的键盘钩子。
        ; V: 可见模式（不拦截任何按键，让你正常打字）
        ; L0: 长度为0（坚决不收集你打了什么字，保护隐私且极限节省性能）
        this.IH := InputHook("V L0")
        
        ; 【核心防误触逻辑】：
        ; 默认情况下，InputHook 会监听所有按键。
        ; 这里我们把所有“标点键”的通知给关掉（"-N"）。
        ; 这样一来：
        ; 1. 按标点键时：InputHook 假装没看见，完全交由底下的 HandleKey（热键）处理。
        ; 2. 按其他任何键（如字母、空格）时：InputHook 会立刻察觉，并触发下面的 OnKeyDown。
        for vkCode in this.PunctVKMap {
            this.IH.KeyOpt("{vk" Format("{:X}", vkCode) "}", "-N")
        }
        
        ; 一旦你按下了“非标点键”（比如你在正常打字），立刻清空“上一次按下的热键”记录。
        ; 这完美解决了误触发问题：比如你按了逗号，然后打了几个字母，再按逗号，它就不会被误认为是连击！
        this.IH.OnKeyDown := (ih, vk, sc) => this.LastHotkey := ""
        
        this.IH.Start()
    }

    ; --------------------------------------------------------------------------
    ;   7. 注册热键：让系统知道我们要接管这些标点符号
    ; --------------------------------------------------------------------------
    static RegisterHotkeys() {
        failedKeys := []

        for item in this.Config {
            try {
                ; "~" 符号非常关键：它意味着按键原本的功能不会被屏蔽，你按逗号，屏幕上还是会先打出一个逗号。
                ; 当按下这些键时，去执行 HandleKey 函数，并把对应的“中文标点”当做参数传过去。
                Hotkey("~" item.Key, this.HandleKey.Bind(this, item.Cn))
            } catch as e {
                failedKeys.Push("Key='" item.Key "': " e.Message)
            }
        }

        if failedKeys.Length > 0 {
            msg := "【RegisterHotkeys】以下热键注册失败：`n`n"
            for entry in failedKeys
                msg .= "  · " entry "`n"
            MsgBox(msg, "CnEnPunctSwitcher 热键注册警告", "Icon!")
        }
    }

    ; --------------------------------------------------------------------------
    ;   8. 核心转换逻辑：你每次按下配置好的标点键，都会进到这里
    ; --------------------------------------------------------------------------
    static HandleKey(char, *) {
        ; 获取你当前正在打字的那个窗口的“句柄”（相当于窗口的身份证号）
        ; 在最外层获取一次，避免下面反复去调用底层系统接口，提升响应速度
        hwnd := this.GetFocusedHwnd()
        
        ; 如果当前输入法不是“中文状态”，直接什么都不做，让你正常打英文标点
        if !this.IsIMECnMode(hwnd)
            return

        ; 【连击判定条件】：
        ; 1. 上次按的热键和这次一样 (A_PriorHotkey = A_ThisHotkey)
        ; 2. 两次按键的间隔小于 500 毫秒 (A_TimeSincePriorHotkey < 500)
        ; 3. 这中间没有被其他按键打断过 (this.LastHotkey = A_ThisHotkey)
        if (A_PriorHotkey = A_ThisHotkey 
            && A_TimeSincePriorHotkey < 500 
            && this.LastHotkey = A_ThisHotkey) {

            ; 防御性代码：确保我们要转换的字符确实在字典里
            if !this.SymbolMap.Has(char) {
                MsgBox("【HandleKey】SymbolMap 中找不到字符：'" char "'`n热键：" A_ThisHotkey, "CnEnPunctSwitcher 运行错误", "Icon!")
                this.LastHotkey := ""
                return
            }

            ; 如果你按的是带 Shift 的键（比如问号），先等你的手松开 Shift，不然一会发退格键会变成 Shift+Backspace
            if GetKeyState("Shift", "P")
                KeyWait("Shift")

            ; 记录当前的输入法具体状态，以防万一转换过程中被改变
            savedMode := this.GetIMEConvMode(hwnd)
            
            ; 魔法发生的地方：
            ; 因为你连按了两次标点（且没被拦截），屏幕上其实已经打出了两个中文字符，比如“，，”
            ; 所以我们先发送两次退格键，把它们删掉！
            Send("{BackSpace 2}")
            
            ; 然后把对应的英文标点粘贴上去
            this.SafeSendText(this.SymbolMap[char])

            ; 如果输入法状态刚才有变动，给它恢复原状
            if (savedMode != -1)
                this.RestoreIMEMode(savedMode, hwnd)

            ; 转换完成后，清空记录，等待你的下一次重新连击
            this.LastHotkey := ""
        } else {
            ; 如果条件不满足（比如你是第一次按这个标点，或者按得太慢了），
            ; 就把这次按键记录下来，等下一次按键来看看能不能凑成双击。
            this.LastHotkey := A_ThisHotkey
        }
    }

    ; --------------------------------------------------------------------------
    ;   9. 智能发送文本：利用剪贴板实现“秒贴”，比一个个字母敲要快得多
    ; --------------------------------------------------------------------------
    static SafeSendText(str) {
        try {
            savedClip := ClipboardAll()  ; 先把你电脑剪贴板里原有的东西（比如你刚才复制的图片、文字）妥善保存起来
            A_Clipboard := ""            ; 清空剪贴板，为了给后面的“等待剪贴板变化”提供一个干净的环境
            A_Clipboard := str           ; 把我们的英文标点塞进剪贴板


            if ClipWait(0.5) {           ; 给系统最多0.5秒的时间去处理剪贴板数据
                Send("^v")               ; 按下 Ctrl+V 粘贴出来
                Sleep 50                 ; 稍微睡50毫秒，等系统粘贴动作完成，防止还没贴完我们就把剪贴板恢复了
            } else {
                ; 如果系统太卡，0.5秒都没处理完，我们就放弃剪贴板，使用备选方案：老老实实模拟键盘敲出来
                MsgBox("【SafeSendText】ClipWait 超时，剪贴板未能及时更新。`n将回退至 SendText 发送：'" str "'", "CnEnPunctSwitcher 警告", "Icon!")
                SendText(str)
            }

            A_Clipboard := savedClip     ; 无论如何，最后把你原本的剪贴板内容还给你，不影响你正常使用复制粘贴
        } catch as e {
            ; 万一剪贴板彻底崩溃报错，同样启用备用方案
            MsgBox("【SafeSendText】发生异常，已回退至 SendText。`n`n错误：" e.Message "`n`n" e.Stack, "CnEnPunctSwitcher 运行错误", "Icon!")
            SendText(str)
        }
    }

    ; --------------------------------------------------------------------------
    ;   底层代码区：与 Windows 系统进行深层沟通的 API 接口
    ;   这部分不需要完全弄懂，主要就是用来“偷窥”系统现在的输入法状态
    ; --------------------------------------------------------------------------

    ; 获取输入法是否处于开启状态（0为英文，1为开启输入法）
    static GetIMEOpenStatus(hwnd := 0) {
        return this.SendIMEMessage(0x005, 0, hwnd)  ; IMC_GETOPENSTATUS
    }

    ; 综合判断当前是不是纯正的【中文输入状态】
    static IsIMECnMode(hwnd := 0) {
        mode := this.GetIMEConvMode(hwnd)
        if (mode == -1)
            return false
        
        ; 对于传统的 Win32 程序，0x400 这个标志位非常准，有它就绝对是中文
        if (mode & 0x400)
            return true
            
        ; 对于新型的 TSF 架构程序（比如 Edge 浏览器），0x400 会丢失，我们就退而求其次，看输入法是不是开着的
        if (mode & 0x1)
            return (this.GetIMEOpenStatus(hwnd) == 1)
        return false
    }

    ; 获取当前你光标真正闪烁的那个“输入框”的句柄
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

    ; 获取输入法当前的转换模式（全角/半角、中文/英文等复杂状态的集合）
    static GetIMEConvMode(hwnd := 0) {
        return this.SendIMEMessage(0x001, 0, hwnd)
    }

    ; 强制恢复输入法的转换模式
    static RestoreIMEMode(savedMode, hwnd := 0) {
        this.SendIMEMessage(0x002, savedMode, hwnd)
    }

    ; 核心系统调用：向输入法系统发送底层消息
    static SendIMEMessage(wParam, lParam, hwnd := 0) {
        static WM_IME_CONTROL := 0x283
        if !hwnd
            hwnd := this.GetFocusedHwnd()
            
        ; hwnd == 0 说明当前没有激活的窗口，属于正常情况，直接返回 -1
        if !hwnd
            return -1
        
        ; 拿到负责处理输入法的系统窗口
        imeHwnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
        
        ; 如果拿不到，说明当前程序可能不支持传统输入法探测（TSF应用），交由上层处理
        if !imeHwnd
            return -1
            
        ; 使用 TimeoutW 版本防止卡死：如果系统输入法卡主了，最多等 0.5 秒就放弃，保护脚本不卡死
        DllCall("SendMessageTimeoutW", "ptr", imeHwnd, "uint", WM_IME_CONTROL,
            "ptr", wParam, "ptr", lParam, "uint", 0, "uint", 500, "ptr*", &result := 0)
        return result
    }
}

; ==============================================================================
;   启动脚本
; ==============================================================================
CnEnPunctSwitcher.Start()
